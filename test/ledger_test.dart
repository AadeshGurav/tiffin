import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/core/meal_type.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/inventory.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/domain/menu.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/services/scan_service.dart';

import 'support/fake_backend.dart';

/// The money-adjacent paths: scans, top-ups, refunds and their reversals, on
/// Firestore. Every scan passes an explicit meal so these never depend on the
/// time of day (the old host test failed every Saturday for that reason).
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late Backend b;

  Future<Member> student({UnitCounts balances = const UnitCounts()}) =>
      b.createMember(MemberDraft(
          type: 'student', name: 'Asha', className: '7B', balances: balances));

  setUp(() async {
    b = (await fakeBackend()).backend;
    await signInAdmin(b);
    await b.updateSettings(const SettingsPatch(
        unitPrices: UnitPrices(lunch: 40, breakfast: 25, brunch: 50)));
  });

  group('scanning', () {
    test('an accepted scan takes one unit and locks the meal for the day',
        () async {
      final m = await student(balances: const UnitCounts(lunch: 2));

      final first = await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      expect(first.outcome, ScanOutcome.accepted);
      expect(first.remainingBalance, 1);
      expect((await b.getMember(m.id)).balances.lunch, 1);

      final again = await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      expect(again.outcome, ScanOutcome.rejectedAlreadyScanned);
      expect((await b.getMember(m.id)).balances.lunch, 1,
          reason: 'a refused scan must not take a unit');
    });

    test('the lock is per meal: breakfast after lunch is fine', () async {
      final m =
          await student(balances: const UnitCounts(lunch: 1, breakfast: 1));
      await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      final breakfast =
          await b.scan(m.qrCodeId, mealTypeOverride: MealType.breakfast);
      expect(breakfast.outcome, ScanOutcome.accepted);
    });

    test('no units, no grace: rejected and the balance is untouched', () async {
      final m = await student();
      final r = await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      expect(r.outcome, ScanOutcome.rejectedZeroBalance);
      expect((await b.getMember(m.id)).balances.lunch, 0);
    });

    test('grace lets a zero balance go negative, then hard-stops', () async {
      await b.updateSettings(const SettingsPatch(
          graceAllowanceEnabled: true, graceAllowanceUnits: 1));
      final m = await student();
      final lunch = await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      expect(lunch.outcome, ScanOutcome.accepted);
      expect(lunch.viaGrace, isTrue);
      expect(lunch.remainingBalance, -1);

      final m2 = await b.getMember(m.id);
      expect(m2.balances.lunch, -1);
      final breakfast =
          await b.scan(m.qrCodeId, mealTypeOverride: MealType.breakfast);
      expect(breakfast.outcome, ScanOutcome.accepted,
          reason: 'grace is per meal type');
    });

    test('unknown and inactive codes are refused with their reason', () async {
      expect((await b.scan('nope')).outcome, ScanOutcome.rejectedUnknownCode);
      final m = await student(balances: const UnitCounts(lunch: 3));
      await b.updateMember(m.id, const MemberPatch(status: 'inactive'));
      expect(
          (await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch)).outcome,
          ScanOutcome.rejectedInactive);
    });

    test('a scan consumes the plate recipe from stock; reversal puts it back',
        () async {
      await b.createMenuCategory('Normal', null);
      final rice = await b.createIngredient('Rice', 'kg', stockQty: 10);
      await b.createRecipe(RecipeDraft(dishName: 'Dal rice', ingredients: [
        RecipeIngredient(ingredientId: rice.id, quantity: 0.2),
      ]));
      await b.addMenuEntry(MenuEntryDraft(
        date: DateTime.now(),
        mealType: MealType.lunch,
        category: 'Normal',
        headcount: 1,
        items: const ['dal rice'],
        createdBy: '',
      ));
      final m = await student(balances: const UnitCounts(lunch: 1));

      final r = await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      expect(r.outcome, ScanOutcome.accepted);
      expect(r.plannedCount, 1);
      expect(r.servedCount, 1);
      expect(r.headcountReached, isTrue);
      expect((await b.listIngredients()).single.stockQty, closeTo(9.8, 1e-9));

      final undo = await b.reverseScan(r.scanId!);
      expect(undo.code, ReversalCode.scanReversed);
      expect(undo.restored, 1);
      expect((await b.listIngredients()).single.stockQty, closeTo(10, 1e-9));
      expect((await b.getMember(m.id)).balances.lunch, 1);

      // Reversal keeps the record (audit) and frees the meal again.
      final scans = await b.recentScans();
      expect(scans.where((s) => s.reversed), hasLength(1));
      expect(
          (await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch)).outcome,
          ScanOutcome.accepted);
    });

    test('a reversed scan cannot be reversed twice', () async {
      final m = await student(balances: const UnitCounts(lunch: 1));
      final r = await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      await b.reverseScan(r.scanId!);
      expect((await b.reverseScan(r.scanId!)).code, ReversalCode.scanNotFound);
    });

    test('the lock id is member, day and meal', () {
      expect(ScanService.lockId('m1', '2026-10-17', MealType.brunch),
          'm1_2026-10-17_brunch');
    });
  });

  group('top-ups and refunds', () {
    test('a top-up credits units and prices them from settings', () async {
      final m = await student();
      final t = await b.createTopup(TopupDraft(
          memberId: m.id,
          lunchUnits: 3,
          paymentMethod: PaymentMethod.cash,
          createdBy: ''));
      expect(t.amount, 120);
      expect(t.paymentStatus, 'confirmed');
      expect(t.createdBy, 'admin', reason: 'stamped by the backend');
      expect(t.balancesAfter?.lunch, 3);
      expect((await b.getMember(m.id)).balances.lunch, 3);
    });

    test('a top-up cannot be reversed once its units have been spent',
        () async {
      final m = await student();
      final t = await b.createTopup(TopupDraft(
          memberId: m.id,
          lunchUnits: 1,
          paymentMethod: PaymentMethod.upi,
          createdBy: ''));
      expect(t.paymentStatus, 'pending');
      await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      expect((await b.reverseTopup(t.id)).code, ReversalCode.topupUnitsUsed);
    });

    test('an unspent top-up reverses and the balance comes back down',
        () async {
      final m = await student();
      final t = await b.createTopup(TopupDraft(
          memberId: m.id,
          breakfastUnits: 2,
          paymentMethod: PaymentMethod.cash,
          createdBy: ''));
      expect((await b.reverseTopup(t.id)).code, ReversalCode.topupReversed);
      expect((await b.getMember(m.id)).balances.breakfast, 0);
      expect(
          (await b.reverseTopup(t.id)).code, ReversalCode.topupAlreadyReversed);
    });

    test('a refund larger than the balance is refused with the numbers',
        () async {
      final m = await student(balances: const UnitCounts(lunch: 1));
      await expectLater(
        b.createRefund(
            RefundDraft(memberId: m.id, lunchUnits: 2, processedBy: '')),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.refundExceedsBalance)
            .having((e) => e.args, 'args',
                {'requested': 2, 'meal': 'lunch', 'available': 1})),
      );
    });

    test('revenue counts confirmed top-ups only, never reversed ones',
        () async {
      final m = await student();
      final kept = await b.createTopup(TopupDraft(
          memberId: m.id,
          lunchUnits: 1,
          paymentMethod: PaymentMethod.cash,
          createdBy: ''));
      final undone = await b.createTopup(TopupDraft(
          memberId: m.id,
          lunchUnits: 1,
          paymentMethod: PaymentMethod.cash,
          createdBy: ''));
      await b.reverseTopup(undone.id);
      expect(kept.amount, 40);
      expect((await b.profitSummary()).revenue, 40);
    });
  });

  group('members', () {
    test('a member with history cannot be deleted', () async {
      final m = await student(balances: const UnitCounts(lunch: 1));
      await b.scan(m.qrCodeId, mealTypeOverride: MealType.lunch);
      await expectLater(
          b.deleteMember(m.id), throwsA(isA<ConflictException>()));
    });

    test('converting a student to staff clears class and roll', () async {
      final m = await student();
      final staff = await b.updateMember(
          m.id, const MemberPatch(type: 'staff', staffId: 'S9'));
      expect(staff.className, isNull);
      expect(staff.staffId, 'S9');
    });
  });
}
