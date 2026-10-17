import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/app/firebase_config.dart';
import 'package:tiffin/core/errors.dart';

/// The Firebase console's own files are the only configuration this build
/// takes; a wrong or foreign file must say which app id to register.
void main() {
  Map<String, dynamic> googleServices(
          {String pkg = FirebaseConfig.androidPackage}) =>
      {
        'project_info': {
          'project_number': '123456789',
          'project_id': 'canteen-demo',
          'storage_bucket': 'canteen-demo.appspot.com',
        },
        'client': [
          {
            'client_info': {
              'mobilesdk_app_id': '1:123456789:android:abc',
              'android_client_info': {'package_name': pkg},
            },
            'api_key': [
              {'current_key': 'AIzaTest'}
            ],
          }
        ],
      };

  test('google-services.json becomes FirebaseOptions for this app', () {
    final c = FirebaseConfig.parse(jsonEncode(googleServices()));
    expect(c.projectId, 'canteen-demo');
    expect(c.options.appId, '1:123456789:android:abc');
    expect(c.options.apiKey, 'AIzaTest');
    expect(c.options.messagingSenderId, '123456789');
  });

  test('a file for another app names the id to register', () {
    expect(
      () => FirebaseConfig.parse(jsonEncode(googleServices(pkg: 'com.other'))),
      throwsA(isA<ValidationException>()
          .having((e) => e.code, 'code', ErrorCode.firebaseConfigWrongApp)
          .having(
              (e) => e.args['appId'], 'appId', FirebaseConfig.androidPackage)),
    );
  });

  test('GoogleService-Info.plist is read too', () {
    const plist = '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>API_KEY</key><string>AIzaIos</string>
  <key>GCM_SENDER_ID</key><string>123456789</string>
  <key>BUNDLE_ID</key><string>${FirebaseConfig.iosBundleId}</string>
  <key>PROJECT_ID</key><string>canteen-demo</string>
  <key>STORAGE_BUCKET</key><string>canteen-demo.appspot.com</string>
  <key>GOOGLE_APP_ID</key><string>1:123456789:ios:def</string>
</dict></plist>''';
    final c = FirebaseConfig.parse(plist);
    expect(c.options.appId, '1:123456789:ios:def');
    expect(c.options.iosBundleId, FirebaseConfig.iosBundleId);
  });

  test('anything else is refused as unreadable', () {
    for (final junk in ['', 'not a config', '{"hello": 1}']) {
      expect(
          () => FirebaseConfig.parse(junk),
          throwsA(isA<ValidationException>().having(
              (e) => e.code, 'code', ErrorCode.firebaseConfigUnreadable)));
    }
  });

  test('stored config round-trips', () {
    final c = FirebaseConfig.parse(jsonEncode(googleServices()));
    final back = FirebaseConfig.fromJson(c.toJson());
    expect(back.options, c.options);
  });
}
