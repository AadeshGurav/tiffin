import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../core/logging.dart';
import '../core/sentinels.dart';
import '../data/store.dart';
import '../domain/inventory.dart';

/// Ingredients master list (PRD §6.5.1). Admin writes; counter reads. Stock
/// changes are increments so deliveries and scans recorded on different
/// phones add up instead of overwriting each other.
class IngredientService {
  IngredientService(this._store);

  final Store _store;
  final _log = log('ingredient');

  CollectionReference<Json> get _col => _store.col(Col.ingredients);

  Future<List<Ingredient>> list() async =>
      (await _store.cached(_col)).map(Ingredient.fromJson).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<Ingredient> _get(String id) async {
    final row = await _store.cachedDoc(_col.doc(id));
    if (row == null) {
      throw const NotFoundException(ErrorCode.ingredientNotFound);
    }
    return Ingredient.fromJson(row);
  }

  Future<Ingredient> create(
    String name,
    String unit, {
    double stockQty = 0,
    double? lowStockAt,
  }) async {
    if (name.trim().isEmpty || unit.trim().isEmpty) {
      throw const ValidationException(ErrorCode.ingredientNameUnitRequired);
    }
    await _requireFreeName(name.trim());
    final now = DateTime.now().toUtc();
    final ingredient = Ingredient(
      id: _store.newId(Col.ingredients),
      name: name.trim(),
      unit: unit.trim(),
      stockQty: stockQty,
      lowStockAt: lowStockAt,
      createdAt: now,
      updatedAt: now,
    );
    await _store.commit(
        _store.batch()
          ..set(_col.doc(ingredient.id), ingredient.toJson()..remove('id')),
        'ingredients.create');
    return ingredient;
  }

  Future<Ingredient> update(
    String id, {
    String? name,
    String? unit,
    double? stockQty,
    Object? lowStockAt = kUnset,
  }) async {
    if (name == null &&
        unit == null &&
        stockQty == null &&
        identical(lowStockAt, kUnset)) {
      throw const ValidationException(ErrorCode.nothingToUpdate);
    }
    await _get(id);
    if (name != null) await _requireFreeName(name.trim(), except: id);
    final changes = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (unit != null) 'unit': unit.trim(),
      if (stockQty != null) 'stockQty': stockQty,
      if (!identical(lowStockAt, kUnset)) 'lowStockAt': lowStockAt,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _store.commit(
        _store.batch()..update(_col.doc(id), changes), 'ingredients.update');
    return _get(id);
  }

  /// Manual stock correction (an untracked delivery, spoilage, a recount).
  /// [delta] is added to the on-hand quantity; [reason] is logged.
  Future<Ingredient> adjustStock(String id, double delta, String reason) async {
    await _get(id);
    await _store.commit(
        _store.batch()
          ..update(_col.doc(id), {
            'stockQty': FieldValue.increment(delta),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        'ingredients.adjust');
    _log.info('stock_adjust ingredient_id=$id delta=$delta '
        'reason="${reason.trim()}"');
    return _get(id);
  }

  Future<void> delete(String id) async {
    await _get(id);
    await _store.commit(
        _store.batch()..delete(_col.doc(id)), 'ingredients.delete');
  }

  Future<void> _requireFreeName(String name, {String? except}) async {
    final taken = (await list()).any(
        (i) => i.name.toLowerCase() == name.toLowerCase() && i.id != except);
    if (taken) {
      throw ConflictException(ErrorCode.ingredientExists, {'name': name});
    }
  }
}
