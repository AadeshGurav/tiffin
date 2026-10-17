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
- A **Firebase project** (the free Spark plan is enough).

## Setup

```bash
make setup      # flutter pub get + generate the AppText classes
make run        # run on a connected device
make apk        # release APK  ->  build/app/outputs/flutter-apk/app-release.apk
make test       # unit + widget tests
make analyze    # dart analyze --fatal-infos
make rules-test # firestore.rules on the Firestore emulator (Node + Java 17+)
```

Re-run `make l10n` after editing `lib/l10n/*.arb`. `app_en.arb` is the
template; every message with placeholders carries a description for
translators, and `test/l10n_parity_test.dart` fails on missing, unused or
untranslated keys.

## Firebase setup (once per canteen)

1. **Create a project** at <https://console.firebase.google.com>.
2. **Authentication ▸ Sign-in method:** enable **Anonymous** (how phones
   join) and, if you want online accounts, **Email/Password**.
3. **Firestore Database ▸ Create database** (production mode; pick the region
   nearest the canteen, e.g. `asia-south1`).
4. **Deploy the rules and indexes** from this repo:
   ```bash
   npm install -g firebase-tools   # or: npx firebase-tools …
   firebase login
   firebase deploy --only firestore --project <your-project-id>
   ```
5. **Add the app** under Project settings ▸ Your apps and download its config
   file:
   - Android package name **`com.canteen.canteen_coupon`** →
     `google-services.json`
   - iOS bundle ID **`com.aadeshgurav.canteencoupon`** →
     `GoogleService-Info.plist`
6. Put that file on the phone (download, Drive, WhatsApp…) and pick it on the
   app's **Connect to your Firebase project** screen. The first phone becomes
   the canteen's first admin phone.

Don't commit the config file; the app never needs it in source.

**Without a real project**, run against the local emulators:

```bash
firebase emulators:start                 # from the repo root (firebase.json)
flutter run --dart-define=USE_EMULATOR=true
# a phone on the same Wi-Fi instead of an Android emulator:
flutter run --dart-define=USE_EMULATOR=true --dart-define=EMULATOR_HOST=192.168.1.20
```

## Moving an existing (v2, LAN-host) canteen across

On the old app's host phone: **Settings ▸ Backup & restore ▸ Export**. On the
new app's first phone, after starting the canteen: **Bring over existing
records?** on the setup screen, and pick that `.tiffin` file. Members keep
their QR codes (printed cards keep working) and accounts keep their passwords.

## Project layout

```
lib/
  app/            bootstrap, the routing gate, providers, Firebase config import
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
- Android release signing still uses the debug keystore.
- Home-screen icon switching per theme is not wired (the in-app logo follows
  the theme).
