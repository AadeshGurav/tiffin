/// The three meal services (PRD §5). The wire name is what Firestore stores.
enum MealType {
  breakfast,
  lunch,
  brunch;

  static MealType fromWire(String v) =>
      MealType.values.firstWhere((m) => m.name == v,
          orElse: () => throw ArgumentError('Unknown meal type: $v'));

  String get wire => name;
}
