// Ingredients, recipes, purchase schedule (PRD §6.5.1).

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    this.stockQty = 0,
    this.lowStockAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'] as int,
        name: j['name'] as String,
        unit: j['unit'] as String,
        stockQty: (j['stockQty'] as num?)?.toDouble() ?? 0,
        lowStockAt: (j['lowStockAt'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  final int id;
  final String name;
  final String unit;

  /// On-hand quantity in [unit].
  final double stockQty;

  /// Alert threshold in [unit]; null = no low-stock alert.
  final double? lowStockAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLow => lowStockAt != null && stockQty <= lowStockAt!;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'stockQty': stockQty,
        'lowStockAt': lowStockAt,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

/// One line of a recipe: an ingredient plus how much of it, counted in that
/// ingredient's own unit (PRD §6.5.1). `quantity` is a plain number — the unit
/// lives on the [Ingredient], so a line renders as e.g. "Rice — 2 kg".
class RecipeIngredient {
  const RecipeIngredient({required this.ingredientId, required this.quantity});

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        ingredientId: j['ingredientId'] as int,
        // Tolerate the pre-v6 shape ({quantityNote: "2kg per 50"}) in case a
        // row slips through unmigrated — take the leading number.
        quantity: (j['quantity'] as num?)?.toDouble() ??
            _leadingNumber(j['quantityNote'] as String?),
      );

  final int ingredientId;
  final double quantity;

  Map<String, dynamic> toJson() =>
      {'ingredientId': ingredientId, 'quantity': quantity};

  static double _leadingNumber(String? note) {
    if (note == null) return 1;
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(note);
    return match == null ? 1 : (double.tryParse(match.group(0)!) ?? 1);
  }
}

/// Formats a quantity for display without a trailing ".0" on whole numbers:
/// 2.0 -> "2", 1.5 -> "1.5".
String formatQuantity(double q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

class Recipe {
  const Recipe({
    required this.id,
    required this.dishName,
    required this.ingredients,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as int,
        dishName: j['dishName'] as String,
        ingredients: (j['ingredients'] as List<dynamic>)
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  final int id;
  final String dishName;
  final List<RecipeIngredient> ingredients;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dishName': dishName,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

class RecipeDraft {
  const RecipeDraft({required this.dishName, required this.ingredients});

  factory RecipeDraft.fromJson(Map<String, dynamic> j) => RecipeDraft(
        dishName: j['dishName'] as String,
        ingredients: (j['ingredients'] as List<dynamic>)
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String dishName;
  final List<RecipeIngredient> ingredients;

  Map<String, dynamic> toJson() => {
        'dishName': dishName,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
      };
}

class PurchaseScheduleItem {
  const PurchaseScheduleItem({
    required this.id,
    required this.date,
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientUnit,
    required this.quantityNote,
    required this.source,
    required this.purchased,
    this.purchasedBy,
    this.purchasedAt,
    this.purchasedQty,
    this.purchasedCost,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseScheduleItem.fromJson(Map<String, dynamic> j) =>
      PurchaseScheduleItem(
        id: j['id'] as int,
        date: DateTime.parse(j['date'] as String),
        ingredientId: j['ingredientId'] as int,
        ingredientName: j['ingredientName'] as String,
        ingredientUnit: j['ingredientUnit'] as String,
        quantityNote: j['quantityNote'] as String,
        source: j['source'] as String,
        purchased: j['purchased'] as bool,
        purchasedBy: j['purchasedBy'] as String?,
        purchasedAt: j['purchasedAt'] == null
            ? null
            : DateTime.parse(j['purchasedAt'] as String),
        purchasedQty: (j['purchasedQty'] as num?)?.toDouble(),
        purchasedCost: (j['purchasedCost'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  final int id;
  final DateTime date;
  final int ingredientId;
  final String ingredientName;
  final String ingredientUnit;
  final String quantityNote;
  final String source; // 'auto' | 'manual'
  final bool purchased;
  final String? purchasedBy;
  final DateTime? purchasedAt;
  final double? purchasedQty;
  final double? purchasedCost;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': _ymd(date),
        'ingredientId': ingredientId,
        'ingredientName': ingredientName,
        'ingredientUnit': ingredientUnit,
        'quantityNote': quantityNote,
        'source': source,
        'purchased': purchased,
        'purchasedBy': purchasedBy,
        'purchasedAt': purchasedAt?.toUtc().toIso8601String(),
        'purchasedQty': purchasedQty,
        'purchasedCost': purchasedCost,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}
