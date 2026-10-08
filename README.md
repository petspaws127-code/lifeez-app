# Ai Life Assistant — Flutter App

**"Tell it. It remembers it."** — a WhatsApp-first AI life management app.
This is the complete, production-structured Flutter codebase for Android and iOS.

> Source was written without a Flutter SDK on the build machine, so it has
> not been through `flutter analyze`. It follows null-safe Dart 3
> conventions; run `flutter analyze` after setup and fix anything it flags.

---

## 1. Prerequisites

| Need | Why |
|---|---|
| Flutter SDK 3.22+ (`flutter doctor` clean) | Build & run |
| A Supabase account + project | Database, auth, edge functions |
| Google Cloud Console access | Google sign-in OAuth client IDs |
| Apple Developer account ($99/yr) | Apple sign-in + any iOS build |
| Meta for Developers app | Facebook login + WhatsApp Business API |
| A Mac with Xcode | iOS builds only |

---

## 2. First-time setup

```bash
cd flutter_app

# 2a. Generate the android/ and ios/ folders (not committed here)
flutter create --org com.ailifeassistant.app --project-name ai_life_assistant .

# 2b. Get packages
flutter pub get
```

### 2c. Supabase

1. Create a project at https://supabase.com/dashboard.
2. Open the SQL editor and run **`supabase/schema.sql`** (all tables + RLS).
3. Copy your **Project URL** and **anon public key**
   (Project Settings → API) into
   `lib/services/supabase_client.dart` (the two `TODO-PASTE-…` spots).

### 2d. Where every credential goes

| Provider | What to create | Where it goes |
|---|---|---|
| **Supabase** | Project URL + anon key | `lib/services/supabase_client.dart` |
| **Google** | Google Cloud → APIs & Services → Credentials: Android OAuth client (needs SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore`), iOS OAuth client, Web OAuth client. Enable Google in Supabase → Auth → Providers. | `lib/services/auth_service.dart` → `iosClientId`, `serverClientId` |
| **Apple** | Apple Developer → Services ID (e.g. `com.ailifeassistant.app.signin`), configure Sign in with Apple return URL `https://<ref>.supabase.co/auth/v1/callback`. Enable Apple in Supabase → Auth → Providers. | `lib/services/auth_service.dart` → `servicesId`, `redirectUri` |
| **Facebook** | Meta for Developers → app + Facebook Login product. Put the App ID in `android/app/src/main/AndroidManifest.xml` (`com.facebook.sdk.ApplicationId`) and `ios/Runner/Info.plist` (`FacebookAppID`). Enable Facebook in Supabase → Auth → Providers. | Manifest / Info.plist (see TODO in `auth_service.dart`) |
| **WhatsApp login (OTP)** | `supabase functions deploy whatsapp-otp`; `supabase secrets set WHATSAPP_TOKEN=… WHATSAPP_PHONE_NUMBER_ID=…`; create a Meta message template (e.g. `otp_code`) and put its name in the function. | `supabase/functions/whatsapp-otp/index.ts` |
| **WhatsApp inbound chat** | `supabase functions deploy whatsapp-webhook`; set `WHATSAPP_VERIFY_TOKEN`; subscribe the webhook URL in the Meta dashboard. | `supabase/functions/whatsapp-webhook/index.ts` |

Until the TODO credentials are filled, the corresponding login button shows a
clear in-app message naming exactly what is missing — **nothing is faked**.

---

## 3. Run it

```bash
flutter run
```

Login screen shows exactly 4 options (Google, WhatsApp, Apple, Facebook) →
onboarding (name, income, budget) → Home with the WhatsApp command center.

---

## 4. Build the Android APK (no Play Store needed)

```bash
flutter build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk
```

Copy the APK to the phone and install it (allow "install unknown apps").
For a release APK later: create a keystore, add `key.properties`, then
`flutter build apk --release`.

## 5. Build for iPhone (requires Mac + Xcode + Apple Developer Program)

```bash
flutter build ipa
```

Distribute via TestFlight (no public App Store release required for testing).

---

## 6. Project structure

```
lib/
  main.dart                    # entry, providers, named routes
  theme/app_theme.dart          # Poppins theme, ivory/deep-green/gold,
                                # 3D card / gradient-tile decorations
  models/                      # 12 models, fromJson/toJson for Supabase
  services/
    supabase_client.dart        # init (TODO: URL + anon key)
    auth_service.dart           # real Google/Apple/Facebook SDK wiring +
                                # WhatsApp OTP via Edge Function (TODO keys)
    app_state.dart              # all data, Supabase CRUD, computed values,
                                # command execution → assistant replies
    command_parser.dart         # natural-language intent parser
    assistant_engine.dart       # parse → confirm → execute → reply
    whatsapp_service.dart       # connection state + in-app chat
  widgets/
    category_icon.dart          # unique 3D icon tile per category
    ai_input_bar.dart           # text + mic (speech_to_text) + send
    suggestion_card.dart        # contextual AI suggestions
    app_logo.dart               # speech-bubble + checkmark logo tile
    ui_kit.dart                 # section headers, gradient buttons…
  screens/                     # 20 screens (splash → login → onboarding →
                                # home/tabs → whatsapp chat, tasks, money,
                                # calendar, more + 11 feature screens)
supabase/
  schema.sql                    # 15 tables + RLS + new-user trigger
  functions/whatsapp-otp/       # WhatsApp login codes (Cloud API)
  functions/whatsapp-webhook/   # inbound WhatsApp messages
```

## 7. How the "brain" works

`lib/services/command_parser.dart` turns plain text into a `ParsedCommand`
(intent + params): dates ("tomorrow 5pm", "on the 1st", "every day"),
amounts ("$45"), categories, and all spec example commands.
`AssistantEngine` asks "are you sure?" before destructive commands, then
`AppState.executeCommand` performs it and returns the reply. The AI input
bar, AI Assistant screen, and WhatsApp chat all share this engine, so every
screen updates instantly.

Every record shows a **unique 3D icon** via `CategoryIcon` —
`category_icon.dart` maps categories (grocery→cart, rent→house,
transport→car, health→heart…) to gradient tiles.

<!-- Build test 2026-10-08T15:47:35.908863 -->
