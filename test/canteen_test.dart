import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffin/app/bootstrap.dart';
import 'package:tiffin/app/canteen_book.dart';
import 'package:tiffin/data/canteens.dart';

void main() {
  group('canteen codes', () {
    test('typing is forgiving: case, spaces and dashes are ignored', () {
      expect(CanteenService.normalise('abcd-2345'), 'ABCD2345');
      expect(CanteenService.normalise(' abcd 2345 '), 'ABCD2345');
    });
  });

  group('CanteenBook', () {
    Future<ProviderContainer> phone(
        [Map<String, Object> saved = const {}]) async {
      SharedPreferences.setMockInitialValues(saved);
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    }

    test('starts with no canteen, so the Welcome screen shows', () async {
      final c = await phone();
      expect(c.read(activeCanteenProvider), isNull);
    });

    test('activating remembers the canteen and survives a restart', () async {
      final c = await phone();
      await c.read(canteenBookProvider.notifier).activate('AAAA2222', 'Gate');
      expect(c.read(activeCanteenProvider), 'AAAA2222');

      final prefs = await SharedPreferences.getInstance();
      final restarted = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      expect(restarted.read(canteenBookProvider).active?.name, 'Gate');
    });

    test('switching keeps both canteens; leaving forgets only one', () async {
      final c = await phone();
      final book = c.read(canteenBookProvider.notifier);
      await book.activate('AAAA2222', 'Gate');
      await book.activate('BBBB3333', 'Hostel');
      await book.deactivate();
      expect(c.read(activeCanteenProvider), isNull);
      expect(c.read(canteenBookProvider).canteens.length, 2);

      await book.leave('AAAA2222');
      expect([for (final x in c.read(canteenBookProvider).canteens) x.code],
          ['BBBB3333']);
    });

    test('a corrupt saved entry means Welcome, not a crash', () async {
      final c = await phone({'canteen_book': '{not json'});
      expect(c.read(activeCanteenProvider), isNull);
    });
  });
}
