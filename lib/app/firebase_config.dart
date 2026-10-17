import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors.dart';

/// The one setting this build has: which Firebase project to use.
///
/// The operator imports the file the Firebase console hands out for this app
/// — `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) —
/// and it is parsed into [FirebaseOptions] here, so the same build works for
/// any canteen's project. That is why there is no google-services Gradle
/// plugin and no config file in the repository (FlutterFire docs:
/// `Firebase.initializeApp(options: …)` needs neither).
class FirebaseConfig {
  const FirebaseConfig._(this.options);

  final FirebaseOptions options;

  String get projectId => options.projectId;

  /// The app ids this build registers as. They must match the app the file
  /// was downloaded for, or Firebase rejects every call.
  static const androidPackage = 'com.canteen.canteen_coupon';
  static const iosBundleId = 'com.aadeshgurav.canteencoupon';

  static String get thisAppId => Platform.isIOS ? iosBundleId : androidPackage;

  /// Accepts either console file, whichever platform this is: the content
  /// says which it is.
  static FirebaseConfig parse(String content) {
    final trimmed = content.trimLeft();
    final options = trimmed.startsWith('{')
        ? _fromGoogleServicesJson(trimmed)
        : _fromPlist(trimmed);
    return FirebaseConfig._(options);
  }

  static FirebaseOptions _fromGoogleServicesJson(String raw) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      throw const ValidationException(ErrorCode.firebaseConfigUnreadable);
    }
    final project = json['project_info'] as Map<String, dynamic>?;
    final clients = json['client'] as List<dynamic>?;
    if (project == null || clients == null) {
      throw const ValidationException(ErrorCode.firebaseConfigUnreadable);
    }
    final client = clients.cast<Map<String, dynamic>>().where((c) {
      final info = c['client_info'] as Map<String, dynamic>?;
      final android = info?['android_client_info'] as Map<String, dynamic>?;
      return android?['package_name'] == androidPackage;
    }).firstOrNull;
    if (client == null) {
      throw const ValidationException(
          ErrorCode.firebaseConfigWrongApp, {'appId': androidPackage});
    }
    final keys = client['api_key'] as List<dynamic>? ?? const [];
    final apiKey = keys.isEmpty
        ? null
        : (keys.first as Map<String, dynamic>)['current_key'] as String?;
    final appId = (client['client_info']
        as Map<String, dynamic>)['mobilesdk_app_id'] as String?;
    final sender = project['project_number'] as String?;
    final projectId = project['project_id'] as String?;
    if ([apiKey, appId, sender, projectId].contains(null)) {
      throw const ValidationException(ErrorCode.firebaseConfigUnreadable);
    }
    return FirebaseOptions(
      apiKey: apiKey!,
      appId: appId!,
      messagingSenderId: sender!,
      projectId: projectId!,
      storageBucket: project['storage_bucket'] as String?,
    );
  }

  /// The console's plist is a flat `<key>…</key><string>…</string>` dict, so
  /// a pattern read is enough. ponytail: no plist parser dependency; switch
  /// to one if Google ever nests this file.
  static FirebaseOptions _fromPlist(String raw) {
    final values = {
      for (final m in RegExp(r'<key>([^<]+)</key>\s*<string>([^<]*)</string>')
          .allMatches(raw))
        m.group(1)!: m.group(2)!,
    };
    final apiKey = values['API_KEY'];
    final appId = values['GOOGLE_APP_ID'];
    final sender = values['GCM_SENDER_ID'];
    final projectId = values['PROJECT_ID'];
    if ([apiKey, appId, sender, projectId].contains(null)) {
      throw const ValidationException(ErrorCode.firebaseConfigUnreadable);
    }
    if (values['BUNDLE_ID'] != iosBundleId) {
      throw const ValidationException(
          ErrorCode.firebaseConfigWrongApp, {'appId': iosBundleId});
    }
    return FirebaseOptions(
      apiKey: apiKey!,
      appId: appId!,
      messagingSenderId: sender!,
      projectId: projectId!,
      storageBucket: values['STORAGE_BUCKET'],
      iosBundleId: iosBundleId,
    );
  }

  Map<String, String?> toJson() => {
        'apiKey': options.apiKey,
        'appId': options.appId,
        'messagingSenderId': options.messagingSenderId,
        'projectId': options.projectId,
        'storageBucket': options.storageBucket,
        'iosBundleId': options.iosBundleId,
      };

  static FirebaseConfig fromJson(Map<String, dynamic> j) =>
      FirebaseConfig._(FirebaseOptions(
        apiKey: j['apiKey'] as String,
        appId: j['appId'] as String,
        messagingSenderId: j['messagingSenderId'] as String,
        projectId: j['projectId'] as String,
        storageBucket: j['storageBucket'] as String?,
        iosBundleId: j['iosBundleId'] as String?,
      ));
}

/// Where the imported config lives on this phone. Not a secret — every
/// Firebase client config ships inside the app it belongs to — so plain
/// preferences are the right home.
class FirebaseConfigStore {
  FirebaseConfigStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'firebase_config';

  FirebaseConfig? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return FirebaseConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // a corrupt entry means "import again", not a crash
    }
  }

  Future<void> write(FirebaseConfig config) =>
      _prefs.setString(_key, jsonEncode(config.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}
