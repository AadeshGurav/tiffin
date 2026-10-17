import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';
import '../core/role.dart';
import '../data/access.dart';
import '../data/backend.dart';
import '../data/cache_warmer.dart';
import '../data/store.dart';
import '../domain/menu.dart';
import '../domain/ops.dart';
import 'bootstrap.dart';
import 'firebase_config.dart';

export 'bootstrap.dart' show sharedPreferencesProvider;

// ===========================================================================
// Firebase project — the only thing this build is configured with
// ===========================================================================

/// Development switch: run against the local Firebase emulators
/// (`firebase emulators:start`) instead of a real project. From an Android
/// emulator the host machine is 10.0.2.2; pass EMULATOR_HOST for a phone on
/// the same Wi-Fi.
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');
const _emulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

final firebaseConfigStoreProvider = Provider<FirebaseConfigStore>(
    (ref) => FirebaseConfigStore(ref.read(sharedPreferencesProvider)));

/// The imported config. Null → the "Connect to Firebase" screen.
class FirebaseConfigController extends Notifier<FirebaseConfig?> {
  @override
  FirebaseConfig? build() => _useEmulator
      ? FirebaseConfig.demo
      : ref.read(firebaseConfigStoreProvider).read();

  /// Parses and stores a console config file. Throws a coded
  /// ValidationException for the wrong file, before anything is saved.
  Future<void> import(String content) async {
    final config = FirebaseConfig.parse(content);
    await ref.read(firebaseConfigStoreProvider).write(config);
    state = config;
  }

  /// Forget the project on this phone: sign out, drop the local copy of its
  /// data, and go back to the connect screen. Nothing is deleted in Firebase.
  Future<void> forget() async {
    if (Firebase.apps.isNotEmpty) {
      _firestoreTerminated = true;
      await FirebaseAuth.instance.signOut();
      final db = FirebaseFirestore.instance;
      await db.terminate();
      await db.clearPersistence();
    }
    await ref.read(firebaseConfigStoreProvider).clear();
    state = null;
  }
}

final firebaseConfigProvider =
    NotifierProvider<FirebaseConfigController, FirebaseConfig?>(
        FirebaseConfigController.new);

/// Set once this process has shut its Firestore instance down; a terminated
/// instance can't be used again, even for the same project.
bool _firestoreTerminated = false;

/// True when a project is imported but this process can't serve it: it was
/// started against a different project, or its Firestore was shut down by
/// [FirebaseConfigController.forget]. Firebase's default app can't be
/// re-pointed in place, so the UI asks for a restart instead of half-switching.
final needsRestartProvider = Provider<bool>((ref) {
  final config = ref.watch(firebaseConfigProvider);
  if (config == null || Firebase.apps.isEmpty) return false;
  return _firestoreTerminated ||
      Firebase.app().options.projectId != config.projectId;
});

final firebaseAppProvider = FutureProvider<FirebaseApp>((ref) async {
  final config = ref.watch(firebaseConfigProvider);
  if (config == null) throw StateError('No Firebase project imported');
  if (Firebase.apps.isNotEmpty) return Firebase.app();
  final app = await Firebase.initializeApp(options: config.options);
  // Persistence is what lets a scanner work with no internet (FlutterFire
  // docs: on by default on mobile; set explicitly so it is a decision).
  final db = FirebaseFirestore.instanceFor(app: app)
    ..settings = const Settings(persistenceEnabled: true);
  if (_useEmulator) {
    db.useFirestoreEmulator(_emulatorHost, 8080);
    await FirebaseAuth.instanceFor(app: app)
        .useAuthEmulator(_emulatorHost, 9099);
  }
  return app;
});

final storeProvider = Provider<Store>((ref) {
  final app = ref.watch(firebaseAppProvider).requireValue;
  return Store(FirebaseFirestore.instanceFor(app: app));
});

final accessServiceProvider = Provider<AccessService>((ref) {
  final app = ref.watch(firebaseAppProvider).requireValue;
  return AccessService(
      app, FirebaseAuth.instanceFor(app: app), ref.watch(storeProvider));
});

/// Where this phone stands: signed out, waiting for approval, approved, or
/// signed in online. Live — approval on the admin's phone moves this phone on
/// by itself.
final accessProvider =
    StreamProvider<Access>((ref) => ref.watch(accessServiceProvider).watch());

/// The part of [accessProvider] that decides which data this phone may read:
/// as a phone with a role, as an online account with a role, or not at all.
/// Watching this (not [accessProvider]) keeps the cache and backend from
/// being rebuilt on unrelated device-record changes.
typedef Grant = ({Role role, bool online});

