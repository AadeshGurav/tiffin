import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../data/store.dart';
import '../domain/inventory.dart';

/// Recipes (PRD §6.5.1): a dish name, matched case-insensitively against menu
/// items, linked to the per-plate quantity of each ingredient it uses.
class RecipeService {
  RecipeService(this._store);

  final Store _store;

  CollectionReference<Json> get _col => _store.col(Col.recipes);

  Future<List<Recipe>> list() async =>
      (await _store.cached(_col)).map(Recipe.fromJson).toList()
        ..sort((a, b) => a.dishName.compareTo(b.dishName));

  Future<Recipe> create(RecipeDraft draft) async {
    if (draft.dishName.trim().isEmpty) {
      throw const ValidationException(ErrorCode.recipeDishBlank);
    }
    if (draft.ingredients.isEmpty) {
      throw const ValidationException(ErrorCode.recipeNeedsIngredient);
    }
    _rejectNonPositiveQuantities(draft.ingredients);
    await _validateIngredientIds(draft.ingredients.map((i) => i.ingredientId));
    await _requireFreeDish(draft.dishName.trim());

    final now = DateTime.now().toUtc();
    final recipe = Recipe(
      id: _store.newId(Col.recipes),
      dishName: draft.dishName.trim(),
      ingredients: draft.ingredients,
      createdAt: now,
      updatedAt: now,
    );
    await _store.commit(
        _store.batch()..set(_col.doc(recipe.id), recipe.toJson()..remove('id')),
        'recipes.create');
    return recipe;
  }

  Future<Recipe> update(
    String id, {
    String? dishName,
    List<RecipeIngredient>? ingredients,
  }) async {
    if (dishName == null && ingredients == null) {
      throw const ValidationException(ErrorCode.nothingToUpdate);
    }
    final existing = await _store.cachedDoc(_col.doc(id));
    if (existing == null) {
      throw const NotFoundException(ErrorCode.recipeNotFound);
    }
    if (ingredients != null) {
      _rejectNonPositiveQuantities(ingredients);
      await _validateIngredientIds(ingredients.map((i) => i.ingredientId));
    }
    if (dishName != null) await _requireFreeDish(dishName.trim(), except: id);
    final changes = <String, dynamic>{
      if (dishName != null) 'dishName': dishName.trim(),
      if (ingredients != null)
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _store.commit(
        _store.batch()..update(_col.doc(id), changes), 'recipes.update');
    return Recipe.fromJson({...existing, ...changes});
  }

  Future<void> delete(String id) async {
    if (await _store.cachedDoc(_col.doc(id)) == null) {
      throw const NotFoundException(ErrorCode.recipeNotFound);
    }
    await _store.commit(_store.batch()..delete(_col.doc(id)), 'recipes.delete');
  }

  void _rejectNonPositiveQuantities(List<RecipeIngredient> lines) {
    if (lines.any((l) => l.quantity <= 0)) {
      throw const ValidationException(ErrorCode.recipeQuantityPositive);
    }
  }

  Future<void> _validateIngredientIds(Iterable<String> ids) async {
    final known = {
      for (final i in await _store.cached(_store.col(Col.ingredients)))
        i['id'] as String
    };
    if (!ids.every(known.contains)) {
      throw const ValidationException(ErrorCode.recipeUnknownIngredient);
    }
  }

  Future<void> _requireFreeDish(String dish, {String? except}) async {
    final taken = (await list()).any((r) =>
        r.dishName.toLowerCase() == dish.toLowerCase() && r.id != except);
    if (taken) throw ConflictException(ErrorCode.recipeExists, {'name': dish});
  }
}
