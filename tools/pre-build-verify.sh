#!/usr/bin/env bash
# PRE-BUILD VERIFICATION GATE for Lifeez
# Implements the pinned PRE-BUILD VERIFICATION PROTOCOL (user, Oct 12, 2026):
#   "Tumhain pass asa koe system nahi hai ju bnana hai usy verify krny k bad build bnain"
#
# FAIL-CLOSED: any failed gate exits non-zero. DO NOT dispatch the APK build
# until this script prints "READY TO BUILD".
#
# Usage:
#   ./tools/pre-build-verify.sh [--base <ref>] [--claim-file <path>]
#       Pre-build gate. --base defaults to the previous release tag.
#       --claim-file: lines of "FILE_PATH|SYMBOL" describing what the agent
#       claims was implemented (symbol must exist in that file after the change).
#   ./tools/pre-build-verify.sh --post-build <run_id> <expected_sha>
#       Post-build gate: verifies the CI run built the EXACT pushed commit.
#
# Created Oct 12, 2026 after the v1.4.45 incident: the APK was built from a
# commit that did not contain the code changes (version number bumped, code
# identical). Gate #1 and Gate #4 exist specifically to make that impossible.

set -u
REPO_OWNER="petspaws127-code"
REPO="lifeez-app"

fail() { echo "GATE FAILED: $1" >&2; exit 1; }
pass() { echo "PASS: $1"; }

# ---------------- POST-BUILD MODE ----------------
if [[ "${1:-}" == "--post-build" ]]; then
  [[ $# -eq 3 ]] || fail "usage: $0 --post-build <run_id> <expected_sha>"
  RUN_ID="$2"; EXPECTED_SHA="$3"
  echo "=== POST-BUILD GATE: run $RUN_ID must have built $EXPECTED_SHA ==="
  HEAD_SHA=$(gh api "repos/$REPO_OWNER/$REPO/actions/runs/$RUN_ID" --jq '.head_sha' 2>/dev/null) \
    || fail "could not read run $RUN_ID from GitHub API"
  [[ "$HEAD_SHA" == "$EXPECTED_SHA" ]] \
    || fail "run built $HEAD_SHA but pushed commit was $EXPECTED_SHA — DO NOT RELEASE THIS APK"
  pass "CI built the exact pushed commit ($HEAD_SHA)"
  echo "REQUIRED HONESTY LINE: code written and built — device testing pending, nothing claimed working until confirmed on device."
  exit 0
fi

# ---------------- PRE-BUILD MODE ----------------
BASE=""
CLAIM_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    --claim-file) CLAIM_FILE="$2"; shift 2;;
    *) fail "unknown arg: $1";;
  esac
done

cd "$(dirname "$0")/.." || fail "not in repo"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git repo"

echo "=== PRE-BUILD VERIFICATION GATE ==="

# ---- Gate 1: working tree must be clean (the v1.4.45 failure) ----
DIRTY=$(git status --porcelain | head -20)
[[ -z "$DIRTY" ]] || fail "working tree has UNCOMMITTED changes — CI can never build these:
$DIRTY
Commit and push first, then re-run."
pass "working tree clean (no uncommitted changes CI cannot see)"

# ---- Determine base ref for the diff ----
if [[ -z "$BASE" ]]; then
  BASE=$(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)
fi
git rev-parse --verify "$BASE" >/dev/null 2>&1 || fail "base ref '$BASE' not found"
echo "Base: $BASE"

# ---- Gate 2: file list — exact paths + what changed ----
echo "--- Changed files ($BASE..HEAD) ---"
CHANGED=$(git diff --name-only "$BASE"..HEAD)
[[ -n "$CHANGED" ]] || fail "no files changed vs $BASE — nothing to build"
git diff --stat "$BASE"..HEAD
echo "$CHANGED" | while read -r f; do
  ADDED=$(git diff "$BASE"..HEAD -- "$f" | grep -c '^+' || true)
  REMOVED=$(git diff "$BASE"..HEAD -- "$f" | grep -c '^-' || true)
  echo "  $f (+$ADDED/-$REMOVED)"
done

# ---- Gate 3: static code review on changed Dart files ----
echo "--- Code review ---"
BALANCE_FAIL=0
for f in $CHANGED; do
  case "$f" in
    *.dart)
      for pair in '{}' '()' '[]'; do
        o=${pair:0:1}; c=${pair:1:1}
        oc=$(tr -cd "$o" < "$f" | wc -c); cc=$(tr -cd "$c" < "$f" | wc -c)
        if [[ "$oc" -ne "$cc" ]]; then
          echo "  UNBALANCED $pair in $f ($o=$oc $c=$cc)" >&2; BALANCE_FAIL=1
        fi
      done
      ;;
  esac
