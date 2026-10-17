import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../core/logging.dart';

typedef Json = Map<String, dynamic>;

/// Every collection name in one place, so the services and `firestore.rules`
/// can be checked against a single list.
abstract final class Col {
  static const meta = 'meta'; // docs: settings, owner
  static const devices = 'devices';
  static const onlineUsers = 'onlineUsers';
  static const users = 'users';
  static const members = 'members';
  static const scans = 'scans';
  static const topups = 'topups';
  static const refunds = 'refunds';
  static const menuCategories = 'menuCategories';
  static const menu = 'menu';
  static const ingredients = 'ingredients';
  static const recipes = 'recipes';
  static const purchaseSchedule = 'purchaseSchedule';
  static const expenses = 'expenses';
  static const notifications = 'notifications';

  /// Collections that hold the canteen's own records — what a backup carries
  /// and what a reset clears. Devices and online accounts are access control,
  /// not data, so they stay put.
  static const data = [
    users,
    members,
    scans,
    topups,
    refunds,
    menuCategories,
    menu,
    ingredients,
    recipes,
    purchaseSchedule,
    expenses,
    notifications,
  ];
}

/// The one doorway to Firestore. It exists for two decisions every service
/// would otherwise make on its own, and make differently:
///
///  * **Reads.** [cached] answers from the local cache only. The collections a
///    counter needs at speed (members, settings, menu, kitchen, today's scans)
///    are kept warm by `CacheWarmer`, so this is both instant and offline-safe.
///    [fresh] asks the server first and falls back to the cache — for history
///    screens that aren't kept warm.
///  * **Writes.** Firestore transactions fail offline (official docs), so all
///    writes are batches. [commit] applies a batch locally straight away. When
///    the device is online it also waits briefly for the server, so a
///    permission or conflict error reaches the screen that caused it; offline
///    it returns at once and the batch syncs when the network comes back.
class Store {
  Store(this.db, {this.serverWait = const Duration(seconds: 4)});

  final FirebaseFirestore db;
  final Duration serverWait;
  final _log = log('store');

  /// Kept current by `CacheWarmer` from snapshot metadata. Starts optimistic:
  /// the first server answer or cache fallback corrects it within a second.
  bool online = true;

  CollectionReference<Json> col(String name) => db.collection(name);
  DocumentReference<Json> doc(String col, String id) =>
      db.collection(col).doc(id);
  String newId(String col) => db.collection(col).doc().id;

  WriteBatch batch() => db.batch();

  Future<List<Json>> cached(Query<Json> query) async =>
      _rows(await query.get(const GetOptions(source: Source.cache)));

  Future<List<Json>> fresh(Query<Json> query) async => _rows(await query.get());

  Future<Json?> cachedDoc(DocumentReference<Json> ref) async {
    try {
      final snap = await ref.get(const GetOptions(source: Source.cache));
      return snap.exists ? withId(snap) : null;
    } on FirebaseException {
      // A document that was never cached is reported as an error, not a miss.
      return null;
    }
  }

  Future<Json?> freshDoc(DocumentReference<Json> ref) async {
    final snap = await ref.get();
    return snap.exists ? withId(snap) : null;
  }

  static Json withId(DocumentSnapshot<Json> snap) =>
      {...?snap.data(), 'id': snap.id};

  List<Json> _rows(QuerySnapshot<Json> snap) =>
      [for (final d in snap.docs) withId(d)];

  /// See the class comment. [onRejected] runs if the server later refuses a
  /// batch that was already applied locally (for example a duplicate scan made
  /// on two offline phones) — the local copy is rolled back by Firestore
  /// itself, so the callback is only for telling someone.
  Future<void> commit(
    WriteBatch batch,
    String what, {
    void Function(Object error)? onRejected,
  }) async {
    final ack = batch.commit();
    if (online) {
      try {
        await ack.timeout(serverWait);
        return;
      } on TimeoutException {
        // Queued; it will sync. Fall through to watching it in the background.
      } on FirebaseException catch (e) {
        _log.warning('server rejected $what', e);
        throw mapFirebaseError(e);
      }
    }
    // Still observed, so a rejection that arrives long after the screen moved
    // on is logged and reported rather than lost.
    unawaited(ack.then((_) => _log.fine('synced $what'), onError: (Object e) {
      _log.warning('server rejected $what after sync', e);
      onRejected?.call(e);
    }));
  }
}

/// Firestore's own failures, as the app's error codes.
AppException mapFirebaseError(FirebaseException e) => switch (e.code) {
      'permission-denied' =>
        const ForbiddenException(ErrorCode.permissionDenied),
      'unavailable' => const ValidationException(ErrorCode.needsInternet),
      _ => const InternalException(),
    };
