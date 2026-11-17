#!/usr/bin/env bash
# Copies the app's log file from a running iOS simulator or a connected Android
# device (debug/profile builds) to ./app.log and prints the path.
# A real iPhone: use Settings > Share log, or Xcode > Devices > Download Container.
set -euo pipefail

OUT="${1:-app.log}"
IOS_ID=com.aadeshgurav.canteencoupon
ANDROID_ID=com.canteen.canteen_coupon

if command -v adb >/dev/null && [ -n "$(adb devices | sed 1d | grep -w device || true)" ]; then
  adb exec-out run-as "$ANDROID_ID" cat app_flutter/logs/app.log >"$OUT"
elif command -v xcrun >/dev/null && data=$(xcrun simctl get_app_container booted "$IOS_ID" data 2>/dev/null); then
  cp "$data/Documents/logs/app.log" "$OUT"
else
  echo "No Android device or booted iOS simulator running the app." >&2
  echo "On a real iPhone use Settings > Share log, or Xcode > Window > Devices and Simulators > Download Container." >&2
  exit 1
fi
echo "$OUT ($(wc -l <"$OUT") lines)"
