import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../core/meal_type.dart';
import '../core/time/meal_window.dart';
import '../data/store.dart';
import '../domain/inventory.dart';
import '../domain/ledger.dart';
import '../domain/member.dart';
import '../domain/menu.dart';
import 'member_service.dart';
import 'menu_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

/// The counter scan flow (PRD §5, §6.4), built to work with no internet.
///
/// Each accepted scan is ONE batched write: the scan record, the balance
/// decrement and the stock it consumes. Batches run offline (Firestore
/// transactions don't), and increments merge correctly when several phones
/// sync later.
///
/// The one-scan-per-meal lock is the scan's document id —
/// `{member}_{day}_{meal}`. Firestore rules allow *creating* that document but
/// never overwriting it, so if two offline phones both serve the same person
/// the same meal, the second batch is refused when it syncs — balance
/// decrement included, because a batch is all-or-nothing. That phone then
/// raises a notification so someone can follow up.
///
/// Balance checks use the cached member, so two offline phones can each let
/// the same person spend their last unit on different meals; the balance then
/// goes below zero and shows up in reports. That's the accepted cost of
/// scanning without a network.
class ScanService {
  ScanService(this._store, this._settings, this._notifications);

  final Store _store;
  final SettingsService _settings;
  final NotificationService _notifications;
  final _log = log('scan');

  static String lockId(String memberId, String day, MealType meal) =>
      '${memberId}_${day}_${meal.wire}';

