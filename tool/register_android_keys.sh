#!/usr/bin/env bash
# Registers the fingerprints of every key this machine signs Android builds
# with (the debug key, and the release key from android/key.properties) on the
# Firebase Android app. Without them Google sign-in on Android fails, because
# Firebase only finishes the browser sign-in for apps whose signing key it
# knows. Idempotent: keys already registered are left alone.
#
# Needs: keytool (JDK), the Firebase CLI logged in with access to the project.
set -euo pipefail
cd "$(dirname "$0")/.."

# One source of truth for the ids: the config the app itself is built with.
config=lib/app/shared_project.dart
project=$(sed -nE "s/.*projectId = '([^']+)'.*/\1/p" "$config" | head -1)
app_id=$(sed -nE "s/.*appId: '([^']+:android:[^']+)'.*/\1/p" "$config" | head -1)
[[ -n $project && -n $app_id ]] || { echo "Could not read project/app id from $config" >&2; exit 1; }

fingerprints() { # keystore password alias -> "sha1 sha256", lowercase, no colons
  keytool -list -v -keystore "$1" -storepass "$2" -alias "$3" 2>/dev/null |
    sed -nE 's/^[[:space:]]*SHA(1|256):[[:space:]]*([0-9A-F:]+).*/\2/p' |
    tr -d ':' | tr 'A-F' 'a-f'
}

keys=()
debug_ks=$HOME/.android/debug.keystore
if [[ -f $debug_ks ]]; then
  keys+=($(fingerprints "$debug_ks" android androiddebugkey))
else
  echo "No debug keystore yet ($debug_ks); it is created on the first Android build. Re-run after that."
fi

props=android/key.properties
if [[ -f $props ]]; then
  prop() { sed -nE "s/^$1=(.*)$/\1/p" "$props"; }
  keys+=($(fingerprints "$(prop storeFile)" "$(prop storePassword)" "$(prop keyAlias)"))
fi
[[ ${#keys[@]} -gt 0 ]] || { echo "No signing keys found." >&2; exit 1; }

registered=$(firebase apps:android:sha:list "$app_id" --project "$project" --json |
  python3 -c 'import json,sys; t=sys.stdin.read(); print("\n".join(c["shaHash"].lower() for c in json.loads(t[t.index("{"):]).get("result", [])))')

for sha in "${keys[@]}"; do
  if grep -qx "$sha" <<<"$registered"; then
    echo "already registered: $sha"
  else
    firebase apps:android:sha:create "$app_id" "$sha" --project "$project" >/dev/null
    echo "registered:         $sha"
  fi
done
