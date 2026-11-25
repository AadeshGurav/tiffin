import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/core/meal_type.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/inventory.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/domain/menu.dart';
import 'package:tiffin/domain/settings.dart';

import '../../support/fake_backend.dart';

/// Anytime meals (ADR 0009 §5): no window, no daily lock, one unit per scan.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  const tea = 'mtea00001';
  late Backend b;
  late FakeFirebaseFirestore db;

  Future<Member> asha({int tea_ = 0, int lunch = 0}) =>
      b.createMember(MemberDraft(
          type: 'staff',
          name: 'Asha',
          balances: UnitCounts(lunch: lunch, anytime: {tea: tea_})));

  setUp(() async {
    final f = await fakeBackend();
    b = f.backend;
    db = f.db;
    await signInAdmin(b);
    await b.updateSettings(const SettingsPatch(anytimeMeals: [
      AnytimeMeal(id: tea, name: 'Tea', price: 10),
      AnytimeMeal(id: 'mjuice001', name: 'Juice', price: 25, active: false),
    ]));
  });

  test('three Teas the same day are all served, one unit each', () async {
    final m = await asha(tea_: 5);
    for (var i = 0; i < 3; i++) {
      final r = await b.scan(m.qrCodeId, anytimeMealId: tea);
      expect(r.outcome, ScanOutcome.accepted);
      expect(r.meal, tea);
    }
    expect((await b.getMember(m.id)).balances[tea], 2);
  });

  test('outside every meal window, Tea is still served', () async {
    // Windows that are certainly not open now (canteen time).
    final now = tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'));
    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final later = now.add(const Duration(hours: 3));
    final shut = later.hour == 23 && later.minute == 59
        ? later.subtract(const Duration(minutes: 1))
        : later;
    final w = MealWindowConfig(
        start: hhmm(shut), end: hhmm(shut.add(const Duration(minutes: 1))));
    await b.updateSettings(
        SettingsPatch(mealWindows: {'breakfast': w, 'lunch': w, 'brunch': w}));
    final m = await asha(tea_: 1, lunch: 1);

    expect(
        (await b.scan(m.qrCodeId)).outcome, ScanOutcome.rejectedNoMealWindow);
    expect((await b.scan(m.qrCodeId, anytimeMealId: tea)).outcome,
        ScanOutcome.accepted);
  });

  test('a spent balance is refused; grace allows exactly its allowance',
      () async {
    final m = await asha();
    expect((await b.scan(m.qrCodeId, anytimeMealId: tea)).outcome,
        ScanOutcome.rejectedZeroBalance);

    await b.updateSettings(const SettingsPatch(
        graceAllowanceEnabled: true, graceAllowanceUnits: 2));
    final first = await b.scan(m.qrCodeId, anytimeMealId: tea);
    expect((first.outcome, first.viaGrace, first.remainingBalance),
        (ScanOutcome.accepted, true, -1));
    expect((await b.scan(m.qrCodeId, anytimeMealId: tea)).remainingBalance, -2);
    expect((await b.scan(m.qrCodeId, anytimeMealId: tea)).outcome,
        ScanOutcome.rejectedZeroBalance);
    expect((await b.getMember(m.id)).balances[tea], -2);
  });

  test('an unknown or retired meal is refused before anything moves', () async {
    final m = await asha(tea_: 1);
    for (final id in ['mnope0000', 'mjuice001']) {
      await expectLater(
          b.scan(m.qrCodeId, anytimeMealId: id),
          throwsA(isA<ValidationException>()
              .having((e) => e.code, 'code', ErrorCode.unknownMeal)));
    }
    expect((await b.getMember(m.id)).balances[tea], 1);
  });

  test('a lunch scan after a Tea still holds the once-a-day lunch lock',
      () async {
    final m = await asha(tea_: 2, lunch: 2);
    await b.scan(m.qrCodeId, anytimeMealId: tea);
    expect((await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch)).outcome,
        ScanOutcome.accepted);
    expect((await b.scan(m.qrCodeId, anytimeMealId: tea)).outcome,
        ScanOutcome.accepted);
    expect((await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch)).outcome,
        ScanOutcome.rejectedAlreadyScanned);
  });

  test('every scan names its meal in lastScanMeal (the rules key on it)',
      () async {
    final m = await asha(tea_: 1, lunch: 1);
    Future<Object?> last() async =>
        (await db.doc('canteens/test-canteen/members/${m.id}').get())
            .data()!['lastScanMeal'];
    await b.scan(m.qrCodeId, anytimeMealId: tea);
    expect(await last(), tea);
    await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
    expect(await last(), 'lunch');
  });

  test(
      'the menu entry for Tea drives stock use and planned/served; '
      'reversal puts the unit and stock back', () async {
    await b.createMenuCategory('Normal', null);
    final milk = await b.createIngredient('Milk', 'l', stockQty: 10);
    await b.createRecipe(RecipeDraft(dishName: 'Masala chai', ingredients: [
      RecipeIngredient(ingredientId: milk.id, quantity: 0.1),
    ]));
    await b.addMenuEntry(MenuEntryDraft(
      date: DateTime.now(),
      meal: tea,
      category: 'Normal',
      headcount: 2,
      items: const ['masala chai'],
      createdBy: '',
    ));
    final m = await asha(tea_: 3);

    final r = await b.scan(m.qrCodeId, anytimeMealId: tea);
    expect((r.plannedCount, r.servedCount), (2, 1));
    expect((await b.listIngredients()).single.stockQty, closeTo(9.9, 1e-9));
    expect((await b.scan(m.qrCodeId, anytimeMealId: tea)).headcountReached,
        isTrue);

    final undo = await b.reverseScan(r.scanId!);
    expect((undo.code, undo.meal, undo.restored),
        (ReversalCode.scanReversed, tea, 2));
    expect((await b.getMember(m.id)).balances[tea], 2);
    expect((await b.listIngredients()).single.stockQty, closeTo(9.9, 1e-9));
  });
}
