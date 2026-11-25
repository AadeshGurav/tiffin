import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/services/system/settings_service.dart';

import '../../support/fake_backend.dart';

/// The anytime-meal catalogue in `meta/settings` (ADR 0009 §2).
void main() {
  late Backend b;

  setUp(() async {
    b = (await fakeBackend()).backend;
    await signInAdmin(b);
  });

  const tea = AnytimeMeal(id: 'mtea00001', name: 'Tea', price: 10);
  const juice =
      AnytimeMeal(id: 'mjuice001', name: 'Juice', price: 25, group: 'Drinks');

  Future<void> save(List<AnytimeMeal> meals) =>
      b.updateSettings(SettingsPatch(anytimeMeals: meals));

  Matcher code(ErrorCode c) =>
      throwsA(isA<ValidationException>().having((e) => e.code, 'code', c));

  test('a canteen that never saved the catalogue reads none', () async {
    expect((await b.getSettings()).anytimeMeals, isEmpty);
  });

  test('the catalogue round-trips, group included, names trimmed', () async {
    await save([tea.copyWith(name: '  Tea '), juice]);
    final s = await b.getSettings();
    expect(s.anytimeMeals.map((m) => m.name), ['Tea', 'Juice']);
    expect(s.anytimeMeal('mjuice001')!.group, 'Drinks');
    expect(s.anytimeMeal('mtea00001')!.group, isNull);
  });

  test('a blank group reads as none', () {
    expect(
        AnytimeMeal.fromJson({...tea.toJson(), 'group': '  '}).group, isNull);
    expect(tea.copyWith(group: ' ').toJson().containsKey('group'), isFalse);
  });

  test('each validation branch', () async {
    await expectLater(
        save([tea.copyWith(name: ' ')]), code(ErrorCode.mealNameBlank));
    await expectLater(save([tea, juice.copyWith(name: 'TEA')]),
        code(ErrorCode.mealNameTaken));
    await expectLater(
        save([tea.copyWith(price: -1)]), code(ErrorCode.settingsNegative));
    await expectLater(
        save([const AnytimeMeal(id: 'Bad.id', name: 'X', price: 1)]),
        code(ErrorCode.unknownMeal));
    await expectLater(
        save([const AnytimeMeal(id: 'lunch', name: 'X', price: 1)]),
        code(ErrorCode.unknownMeal));
    await expectLater(
        save([tea, juice.copyWith(name: 'Other').copyWithId(tea.id)]),
        code(ErrorCode.unknownMeal));
  });

  test('a stored meal cannot be dropped, only retired', () async {
    await save([tea, juice]);
    await expectLater(save([juice]), code(ErrorCode.mealCannotBeRemoved));
    await save([tea.copyWith(active: false), juice]);
    final s = await b.getSettings();
    expect(s.activeAnytimeMeals.map((m) => m.id), ['mjuice001']);
    expect(s.anytimeMeal('mtea00001')!.active, isFalse);
  });

  test('priceOf: built-in, anytime (retired too), unknown', () async {
    await save([tea.copyWith(active: false)]);
    final s = await b.getSettings();
    expect(s.priceOf('lunch'), s.unitPrices.lunch);
    expect(s.priceOf('mtea00001'), 10);
    expect(() => s.priceOf('mnope0000'), code(ErrorCode.unknownMeal));
  });

  test('new ids are well-formed and distinct', () {
    final ids = {
      for (var i = 0; i < 50; i++) SettingsService.newAnytimeMealId()
    };
    expect(ids, hasLength(50));
    expect(ids.every(AnytimeMeal.idPattern.hasMatch), isTrue);
  });

  test('groupMeals: ungrouped first, then groups in first-seen order', () {
    const a =
        AnytimeMeal(id: 'ma0000000', name: 'A', price: 1, group: 'Snacks');
    const c =
        AnytimeMeal(id: 'mc0000000', name: 'C', price: 1, group: 'drinks');
    final ordered = groupMeals([a, juice, tea, c]);
    expect(ordered.map((m) => m.name), ['Tea', 'A', 'Juice', 'C']);
  });
}

extension on AnytimeMeal {
  AnytimeMeal copyWithId(String id) => AnytimeMeal(
      id: id, name: name, price: price, active: active, group: this.group);
}
