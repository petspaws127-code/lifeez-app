# PRE-BUILD VERIFICATION PROTOCOL (PINNED)

**User order (Oct 12, 2026):** "Tumhain pass asa koe system nahi hai ju bnana hai usy verify krny k bad build bnain"
— there must be a system that verifies what was built BEFORE the build goes out.

**Mandatory before EVERY Lifeez APK build. No exceptions.**

## The gate

Run the executable gate — it is fail-closed (any failure blocks the build):

```bash
cd ~/workspace/lifeez-app
# 1. Write the claim file: what you claim is implemented (FILE|SYMBOL per line)
cat > /tmp/fixes.txt <<'EOF'
lib/services/app_state.dart|syncOAuthProfile
android/app/src/main/AndroidManifest.xml|READ_MEDIA_IMAGES
lib/screens/pets_screen.dart|PetSelector
EOF
# 2. Commit + push your changes FIRST
git add -A && git commit -m "..." && git push origin main
# 3. Run the gate
./tools/pre-build-verify.sh --claim-file /tmp/fixes.txt
```

The gate enforces, in order:

| # | Gate | What it checks | Why it exists |
|---|------|----------------|---------------|
| 1 | **Clean tree** | `git status` must be clean | v1.4.45 incident: changes sat uncommitted locally; CI can only build what is pushed |
| 2 | **File list** | Exact paths + add/remove counts vs previous release | No silent items, no mystery diffs |
| 3 | **Code review** | Bracket balance per changed Dart file; `dart analyze` when available | Catches broken edits before CI |
| 4 | **Claim check** | Every `FILE\|SYMBOL` in the claim file must exist in that file | "Code written" must be provable, per the strict directive |
| 5 | **Integration scan** | Added calls cross-referenced against definitions in `lib/` | Catches calls to methods that don't exist |
| 6 | **Commit verify (GitHub API)** | `gh api` confirms remote `main` SHA == local HEAD, and every changed file is IN the pushed commit | Proves the changes are actually in the commit CI will build |

Only when it prints **READY TO BUILD** may the workflow be dispatched.

## After CI finishes (post-build)

```bash
./tools/pre-build-verify.sh --post-build <RUN_ID> <PUSHED_SHA>
```

This verifies the CI run built the **exact pushed commit** (`run.head_sha == pushed SHA`).
If it mismatches — **do not release that APK**.

Then the required honesty line goes to the user:

> "Code written and built — device testing pending, nothing claimed working until confirmed on device."

## What this protocol replaced

- v1.4.45 (Oct 12, 2026): the "verification report" cited a commit (`ce9dbda`) that did not
  exist in the repo; the 6 changed files were never committed/pushed; CI built old code
  with a bumped version number. The user installed it and nothing had changed.
- Gates 1 and 6 make that sequence structurally impossible: uncommitted changes abort
  the gate, and the GitHub API check proves the pushed commit contains every file.
