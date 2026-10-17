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

/// Has an identity but no device record — first join, or after starting over.
class NotJoined extends Access {
  const NotJoined({required this.newCanteen});

  /// Nobody owns this Firebase project yet: joining makes this phone the
  /// first admin phone.
  final bool newCanteen;
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

/// Signed in with an online account the admin has turned off or removed.
class OnlineRefused extends Access {
  const OnlineRefused(this.email);
  final String email;
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
  DocumentReference<Json> get _owner => _store.doc(Col.meta, 'owner');

  User? get user => _auth.currentUser;

  Stream<Access> watch() => _switchMap(_auth.userChanges(), (User? u) {
        if (u == null) return Stream.value(const SignedOut());
        if (u.isAnonymous) return _watchDevice(u.uid);
        return _watchOnline(u);
      });

  Stream<Access> _watchDevice(String uid) {
    late final StreamController<Access> out;
    DocumentSnapshot<Json>? device;
    DocumentSnapshot<Json>? owner;
    final subs = <StreamSubscription<Object>>[];

    void emit() {
      if (device == null || owner == null) return;
      if (!device!.exists) {
        out.add(NotJoined(newCanteen: !owner!.exists));
        return;
      }
      final d = Device.fromJson(Store.withId(device!));
      out.add(switch (d.status) {
        'approved' => ApprovedDevice(d),
        'removed' => Removed(d),
        _ => PendingApproval(d),
      });
    }

    out = StreamController<Access>(
      onListen: () {
        subs
          ..add(_device(uid).snapshots().listen((s) {
            device = s;
            emit();
          }, onError: out.addError))
          ..add(_owner.snapshots().listen((s) {
            owner = s;
            emit();
          }, onError: out.addError));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return out.stream;
  }

  Stream<Access> _watchOnline(User u) =>
      _store.doc(Col.onlineUsers, u.uid).snapshots().map((s) {
        final account =
            s.exists ? OnlineAccount.fromJson(Store.withId(s)) : null;
        return account != null && account.isActive
            ? OnlineAccess(account)
            : OnlineRefused(u.email ?? '');
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
      throw const ValidationException(ErrorCode.needsInternet);
    }
  }

  /// Whether someone has already started a canteen in this project. Asks the
  /// server: joining needs the network anyway, and a stale cached "no" would
  /// offer to start a second canteen.
  Future<bool> canteenExists() async {
    try {
      return (await _owner.get(const GetOptions(source: Source.server))).exists;
    } on FirebaseException catch (e) {
      throw mapFirebaseError(e);
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

  /// First phone on a fresh project becomes its owner and first admin phone.
  /// A transaction on purpose — it needs the network anyway, and two phones
  /// racing to claim the same project must not both win.
  Future<void> claimNewCanteen(String name) async {
    await ensureIdentity();
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _store.db.runTransaction((tx) async {
        final owner = await tx.get(_owner);
        if (owner.exists) {
          throw const ConflictException(ErrorCode.alreadySetUp);
        }
        tx
          ..set(_owner, {'uid': uid, 'createdAt': now})
          ..set(_device(uid), {
            'name': name.trim(),
            'status': 'approved',
            'role': Role.admin.wire,
            'platform': Platform.operatingSystem,
            'requestedAt': now,
            'approvedAt': now,
          });
      });
      _log.warning('canteen_claimed uid=$uid');
    } on FirebaseException catch (e) {
      throw mapFirebaseError(e);
    }
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

  Future<OnlineAccount> signInOnline(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    final row =
        await _store.freshDoc(_store.doc(Col.onlineUsers, cred.user!.uid));
    final account = row == null ? null : OnlineAccount.fromJson(row);
    if (account == null || !account.isActive) {
      await _auth.signOut();
      throw const ForbiddenException(ErrorCode.permissionDenied);
    }
    return account;
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
