import 'package:drift/drift.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../core/sentinels.dart';
import '../data/local/database.dart' hide Ingredient;
import '../data/local/mappers.dart';
import '../domain/inventory.dart';

/// Ingredients master list — a port of v1 `app/routers/ingredients.py`
/// (PRD §6.5.1). Admin writes; counter reads (for manual purchase items).
class IngredientService {
  IngredientService(this._db);

  final AppDatabase _db;
  final _log = log('ingredient');

  Future<List<Ingredient>> list() async {
    final rows = await (_db.select(_db.ingredients)
          ..orderBy([(i) => OrderingTerm.asc(i.name)]))
        .get();
    return rows.map(ingredientFromRow).toList();
  }

  Future<Ingredient> create(
    String name,
    String unit, {
    double stockQty = 0,
    double? lowStockAt,
  }) async {
    if (name.trim().isEmpty || unit.trim().isEmpty) {
      throw const ValidationException('Name and unit are both required.');
    }
    final now = DateTime.now().toUtc();
    try {
      final id = await _db.into(_db.ingredients).insert(
            IngredientsCompanion.insert(
              name: name,
              unit: unit,
              stockQty: Value(stockQty),
              lowStockAt: Value(lowStockAt),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final row = await (_db.select(_db.ingredients)
            ..where((i) => i.id.equals(id)))
          .getSingle();
      return ingredientFromRow(row);
    } on Exception catch (e) {
      if (_isUnique(e)) {
        throw ConflictException("Ingredient '$name' already exists.");
      }
      rethrow;
    }
  }

  Future<Ingredient> update(
    int id, {
    String? name,
    String? unit,
    double? stockQty,
    Object? lowStockAt = kUnset,
  }) async {
    if (name == null &&
        unit == null &&
        stockQty == null &&
        identical(lowStockAt, kUnset)) {
      throw const ValidationException('Nothing to update.');
    }
    try {
      final n = await (_db.update(_db.ingredients)
            ..where((i) => i.id.equals(id)))
          .write(IngredientsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        unit: unit == null ? const Value.absent() : Value(unit),
        stockQty: stockQty == null ? const Value.absent() : Value(stockQty),
        lowStockAt: identical(lowStockAt, kUnset)
            ? const Value.absent()
            : Value(lowStockAt as double?),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      if (n == 0) throw const NotFoundException('Ingredient not found.');
    } on Exception catch (e) {
      if (_isUnique(e)) {
        throw ConflictException("Ingredient '$name' already exists.");
      }
      rethrow;
    }
    final row = await (_db.select(_db.ingredients)
          ..where((i) => i.id.equals(id)))
        .getSingle();
    return ingredientFromRow(row);
  }

  /// Manual stock correction (delivery not tracked, spoilage, a bad count).
  /// [delta] is added to the on-hand quantity; [reason] is logged.
  Future<Ingredient> adjustStock(int id, double delta, String reason) async {
    final row = await (_db.select(_db.ingredients)
          ..where((i) => i.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw const NotFoundException('Ingredient not found.');
    final next = row.stockQty + delta;
    await (_db.update(_db.ingredients)..where((i) => i.id.equals(id)))
        .write(IngredientsCompanion(
      stockQty: Value(next),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
    _log.info('stock_adjust ingredient_id=$id delta=$delta -> $next '
        'reason="${reason.trim()}"');
    final updated = await (_db.select(_db.ingredients)
          ..where((i) => i.id.equals(id)))
        .getSingle();
    return ingredientFromRow(updated);
  }

  Future<void> delete(int id) async {
    final n =
        await (_db.delete(_db.ingredients)..where((i) => i.id.equals(id))).go();
    if (n == 0) throw const NotFoundException('Ingredient not found.');
  }

  bool _isUnique(Exception e) => e.toString().toLowerCase().contains('unique');
}
