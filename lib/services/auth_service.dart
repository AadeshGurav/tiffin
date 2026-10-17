import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../core/role.dart';
import '../data/store.dart';
import '../domain/ops.dart';

/// A signed-in offline account on this phone.
class LocalSession {
  const LocalSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.role,
    required this.expiresAt,
  });

  factory LocalSession.fromJson(Map<String, dynamic> j) => LocalSession(
        token: j['token'] as String,
        userId: j['userId'] as String,
        username: j['username'] as String,
        role: Role.fromWire(j['role'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );

  final String token;
  final String userId;
  final String username;
  final Role role;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
        'token': token,
        'userId': userId,
        'username': username,
        'role': role.wire,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };
}

/// Offline accounts: PBKDF2-HMAC-SHA256 (260k iterations, `salt\$digest` hex —
/// unchanged from v1, so imported accounts verify as they are) checked against
/// the synced `users` collection on this phone, so signing in needs no
/// network. Sessions live on the device only: a session is "this phone, this
/// person, until sign-out or expiry", and the phone itself is what Firestore
/// rules trust (see `firestore.rules`).
class AuthService {
  AuthService(this._store, this._prefs, {required this.sessionTtl});

  final Store _store;
  final SharedPreferences _prefs;
  final Duration sessionTtl;
  final _log = log('auth');

  static const _sessionsKey = 'local_sessions';

  static const _iterations = 260000;
  static const _keyLen = 32;
  final _random = Random.secure();

  // ---- password hashing -------------------------------------------------

  String hashPassword(String password) {
    final salt = _randomBytes(16);
    final digest = _pbkdf2(password, salt);
    return '${_hex(salt)}\$${_hex(digest)}';
  }

  bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split('\$');
    if (parts.length != 2) return false;
    final salt = _unhex(parts[0]);
    final expected = parts[1];
    final actual = _hex(_pbkdf2(password, salt));
    return _constantTimeEquals(actual, expected);
  }

  Uint8List _pbkdf2(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _iterations, _keyLen));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  // ---- authentication + sessions -------------------------------------

  /// The account on success, null on ANY failure — a caller never learns
  /// whether the username or the password was wrong.
  Future<Json?> authenticate(String username, String password) async {
    final rows = await _store.cached(
        _store.col(Col.users).where('username', isEqualTo: username.trim()));
    if (rows.isEmpty) return null;
    final user = rows.first;
    if (user['status'] != 'active') return null;
    if (!verifyPassword(password, user['passwordHash'] as String)) return null;
    return user;
  }

  Future<LocalSession> createSession(Json user) async {
    final session = LocalSession(
      token: _urlSafeToken(32),
      userId: user['id'] as String,
      username: user['username'] as String,
      role: Role.fromWire(user['role'] as String),
      expiresAt: DateTime.now().toUtc().add(sessionTtl),
    );
    await _writeSessions({..._readSessions(), session.token: session});
    _log.info('login_succeeded username=${session.username} '
        'role=${session.role.wire}');
    return session;
  }

  /// Resolves a token saved on this phone, or throws [AuthException]. The
  /// account is re-checked, so a deactivated person is signed out the next
  /// time the app asks.
  Future<LocalSession> requireSession(String token) async {
    final session = _readSessions()[token];
    if (session == null || session.expiresAt.isBefore(DateTime.now().toUtc())) {
      throw const AuthException(ErrorCode.notSignedIn);
    }
    final user = await _store.cachedDoc(_store.doc(Col.users, session.userId));
    if (user == null || user['status'] != 'active') {
      await deleteSession(token);
      throw const AuthException(ErrorCode.notSignedIn);
    }
    return session;
  }

  Future<void> deleteSession(String token) async {
    final all = _readSessions()..remove(token);
    await _writeSessions(all);
  }

  Map<String, LocalSession> _readSessions() {
    final raw = _prefs.getString(_sessionsKey);
    if (raw == null) return {};
    final now = DateTime.now().toUtc();
    return {
      for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
        if (LocalSession.fromJson(e.value as Map<String, dynamic>)
            .expiresAt
            .isAfter(now))
          e.key: LocalSession.fromJson(e.value as Map<String, dynamic>),
    };
  }

  Future<void> _writeSessions(Map<String, LocalSession> all) =>
      _prefs.setString(
          _sessionsKey, jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))));

  // ---- first-run setup -------------------------------------------------

  /// True while the canteen has no accounts at all — what the setup screen
  /// exists to resolve. Derived on every read, so it is also right after a
  /// data reset instead of being a one-shot that can be missed.
  Future<bool> needsSetup() async =>
      (await _store.cached(_store.col(Col.users).limit(1))).isEmpty;

  /// Creates the first admin with credentials the operator chose. (Choosing
  /// replaced a generated password that lived only in memory and stranded
  /// hosts when missed — ADR 0001 §4.)
  Future<AppUser> createInitialAdmin({
    required String username,
    required String password,
  }) async {
    if (!await needsSetup()) {
      throw const ValidationException(ErrorCode.alreadySetUp);
    }
    final name = username.trim();
    if (name.isEmpty) {
      throw const ValidationException(ErrorCode.usernameRequired);
    }
    requireStrongPassword(password);
    final user = await writeUser(name, password, Role.admin);
    _log.info('initial_admin_created username=$name');
    return user;
  }

  /// Shared by setup and user management: one place builds an account row.
  Future<AppUser> writeUser(String username, String password, Role role) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _store.newId(Col.users);
    final row = {
      'username': username,
      'passwordHash': hashPassword(password),
      'role': role.wire,
      'status': 'active',
      'createdAt': now,
      'updatedAt': now,
    };
    final b = _store.batch()..set(_store.doc(Col.users, id), row);
    await _store.commit(b, 'users.create');
    return AppUser.fromJson({...row, 'id': id});
  }

  /// Length floor rather than character-class rules: length is what helps,
  /// and rules people fight produce `Password1!`.
  static const minPasswordLength = 8;

  void requireStrongPassword(String password) {
    if (password.length < minPasswordLength) {
      throw const ValidationException(
          ErrorCode.passwordTooShort, {'min': minPasswordLength});
    }
  }

  /// A strong password the operator can accept rather than invent. Returned,
  /// never logged.
  String suggestPassword() => _urlSafeToken(9);

  /// Last-resort recovery, on an admin-approved phone only (the UI gates it).
  /// Grants nothing that phone didn't already have: it can manage every
  /// account from Settings anyway.
  Future<void> resetPasswordFor(String username, String newPassword) async {
    requireStrongPassword(newPassword);
    final rows = await _store.cached(
        _store.col(Col.users).where('username', isEqualTo: username.trim()));
    if (rows.isEmpty) {
      throw ValidationException(ErrorCode.noSuchAccount, {'name': username});
    }
    final b = _store.batch()
      ..update(_store.doc(Col.users, rows.first['id'] as String), {
        'passwordHash': hashPassword(newPassword),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    await _store.commit(b, 'users.resetPassword');
    final remaining = _readSessions()
      ..removeWhere((_, s) => s.username == username.trim());
    await _writeSessions(remaining);
    _log.warning('password_reset username=$username');
  }

  // ---- primitives --------------------------------------------------------

  Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

  String _urlSafeToken(int bytes) =>
      base64Url.encode(_randomBytes(bytes)).replaceAll('=', '');

  static String _hex(Uint8List b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _unhex(String s) {
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
