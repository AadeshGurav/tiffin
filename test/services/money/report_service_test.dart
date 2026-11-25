import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/member.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/services/money/report_service.dart';

import '../../support/fake_backend.dart';

/// Report columns for anytime meals (ADR 0009 §8).
void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('en');
  });

  test(
      'Balances and Top-ups get one column per catalogue meal, grouped, '
      'retired included, and the rows line up', () async {
    final b = (await fakeBackend()).backend;
    await signInAdmin(b);
    await b.updateSettings(const SettingsPatch(anytimeMeals: [
      AnytimeMeal(id: 'mjuice001', name: 'Juice', price: 25, group: 'Drinks'),
      AnytimeMeal(id: 'mtea00001', name: 'Tea', price: 10, active: false),
    ]));
    final m = await b.createMember(const MemberDraft(
        type: 'staff',
        name: 'Asha',
        balances: UnitCounts(lunch: 1, anytime: {'mtea00001': 4})));
    await b.createTopup(TopupDraft(
        memberId: m.id,
        anytimeUnits: const {'mjuice001': 3},
        paymentMethod: PaymentMethod.cash,
        createdBy: ''));

    final t = lookupAppText(const Locale('en'));
    final zip = ZipDecoder().decodeBytes(await b.buildReport(t,
        sections: {ReportSection.balances, ReportSection.topups}));
    List<List<String>> rows(String path) {
      final xml = utf8.decode(
          zip.files.firstWhere((f) => f.name == path).content as List<int>);
      return [
        for (final row in RegExp(r'<row[^>]*>(.*?)</row>').allMatches(xml))
          [
            for (final c in RegExp(r'<(?:t[^>]*|v)>([^<]*)</(?:t|v)>')
                .allMatches(row.group(1)!))
              c.group(1)!,
          ],
      ];
    }

    final balances = rows('xl/worksheets/sheet1.xml');
    final head = balances.first;
    final tea = head.indexOf('Tea'), juice = head.indexOf('Drinks · Juice');
    expect(tea, greaterThan(head.indexOf(t.mealBrunch)));
    expect(juice, greaterThan(tea), reason: 'ungrouped first, then groups');
    final asha = balances.firstWhere((r) => r.contains('Asha'));
    expect(asha, hasLength(head.length));
    expect((asha[tea], asha[juice]), ('4', '3'));
    expect(asha[head.indexOf(t.reportColTotal)], '8');

    final topups = rows('xl/worksheets/sheet2.xml');
    final th = topups.first;
    expect(topups[1], hasLength(th.length));
    expect(topups[1][th.indexOf('Drinks · Juice')], '3');
    expect(double.parse(topups[1][th.indexOf(t.reportColAmount)]), 75);
  });
}
