import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/menu.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/services/kitchen/menu_service.dart';

import '../../support/fake_backend.dart';

/// Planning anytime meals on the menu (ADR 0009 §7).
void main() {
  late Backend b;
  const tea = 'mtea00001';

  MenuEntryDraft draft(String meal) => MenuEntryDraft(
        date: DateTime(2026, 11, 28), // a Saturday: no day rule for Tea
        meal: meal,
        category: 'Normal',
        headcount: 20,
        items: const ['Masala chai'],
        createdBy: '',
      );

  setUp(() async {
    b = (await fakeBackend()).backend;
    await signInAdmin(b);
    await b.createMenuCategory('Normal', null);
    await b.updateSettings(const SettingsPatch(anytimeMeals: [
      AnytimeMeal(id: tea, name: 'Tea', price: 10),
      AnytimeMeal(id: 'mold00001', name: 'Old', price: 5, active: false),
    ]));
  });

  test('an anytime meal is planned beside a built-in on the same day',
      () async {
    final t = await b.addMenuEntry(draft(tea));
    final l = await b.addMenuEntry(draft('lunch'));
    expect(t.id, isNot(l.id));
    expect(t.id, MenuService.entryId('2026-11-28', tea, 'Normal'));
    expect(
        (await b.listMenu()).map((e) => e.meal), containsAll([tea, 'lunch']));
  });

  test('an unknown or retired meal cannot be planned', () async {
    for (final id in ['mnope0000', 'mold00001', 'a/b']) {
      await expectLater(
          b.addMenuEntry(draft(id)),
          throwsA(isA<ValidationException>()
              .having((e) => e.code, 'code', ErrorCode.unknownMeal)));
    }
  });
}
