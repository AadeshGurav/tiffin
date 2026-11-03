import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../core/role.dart';
import 'store.dart';

/// Where this phone stands with the canteen. Drives the whole routing
/// decision before anyone signs in (see `AppGate`).
sealed class Access {
  const Access();
}

/// No Firebase identity on this phone yet.
class SignedOut extends Access {
  const SignedOut();
}

/// Has an identity but no device record in this canteen — first join, or after starting over.
class NotJoined extends Access {
  const NotJoined();
}

class PendingApproval extends Access {
  const PendingApproval(this.device);
  final Device device;
}

class Removed extends Access {
  const Removed(this.device);
  final Device device;
}

/// An approved phone. Offline accounts sign in on it, capped at [Device.role].
class ApprovedDevice extends Access {
  const ApprovedDevice(this.device);
  final Device device;
}

/// Signed in with an online (email) account.
class OnlineAccess extends Access {
  const OnlineAccess(this.account);
  final OnlineAccount account;
}

/// Signed in with an online account the admin has not approved, or has turned off.
class OnlineRefused extends Access {
  const OnlineRefused(this.email, {this.pending = false});
  final String email;

  /// Asked to join and not yet approved, as opposed to turned off.
  final bool pending;
}

class Device {
  const Device({
    required this.uid,
    required this.name,
    required this.status,
    required this.role,
    this.platform,
    this.requestedAt,
  });

  factory Device.fromJson(Json j) => Device(
        uid: j['id'] as String,
        name: j['name'] as String? ?? '?',
        status: j['status'] as String? ?? 'pending',
        role: Role.values.where((r) => r.wire == j['role']).firstOrNull ??
            Role.scanner,
        platform: j['platform'] as String?,
        requestedAt: DateTime.tryParse(j['requestedAt'] as String? ?? ''),
      );

  final String uid;
  final String name;
  final String status; // pending | approved | removed
  final Role role;
  final String? platform;
  final DateTime? requestedAt;

  /// What the admin matches against this phone's waiting screen.
  String get code => uid.substring(0, 6).toUpperCase();
}

class OnlineAccount {
  const OnlineAccount({
    required this.uid,
    required this.email,
    required this.role,
    required this.status,
  });

  factory OnlineAccount.fromJson(Json j) => OnlineAccount(
        uid: j['id'] as String,
        email: j['email'] as String? ?? '',
        role: Role.values.where((r) => r.wire == j['role']).firstOrNull ??
            Role.scanner,
        status: j['status'] as String? ?? 'inactive',
      );

  final String uid;
  final String email;
  final Role role;
  final String status;

  bool get isActive => status == 'active';
}

/// Phones, online accounts, and the first-owner claim. Every rule here is
/// also enforced by `firestore.rules`; this class only decides what to ask.
class AccessService {
  AccessService(this._app, this._auth, this._store);

  final FirebaseApp _app;
  final FirebaseAuth _auth;
  final Store _store;
  final _log = log('access');

  DocumentReference<Json> _device(String uid) => _store.doc(Col.devices, uid);

  User? get user => _auth.currentUser;

  Stream<Access> watch() => _switchMap(_auth.userChanges(), (User? u) {
        if (u == null) return Stream.value(const SignedOut());
        if (u.isAnonymous) return _watchDevice(u.uid);
        return _watchOnline(u);
      });

  Stream<Access> _watchDevice(String uid) =>
      _device(uid).snapshots().map((device) {
        if (!device.exists) return const NotJoined();
        final d = Device.fromJson(Store.withId(device));
        return switch (d.status) {
          'approved' => ApprovedDevice(d),
          'removed' => Removed(d),
          _ => PendingApproval(d),
        };
      });

  Stream<Access> _watchOnline(User u) =>
      _store.doc(Col.onlineUsers, u.uid).snapshots().map((s) {
        final account =
            s.exists ? OnlineAccount.fromJson(Store.withId(s)) : null;
        return account != null && account.isActive
            ? OnlineAccess(account)
            : OnlineRefused(u.email ?? '',
                pending: account == null || account.status == 'pending');
      });

  // ---- this phone ------------------------------------------------------

