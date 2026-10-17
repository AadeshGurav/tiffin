import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../data/store.dart';
import '../domain/inventory.dart';
import '../domain/menu.dart';
import 'scan_service.dart' show ymd;

/// Derives a shopping list from the menu calendar (PRD §6.5.1).
///
/// [generate] is idempotent: an automatic item's id is `{day}_{ingredient}_auto`,
/// so re-running over an overlapping range refreshes the figure instead of
/// adding a second row, and never touches an item already bought. Manual
/// items get random ids and so coexist with automatic ones.
class PurchaseScheduleService {
  PurchaseScheduleService(this._store);

  final Store _store;

  CollectionReference<Json> get _col => _store.col(Col.purchaseSchedule);

  /// For each menu entry in range, need per ingredient = Σ(per-plate recipe
  /// qty) × headcount, summed per (day, ingredient), rounded up to 2 dp.
  /// Returns the count of newly created items.
  Future<int> generate(DateTime start, DateTime end) async {
    if (start.isAfter(end)) {
      throw const ValidationException(ErrorCode.purchaseRangeInvalid);
    }
    final entries = (await _store.cached(_store
            .col(Col.menu)
            .where('date', isGreaterThanOrEqualTo: ymd(start))
            .where('date', isLessThanOrEqualTo: ymd(end))))
        .map(MenuEntry.fromJson);
    final recipes =
        (await _store.cached(_store.col(Col.recipes))).map(Recipe.fromJson);
    final recipeByDish = {
      for (final r in recipes) r.dishName.trim().toLowerCase(): r
    };
    final ingredientById = {
      for (final i in (await _store.cached(_store.col(Col.ingredients)))
          .map(Ingredient.fromJson))
        i.id: i
    };

    final need = <(String, String), double>{};
    for (final entry in entries) {
      if (entry.headcount <= 0) continue;
      final day = ymd(entry.date);
      for (final item in entry.items) {
        final recipe = recipeByDish[item.trim().toLowerCase()];
        if (recipe == null) continue;
        for (final ri in recipe.ingredients) {
          if (!ingredientById.containsKey(ri.ingredientId)) continue;
          final key = (day, ri.ingredientId);
          need[key] = (need[key] ?? 0) + ri.quantity * entry.headcount;
        }
      }
    }
    if (need.isEmpty) return 0;

    final now = DateTime.now().toUtc().toIso8601String();
    final b = _store.batch();
    var created = 0;
    for (final MapEntry(key: (day, ingredientId), value: qty) in need.entries) {
      final ingredient = ingredientById[ingredientId]!;
      final note = '${formatQuantity(_roundUp2(qty))} ${ingredient.unit}';
      final ref = _col.doc('${day}_${ingredientId}_auto');
      final existing = await _store.cachedDoc(ref);
      if (existing == null) {
        b.set(ref, {
          'date': day,
          'ingredientId': ingredientId,
          'ingredientName': ingredient.name,
          'ingredientUnit': ingredient.unit,
          'quantityNote': note,
          'source': 'auto',
          'purchased': false,
          'createdAt': now,
          'updatedAt': now,
        });
        created++;
      } else if (existing['purchased'] != true) {
        // Headcount or recipe changed since the last run — refresh it.
        b.update(ref, {
          'quantityNote': note,
          'ingredientName': ingredient.name,
          'ingredientUnit': ingredient.unit,
          'updatedAt': now,
        });
      }
    }
    await _store.commit(b, 'purchaseSchedule.generate');
    return created;
  }

  double _roundUp2(double x) => (x * 100).ceil() / 100;

