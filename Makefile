.PHONY: setup l10n run apk ios analyze test rules-test format clean doctor icons

# Zero-touch setup (CLAUDE.md §9): one command from a fresh checkout to a
# runnable app. The Firebase project is not configured here — the app asks
# for its config file on first launch (README "Firebase setup").
setup:
	flutter pub get
	flutter gen-l10n

# Regenerate the AppText classes after editing an .arb file.
l10n:
	flutter gen-l10n

# Run on a connected Android device / emulator.
run:
	flutter run

# Build the release APK.
apk:
	flutter build apk --release

# Build the iOS app (needs full Xcode + CocoaPods). Signing is set in Xcode.
ios:
	flutter build ios --release

# Regenerate the per-theme launcher icons from the app's own painter, then
# rebuild the native icon sets. Run after changing a theme's palette or shape.
icons:
	flutter test test/generate_icons_test.dart --tags tool
	dart run flutter_launcher_icons

analyze:
	dart analyze --fatal-infos

test:
	flutter test --exclude-tags tool

# firestore.rules on the Firestore emulator (needs Node and Java 17+).
rules-test:
	cd tool/rules-test && npm install --no-audit --no-fund && npm test

format:
	dart format lib test

doctor:
	flutter doctor -v

clean:
	flutter clean
