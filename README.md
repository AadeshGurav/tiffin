# Tiffin — canteen coupon system (v3)

A single-campus canteen tool that issues each student/staff member a permanent
QR code, scans it at meal time for an instant accept/reject, and tracks meal
entitlements as **units** (lunch / breakfast / brunch) — never currency.

**v3 architecture (PRD §15, ADR 0005):** one Flutter app on every phone. Each
phone reads and writes the canteen's own **Firebase** project (Cloud
Firestore) directly and **keeps working offline** — scans included — syncing
when the connection returns. There is no host phone and no LAN server.

- **The only configuration** is the Firebase console's config file for this
  app, imported on first launch. Nothing about any canteen is baked into the
  build.
- **Phones are approved, not trusted by default.** A phone asks to join; an
  admin phone approves it with a role (admin / counter / scanner) that
  `firestore.rules` enforce.
- **Two kinds of account.** Offline accounts (username + password) always work
  with no network; online (email) accounts are an optional Settings toggle.
- **Three languages.** English, Hindi and Marathi, chosen per phone — scan
  verdicts, errors, notifications, the bill and the spreadsheet included.

The full product spec is in [`docs/PRD.md`](docs/PRD.md) (§5–§8 business rules,
§15 architecture). Why things are the way they are, with the alternatives that
were rejected: [`docs/adr/`](docs/adr/). Day-to-day use:
[`docs/USER_GUIDE.md`](docs/USER_GUIDE.md). Themes:
[`docs/THEME_SPEC.md`](docs/THEME_SPEC.md).

## Requirements

- Flutter SDK ≥ 3.24 (Dart ≥ 3.5)
- **Android:** Android SDK + JDK 17. Android 6.0 (API 23) or newer on the
  phone.
- **iOS:** a Mac with Xcode + CocoaPods, iOS 15+.
- The shared **Firebase project** (the free Spark plan is enough to start).

## Setup

```bash
make setup      # flutter pub get + AppText classes + register Android keys
make run        # run on a connected device
make apk        # release APK  ->  build/app/outputs/flutter-apk/app-release.apk
make test       # unit + widget tests
make analyze    # dart analyze --fatal-infos
make rules-test # firestore.rules on the Firestore emulator (Node + Java 17+)
```

Re-run `make l10n` after editing `lib/l10n/*.arb`. `app_en.arb` is the
template; every message with placeholders carries a description for
translators, and `test/l10n/l10n_parity_test.dart` fails on missing, unused or
untranslated keys.

## Firebase setup (once, by the app owner)

Every canteen lives in **one shared Firebase project** that you run (ADR 0006).
Its config is built into the app (`lib/app/shared_project.dart`); a canteen is
created inside the app in one tap.

1. **Authentication ▸ Sign-in method:** enable **Anonymous** (how phones join),
   **Email/Password**, and the providers you offer: **Google**, and optionally
   **Microsoft** (needs an Azure app registration; build with
   `--dart-define=MICROSOFT_SIGN_IN=true`) and **Apple** (paid Apple
   Developer account + the Sign in with Apple capability; build with
   `--dart-define=APPLE_SIGN_IN=true`). Phone sign-in is not built yet.
2. **Firestore Database ▸ Create database** with the ID **`(default)`**,
   Standard edition (a database named `default` is not found by the app).
3. **Deploy the rules and indexes:**
   ```bash
   firebase deploy --only firestore --project lunch-time-712b2
   ```
4. **Apps:** the Android (`com.canteen.canteen_coupon`) and iOS
   (`com.aadeshgurav.canteencoupon`) apps must exist in the project; their
   values are in `lib/app/shared_project.dart`. The Android app also needs
   the SHA fingerprints of every key builds are signed with; see
   [Android signing](#android-signing).
5. **Before a public release:** turn on Firebase **App Check** (App Attest /
   Play Integrity) and enforce it for Firestore and Auth, and watch usage —
   everyone's canteen shares your quota. This is not wired in the app yet.

**Switching to a different Firebase project** (another account, or a fresh
project for testing): download `google-services.json` (Android app) and
`GoogleService-Info.plist` (iOS app) from Project settings ▸ Your apps, then

```bash
make firebase ANDROID=~/Downloads/google-services.json IOS=~/Downloads/GoogleService-Info.plist
```

It rewrites `lib/app/shared_project.dart`, `.firebaserc` and the iOS sign-in
URL scheme, then prints the one-time steps above to repeat in the new project.
Rebuild afterwards. Each project has its own canteens and accounts: nothing
moves across (use Backup & restore for that).

**Without a real project**, run against the local emulators:

```bash
firebase emulators:start                 # from the repo root (firebase.json)
flutter run --dart-define=USE_EMULATOR=true
# a phone on the same Wi-Fi instead of an Android emulator:
flutter run --dart-define=USE_EMULATOR=true --dart-define=EMULATOR_HOST=192.168.1.20
```

## Android signing

Google (and any browser-based) sign-in on Android only works for builds signed
with a key whose SHA-1/SHA-256 is registered on the Firebase Android app. A
new machine has its own debug key, and the release key is separate, so:

```bash
make android-keys   # registers this machine's debug + release keys; safe to re-run
```

`make setup` and `make apk` run it for you. It needs the Firebase CLI logged in
with access to the project. If you build with plain `flutter run` on a new
machine, run it once after the first build creates `~/.android/debug.keystore`.

**Release key.** Release builds are signed with the upload key named in
`android/key.properties` (git-ignored):

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/Users/<you>/.android/lunch-time-upload.jks
```

Without that file, release builds fall back to the debug key. **Back up the
`.jks` and its password** (a password manager): every future update must be
signed with the same key. Publishing on Google Play adds Play's own app-signing
key; copy its fingerprints from Play Console ▸ App integrity into the Firebase
Android app too.

## Moving an existing (v2, LAN-host) canteen across

On the old app's host phone: **Settings ▸ Backup & restore ▸ Export**. On the
new app: **Start a new canteen**, tick **Start from a backup file**, and pick
that `.tiffin` file on the screen that opens. Members keep
their QR codes (printed cards keep working) and accounts keep their passwords.

## Project layout

```
lib/
  app/            bootstrap, the routing gate, providers, shared project, canteen book
  core/           typed error codes, logging, roles, meal windows
  domain/         plain models shared by every layer
  data/
    store.dart        the one doorway to Firestore (cached reads, offline commits)
    cache_warmer.dart keeps the counter's collections synced for offline use
    access.dart       phones, approval, online accounts
    backend.dart      the seam every screen depends on
  services/       business rules (scan, top-up, refund, menu, kitchen, backup…)
  l10n/           ARB files (en/hi/mr), labels for stored values, message wording
  ui/             screens, shared widgets, the four themes (OKLCH tokens)
firestore.rules   the security boundary (tested in tool/rules-test)
```

## Status

- Unit, widget and rules tests green (`make test`, `make rules-test`).
- **Not yet exercised on real hardware** with a live Firebase project. Before
  a shift, check on two phones: approve a phone, scan in airplane mode on
  both, reconnect, and confirm the duplicate is dropped
  (USER_GUIDE §4).
- Home-screen icon switching per theme is not wired (the in-app logo follows
  the theme).
