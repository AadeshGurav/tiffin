import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/domain/settings.dart';

import '../../support/fake_backend.dart';

/// Top-ups (PRD §6.3) only ever credit units.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late Backend b;

  setUp(() async {
    b = (await fakeBackend()).backend;
    await signInAdmin(b);
  });

  test('negative units are refused, not turned into a debit', () async {
    final m = await b.createMember(const MemberDraft(
        type: 'staff', name: 'Asha', balances: UnitCounts(lunch: 2)));
    await expectLater(
        b.createTopup(TopupDraft(
            memberId: m.id,
            lunchUnits: 3,
            breakfastUnits: -1,
            paymentMethod: PaymentMethod.cash,
            createdBy: '')),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.negativeUnits)));
    final after = await b.getMember(m.id);
    expect(after.balances.lunch, 2);
    expect(after.balances.breakfast, 0);
    expect(await b.listTopups(), isEmpty);
  });

  group('anytime units (ADR 0009 §4)', () {
    const tea = 'mtea00001';

    setUp(() => b.updateSettings(const SettingsPatch(
          unitPrices: UnitPrices(lunch: 40, breakfast: 25, brunch: 50),
          anytimeMeals: [
            AnytimeMeal(id: tea, name: 'Tea', price: 10),
            AnytimeMeal(id: 'mold00001', name: 'Old', price: 5, active: false),
          ],
        )));

    Future<Member> asha() => b.createMember(const MemberDraft(
        type: 'staff', name: 'Asha', balances: UnitCounts(lunch: 1)));

    test(
        'the amount includes the anytime price; the record keeps the '
        'flat built-in fields', () async {
      final m = await asha();
      final t = await b.createTopup(TopupDraft(
          memberId: m.id,
          lunchUnits: 2,
          anytimeUnits: const {tea: 5},
          paymentMethod: PaymentMethod.cash,
          createdBy: ''));
      expect(t.amount, 2 * 40 + 5 * 10);
      expect(t.balancesAfter!.byMeal, {'lunch': 3, tea: 5});
      expect((await b.getMember(m.id)).balances[tea], 5);

      final stored = t.toJson();
      expect(stored['lunchUnits'], 2);
      expect(stored['breakfastUnits'], 0);
      expect(stored['brunchUnits'], 0);
      expect(stored['anytimeUnits'], {tea: 5});
      expect((await b.listTopups()).single.units[tea], 5);
    });

    test('an unknown or retired meal cannot be bought', () async {
      final m = await asha();
      for (final id in ['mnope0000', 'mold00001']) {
        await expectLater(
            b.createTopup(TopupDraft(
                memberId: m.id,
                anytimeUnits: {id: 1},
                paymentMethod: PaymentMethod.cash,
                createdBy: '')),
            throwsA(isA<ValidationException>()
                .having((e) => e.code, 'code', ErrorCode.unknownMeal)));
      }
      await expectLater(
          b.createTopup(TopupDraft(
              memberId: m.id,
              anytimeUnits: const {tea: -2},
              paymentMethod: PaymentMethod.cash,
              createdBy: '')),
          throwsA(isA<ValidationException>()
              .having((e) => e.code, 'code', ErrorCode.negativeUnits)));
    });

    test('reversal is refused once an anytime unit has been spent', () async {
      final m = await asha();
      final t = await b.createTopup(TopupDraft(
          memberId: m.id,
          anytimeUnits: const {tea: 2},
          paymentMethod: PaymentMethod.cash,
          createdBy: ''));
      await b.scan(m.qrCodeId, anytimeMealId: tea);
      expect((await b.reverseTopup(t.id)).code, ReversalCode.topupUnitsUsed);

      final t2 = await b.createTopup(TopupDraft(
          memberId: m.id,
          anytimeUnits: const {tea: 3},
          paymentMethod: PaymentMethod.cash,
          createdBy: ''));
      expect((await b.reverseTopup(t2.id)).code, ReversalCode.topupReversed);
      expect((await b.getMember(m.id)).balances[tea], 1);
    });

    test('a pre-0009 top-up document (no anytimeUnits) still parses', () {
      final t = Topup.fromJson({
        'id': 't1',
        'memberId': 'm1',
        'lunchUnits': 2,
        'breakfastUnits': 0,
        'brunchUnits': 0,
        'amount': 80,
        'paymentMethod': 'cash',
        'paymentStatus': 'confirmed',
        'createdBy': 'admin',
        'createdAt': '2026-10-01T10:00:00Z',
      });
      expect(t.anytimeUnits, isEmpty);
      expect(t.units.byMeal, {'lunch': 2});
      expect(t.toJson().containsKey('anytimeUnits'), isFalse);
    });
  });
}
