import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/admin/money/bill_view.dart';

/// The bill lists one line per meal that moved (ADR 0009), anytime included.
void main() {
  testWidgets('a Tea top-up bills Tea, not three zeros', (tester) async {
    const tea = AnytimeMeal(id: 'mtea00001', name: 'Tea', price: 10);
    final topup = Topup(
      id: 'abcdef123456',
      memberId: 'm1',
      lunchUnits: 0,
      breakfastUnits: 0,
      brunchUnits: 0,
      anytimeUnits: const {'mtea00001': 5},
      amount: 50,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: 'confirmed',
      createdBy: 'admin',
      createdAt: DateTime.utc(2026, 11, 25),
      balancesAfter: const UnitCounts(lunch: 2, anytime: {'mtea00001': 7}),
    );
    final member = Member(
      id: 'm1',
      type: 'staff',
      name: 'Asha',
      qrCodeId: 'q',
      balances: const UnitCounts(),
      status: 'active',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppText.localizationsDelegates,
      supportedLocales: AppText.supportedLocales,
      home: BillView(
          topup: topup,
          member: member,
          appName: 'Canteen',
          catalogue: const [tea]),
    ));
    final text = AppText.of(tester.element(find.byType(BillView)));

    expect(find.text(text.mealUnits('Tea', 5)), findsOneWidget);
    expect(find.text(text.mealUnits('Tea', 7)), findsOneWidget);
    expect(find.text(text.mealUnits(text.mealLunch, 2)), findsOneWidget);
    expect(find.text(text.mealUnits(text.mealLunch, 0)), findsNothing);
  });
}