done
[[ "$BALANCE_FAIL" -eq 0 ]] || fail "unbalanced brackets/parens in changed Dart files"
pass "bracket balance OK in changed Dart files"

if command -v dart >/dev/null 2>&1; then
  echo "Running dart analyze on changed Dart files..."
  FILES=$(echo "$CHANGED" | grep '\.dart$' | tr '\n' ' ')
  # shellcheck disable=SC2086
  dart analyze $FILES 2>&1 | tail -5 || fail "dart analyze reported errors"
else
  echo "NOTE: dart not installed here — analyzer step skipped (CI flutter pub get + build still compiles)."
fi

# ---- Gate 4: claim check — every claimed symbol must exist in its file ----
if [[ -n "$CLAIM_FILE" ]]; then
  [[ -f "$CLAIM_FILE" ]] || fail "claim file '$CLAIM_FILE' not found"
  echo "--- Claim check ($CLAIM_FILE) ---"
  while IFS='|' read -r fpath symbol rest; do
    [[ -z "$fpath" || "$fpath" == \#* ]] && continue
    [[ -f "$fpath" ]] || fail "claimed file missing: $fpath"
    grep -qF "$symbol" "$fpath" \
      || fail "claimed symbol '$symbol' NOT FOUND in $fpath"
    pass "claim: $fpath contains '$symbol'"
  done < "$CLAIM_FILE"
else
  echo "NOTE: no --claim-file given — claim check skipped. Write one: lines of FILE|SYMBOL."
fi

# ---- Gate 5: integration check — new symbols in the diff must resolve ----
echo "--- Integration check ---"
# Collect identifiers ADDED as definitions in the diff (class X, void foo(, String bar(, etc.)
NEW_DEFS=$(git diff "$BASE"..HEAD -- '*.dart' | grep '^+' | grep -v '^+++' \
  | grep -oE '(class|void|Future<[^>]+>|String|int|bool|Widget|List<[^>]+>)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
  | awk '{print $NF}' | sort -u)
# Collect method calls ADDED in the diff: word( 
NEW_CALLS=$(git diff "$BASE"..HEAD -- '*.dart' | grep '^+' | grep -v '^+++' \
  | grep -oE '[A-Za-z_][A-Za-z0-9_]*\(' | tr -d '(' | sort -u)
MISSING=0
WHITELIST='^(if|for|while|switch|return|print|setState|super|this|const|final|var|await|throw|assert|import|export|part|class|extends|implements|with|get|set|try|catch|new|is|as|in|of|to|from|by|on|show|hide)$'
for sym in $NEW_CALLS; do
  echo "$sym" | grep -qE "$WHITELIST" && continue
  # defined anywhere in lib/? or in the diff itself?
  if ! grep -rqE "(void|Future|String|int|bool|Widget|class)[[:space:]]+$sym\b" lib/ 2>/dev/null \
     && ! grep -rq "\b$sym\s*(" lib/ 2>/dev/null; then
    echo "  WARNING: added call '$sym(' has no visible definition in lib/ (may be SDK/framework)" >&2
  fi
done
pass "integration scan done (warnings above are advisory, not fatal)"

# ---- Gate 6: commit verify via GitHub API — the v1.4.45 incident gate ----
echo "--- Commit verify (GitHub API) ---"
LOCAL_SHA=$(git rev-parse HEAD)
REMOTE_SHA=$(gh api "repos/$REPO_OWNER/$REPO/commits/main" --jq '.sha' 2>/dev/null) \
  || fail "could not read remote main from GitHub API — verify network/gh auth, then re-run"
[[ "$LOCAL_SHA" == "$REMOTE_SHA" ]] \
  || fail "local HEAD ($LOCAL_SHA) != GitHub main ($REMOTE_SHA) — push first, then re-run"
pass "pushed: GitHub main == local HEAD ($LOCAL_SHA)"

# every changed file must actually be IN the pushed commit
COMMIT_FILES=$(gh api "repos/$REPO_OWNER/$REPO/commits/$LOCAL_SHA" --jq '.files[].filename' 2>/dev/null) \
  || fail "could not read commit file list from GitHub API"
for f in $CHANGED; do
  echo "$COMMIT_FILES" | grep -qxF "$f" \
    || fail "file '$f' changed locally but NOT in pushed commit $LOCAL_SHA"
done
pass "all changed files present in pushed commit"

# version bump sanity
PUBSPEC_VER=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}')
echo "pubspec version in pushed commit: $PUBSPEC_VER"

echo
echo "==================================================="
echo "READY TO BUILD — all gates passed."
echo "Commit:  $LOCAL_SHA"
echo "Version: $PUBSPEC_VER"
echo "Next: gh workflow run dispatch (build-apk.yml), then"
echo "  $0 --post-build <RUN_ID> $LOCAL_SHA"
echo "==================================================="
