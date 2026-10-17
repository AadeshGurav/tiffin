import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/logging.dart';
import '../services/scan_service.dart' show ymd;
import 'store.dart';

/// Whether this phone can reach Firestore right now, and whether it has
/// changes still waiting to go up.
@immutable
class SyncState {
  const SyncState({required this.online, required this.pending});

  static const unknown = SyncState(online: true, pending: false);

  final bool online;
  final bool pending;

  @override
  bool operator ==(Object other) =>
      other is SyncState && other.online == online && other.pending == pending;

  @override
  int get hashCode => Object.hash(online, pending);
}

/// Keeps the collections the counter needs at speed synced into the local
/// cache, which is what makes `Store.cached` reads both instant and correct
/// offline. Listening is the documented way to keep Firestore's cache current
/// (a one-off `get` refreshes nothing afterwards).
///
/// ponytail: whole collections, except scans (today and yesterday only) and
/// dated plans (from a week back). Fine for one canteen's few hundred members;
/// narrow the queries if a collection grows into the tens of thousands.
class CacheWarmer {
  CacheWarmer(this._store);

  final Store _store;
  final _log = log('cache');
  final _subs = <StreamSubscription<Object>>[];
  final _sync = StreamController<SyncState>.broadcast();
  SyncState _state = SyncState.unknown;

  Stream<SyncState> get sync => _sync.stream;
  SyncState get state => _state;

  /// Completes once every warmed query has delivered its first snapshot, from
  /// the server or (offline) from what this phone already had. Capped, so a
  /// phone that is offline with an empty cache still gets to a screen that can
  /// say so.
  Future<void> start() async {
    final now = DateTime.now();
    final yesterday = ymd(now.subtract(const Duration(days: 1)));
    final weekAgo = ymd(now.subtract(const Duration(days: 7)));

    final queries = <Query<Json>>[
      _store.col(Col.users),
      _store.col(Col.members),
      _store.col(Col.menuCategories),
      _store.col(Col.ingredients),
      _store.col(Col.recipes),
      _store.col(Col.notifications),
      _store.col(Col.menu).where('date', isGreaterThanOrEqualTo: weekAgo),
      _store
          .col(Col.purchaseSchedule)
          .where('date', isGreaterThanOrEqualTo: weekAgo),
      _store.col(Col.scans).where('day', isGreaterThanOrEqualTo: yesterday),
    ];

    final firsts = <Future<void>>[];
    // Local changes not yet acknowledged, per query; "pending" is any of them.
    final pending = List<bool>.filled(queries.length, false);
    for (final (i, q) in queries.indexed) {
      final first = Completer<void>();
      firsts.add(first.future);
      _subs.add(q.snapshots(includeMetadataChanges: true).listen((snap) {
        if (!first.isCompleted) first.complete();
        pending[i] = snap.metadata.hasPendingWrites;
        _publish(pending: pending.contains(true));
      }, onError: (Object e) {
        _log.warning('listener failed', e);
        if (!first.isCompleted) first.complete();
      }));
    }

    // The settings document doubles as the connectivity probe: a snapshot
    // that isn't from the cache came from the server.
    final settingsFirst = Completer<void>();
    firsts.add(settingsFirst.future);
    _subs.add(_store
        .doc(Col.meta, 'settings')
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      if (!settingsFirst.isCompleted) settingsFirst.complete();
      _publish(online: !snap.metadata.isFromCache);
    }, onError: (Object e) {
      _log.warning('settings listener failed', e);
      if (!settingsFirst.isCompleted) settingsFirst.complete();
    }));

    await Future.wait(firsts)
        .timeout(const Duration(seconds: 8), onTimeout: () => const []);
    _log.info('cache_ready online=${_state.online}');
  }

  void _publish({bool? online, bool? pending}) {
    final next = SyncState(
      online: online ?? _state.online,
      pending: pending ?? _state.pending,
    );
    _store.online = next.online;
    if (next == _state) return;
    _state = next;
    _sync.add(next);
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }
}