  /// Gets this phone a Firebase identity. Needs the network once; Firebase
  /// keeps the identity across restarts and offline.
  Future<void> ensureIdentity() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      _log.warning('anonymous sign-in failed', e);
      // Only a network failure is "connect and retry"; a refusal (e.g. the
      // Anonymous provider switched off) must not be reported as offline.
      if (e.code == 'network-request-failed') {
        throw const ValidationException(ErrorCode.needsInternet);
      }
      rethrow;
    }
  }

  /// Asks the admin to approve this phone.
  Future<void> requestApproval(String name) async {
    await ensureIdentity();
    final b = _store.batch()
      ..set(_device(_auth.currentUser!.uid), {
        'name': name.trim(),
        'status': 'pending',
        'role': Role.scanner.wire,
        'platform': Platform.operatingSystem,
        'requestedAt': DateTime.now().toUtc().toIso8601String(),
      });
    await _store.commit(b, 'devices.request');
  }

  /// Forget this phone's identity and begin again from the setup screen.
  Future<void> startOver() => _auth.signOut();

  // ---- devices (admin) -----------------------------------------------------

  Stream<List<Device>> devices() =>
      _store.col(Col.devices).snapshots().map((s) => [
            for (final d in s.docs) Device.fromJson(Store.withId(d)),
          ]..sort((a, b) => a.name.compareTo(b.name)));

  Future<void> approve(String uid, Role role, {required String by}) =>
      _store.commit(
          _store.batch()
            ..update(_device(uid), {
              'status': 'approved',
              'role': role.wire,
              'approvedAt': DateTime.now().toUtc().toIso8601String(),
              'approvedBy': by,
            }),
          'devices.approve');

  Future<void> setRole(String uid, Role role) => _store.commit(
      _store.batch()..update(_device(uid), {'role': role.wire}),
      'devices.role');

  Future<void> remove(String uid) => _store.commit(
      _store.batch()..update(_device(uid), {'status': 'removed'}),
      'devices.remove');

  // ---- online accounts --------------------------------------------------------

  /// Signs in, and — for someone this canteen has not seen — asks to join as
  /// a pending scanner. An inactive or pending account stays signed in so the
  /// waiting screen can say so, rather than failing with a bare error.
  Future<OnlineAccount> signInOnline(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    return requestOnlineAccess(cred.user!);
  }

  /// The signed-in person's account in this canteen, creating the pending
  /// join request if there is none yet.
  Future<OnlineAccount> requestOnlineAccess(User user) async {
    final ref = _store.doc(Col.onlineUsers, user.uid);
    final row = await _store.freshDoc(ref);
    final owner = await _isOwner(user);
    if (row != null && !(owner && row['status'] != 'active')) {
      return OnlineAccount.fromJson(row);
    }
    if (owner) {
      // The creator must never be locked out of their own canteen, whatever
      // happened to their row.
      await _store.commit(
          _store.batch()
            ..set(ref, {
              'email': user.email ?? '',
              'role': Role.admin.wire,
              'status': 'active',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            }),
          'onlineUsers.reclaim');
      return OnlineAccount(
          uid: user.uid,
          email: user.email ?? '',
          role: Role.admin,
          status: 'active');
    }
    await _store.commit(
        _store.batch()
          ..set(ref, {
            'email': user.email ?? '',
            'role': Role.scanner.wire,
            'status': 'pending',
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        'onlineUsers.request');
    return OnlineAccount(
        uid: user.uid,
        email: user.email ?? '',
        role: Role.scanner,
        status: 'pending');
  }

  Future<bool> _isOwner(User user) async {
    final root = await _store.canteenDoc.get();
    return root.data()?['ownerUid'] == user.uid;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Stream<List<OnlineAccount>> onlineAccounts() =>
      _store.col(Col.onlineUsers).snapshots().map((s) => [
            for (final d in s.docs) OnlineAccount.fromJson(Store.withId(d)),
          ]..sort((a, b) => a.email.compareTo(b.email)));

  /// Creates the Firebase Auth user through a second app instance: on the
  /// default instance, creating a user signs the admin in as that user.
  Future<OnlineAccount> createOnlineAccount(
      String email, String password, Role role) async {
    final secondary = await Firebase.initializeApp(
        name: 'account-maker-${DateTime.now().microsecondsSinceEpoch}',
        options: _app.options);
    try {
      final cred = await FirebaseAuth.instanceFor(app: secondary)
          .createUserWithEmailAndPassword(
              email: email.trim(), password: password);
      final account = OnlineAccount(
        uid: cred.user!.uid,
        email: email.trim(),
        role: role,
        status: 'active',
      );
      await _store.commit(
          _store.batch()
            ..set(_store.doc(Col.onlineUsers, account.uid), {
              'email': account.email,
              'role': role.wire,
              'status': 'active',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            }),
          'onlineUsers.create');
      return account;
    } finally {
      await secondary.delete();
    }
  }

  Future<void> setOnlineAccount(String uid, {Role? role, String? status}) =>
      _store.commit(
          _store.batch()
            ..update(_store.doc(Col.onlineUsers, uid), {
              if (role != null) 'role': role.wire,
              if (status != null) 'status': status,
            }),
          'onlineUsers.update');
}

/// Like `asyncExpand`, but drops the previous inner stream when a new outer
/// event arrives — `asyncExpand` would wait forever on a live listener.
Stream<R> _switchMap<T, R>(Stream<T> source, Stream<R> Function(T) inner) {
  late final StreamController<R> out;
  StreamSubscription<T>? outerSub;
  StreamSubscription<R>? innerSub;
  out = StreamController<R>(
    onListen: () {
      outerSub = source.listen((value) async {
        await innerSub?.cancel();
        innerSub = inner(value).listen(out.add, onError: out.addError);
      }, onError: out.addError);
    },
    onCancel: () async {
      await innerSub?.cancel();
      await outerSub?.cancel();
    },
  );
  return out.stream;
}
