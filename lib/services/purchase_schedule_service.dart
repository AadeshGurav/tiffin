import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/errors.dart';
import '../data/local/database.dart' hide PurchaseScheduleItem;
import '../data/local/mappers.dart';
import '../domain/inventory.dart';

/// Derives a shopping list from the menu calendar — a port of v1
/// `app/services/purchase_schedule_service.py` + `app/routers/purchase_schedule.py`
/// (PRD §6.5.1).
///
/// [generate] is idempotent: re-running it over an overlapping range never
/// duplicates an item or resets one already checked off. It does this the same
/// way v1 did — check whether a row for (date, ingredient) exists before
/// inserting — rather than a DB unique constraint, so ad-hoc manual items for
/// the same (date, ingredient) still coexist.
class PurchaseScheduleService {
  PurchaseScheduleService(this._db);

  final AppDatabase _db;

  /// Builds/refreshes the shopping list from the menu calendar in the range.
  /// For each entry, `need per ingredient = Σ(per-plate recipe qty) ×
  /// entry.headcount`, summed per `(date, ingredient)` and rounded up to 2 dp.
  /// Re-runnable: un-purchased `auto` rows are recomputed, purchased rows and
  /// `manual` rows are left alone. Returns the count of newly created rows.
  Future<int> generate(DateTime start, DateTime end) async {
    if (start.isAfter(end)) {
      throw const ValidationException('start must be on or before end.');
    }
    final startDate = _dateOnly(start);
    final endDate = _dateOnly(end);

    final entries = await (_db.select(_db.menuEntries)
          ..where((e) =>
              e.date.isBiggerOrEqualValue(startDate) &
              e.date.isSmallerOrEqualValue(endDate)))
        .get();
    if (entries.isEmpty) return 0;

    final allRecipes = await _db.select(_db.recipes).get();
    final recipeByDish = {for (final r in allRecipes) r.dishNameLower: r};
    final allIngredients = await _db.select(_db.ingredients).get();
    final ingredientById = {for (final i in allIngredients) i.id: i};

    // (date, ingredientId) -> total quantity needed.
    final need = <(DateTime, int), double>{};

    for (final entry in entries) {
      if (entry.headcount <= 0) continue;
      final entryDate = _dateOnly(entry.date);
      final items =
          (jsonDecode(entry.itemsJson) as List<dynamic>).cast<String>();
      for (final itemName in items) {
        final recipe = recipeByDish[itemName.trim().toLowerCase()];
        if (recipe == null) continue;
        final lines = (jsonDecode(recipe.ingredientsJson) as List<dynamic>)
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>));
        for (final ri in lines) {
          if (!ingredientById.containsKey(ri.ingredientId)) continue;
          final key = (entryDate, ri.ingredientId);
          need[key] = (need[key] ?? 0) + ri.quantity * entry.headcount;
        }
      }
    }

    final now = DateTime.now().toUtc();
    var created = 0;

    for (final entry in need.entries) {
      final (date, ingredientId) = entry.key;
      final ingredient = ingredientById[ingredientId]!;
      final qty = _roundUp2(entry.value);
      final note = '${formatQuantity(qty)} ${ingredient.unit}';

      final existing = await (_db.select(_db.purchaseScheduleItems)
            ..where((p) =>
                p.date.equals(date) &
                p.ingredientId.equals(ingredientId) &
                p.source.equals('auto'))
            ..limit(1))
          .getSingleOrNull();

      if (existing == null) {
        await _db.into(_db.purchaseScheduleItems).insert(
              PurchaseScheduleItemsCompanion.insert(
                date: date,
                ingredientId: ingredientId,
                ingredientName: ingredient.name,
                ingredientUnit: ingredient.unit,
                quantityNote: note,
                source: 'auto',
                createdAt: now,
                updatedAt: now,
              ),
            );
        created++;
      } else if (!existing.purchased) {
        // Headcount or recipe changed since last run — refresh the figure.
        await (_db.update(_db.purchaseScheduleItems)
              ..where((p) => p.id.equals(existing.id)))
            .write(PurchaseScheduleItemsCompanion(
          quantityNote: Value(note),
          ingredientName: Value(ingredient.name),
          ingredientUnit: Value(ingredient.unit),
          updatedAt: Value(now),
        ));
      }
    }
    return created;
  }

  double _roundUp2(double x) => (x * 100).ceil() / 100;

  Future<List<PurchaseScheduleItem>> list({
    DateTime? start,
    DateTime? end,
  }) async {
    final query = _db.select(_db.purchaseScheduleItems)
      ..orderBy([(p) => OrderingTerm.asc(p.date)]);
    if (start != null) {
      query.where((p) => p.date.isBiggerOrEqualValue(_dateOnly(start)));
    }
    if (end != null) {
      query.where((p) => p.date.isSmallerOrEqualValue(_dateOnly(end)));
    }
    return (await query.get()).map(purchaseItemFromRow).toList();
  }

  Future<PurchaseScheduleItem> addManual(
    DateTime date,
    int ingredientId,
    String quantityNote,
  ) async {
    if (quantityNote.trim().isEmpty) {
      throw const ValidationException('A quantity note is required.');
    }
    final ingredient = await (_db.select(_db.ingredients)
          ..where((i) => i.id.equals(ingredientId)))
        .getSingleOrNull();
    if (ingredient == null) {
      throw const NotFoundException('Ingredient not found.');
    }
    final now = DateTime.now().toUtc();
    final id = await _db.into(_db.purchaseScheduleItems).insert(
          PurchaseScheduleItemsCompanion.insert(
            date: _dateOnly(date),
            ingredientId: ingredientId,
            ingredientName: ingredient.name,
            ingredientUnit: ingredient.unit,
            quantityNote: quantityNote,
            source: 'manual',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final row = await (_db.select(_db.purchaseScheduleItems)
          ..where((p) => p.id.equals(id)))
        .getSingle();
    return purchaseItemFromRow(row);
  }

  /// [actingUsername] is recorded when an item is marked purchased.
  ///
  /// Marking purchased with [purchasedQty] adds that amount to the ingredient's
  /// stock; with [purchasedCost] it also records an [Expenses] row. Un-marking
  /// reverses both. All in one transaction.
  Future<PurchaseScheduleItem> updateItem(
    int id, {
    String? quantityNote,
    bool? purchased,
    double? purchasedQty,
    double? purchasedCost,
    required String actingUsername,
  }) async {
    if (quantityNote == null && purchased == null) {
      throw const ValidationException('Nothing to update.');
    }
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      final row = await (_db.select(_db.purchaseScheduleItems)
            ..where((p) => p.id.equals(id)))
          .getSingleOrNull();
      if (row == null) {
        throw const NotFoundException('Purchase schedule item not found.');
      }

      var expenseId = row.expenseId;
      var storedQty = row.purchasedQty;
      var storedCost = row.purchasedCost;

      if (purchased == true && !row.purchased) {
        // Newly purchased — apply stock and, if given, an expense.
        if (purchasedQty != null && purchasedQty != 0) {
          await _bumpStock(row.ingredientId, purchasedQty, now);
        }
        if (purchasedCost != null && purchasedCost > 0) {
          expenseId = await _db.into(_db.expenses).insert(
                ExpensesCompanion.insert(
                  category: 'ingredients',
                  description: '${row.ingredientName} — purchase',
                  amount: purchasedCost,
                  date: _dateOnly(now),
                  createdBy: actingUsername,
                ),
              );
        }
        storedQty = purchasedQty;
        storedCost = purchasedCost;
      } else if (purchased == false && row.purchased) {
        // Un-marked — roll back what marking it did.
        if (row.purchasedQty != null && row.purchasedQty != 0) {
          await _bumpStock(row.ingredientId, -row.purchasedQty!, now);
        }
        if (row.expenseId != null) {
          await (_db.delete(_db.expenses)
                ..where((e) => e.id.equals(row.expenseId!)))
              .go();
        }
        expenseId = null;
        storedQty = null;
        storedCost = null;
      }

      await (_db.update(_db.purchaseScheduleItems)
            ..where((p) => p.id.equals(id)))
          .write(PurchaseScheduleItemsCompanion(
        quantityNote:
            quantityNote == null ? const Value.absent() : Value(quantityNote),
        purchased: purchased == null ? const Value.absent() : Value(purchased),
        purchasedBy: purchased == null
            ? const Value.absent()
            : Value(purchased ? actingUsername : null),
        purchasedAt: purchased == null
            ? const Value.absent()
            : Value(purchased ? now : null),
        purchasedQty: Value(storedQty),
        purchasedCost: Value(storedCost),
        expenseId: Value(expenseId),
        updatedAt: Value(now),
      ));
    });

    final row = await (_db.select(_db.purchaseScheduleItems)
          ..where((p) => p.id.equals(id)))
        .getSingle();
    return purchaseItemFromRow(row);
  }

  Future<void> _bumpStock(int ingredientId, double delta, DateTime now) async {
    final ing = await (_db.select(_db.ingredients)
          ..where((i) => i.id.equals(ingredientId)))
        .getSingleOrNull();
    if (ing == null) return;
    await (_db.update(_db.ingredients)..where((i) => i.id.equals(ingredientId)))
        .write(IngredientsCompanion(
      stockQty: Value(ing.stockQty + delta),
      updatedAt: Value(now),
    ));
  }

  Future<void> deleteItem(int id) async {
    final n = await (_db.delete(_db.purchaseScheduleItems)
          ..where((p) => p.id.equals(id)))
        .go();
    if (n == 0) {
      throw const NotFoundException('Purchase schedule item not found.');
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}
