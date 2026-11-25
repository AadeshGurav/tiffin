import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffin/app/canteen_book.dart';
import 'package:tiffin/app/providers.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/scanner/meal_mode_bar.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

/// The scanner's meal bar (ADR 0009 §5).
void main() {
  const tea = AnytimeMeal(id: 'mtea00001', name: 'Tea', price: 10);
  const juice =
      AnytimeMeal(id: 'mjuice001', name: 'Juice', price: 25, group: 'Drinks');
  const retired =
      AnytimeMeal(id: 'mold00001', name: 'Old', price: 5, active: false);

  Future<void> pump(WidgetTester tester, List<AnytimeMeal> catalogue,
      ValueChanged<String?> onSelect,
      {String? selected}) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppText.localizationsDelegates,
      supportedLocales: AppText.supportedLocales,
      theme: buildTiffinTheme(TiffinThemeId.defaultTheme, Brightness.light),
      home: Scaffold(
        body: MealModeBar(
            catalogue: catalogue, selected: selected, onSelect: onSelect),
      ),
    ));
  }

  testWidgets('hidden when the canteen has no active anytime meal',
      (tester) async {
    await pump(tester, const [retired], (_) {});
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('lists By time, then meals grouped, and reports the pick',
      (tester) async {
    String? picked = 'unset';
    await pump(tester, const [juice, tea, retired], (id) => picked = id,
        selected: tea.id);
    final text = AppText.of(tester.element(find.byType(MealModeBar)));
    expect(find.text('Old'), findsNothing, reason: 'retired meals hide');
    expect(find.text('Drinks'), findsOneWidget, reason: 'group label');

    // Ungrouped Tea comes before the Drinks group.
    final x = tester.getTopLeft;
    expect(x(find.text(text.scannerModeByTime)).dx,
        lessThan(x(find.text('Tea')).dx));
    expect(x(find.text('Tea')).dx, lessThan(x(find.text('Juice')).dx));

    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tea'))
            .selected,
        isTrue);
    await tester.tap(find.text('Juice'));
    expect(picked, juice.id);
    await tester.tap(find.text(text.scannerModeByTime));
    expect(picked, isNull);
    expect(tester.getSize(find.byType(ChoiceChip).first).height,
        greaterThanOrEqualTo(48));
  });

  test('the mode is kept per phone and canteen; a retired one reads as By time',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer phone(String canteen) => ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeCanteenProvider.overrideWithValue(canteen),
        ]);

    await phone('A').read(scannerModeProvider.notifier).set(tea.id);
    expect(phone('A').read(scannerModeProvider), tea.id);
    expect(phone('B').read(scannerModeProvider), isNull);

    expect(liveMode(tea.id, const [tea]), tea.id);
    expect(liveMode(tea.id, [tea.copyWith(active: false)]), isNull);
    expect(liveMode('mgone0000', const [tea]), isNull);
  });
}
