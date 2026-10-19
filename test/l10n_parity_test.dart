import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/core/meal_type.dart';
import 'package:tiffin/domain/ledger.dart';
import 'package:tiffin/domain/ops.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/l10n/labels.dart';
import 'package:tiffin/l10n/messages.dart';

/// A translation that drops a key silently falls back to English, one that
/// drops a `{placeholder}` renders a broken sentence, and English typed straight
/// into a widget never gets translated at all — all three are pinned here.
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

      test('translates every message, bar the language-neutral ones', () {
        // Brand, proper nouns and bare ids read the same in every language.
        const neutral = {
          'appTitle',
          'apprScreenSavedLoginsRow',
          'membersScreenQrButton',
          'topupScreenPaymentUpi',
          'settingsConfigScreenSectionUpi',
          'paymentUpi',
          'reportColId',
        };
        final untranslated = [
          for (final key in keys(en))
            if (!neutral.contains(key) && translated[key] == en[key]) key,
        ];
        expect(untranslated, isEmpty);
      });

      test('uses Latin digits, like every number the app interpolates', () {
        final mixed = [
          for (final key in keys(translated))
            if (RegExp('[०-९]').hasMatch(translated[key] as String)) key,
        ];
        expect(mixed, isEmpty);
      });
    });
  }

  test('every English message is used somewhere in lib/', () {
    final source = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.contains('app_localizations'))
          f.readAsStringSync(),
    ].join('\n');
    final unused = [
      for (final key in keys(en))
        if (!RegExp('\\b$key\\b').hasMatch(source)) key,
    ];
    expect(unused, isEmpty, reason: 'dead keys cost every translator time');
  });

  test('no screen hard-codes visible English text', () {
    // Text('Something') in a widget never reaches a translator. Non-letter
    // literals (separators, symbols) are fine.
    final hardCoded = [
      for (final f in Directory('lib/ui').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (RegExp(r"Text\(\s*'[A-Za-z]").hasMatch(line))
              '${f.path}:${i + 1}',
    ];
    expect(hardCoded, isEmpty);
  });

  group('codes from the services are worded in every language', () {
    for (final code in ['en', 'hi', 'mr']) {
      final t = lookupAppText(Locale(code));

      test('$code: every error code has its own sentence', () {
        final texts = {
          for (final c in ErrorCode.values)
            t.errorText(ValidationException(c, const {'name': 'X'})),
        };
        expect(texts, hasLength(ErrorCode.values.length),
            reason: 'two codes sharing a sentence means one is mis-mapped');
        expect(texts, isNot(contains(t.errUnexpected)));
      });

      test('$code: a scan verdict names the person and the meal', () {
        const r = ScanResult(
          outcome: ScanOutcome.accepted,
          memberName: 'Asha',
          mealType: MealType.lunch,
          remainingBalance: 2,
        );
        expect(t.scanText(r), allOf(contains('Asha'), contains(t.mealLunch)));
      });

      test('$code: notifications are worded from their params', () {
        final n = AppNotification(
          id: 'x',
          type: 'low_stock',
          params: const {
            'name': 'Rice',
            'qty': 2,
            'threshold': 5,
            'unit': 'kg'
          },
          createdAt: DateTime(2026),
        );
        final words = t.notificationText(n);
        expect(words.title, contains('Rice'));
        expect(words.body, contains(t.unitKg));
      });

      test('$code: money uses the rupee sign and lakh grouping', () {
        expect(t.money(125000), '₹1,25,000.00');
      });
    }
  });
}
