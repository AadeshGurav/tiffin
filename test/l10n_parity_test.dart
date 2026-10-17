import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A translation that drops a key silently falls back to English, and one that
/// drops a `{placeholder}` renders a broken sentence — so both are pinned here.
void main() {
  Map<String, dynamic> load(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> keys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  // Placeholders plus ICU selector variables: `{count, plural, …}` → count.
  Set<String> variables(String message) => RegExp(r'\{(\w+)(?=[,}])')
      .allMatches(message)
      .map((m) => m.group(1)!)
      .toSet();

  final en = load('en');

  for (final locale in ['hi', 'mr']) {
    group('app_$locale.arb', () {
      final translated = load(locale);

      test('has exactly the keys of app_en.arb', () {
        expect(keys(translated).difference(keys(en)), isEmpty,
            reason: 'keys not in the English template');
        expect(keys(en).difference(keys(translated)), isEmpty,
            reason: 'keys missing a translation');
      });

      test('keeps every placeholder of the English message', () {
        final broken = [
          for (final key in keys(en))
            if (translated[key] is String &&
                !variables(translated[key] as String)
                    .containsAll(variables(en[key] as String)))
              key,
        ];
        expect(broken, isEmpty);
      });
    });
  }
}
