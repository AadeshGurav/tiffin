import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/admin/system/anytime_meals_section.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

/// Settings ▸ anytime meals: each edit hands the whole catalogue to onSave.
void main() {
  const tea = AnytimeMeal(id: 'mtea00001', name: 'Tea', price: 10);
  const juice =
      AnytimeMeal(id: 'mjuice001', name: 'Juice', price: 25, group: 'Drinks');

  late List<AnytimeMeal>? saved;
  late AppText text;

  Future<void> pump(WidgetTester tester, List<AnytimeMeal> meals,
      {Object? fail}) async {
    saved = null;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppText.localizationsDelegates,
      supportedLocales: AppText.supportedLocales,
      theme: buildTiffinTheme(TiffinThemeId.defaultTheme, Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnytimeMealsSection(
            meals: meals,
            onSave: (next) async {
              if (fail != null) throw fail;
              saved = next;
            },
          ),
        ),
      ),
    ));
    text = AppText.of(tester.element(find.byType(AnytimeMealsSection)));
  }

  Finder field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)),
      matching: find.byType(TextField));

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(text.anytimeMealsSaveButton));
    await tester.pumpAndSettle();
  }

  testWidgets('add: a new meal with a fresh id, trimmed group', (tester) async {
    await pump(tester, const [tea]);
    await tester.tap(find.text(text.anytimeMealsAddButton));
    await tester.pumpAndSettle();
    await tester.enterText(field(text.anytimeMealsNameLabel).first, 'Samosa');
    await tester.enterText(field(text.anytimeMealsPriceLabel).first, '15');
    await tester.enterText(field(text.anytimeMealsGroupLabel).first, 'Snacks ');
    await save(tester);

    expect(saved, hasLength(2));
    expect(saved!.first.id, tea.id);
    final added = saved!.last;
    expect(AnytimeMeal.idPattern.hasMatch(added.id), isTrue);
    expect((added.name, added.price, added.active), ('Samosa', 15, true));
    expect(added.toJson()['group'], 'Snacks');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('rename, regroup from a suggestion, and retire', (tester) async {
    await pump(tester, const [tea, juice]);
    expect(find.text('Drinks'), findsOneWidget, reason: 'group heading');

    await tester.tap(find.text('Tea'));
    await tester.pumpAndSettle();
    await tester.enterText(field(text.anytimeMealsNameLabel).first, 'Chai');
    await tester.tap(find.widgetWithText(ActionChip, 'Drinks'));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await save(tester);

    final chai = saved!.firstWhere((m) => m.id == tea.id);
    expect((chai.name, chai.group, chai.active), ('Chai', 'Drinks', false));
    expect(saved!.map((m) => m.id), [tea.id, juice.id],
        reason: 'nothing dropped, order kept');
  });

  testWidgets('a refused save stays open with the typing and the reason',
      (tester) async {
    await pump(tester, const [tea],
        fail: const ValidationException(
            ErrorCode.mealNameTaken, {'name': 'Tea'}));
    await tester.tap(find.text(text.anytimeMealsAddButton));
    await tester.pumpAndSettle();
    await tester.enterText(field(text.anytimeMealsNameLabel).first, 'Tea');
    await save(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(text.errMealNameTaken('Tea')), findsOneWidget);
  });
}
