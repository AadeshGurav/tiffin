import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';

/// The one shared Firebase project every canteen lives in (ADR 0006). These
/// values identify the app to Firebase and are not secrets — they ship inside
/// every Firebase app; access is enforced by `firestore.rules` and App Check.
///
/// Written by hand from `firebase apps:sdkconfig` rather than
/// `flutterfire configure`, which would also add the google-services Gradle
/// plugin and native files this build does not need.
abstract final class SharedProject {
  static const projectId = 'tiffin-dd7c6';

  static FirebaseOptions get options => Platform.isIOS ? _ios : _android;

  static const _android = FirebaseOptions(
    apiKey: 'AIzaSyBysEFhizIQ6NXfP-I8g8RVp1AgRxm7NQU',
    appId: '1:534390191839:android:ccec29f02558be97499b6a',
    messagingSenderId: '534390191839',
    projectId: projectId,
    storageBucket: 'tiffin-dd7c6.firebasestorage.app',
  );

  static const _ios = FirebaseOptions(
    apiKey: 'AIzaSyDXLwis4oz6Hk4ucR86lJN6nH-Ry3Bdy8M',
    appId: '1:534390191839:ios:e409cf33ab5365c5499b6a',
    messagingSenderId: '534390191839',
    projectId: projectId,
    storageBucket: 'tiffin-dd7c6.firebasestorage.app',
    iosBundleId: 'com.aadeshgurav.canteencoupon',
  );

  /// Development only (`--dart-define=USE_EMULATOR=true`): a `demo-` project
  /// the emulators accept without real config.
  static const demo = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:1:android:1',
    messagingSenderId: '1',
    projectId: 'demo-tiffin',
  );
}
