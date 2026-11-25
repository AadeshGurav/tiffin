import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/l10n/messages.dart';

import '../../support/fake_backend.dart';

/// Refunds (PRD §6.7): units come off the balance and a record is kept, in one
/// batch, and a refund can never take a balance below zero.
void main() {
  late Backend b;

  setUp(() async {
    b = (await fakeBackend()).backend;
    await signInAdmin(b);
  });

  Future<Member> member({int lunch = 0, int breakfast = 0}) =>
      b.createMember(MemberDraft(
          type: 'staff',
          name: 'Asha',
          balances: UnitCounts(lunch: lunch, breakfast: breakfast)));

  test('a refund deducts units and is listed', () async {
    final m = await member(lunch: 5, breakfast: 2);
    final r = await b.createRefund(RefundDraft(
        memberId: m.id, lunchUnits: 3, reason: 'leaving', processedBy: ''));

    final after = await b.getMember(m.id);
    expect(after.balances.lunch, 2);
    expect(after.balances.breakfast, 2);
    expect(r.processedBy, 'admin');

    final listed = await b.listRefunds();
    expect(listed.map((x) => x.id), [r.id]);
    expect((await b.listRefunds(memberId: m.id)).map((x) => x.id), [r.id]);
  });

  test('a refund over the balance is refused and changes nothing', () async {
    final m = await member(lunch: 1);
    await expectLater(
        b.createRefund(
            RefundDraft(memberId: m.id, lunchUnits: 2, processedBy: '')),
        throwsA(isA<ValidationException>()));
    expect((await b.getMember(m.id)).balances.lunch, 1);
    expect(await b.listRefunds(), isEmpty);
  });

  test('negative units are refused, not turned into a credit', () async {
    final m = await member(lunch: 2);
    await expectLater(
        b.createRefund(
            RefundDraft(memberId: m.id, lunchUnits: -3, processedBy: '')),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.negativeUnits)));
    expect((await b.getMember(m.id)).balances.lunch, 2);
    expect(await b.listRefunds(), isEmpty);
  });

  test('a meal on grace (below zero) does not block refunding another',
      () async {
    final m = await member(lunch: -1, breakfast: 3);
    await b.createRefund(
        RefundDraft(memberId: m.id, breakfastUnits: 3, processedBy: ''));
    final after = await b.getMember(m.id);
    expect(after.balances.breakfast, 0);
    expect(after.balances.lunch, -1, reason: 'grace owed is left alone');
  });

  group('anytime units (ADR 0009)', () {
    const tea = 'mtea00001';

    setUp(() => b.updateSettings(const SettingsPatch(anytimeMeals: [
          AnytimeMeal(id: tea, name: 'Tea', price: 10),
          AnytimeMeal(id: 'mold00001', name: 'Old', price: 5, active: false),
        ])));

    Future<Member> holder() => b.createMember(const MemberDraft(
        type: 'staff',
        name: 'Asha',
        balances: UnitCounts(lunch: 1, anytime: {tea: 4, 'mold00001': 2})));

    test('anytime units come off, priced, and the record keeps them', () async {
      final m = await holder();
      final r = await b.createRefund(RefundDraft(
          memberId: m.id, anytimeUnits: const {tea: 3}, processedBy: ''));
      expect(r.refundAmount, 30);
      expect((await b.getMember(m.id)).balances[tea], 1);
      expect((await b.listRefunds()).single.units[tea], 3);
    });

    test('a retired meal is still refundable', () async {
      final m = await holder();
      final r = await b.createRefund(RefundDraft(
          memberId: m.id,
          anytimeUnits: const {'mold00001': 2},
          processedBy: ''));
      expect(r.refundAmount, 10);
      expect((await b.getMember(m.id)).balances['mold00001'], 0);
    });

    test('over-refunding Tea is refused, named, and changes nothing', () async {
      final m = await holder();
      Object? error;
      try {
        await b.createRefund(RefundDraft(
            memberId: m.id, anytimeUnits: const {tea: 9}, processedBy: ''));
      } catch (e) {
        error = e;
      }
      expect(error, isA<ValidationException>());
      expect(
          lookupAppText(const Locale('en')).errorText(error!), contains('Tea'));
      expect((await b.getMember(m.id)).balances[tea], 4);
      expect(await b.listRefunds(), isEmpty);
    });

    test('an unknown meal is refused', () async {
      final m = await holder();
      await expectLater(
          b.createRefund(RefundDraft(
              memberId: m.id,
              anytimeUnits: const {'mnope0000': 1},
              processedBy: '')),
          throwsA(isA<ValidationException>()
              .having((e) => e.code, 'code', ErrorCode.unknownMeal)));
    });

    test('an old refund document (no anytimeUnits) still parses', () {
      final r = Refund.fromJson({
        'id': 'r1',
        'memberId': 'm1',
        'lunchUnits': 1,
        'breakfastUnits': 0,
        'brunchUnits': 0,
        'refundAmount': 40,
        'processedBy': 'admin',
        'createdAt': '2026-10-01T10:00:00Z',
      });
      expect(r.anytimeUnits, isEmpty);
      expect(r.units.byMeal, {'lunch': 1});
    });
  });
}
