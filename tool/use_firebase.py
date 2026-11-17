#!/usr/bin/env python3
"""Point the app at a different Firebase project, from the files Firebase gives you.

    make firebase ANDROID=~/Downloads/google-services.json IOS=~/Downloads/GoogleService-Info.plist

Download both from Firebase console > Project settings > Your apps. Either one
alone is fine (the other platform keeps its current values). The script rewrites,
from those files only:

  lib/app/shared_project.dart   the config the app is built with
  .firebaserc                   so `firebase deploy` targets the same project
  ios/Runner/Info.plist         the sign-in return URL scheme (the iOS app id)

It never touches the Android package or iOS bundle id: the files must belong to
the apps in this repo, and it stops if they do not.
"""
import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DART = ROOT / "lib/app/shared_project.dart"
FIREBASERC = ROOT / ".firebaserc"
INFO_PLIST = ROOT / "ios/Runner/Info.plist"
ANDROID_PACKAGE = "com.canteen.canteen_coupon"
IOS_BUNDLE = "com.aadeshgurav.canteencoupon"


def die(message):
    sys.exit(f"error: {message}")


def read_android(path):
    data = json.loads(Path(path).expanduser().read_text())
    client = next(
        (c for c in data["client"]
         if c["client_info"]["android_client_info"]["package_name"] == ANDROID_PACKAGE),
        None,
    )
    if client is None:
        die(f"{path} has no Android app '{ANDROID_PACKAGE}'. Add that app in "
            "Firebase console > Project settings, then download the file again.")
    info = data["project_info"]
    return {
        "projectId": info["project_id"],
        "senderId": info["project_number"],
        "bucket": info.get("storage_bucket", ""),
        "apiKey": client["api_key"][0]["current_key"],
        "appId": client["client_info"]["mobilesdk_app_id"],
    }


def read_ios(path):
    plist = plistlib.loads(Path(path).expanduser().read_bytes())
    if plist["BUNDLE_ID"] != IOS_BUNDLE:
        die(f"{path} is for '{plist['BUNDLE_ID']}', not '{IOS_BUNDLE}'. Add that "
            "iOS app in Firebase console, then download the file again.")
    return {
        "projectId": plist["PROJECT_ID"],
        "senderId": plist["GCM_SENDER_ID"],
        "bucket": plist.get("STORAGE_BUCKET", ""),
        "apiKey": plist["API_KEY"],
        "appId": plist["GOOGLE_APP_ID"],
    }


def current(platform):
    """The values now in shared_project.dart, so a lone file leaves the other side alone."""
    text = DART.read_text()
    block = re.search(rf"static const _{platform} = FirebaseOptions\((.*?)\);", text, re.S).group(1)
    field = lambda name: re.search(rf"{name}: '([^']*)'", block).group(1)
    return {
        "projectId": re.search(r"projectId = '([^']+)'", text).group(1),
        "senderId": field("messagingSenderId"),
        "bucket": field("storageBucket"),
        "apiKey": field("apiKey"),
        "appId": field("appId"),
    }


def options(platform, v, extra=""):
    return (
        f"  static const _{platform} = FirebaseOptions(\n"
        f"    apiKey: '{v['apiKey']}',\n"
        f"    appId: '{v['appId']}',\n"
        f"    messagingSenderId: '{v['senderId']}',\n"
        f"    projectId: projectId,\n"
        f"    storageBucket: '{v['bucket']}',\n{extra}"
        f"  );\n"
    )


def main(args):
    paths = dict(a.split("=", 1) for a in args if "=" in a)
    if not paths.keys() <= {"ANDROID", "IOS"} or not paths:
        die("usage: use_firebase.py ANDROID=<google-services.json> IOS=<GoogleService-Info.plist>")

    android = read_android(paths["ANDROID"]) if "ANDROID" in paths else current("android")
    ios = read_ios(paths["IOS"]) if "IOS" in paths else current("ios")
    if android["projectId"] != ios["projectId"]:
        die(f"Android is project '{android['projectId']}' but iOS is "
            f"'{ios['projectId']}'. Give both files from the same project.")

    text = DART.read_text()
    text = re.sub(r"projectId = '[^']+'", f"projectId = '{android['projectId']}'", text, count=1)
    text = re.sub(r"  static const _android = FirebaseOptions\(.*?\n  \);\n",
                  lambda _: options("android", android), text, count=1, flags=re.S)
    text = re.sub(r"  static const _ios = FirebaseOptions\(.*?\n  \);\n",
                  lambda _: options("ios", ios, f"    iosBundleId: '{IOS_BUNDLE}',\n"),
                  text, count=1, flags=re.S)
    DART.write_text(text)

    FIREBASERC.write_text(json.dumps(
        {"projects": {"default": android["projectId"]}}, indent=2) + "\n")

    scheme = "app-" + ios["appId"].replace(":", "-")
    plist = INFO_PLIST.read_text()
    INFO_PLIST.write_text(re.sub(r"<string>app-[^<]+</string>", f"<string>{scheme}</string>", plist, count=1))

    p = android["projectId"]
    print(f"Now using Firebase project '{p}'. Still to do in that project, once:\n"
          "  1. Authentication > Sign-in method: enable Anonymous, Email/Password, Google\n"
          "  2. Firestore Database: create the '(default)' database\n"
          f"  3. firebase deploy --only firestore --project {p}\n"
          "  4. make android-keys   (registers Android signing keys for Google sign-in)\n"
          "Then rebuild the app. Canteens live inside a project, so a new project starts empty.")


if __name__ == "__main__":
    main(sys.argv[1:])
