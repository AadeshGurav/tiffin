.PHONY: setup l10n run apk ios analyze test rules-test format clean doctor icons android-keys firebase logs

# Zero-touch setup (CLAUDE.md §9): one command from a fresh checkout to a
# runnable app. The shared Firebase project is built in
# (lib/app/shared_project.dart); see README "Firebase setup".
setup:
	flutter pub get
	flutter gen-l10n
	-$(MAKE) android-keys

# Register this machine's Android signing keys (debug + release) in Firebase.
# Google sign-in on Android fails for any build signed with a key Firebase
# does not know. Safe to re-run; setup and apk do it for you.
android-keys:
	tool/register_android_keys.sh

# Switch the app to another Firebase project from the files its console gives
# you (Project settings > Your apps):
#   make firebase ANDROID=~/Downloads/google-services.json IOS=~/Downloads/GoogleService-Info.plist
firebase:
	python3 tool/use_firebase.py $(if $(ANDROID),ANDROID=$(ANDROID)) $(if $(IOS),IOS=$(IOS))

# Copy the app's log file from the running simulator / Android device to
# ./app.log (docs/LOGGING.md). `make logs OUT=x.log` to pick the name.
logs:
	tool/pull_logs.sh $(OUT)

# Regenerate the AppText classes after editing an .arb file.
l10n:
	flutter gen-l10n

# Run on a connected Android device / emulator.
run:
	flutter run

# Build the release APK.
apk: android-keys
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
