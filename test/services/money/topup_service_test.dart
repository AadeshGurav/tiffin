import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';

import '../../support/fake_backend.dart';

/// Top-ups (PRD §6.3) only ever credit units.
void main() {
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
}
