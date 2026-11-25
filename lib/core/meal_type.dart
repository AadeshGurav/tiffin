/// The three meal services (PRD §5). The wire name is what Firestore stores.
enum MealType {
  breakfast,
  lunch,
  brunch;

  static MealType fromWire(String v) =>
      MealType.values.firstWhere((m) => m.name == v,
          orElse: () => throw ArgumentError('Unknown meal type: $v'));

  /// The built-in meal for [v], or null for an anytime meal id (ADR 0009).
  static MealType? tryWire(String v) {
    for (final m in MealType.values) {
      if (m.name == v) return m;
    }
    return null;
  }

  String get wire => name;
}
