import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors.dart';
import '../core/meal_type.dart';
import '../core/sentinels.dart';
import '../data/store.dart';
import '../domain/menu.dart';
import 'scan_service.dart' show ymd;

/// Menu categories + menu entries (PRD §6.5). Categories are an editable
/// list, not an enum.
class MenuService {
  MenuService(this._store);

  final Store _store;

  /// One entry per (day, meal, category), so the id *is* the uniqueness rule
  /// and the scanner can look today's plate up without a query.
  static String entryId(String day, MealType meal, String category) =>
      '${day}_${meal.wire}_${category.trim().toLowerCase().replaceAll('/', '_')}';

  CollectionReference<Json> get _categories => _store.col(Col.menuCategories);
  CollectionReference<Json> get _entries => _store.col(Col.menu);

  // ---- categories --------------------------------------------------

  Future<List<MenuCategory>> listCategories() async =>
      (await _store.cached(_categories)).map(MenuCategory.fromJson).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<MenuCategory> createCategory(String name, String? description) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const ValidationException(ErrorCode.categoryNameBlank);
    }
    await _requireFreeName(clean);
    final now = DateTime.now().toUtc();
    final category = MenuCategory(
      id: _store.newId(Col.menuCategories),
      name: clean,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
    final b = _store.batch()
      ..set(_categories.doc(category.id), category.toJson()..remove('id'));
    await _store.commit(b, 'menuCategories.create');
    return category;
  }

  Future<MenuCategory> updateCategory(
    String id, {
    String? name,
    Object? description = kUnset,
  }) async {
    final existing = await _store.cachedDoc(_categories.doc(id));
    if (existing == null) {
      throw const NotFoundException(ErrorCode.categoryNotFound);
    }
    if (name != null) await _requireFreeName(name.trim(), except: id);
    final changes = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (!identical(description, kUnset)) 'description': description,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _store.commit(_store.batch()..update(_categories.doc(id), changes),
        'menuCategories.update');
    return MenuCategory.fromJson({...existing, ...changes});
  }

  Future<void> deleteCategory(String id) async {
    if (await _store.cachedDoc(_categories.doc(id)) == null) {
      throw const NotFoundException(ErrorCode.categoryNotFound);
    }
    await _store.commit(
        _store.batch()..delete(_categories.doc(id)), 'menuCategories.delete');
  }

  Future<void> _requireFreeName(String name, {String? except}) async {
    final taken = (await listCategories()).any(
        (c) => c.name.toLowerCase() == name.toLowerCase() && c.id != except);
    if (taken) {
      throw ConflictException(ErrorCode.categoryExists, {'name': name});
    }
  }

  // ---- entries ---------------------------------------------------

  Future<List<MenuEntry>> listEntries({DateTime? start, DateTime? end}) async {
    Query<Json> q = _entries;
    if (start != null) q = q.where('date', isGreaterThanOrEqualTo: ymd(start));
    if (end != null) q = q.where('date', isLessThanOrEqualTo: ymd(end));
    return (await _store.cached(q)).map(MenuEntry.fromJson).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<MenuEntry> addEntry(MenuEntryDraft draft) async {
    if (draft.items.isEmpty) {
      throw const ValidationException(ErrorCode.menuItemsRequired);
    }
    if (draft.headcount < 0) {
      throw const ValidationException(ErrorCode.headcountNegative);
    }
    final known = (await listCategories()).any((c) => c.name == draft.category);
    if (!known) {
      throw ValidationException(
          ErrorCode.unknownCategory, {'name': draft.category});
    }

    final id = entryId(ymd(draft.date), draft.mealType, draft.category);
    if (await _store.cachedDoc(_entries.doc(id)) != null) {
      throw ConflictException(ErrorCode.menuEntryExists,
          {'meal': draft.mealType.wire, 'category': draft.category});
    }
    final json = {...draft.toJson(), 'id': id};
    await _store.commit(
        _store.batch()..set(_entries.doc(id), draft.toJson()), 'menu.add');
    return MenuEntry.fromJson(json);
  }

  /// Change the plate contents and/or the expected headcount of an entry.
  Future<MenuEntry> updateEntry(
    String id, {
    List<String>? items,
    int? headcount,
  }) async {
    if (items != null && items.isEmpty) {
      throw const ValidationException(ErrorCode.menuItemsRequired);
    }
    if (headcount != null && headcount < 0) {
      throw const ValidationException(ErrorCode.headcountNegative);
    }
    final existing = await _store.cachedDoc(_entries.doc(id));
    if (existing == null) {
      throw const NotFoundException(ErrorCode.menuEntryNotFound);
    }
    final changes = <String, dynamic>{
      if (items != null) 'items': items,
      if (headcount != null) 'headcount': headcount,
    };
    if (changes.isEmpty) return MenuEntry.fromJson(existing);
    await _store.commit(
        _store.batch()..update(_entries.doc(id), changes), 'menu.update');
    return MenuEntry.fromJson({...existing, ...changes});
  }

  Future<void> deleteEntry(String id) async {
    if (await _store.cachedDoc(_entries.doc(id)) == null) {
      throw const NotFoundException(ErrorCode.menuEntryNotFound);
    }
    await _store.commit(
        _store.batch()..delete(_entries.doc(id)), 'menu.delete');
  }
}
