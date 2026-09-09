import '../core/app_mode.dart';

/// Menu planning models (PRD §6.5).

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
        id: j['id'] as int,
        name: j['name'] as String,
        description: j['description'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

/// One planned meal for a date (PRD §6.5). `date` is a calendar date; time is
/// irrelevant, so it's carried as `YYYY-MM-DD`.
class MenuEntry {
  const MenuEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.category,
    required this.headcount,
    required this.items,
    required this.createdBy,
  });

  factory MenuEntry.fromJson(Map<String, dynamic> j) => MenuEntry(
        id: j['id'] as int,
        date: DateTime.parse(j['date'] as String),
        mealType: MealType.fromWire(j['mealType'] as String),
        category: j['category'] as String,
        headcount: (j['headcount'] as num?)?.toInt() ?? 0,
        items: (j['items'] as List<dynamic>).map((e) => e as String).toList(),
        createdBy: j['createdBy'] as String,
      );

  final int id;
  final DateTime date;
  final MealType mealType;

  /// The single serving group this entry is for (e.g. 'Jain').
  final String category;

  /// Approximate plates of [category] expected for this meal.
  final int headcount;
  final List<String> items;
  final String createdBy;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': _ymd(date),
        'mealType': mealType.wire,
        'category': category,
        'headcount': headcount,
        'items': items,
        'createdBy': createdBy,
      };
}

class MenuEntryDraft {
  const MenuEntryDraft({
    required this.date,
    required this.mealType,
    required this.category,
    required this.headcount,
    required this.items,
    required this.createdBy,
  });

  factory MenuEntryDraft.fromJson(Map<String, dynamic> j) => MenuEntryDraft(
        date: DateTime.parse(j['date'] as String),
        mealType: MealType.fromWire(j['mealType'] as String),
        category: (j['category'] as String).trim(),
        headcount: (j['headcount'] as num?)?.toInt() ?? 0,
        items: (j['items'] as List<dynamic>).map((e) => e as String).toList(),
        createdBy: j['createdBy'] as String,
      );

  final DateTime date;
  final MealType mealType;
  final String category;
  final int headcount;
  final List<String> items;
  final String createdBy;

  Map<String, dynamic> toJson() => {
        'date': _ymd(date),
        'mealType': mealType.wire,
        'category': category,
        'headcount': headcount,
        'items': items,
        'createdBy': createdBy,
      };
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
