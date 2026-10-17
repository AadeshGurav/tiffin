import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../core/meal_type.dart';
import '../core/role.dart';
import '../core/time/meal_window.dart';
import '../data/store.dart';
import '../domain/inventory.dart';
import '../domain/menu.dart';
import '../domain/ops.dart';
import '../domain/settings.dart';
import 'scan_service.dart' show ymd;
import 'settings_service.dart';

/// Persistent in-app reminders (PRD §6.5.2). No scheduled job: [generateDue]
/// runs on each poll from whichever phones are open. Each reminder's id is
/// derived from what it is about (`prep_reminder_2026-10-17_lunch`), so every
/// phone computing the same reminder writes the same document — polling, and
/// several phones polling, never duplicates.
///
/// A notification stores its kind and the values the sentence needs, never
/// the sentence: each phone words it in its own language.
class NotificationService {
  NotificationService(this._store, this._settings);

  final Store _store;
  final SettingsService _settings;

  CollectionReference<Json> get _col => _store.col(Col.notifications);

  Future<void> generateDue(DateTime nowUtc) async {
    final s = await _settings.read();
    final localNow = toLocal(nowUtc, s.localTimezone);
    final due = <String, Json>{};
    void upsert(String type, String key, Json params, List<Role> roles) =>
        due['${type}_$key'] = {
          'type': type,
          'params': params,
          'visibleRoles': roles.map((r) => r.wire).toList(),
        };

    await _prepReminders(localNow, s, upsert);
    await _purchaseReminders(localNow, s, upsert);
    await _lowStock(upsert);
    await _headcountOverrun(localNow, upsert);

    // Every open phone polls, so writing unconditionally would spend the free
    // tier's daily write budget on no-ops. Only new or changed reminders are
    // written; an existing one keeps its creation time and dismissals.
    final b = _store.batch();
    var writes = 0;
    for (final MapEntry(key: id, value: body) in due.entries) {
      final existing = await _store.cachedDoc(_col.doc(id));
      if (existing == null) {
        b.set(_col.doc(id), {...body, 'createdAt': nowUtc.toIso8601String()});
      } else if (!_sameJson(existing['params'], body['params'])) {
        b.update(_col.doc(id), {'params': body['params']});
      } else {
        continue;
      }
      writes++;
    }
    if (writes > 0) await _store.commit(b, 'notifications.generate');
  }

  static bool _sameJson(Object? a, Object? b) =>
      const DeepCollectionEquality().equals(a, b);

  Future<void> _lowStock(_Upsert upsert) async {
    final ingredients = (await _store.cached(_store.col(Col.ingredients)))
        .map(Ingredient.fromJson);
    for (final ing in ingredients.where((i) => i.isLow)) {
      upsert('low_stock', ing.id, {
        'name': ing.name,
        'qty': ing.stockQty,
        'threshold': ing.lowStockAt,
        'unit': ing.unit,
      }, const [
        Role.admin,
        Role.counter,
        Role.scanner
      ]);
    }
  }

  Future<void> _headcountOverrun(DateTime localNow, _Upsert upsert) async {
    final day = ymd(localNow);
    final entries = (await _store
            .cached(_store.col(Col.menu).where('date', isEqualTo: day)))
        .map(MenuEntry.fromJson)
        .where((e) => e.headcount > 0);
    for (final entry in entries) {
      final served = (await _store.cached(_store
              .col(Col.scans)
              .where('day', isEqualTo: day)
              .where('mealType', isEqualTo: entry.mealType.wire)
              .where('memberCategory', isEqualTo: entry.category)
              .where('reversed', isEqualTo: false)))
          .length;
      if (served < entry.headcount) continue;
      upsert('headcount_overrun',
          '${day}_${entry.mealType.wire}_${entry.category}', {
        'category': entry.category,
        'meal': entry.mealType.wire,
        'planned': entry.headcount,
        'served': served,
      }, const [
        Role.admin,
        Role.counter
      ]);
    }
  }

  Future<void> _prepReminders(
      DateTime localNow, SettingsSnapshot s, _Upsert upsert) async {
    final day = ymd(localNow);
    final meals = isSaturday(localNow)
        ? const [MealType.brunch]
        : const [MealType.breakfast, MealType.lunch];
    for (final meal in meals) {
      final window = s.mealWindows[meal.wire];
      if (window == null) continue;
      final planned = (await _store.cached(_store
              .col(Col.menu)
              .where('date', isEqualTo: day)
              .where('mealType', isEqualTo: meal.wire)
              .limit(1)))
          .isNotEmpty;
      if (!planned) continue;

      final parts = window.start.split(':');
      final startLocal = DateTime(localNow.year, localNow.month, localNow.day,
          int.parse(parts[0]), int.parse(parts[1]));
      final minutesUntil = startLocal.difference(localNow).inSeconds / 60.0;
      if (minutesUntil < 0 || minutesUntil > s.prepLeadMinutes) continue;
      upsert('prep_reminder', '${day}_${meal.wire}', {
        'meal': meal.wire,
        'start': window.start,
        'minutes': minutesUntil.round(),
      }, const [
        Role.admin,
        Role.counter
      ]);
    }
  }

  Future<void> _purchaseReminders(
      DateTime localNow, SettingsSnapshot s, _Upsert upsert) async {
    final target = ymd(DateTime(localNow.year, localNow.month, localNow.day)
        .add(Duration(days: s.purchaseLeadDays)));
    final pending = (await _store.cached(_store
            .col(Col.purchaseSchedule)
            .where('date', isEqualTo: target)
            .where('purchased', isEqualTo: false)))
        .length;
    if (pending == 0) return;
    upsert('purchase_due', target, {'count': pending, 'date': target},
        const [Role.admin, Role.counter]);
  }

  /// Raised by a phone whose offline scan the server refused on sync — the
  /// person was already served this meal on another phone.
  Future<void> raiseScanRejectedOnSync({
    required String memberName,
    required MealType meal,
    required String day,
  }) async {
    final now = DateTime.now().toUtc();
    final b = _store.batch()
      ..set(_col.doc('scan_rejected_on_sync_${now.millisecondsSinceEpoch}'), {
        'type': 'scan_rejected_on_sync',
        'params': {'name': memberName, 'meal': meal.wire, 'date': day},
        'visibleRoles': const ['admin', 'counter'],
        'createdAt': now.toIso8601String(),
      });
    await _store.commit(b, 'notifications.scanRejected');
  }

  /// Visible to [role] and not dismissed by [username], newest first.
  Future<List<AppNotification>> listFor(Role role, String username) async {
    final rows = await _store
        .cached(_col.where('visibleRoles', arrayContains: role.wire));
    return rows
        .where((n) => !(n['dismissedBy'] as List<dynamic>? ?? const [])
            .contains(username))
        .map(AppNotification.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> dismiss(String id, String username) async {
    if (await _store.cachedDoc(_col.doc(id)) == null) {
      throw const NotFoundException(ErrorCode.notificationNotFound);
    }
    await _store.commit(
        _store.batch()
          ..update(_col.doc(id), {
            'dismissedBy': FieldValue.arrayUnion([username])
          }),
        'notifications.dismiss');
  }
}

typedef _Upsert = void Function(
    String type, String key, Json params, List<Role> roles);
