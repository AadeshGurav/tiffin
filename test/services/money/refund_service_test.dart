import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';

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
            .having((e) => e.code, 'code', ErrorCode.refundNegativeUnits)));
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
}