  Future<List<PurchaseScheduleItem>> list({
    DateTime? start,
    DateTime? end,
  }) async {
    Query<Json> q = _col;
    if (start != null) q = q.where('date', isGreaterThanOrEqualTo: ymd(start));
    if (end != null) q = q.where('date', isLessThanOrEqualTo: ymd(end));
    return (await _store.cached(q)).map(PurchaseScheduleItem.fromJson).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<PurchaseScheduleItem> addManual(
    DateTime date,
    String ingredientId,
    String quantityNote,
  ) async {
    if (quantityNote.trim().isEmpty) {
      throw const ValidationException(ErrorCode.purchaseQuantityRequired);
    }
    final ingredient =
        await _store.cachedDoc(_store.doc(Col.ingredients, ingredientId));
    if (ingredient == null) {
      throw const NotFoundException(ErrorCode.ingredientNotFound);
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _store.newId(Col.purchaseSchedule);
    final row = {
      'date': ymd(date),
      'ingredientId': ingredientId,
      'ingredientName': ingredient['name'],
      'ingredientUnit': ingredient['unit'],
      'quantityNote': quantityNote,
      'source': 'manual',
      'purchased': false,
      'createdAt': now,
      'updatedAt': now,
    };
    await _store.commit(
        _store.batch()..set(_col.doc(id), row), 'purchaseSchedule.addManual');
    return PurchaseScheduleItem.fromJson({...row, 'id': id});
  }

  /// Marking an item bought with [purchasedQty] adds that much to stock; with
  /// [purchasedCost] it also records an expense. Un-marking undoes both. One
  /// batch, so the stock, the expense and the tick can't disagree.
  Future<PurchaseScheduleItem> updateItem(
    String id, {
    String? quantityNote,
    bool? purchased,
    double? purchasedQty,
    double? purchasedCost,
    required String actingUsername,
  }) async {
    if (quantityNote == null && purchased == null) {
      throw const ValidationException(ErrorCode.nothingToUpdate);
    }
    final ref = _col.doc(id);
    final row = await _store.cachedDoc(ref);
    if (row == null) {
      throw const NotFoundException(ErrorCode.purchaseItemNotFound);
    }
    final now = DateTime.now().toUtc();
    final wasPurchased = row['purchased'] == true;
    final ingredientRef =
        _store.doc(Col.ingredients, row['ingredientId'] as String);
    final b = _store.batch();
    final changes = <String, dynamic>{
      if (quantityNote != null) 'quantityNote': quantityNote,
      'updatedAt': now.toIso8601String(),
    };

    if (purchased == true && !wasPurchased) {
      if (purchasedQty != null && purchasedQty != 0) {
        b.update(
            ingredientRef, {'stockQty': FieldValue.increment(purchasedQty)});
      }
      String? expenseId;
      if (purchasedCost != null && purchasedCost > 0) {
        expenseId = _store.newId(Col.expenses);
        b.set(_store.doc(Col.expenses, expenseId), {
          'category': 'ingredients',
          'description': '${row['ingredientName']} — purchase',
          'amount': purchasedCost,
          'date': ymd(now),
          'createdBy': actingUsername,
        });
      }
      changes.addAll({
        'purchased': true,
        'purchasedBy': actingUsername,
        'purchasedAt': now.toIso8601String(),
        'purchasedQty': purchasedQty,
        'purchasedCost': purchasedCost,
        'expenseId': expenseId,
      });
    } else if (purchased == false && wasPurchased) {
      final qty = (row['purchasedQty'] as num?)?.toDouble();
      if (qty != null && qty != 0) {
        b.update(ingredientRef, {'stockQty': FieldValue.increment(-qty)});
      }
      final expenseId = row['expenseId'] as String?;
      if (expenseId != null) b.delete(_store.doc(Col.expenses, expenseId));
      changes.addAll({
        'purchased': false,
        'purchasedBy': null,
        'purchasedAt': null,
        'purchasedQty': null,
        'purchasedCost': null,
        'expenseId': null,
      });
    }
    b.update(ref, changes);
    await _store.commit(b, 'purchaseSchedule.update $id');
    return PurchaseScheduleItem.fromJson({...row, ...changes});
  }

  Future<void> deleteItem(String id) async {
    if (await _store.cachedDoc(_col.doc(id)) == null) {
      throw const NotFoundException(ErrorCode.purchaseItemNotFound);
    }
    await _store.commit(
        _store.batch()..delete(_col.doc(id)), 'purchaseSchedule.delete');
  }
}
