import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/domain/settings.dart';

import '../../support/fake_backend.dart';

/// The money summary (PRD §6.6): a refund is money paid back, so it shows on
/// its own line and comes off profit.
void main() {
  late Backend b;

  setUp(() async {
    b = (await fakeBackend()).backend;
    await signInAdmin(b);
  });

  test('refunds are counted in the summary and come off profit', () async {
    final settings = await b.settings.read();
    await b.settings.update(SettingsPatch(
        unitPrices: UnitPrices(
            lunch: 50,
            breakfast: settings.unitPrices.breakfast,
            brunch: settings.unitPrices.brunch)));
    final m =
        await b.createMember(const MemberDraft(type: 'staff', name: 'Asha'));
    await b.createTopup(TopupDraft(
        memberId: m.id,
        lunchUnits: 4,
        paymentMethod: PaymentMethod.cash,
        createdBy: ''));
    await b.createRefund(
        RefundDraft(memberId: m.id, lunchUnits: 1, processedBy: ''));

    final s = await b.profitSummary();
    expect(s.revenue, 200);
    expect(s.refunds, 50);
    expect(s.profit, 150);
  });
}
