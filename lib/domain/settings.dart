/// The global settings, as a plain immutable snapshot (PRD §6.8). The drift
/// `AppSettings` row is the storage; this is what services and the API pass
/// around. Nested v1 maps (`meal_windows`, `unit_prices`) are modelled as
/// small value types here.
library;

import '../core/errors.dart';
import '../core/meal_type.dart';

class MealWindowConfig {
  const MealWindowConfig({required this.start, required this.end});

  factory MealWindowConfig.fromJson(Map<String, dynamic> j) =>
      MealWindowConfig(start: j['start'] as String, end: j['end'] as String);

  final String start; // "HH:MM", 24h
  final String end;

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
}

class UnitPrices {
  const UnitPrices(
      {required this.lunch, required this.breakfast, required this.brunch});

  factory UnitPrices.fromJson(Map<String, dynamic> j) => UnitPrices(
        lunch: (j['lunch'] as num).toDouble(),
        breakfast: (j['breakfast'] as num).toDouble(),
        brunch: (j['brunch'] as num).toDouble(),
      );

  final double lunch;
  final double breakfast;
  final double brunch;

  Map<String, dynamic> toJson() =>
      {'lunch': lunch, 'breakfast': breakfast, 'brunch': brunch};
}

/// An admin-defined meal with no window and no daily lock (ADR 0009): Tea,
/// Juice. Each has its own unit balance and price. Retired, never deleted, so
/// paid units always stay findable.
class AnytimeMeal {
  const AnytimeMeal({
    required this.id,
    required this.name,
    required this.price,
    this.active = true,
    this.group,
  });

