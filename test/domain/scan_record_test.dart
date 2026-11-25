import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/menu.dart';
import 'package:tiffin/domain/settings.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/l10n/labels.dart';

/// A meal is any string id (ADR 0009 §1): history naming a meal this build
/// doesn't know must still parse and show.
void main() {
  test('a scan and a menu entry with an unknown meal id parse', () {
    final scan = ScanRecord.fromJson({
      'id': 's1',
      'memberId': 'm1',
      'memberName': 'Asha',
      'mealType': 'mtea00001',
      'scannedAt': '2026-11-25T10:00:00Z',
      'result': 'accepted',
      'viaGrace': false,
      'reversed': false,
    });
    expect(scan.meal, 'mtea00001');
    expect(scan.toJson()['mealType'], 'mtea00001');

    final entry = MenuEntry.fromJson({
      'id': 'e1',
      'date': '2026-11-25',
      'mealType': 'mtea00001',
      'category': 'Normal',
      'items': ['Masala chai'],
      'createdBy': 'admin',
    });
    expect(entry.meal, 'mtea00001');
  });

  test('mealName: built-in label, then catalogue name, then the raw id', () {
    final t = lookupAppText(const Locale('en'));
    const catalogue = [AnytimeMeal(id: 'mtea00001', name: 'Tea', price: 10)];
    expect(t.mealName('lunch', catalogue), t.mealLunch);
    expect(t.mealName('mtea00001', catalogue), 'Tea');
    expect(t.mealName('mtea00001'), 'mtea00001');
  });
}
