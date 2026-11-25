import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/domain/menu.dart';
import 'package:tiffin/ui/theme/category_palette.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);
  Map<String, dynamic> json({Object? color}) => {
        'id': 'c1',
        'name': 'Jain',
        'description': null,
        if (color != null) 'color': color,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

  test('a category colour survives a JSON round trip', () {
    final argb = CategoryColor.teal.argb;
    final back = MenuCategory.fromJson(
        MenuCategory.fromJson(json(color: argb)).toJson());
    expect(back.color, argb);
    expect(CategoryColor.fromArgb(back.color), CategoryColor.teal);
  });

  test('a category stored before colours existed has none', () {
    final c = MenuCategory.fromJson(json());
    expect(c.color, isNull);
    expect(cardColorFor(c.color), kNeutralCardColor);
  });

  test('a colour outside the palette is not mistaken for a palette entry', () {
    expect(CategoryColor.fromArgb(0xFF123456), isNull);
    expect(CategoryColor.fromArgb(null), isNull);
  });

  test('every palette colour is distinct and dark enough for white paper', () {
    final argbs = CategoryColor.values.map((c) => c.argb).toSet();
    expect(argbs, hasLength(CategoryColor.values.length));
    for (final c in CategoryColor.values) {
      // WCAG: 1.05 / (luminance + 0.05) >= 4.5 against white.
      final contrast = 1.05 / (c.color.computeLuminance() + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: c.name);
    }
  });
}