  factory AnytimeMeal.fromJson(Map<String, dynamic> j) => AnytimeMeal(
        id: j['id'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
        active: j['active'] as bool? ?? true,
        group: _blankToNull(j['group'] as String?),
      );

  /// `m` + 8 lowercase alphanumerics: never a built-in meal's id, and safe
  /// as a Firestore field-path segment (`balances.<id>`).
  static final idPattern = RegExp(r'^m[a-z0-9]{8}$');

  final String id;
  final String name;
  final double price;
  final bool active;

  /// Optional free-text label (Drinks, Snacks) that only orders and groups
  /// meals on screen and in reports. Null when blank.
  final String? group;

  AnytimeMeal copyWith(
          {String? name, double? price, bool? active, String? group}) =>
      AnytimeMeal(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        active: active ?? this.active,
        group: group == null ? this.group : _blankToNull(group),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.trim(),
        'price': price,
        'active': active,
        if (_blankToNull(group) case final g?) 'group': g,
      };
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// [meals] in display order: ungrouped first, then each group in the order it
/// is first seen (case ignored), keeping the admin's order within a group.
List<AnytimeMeal> groupMeals(Iterable<AnytimeMeal> meals) {
  final byGroup = <String, List<AnytimeMeal>>{};
  for (final m in meals) {
    (byGroup[m.group?.toLowerCase() ?? ''] ??= []).add(m);
  }
  return [...?byGroup.remove(''), for (final g in byGroup.values) ...g];
}

class SettingsSnapshot {
  factory SettingsSnapshot.fromJson(Map<String, dynamic> j) => SettingsSnapshot(
        graceAllowanceEnabled: j['graceAllowanceEnabled'] as bool,
        graceAllowanceUnits: (j['graceAllowanceUnits'] as num).toInt(),
        reversalWindowMinutes: (j['reversalWindowMinutes'] as num).toInt(),
        mealWindows: (j['mealWindows'] as Map<String, dynamic>).map(
          (k, v) =>
              MapEntry(k, MealWindowConfig.fromJson(v as Map<String, dynamic>)),
        ),
        localTimezone: j['localTimezone'] as String,
        upiId: j['upiId'] as String,
        upiPayeeName: j['upiPayeeName'] as String,
        unitPrices:
            UnitPrices.fromJson(j['unitPrices'] as Map<String, dynamic>),
        appName: j['appName'] as String,
        prepLeadMinutes: (j['prepLeadMinutes'] as num).toInt(),
        purchaseLeadDays: (j['purchaseLeadDays'] as num).toInt(),
        enforceAppearance: j['enforceAppearance'] as bool? ?? false,
        appearanceTheme: j['appearanceTheme'] as String? ?? 'neobrutal',
        appearanceMode: j['appearanceMode'] as String? ?? 'system',
        appearanceMotion: j['appearanceMotion'] as bool? ?? true,
        anytimeMeals: [
          for (final m in j['anytimeMeals'] as List? ?? const [])
            AnytimeMeal.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
      );

  const SettingsSnapshot({
    required this.graceAllowanceEnabled,
    required this.graceAllowanceUnits,
    required this.reversalWindowMinutes,
    required this.mealWindows,
    required this.localTimezone,
    required this.upiId,
    required this.upiPayeeName,
    required this.unitPrices,
    required this.appName,
    required this.prepLeadMinutes,
    required this.purchaseLeadDays,
    this.enforceAppearance = false,
    this.appearanceTheme = 'neobrutal',
    this.appearanceMode = 'system',
    this.appearanceMotion = true,
    this.anytimeMeals = const [],
  });

  final bool graceAllowanceEnabled;
  final int graceAllowanceUnits;
  final int reversalWindowMinutes;

  /// Keyed by meal type wire name: 'breakfast' | 'lunch' | 'brunch'.
  final Map<String, MealWindowConfig> mealWindows;

  final String localTimezone;
  final String upiId;
  final String upiPayeeName;
  final UnitPrices unitPrices;
  final String appName;
  final int prepLeadMinutes;
  final int purchaseLeadDays;

  /// When true, every device on this host renders the appearance below rather
  /// than its own (CLAUDE.md §11.5). Wire names, not enums, because this
  /// crosses the HTTP boundary — an unknown value degrades to the default
  /// theme rather than failing a client's launch.
  final bool enforceAppearance;
  final String appearanceTheme;
  final String appearanceMode;
  final bool appearanceMotion;

  /// The anytime-meal catalogue, retired ones included, in the admin's order.
  final List<AnytimeMeal> anytimeMeals;

  List<AnytimeMeal> get activeAnytimeMeals => [
        for (final m in anytimeMeals)
          if (m.active) m
      ];

  AnytimeMeal? anytimeMeal(String id) {
    for (final m in anytimeMeals) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The unit price of any meal id: a built-in's from [unitPrices], an
  /// anytime meal's (retired too) from the catalogue. An id that is neither
  /// is refused rather than priced at 0, so money never moves for a meal
  /// nobody can see.
  double priceOf(String mealId) {
    switch (MealType.tryWire(mealId)) {
      case MealType.lunch:
        return unitPrices.lunch;
      case MealType.breakfast:
        return unitPrices.breakfast;
      case MealType.brunch:
        return unitPrices.brunch;
      case null:
        final m = anytimeMeal(mealId);
        if (m == null) {
          throw ValidationException(ErrorCode.unknownMeal, {'meal': mealId});
        }
        return m.price;
    }
  }

  /// Effective grace units for a member, given an optional per-member override
  /// (PRD §5). Null override → the global default when enabled, else 0.
  int effectiveGrace(int? memberOverride) {
    if (memberOverride != null) return memberOverride;
    return graceAllowanceEnabled ? graceAllowanceUnits : 0;
  }

  Map<String, dynamic> toJson() => {
        'graceAllowanceEnabled': graceAllowanceEnabled,
        'graceAllowanceUnits': graceAllowanceUnits,
        'reversalWindowMinutes': reversalWindowMinutes,
        'mealWindows': mealWindows.map((k, v) => MapEntry(k, v.toJson())),
        'localTimezone': localTimezone,
        'upiId': upiId,
        'upiPayeeName': upiPayeeName,
        'unitPrices': unitPrices.toJson(),
        'appName': appName,
        'prepLeadMinutes': prepLeadMinutes,
        'purchaseLeadDays': purchaseLeadDays,
        'enforceAppearance': enforceAppearance,
        'appearanceTheme': appearanceTheme,
        'appearanceMode': appearanceMode,
        'appearanceMotion': appearanceMotion,
        'anytimeMeals': [for (final m in anytimeMeals) m.toJson()],
      };

  /// The subset a device needs before anyone signs in, so the theme is right
  /// on the login screen rather than snapping after authentication.
  Map<String, dynamic> toAppearanceJson() => {
        'appName': appName,
        'enforceAppearance': enforceAppearance,
        'theme': appearanceTheme,
        'mode': appearanceMode,
        'motion': appearanceMotion,
      };
}
