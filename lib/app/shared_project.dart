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
  static const projectId = 'lunch-time-712b2';

  static FirebaseOptions get options => Platform.isIOS ? _ios : _android;

  static const _android = FirebaseOptions(
    apiKey: 'AIzaSyB61uwiUQ6paVJUqZ8neqOvM5rpumZLb5k',
    appId: '1:657326771347:android:cc8e08deb8030385581166',
    messagingSenderId: '657326771347',
    projectId: projectId,
    storageBucket: 'lunch-time-712b2.firebasestorage.app',
  );

  static const _ios = FirebaseOptions(
    apiKey: 'AIzaSyCljik7wfmIcrXt1BrUS2_WY6CasiYPUrM',
    appId: '1:657326771347:ios:495f449b00b32646581166',
    messagingSenderId: '657326771347',
    projectId: projectId,
    storageBucket: 'lunch-time-712b2.firebasestorage.app',
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