final grantProvider = Provider<Grant?>((ref) {
  return switch (ref.watch(accessProvider).asData?.value) {
    ApprovedDevice(:final device) => (role: device.role, online: false),
    OnlineAccess(:final account) => (role: account.role, online: true),
    _ => null,
  };
});

final cacheWarmerProvider = FutureProvider<CacheWarmer>((ref) async {
  if (ref.watch(grantProvider) == null) throw StateError('Not approved');
  final warmer = CacheWarmer(ref.watch(storeProvider));
  ref.onDispose(warmer.stop);
  await warmer.start();
  return warmer;
});

final syncStateProvider = StreamProvider<SyncState>((ref) async* {
  final warmer = await ref.watch(cacheWarmerProvider.future);
  yield warmer.state;
  yield* warmer.sync;
});

final _scratchDirProvider =
    FutureProvider<Directory>((ref) async => getTemporaryDirectory());

/// The one seam every screen depends on. Ready once the phone is approved and
/// the cache is warm; throws otherwise so a screen can't half-load.
final backendProvider = Provider<Backend>((ref) {
  final grant = ref.watch(grantProvider);
  if (grant == null) throw StateError('Not approved');
  ref.watch(cacheWarmerProvider).requireValue;
  return Backend(
    ref.watch(storeProvider),
    ref.read(sharedPreferencesProvider),
    deviceRole: grant.online ? null : grant.role,
    scratch: ref.watch(_scratchDirProvider).requireValue,
  );
});

/// Everything [backendProvider] needs, as one thing a screen can wait on.
final backendReadyProvider = FutureProvider<void>((ref) async {
  await ref.watch(cacheWarmerProvider.future);
  await ref.watch(_scratchDirProvider.future);
});

/// True while the canteen has no offline accounts, i.e. first-run setup is
/// still owed. Derived on every read, so it is right after a reset too.
final setupRequiredProvider =
    FutureProvider<bool>((ref) => ref.watch(backendProvider).auth.needsSetup());

// ===========================================================================
// Session
// ===========================================================================

class SessionController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() {
    // Watches the grant, not the live access record: an admin editing this
    // phone's name must not sign its operator out.
    final grant = ref.watch(grantProvider);
    if (grant == null || !grant.online) return null;
    // An online account *is* the session: Firebase Auth already signed it in.
    final access = ref.read(accessProvider).asData?.value;
    if (access is! OnlineAccess) return null;
    return ref
        .read(backendProvider)
        .adoptOnline(access.account.email, access.account.role);
  }

  Future<void> login(String username, String password) async {
    state = await ref.read(backendProvider).login(username, password);
  }

  /// Restores a session saved on this phone. False is the cue to show the
  /// sign-in form.
  Future<bool> resumeWithToken(String token) async {
    final session = await ref.read(backendProvider).resumeSession(token);
    if (session == null) return false;
    state = session;
    return true;
  }

  Future<void> logout() async {
    try {
      await ref.read(backendProvider).logout();
      if (ref.read(grantProvider)?.online ?? false) {
        await ref.read(accessServiceProvider).startOver();
      }
    } finally {
      state = null;
    }
  }
}

final sessionProvider =
    NotifierProvider<SessionController, AuthSession?>(SessionController.new);

// ===========================================================================
// Shared reads
// ===========================================================================

/// The menu-category list (Jain / Normal / Staff …). Shared: menu entries and
/// members are both tagged from it.
final menuCategoriesProvider = FutureProvider.autoDispose<List<MenuCategory>>(
    (ref) => ref.watch(backendProvider).listMenuCategories());

/// Re-reads notifications on a cadence once signed in (PRD §6.5.2). Reads
/// are from the warm cache, so this costs no network.
final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) async* {
  final backend = ref.watch(backendProvider);
  if (ref.watch(sessionProvider) == null) {
    yield const [];
    return;
  }
  while (true) {
    try {
      yield await backend.listNotifications();
    } catch (_) {
      yield const [];
    }
    await Future<void>.delayed(AppConfig.notificationPollInterval);
  }
});

final devicesProvider = StreamProvider.autoDispose<List<Device>>(
    (ref) => ref.watch(accessServiceProvider).devices());

final onlineAccountsProvider = StreamProvider.autoDispose<List<OnlineAccount>>(
    (ref) => ref.watch(accessServiceProvider).onlineAccounts());

final onlineAccountsEnabledProvider = FutureProvider.autoDispose<bool>(
    (ref) => ref.watch(backendProvider).onlineAccountsEnabled());