  /// Resolve a code, decide accept/reject, and on accept deduct one unit and
  /// record the scan. Rejections are logged, not stored.
  Future<ScanResult> processScan(
    String qrCodeId, {
    MealType? mealTypeOverride,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final settings = await _settings.read();
    final nowLocal = toLocal(nowUtc, settings.localTimezone);

    final rows = await _store
        .cached(_store.col(Col.members).where('qrCodeId', isEqualTo: qrCodeId));
    if (rows.isEmpty) {
      _log.warning('rejected reason=unknown_code qr=$qrCodeId');
      return const ScanResult(outcome: ScanOutcome.rejectedUnknownCode);
    }
    final member = Member.fromJson(rows.first);

    if (!member.isActive) {
      _log.info('rejected reason=inactive member_id=${member.id}');
      return ScanResult(
        outcome: ScanOutcome.rejectedInactive,
        memberName: member.name,
        memberType: member.type,
      );
    }

    final windows = settings.mealWindows.map(
      (k, v) => MapEntry(k, MealWindow.parse(v.toJson())),
    );
    final mealType = mealTypeOverride ?? currentMealType(nowLocal, windows);
    if (mealType == null) {
      _log.info('rejected reason=no_meal_window member_id=${member.id}');
      return ScanResult(
        outcome: ScanOutcome.rejectedNoMealWindow,
        memberName: member.name,
        memberType: member.type,
      );
    }

    final day = ymd(nowLocal);
    final lockRef = _store.doc(Col.scans, lockId(member.id, day, mealType));
    if (await _store.cachedDoc(lockRef) != null) {
      _log.info('rejected reason=already_scanned member_id=${member.id} '
          'meal=${mealType.wire}');
      return ScanResult(
        outcome: ScanOutcome.rejectedAlreadyScanned,
        memberName: member.name,
        memberType: member.type,
        mealType: mealType,
      );
    }

    final balance = member.balances.forMeal(mealType);
    final grace = settings.effectiveGrace(member.graceAllowanceOverride);
    if (balance <= -grace) {
      _log.info('rejected reason=zero_balance member_id=${member.id} '
          'meal=${mealType.wire} balance=$balance');
      return ScanResult(
        outcome: ScanOutcome.rejectedZeroBalance,
        memberName: member.name,
        memberType: member.type,
        mealType: mealType,
        remainingBalance: balance,
      );
    }

    final newBalance = balance - 1;
    final usedGrace = newBalance < 0;

    // What one plate of this member's category gets today, and what it uses.
    final entryRow = await _store.cachedDoc(_store.doc(
        Col.menu, MenuService.entryId(day, mealType, member.category)));
    final entry = entryRow == null ? null : MenuEntry.fromJson(entryRow);
    final consumed = await _platesCost(entry);

    final b = _store.batch()
      ..set(lockRef, {
        'memberId': member.id,
        'memberName': member.name,
        'mealType': mealType.wire,
        'day': day,
        'scannedAt': nowUtc.toIso8601String(),
        'result': 'accepted',
        'viaGrace': usedGrace,
        'reversed': false,
        'memberCategory': member.category,
        'consumed': consumed,
      })
      ..update(_store.doc(Col.members, member.id),
          MemberService.balanceDelta(_single(mealType), sign: -1));
    consumed.forEach((ingredientId, qty) =>
        b.update(_store.doc(Col.ingredients, ingredientId), {
          'stockQty': FieldValue.increment(-qty),
          'updatedAt': nowUtc.toIso8601String(),
        }));

    try {
      await _store.commit(b, 'scan ${lockRef.id}',
          onRejected: (_) => _notifications.raiseScanRejectedOnSync(
              memberName: member.name, meal: mealType, day: day));
    } on ForbiddenException {
      // Refused online. Either another phone recorded this meal a moment
      // earlier (the lock now exists), or this phone lost its access.
      if (await _freshOrNull(lockRef) == null) rethrow;
      return ScanResult(
        outcome: ScanOutcome.rejectedAlreadyScanned,
        memberName: member.name,
        memberType: member.type,
        mealType: mealType,
      );
    }

    _log.info('accepted member_id=${member.id} meal=${mealType.wire} '
        'new_balance=$newBalance via_grace=$usedGrace '
        'consumed=${consumed.length} online=${_store.online}');

    // Planned vs actual plates for this category / meal / today.
    int? planned;
    int? served;
    if (entry != null && entry.headcount > 0) {
      planned = entry.headcount;
      served = await servedCount(day, mealType, member.category);
    }

    return ScanResult(
      outcome: ScanOutcome.accepted,
      scanId: lockRef.id,
      memberName: member.name,
      memberType: member.type,
      mealType: mealType,
      remainingBalance: newBalance,
      viaGrace: usedGrace,
      memberCategory: member.category,
      plannedCount: planned,
      servedCount: served,
    );
  }

  /// Accepted, unreversed scans for one day / meal / category, from the warm
  /// cache (today's scans are always kept synced).
  Future<int> servedCount(String day, MealType meal, String category) async =>
      (await _store.cached(_store
              .col(Col.scans)
              .where('day', isEqualTo: day)
              .where('mealType', isEqualTo: meal.wire)
              .where('memberCategory', isEqualTo: category)
              .where('reversed', isEqualTo: false)))
          .length;

  /// `{ingredientId: per-plate quantity}` summed over the recipes of the items
  /// on [entry]. Empty when there's no entry or nothing matches a recipe.
  Future<Map<String, double>> _platesCost(MenuEntry? entry) async {
    if (entry == null || entry.items.isEmpty) return const {};
    final recipes =
        (await _store.cached(_store.col(Col.recipes))).map(Recipe.fromJson);
    final byDish = {
      for (final r in recipes) r.dishName.trim().toLowerCase(): r
    };
    // An ingredient deleted since the recipe was written would make the whole
    // batch fail on update, so only known ingredients are counted.
    final known = {
      for (final i in await _store.cached(_store.col(Col.ingredients)))
        i['id'] as String
    };
    final out = <String, double>{};
    for (final name in entry.items) {
      final recipe = byDish[name.trim().toLowerCase()];
      if (recipe == null) continue;
      for (final ri in recipe.ingredients) {
        if (!known.contains(ri.ingredientId)) continue;
        out[ri.ingredientId] = (out[ri.ingredientId] ?? 0) + ri.quantity;
      }
    }
    return out;
  }

  /// Undo a mistaken accepted scan within the configured window (PRD §5).
  ///
  /// Audit-kept: the record is copied to a new id flagged `reversed`, then the
  /// lock document is removed so the person can be served again. Balance and
  /// stock are put back in the same batch.
  Future<ReversalResult> reverseScan(String scanId, String reversedBy) async {
    final ref = _store.doc(Col.scans, scanId);
    final scan = await _store.cachedDoc(ref) ?? await _freshOrNull(ref);
    if (scan == null) return const ReversalResult(ReversalCode.scanNotFound);
    if (scan['reversed'] == true) {
      return const ReversalResult(ReversalCode.scanAlreadyReversed);
    }

    final settings = await _settings.read();
    final window = Duration(minutes: settings.reversalWindowMinutes);
    final scannedAt = DateTime.parse(scan['scannedAt'] as String);
    if (DateTime.now().toUtc().difference(scannedAt) > window) {
      return ReversalResult(ReversalCode.scanWindowExpired,
          windowMinutes: settings.reversalWindowMinutes);
    }

    final memberId = scan['memberId'] as String;
    final memberRow = await _store.cachedDoc(_store.doc(Col.members, memberId));
    if (memberRow == null) {
      return const ReversalResult(ReversalCode.memberNotFound);
    }
    final meal = MealType.fromWire(scan['mealType'] as String);
    final now = DateTime.now().toUtc();
    final consumed =
        Map<String, dynamic>.from(scan['consumed'] as Map? ?? const {});

    final archived = Map<String, dynamic>.from(scan)
      ..remove('id')
      ..addAll({
        'reversed': true,
        'reversedAt': now.toIso8601String(),
        'reversedBy': reversedBy,
      });
    final b = _store.batch()
      ..set(_store.doc(Col.scans, '${scanId}_r${now.millisecondsSinceEpoch}'),
          archived)
      ..delete(ref)
      ..update(_store.doc(Col.members, memberId),
          MemberService.balanceDelta(_single(meal)));
    consumed.forEach((ingredientId, qty) =>
        b.update(_store.doc(Col.ingredients, ingredientId), {
          'stockQty': FieldValue.increment((qty as num).toDouble()),
          'updatedAt': now.toIso8601String(),
        }));
    await _store.commit(b, 'scan.reverse $scanId');

    final restored = Member.fromJson(memberRow).balances.forMeal(meal) + 1;
    _log.info('reversed scan_id=$scanId member_id=$memberId meal=${meal.wire} '
        'restored=$restored by=$reversedBy');
    return ReversalResult(ReversalCode.scanReversed,
        restored: restored, mealType: meal);
  }

  /// Recent scans, newest first — backs the scan log and reversal picker.
  Future<List<ScanRecord>> recentScans(
      {String? memberId, int limit = 200}) async {
    Query<Json> q = _store
        .col(Col.scans)
        .orderBy('scannedAt', descending: true)
        .limit(limit.clamp(1, 1000));
    if (memberId != null) q = q.where('memberId', isEqualTo: memberId);
    return (await _store.fresh(q)).map(ScanRecord.fromJson).toList();
  }

  Future<Json?> _freshOrNull(DocumentReference<Json> ref) async {
    try {
      return await _store.freshDoc(ref);
    } on FirebaseException {
      return null;
    }
  }

  static UnitCounts _single(MealType meal) => UnitCounts(
        lunch: meal == MealType.lunch ? 1 : 0,
        breakfast: meal == MealType.breakfast ? 1 : 0,
        brunch: meal == MealType.brunch ? 1 : 0,
      );
}

/// `YYYY-MM-DD` of a local date — the day key scans, menu entries and
/// purchase items share.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
