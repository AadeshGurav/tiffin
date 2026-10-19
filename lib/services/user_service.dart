import '../core/errors.dart';
import '../core/logging.dart';
import '../data/store.dart';
import '../domain/ops.dart';
import 'auth_service.dart';

/// Offline-account management (PRD §4). Admin-only by the rules and the UI.
/// Never returns a password hash.
class UserService {
  UserService(this._store, this._auth);

  final Store _store;
  final AuthService _auth;
  final _log = log('user');

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_.-]+$');

  Future<List<AppUser>> list() async {
    final rows = await _store.cached(_store.col(Col.users));
    return rows.map(AppUser.fromJson).toList()
      ..sort((a, b) => a.username.compareTo(b.username));
  }

  Future<AppUser> create(UserDraft draft) async {
    _validateUsername(draft.username);
    _auth.requireStrongPassword(draft.password);
    await _requireFreeUsername(draft.username);
    final user =
        await _auth.writeUser(draft.username, draft.password, draft.role);
    _log.info('created username=${draft.username} role=${draft.role.wire}');
    return user;
  }

  /// [actingUserId] guards the "can't deactivate/delete yourself" rules.
  Future<AppUser> update(String id, UserPatch patch,
      {required String actingUserId}) async {
    if (patch.username != null) {
      _validateUsername(patch.username!);
      await _requireFreeUsername(patch.username!, except: id);
    }
    if (patch.status == 'inactive' && id == actingUserId) {
      throw const ValidationException(ErrorCode.cannotDeactivateSelf);
    }
    if (patch.password != null) _auth.requireStrongPassword(patch.password!);

    final ref = _store.doc(Col.users, id);
    final existing = await _store.cachedDoc(ref);
    if (existing == null) throw const NotFoundException(ErrorCode.userNotFound);

    final changes = <String, dynamic>{
      if (patch.username != null) 'username': patch.username,
      if (patch.password != null)
        'passwordHash': _auth.hashPassword(patch.password!),
      if (patch.role != null) 'role': patch.role!.wire,
      if (patch.status != null) 'status': patch.status,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final b = _store.batch()..update(ref, changes);
    await _store.commit(b, 'users.update');
    _log.info('updated user_id=$id');
    return AppUser.fromJson({...existing, ...changes});
  }

  Future<void> delete(String id, {required String actingUserId}) async {
    if (id == actingUserId) {
      throw const ValidationException(ErrorCode.cannotDeleteSelf);
    }
    final ref = _store.doc(Col.users, id);
    if (await _store.cachedDoc(ref) == null) {
      throw const NotFoundException(ErrorCode.userNotFound);
    }
    await _store.commit(_store.batch()..delete(ref), 'users.delete');
    _log.warning('deleted user_id=$id');
  }

  /// Checked against the synced list. Two offline admins could still pick the
  /// same name at the same moment; sign-in then takes the first match.
  /// ponytail: good enough for a handful of staff accounts.
  Future<void> _requireFreeUsername(String username, {String? except}) async {
    final taken =
        (await list()).any((u) => u.username == username && u.id != except);
    if (taken) {
      throw ConflictException(ErrorCode.usernameTaken, {'name': username});
    }
  }

  void _validateUsername(String username) {
    if (username.length < 3 || username.length > 50) {
      throw const ValidationException(ErrorCode.usernameLength);
    }
    if (!_usernamePattern.hasMatch(username)) {
      throw const ValidationException(ErrorCode.usernameChars);
    }
  }
}
