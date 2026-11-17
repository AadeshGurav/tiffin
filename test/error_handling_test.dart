import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:tiffin/core/error_report.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/core/logging.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/l10n/messages.dart';

/// Pins the error contract (docs/ERRORS.md): a person sees a plain sentence,
/// IT gets a code that finds the full detail in the log, and nothing internal
/// reaches the screen.
void main() {
  final text = lookupAppText(const Locale('en'));
  late List<LogRecord> records;
  late StreamSubscription<LogRecord> sub;

  setUp(() {
    records = [];
    Logger.root.level = Level.ALL;
    sub = Logger.root.onRecord.listen(records.add);
  });
  tearDown(() => sub.cancel());

  group('reference code', () {
    test('is XXXX-XXXX from an alphabet without look-alikes', () {
      final code = newReferenceCode();
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$')));
    });

    test('is not repeated across many failures', () {
      final codes = {for (var i = 0; i < 500; i++) newReferenceCode()};
      expect(codes, hasLength(500));
    });
  });

  group('describeError', () {
    test('an anticipated failure is a plain sentence with no code', () {
      final notice = text
          .describeError(const ValidationException(ErrorCode.usernameRequired));
      expect(notice.ref, isNull);
      expect(notice.message, text.errUsernameRequired);
    });

    test('a refused Firestore write is explained, not reported', () {
      final notice = text.describeError(FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied'));
      expect(notice.ref, isNull);
      expect(notice.message, text.errPermissionDenied);
    });

    test('an unknown failure gets a code, and its detail only in the log', () {
      final notice = text.describeError(
          StateError('table tiffin_members at /var/db/x is corrupt'),
          StackTrace.current);

      expect(notice.ref, isNotNull);
      expect(notice.message, text.errUnexpected);
      expect(notice.message, isNot(contains('tiffin_members')));

      final entry = AppLogger.formatRecord(
          records.firstWhere((r) => r.message.contains(notice.ref!)));
      expect(entry, contains('tiffin_members'),
          reason: 'detail goes to the log');
      expect(entry, contains('error_handling_test'),
          reason: 'with the stack trace it was given');
    });

    test('an unknown Firebase code is reported too', () {
      final notice = text.describeError(
          FirebaseException(plugin: 'cloud_firestore', code: 'data-loss'));
      expect(notice.ref, isNotNull);
    });

    test('an internal failure is reported with a code', () {
      final notice = text.describeError(const InternalException());
      expect(notice.ref, isNotNull);
      expect(notice.message, text.errInternal);
    });

    test('two failures never share a code', () {
      final a = text.describeError(StateError('a')).ref;
      final b = text.describeError(StateError('a')).ref;
      expect(a, isNot(b));
    });
  });

  group('log redaction', () {
    test('masks key shapes and credential assignments', () {
      const secrets = [
        'password=hunter2',
        'passphrase: "correct horse"',
        'Authorization: Bearer abc.def-123',
        'key AIzaSyA1234567890abcdefghijklmnopqrstuvw',
        'jwt eyJhbGciOi.eyJzdWIiOi.SflKxwRJSM',
      ];
      for (final secret in secrets) {
        final out = redactSecrets('failed: $secret now');
        expect(out, contains('[redacted]'), reason: secret);
        expect(out, isNot(contains('hunter2')));
        expect(out, isNot(contains('correct horse')));
        expect(out, isNot(contains('AIzaSy')));
      }
    });

    test('leaves ordinary text alone', () {
      const line = 'scan accepted for member 42 at lunch';
      expect(redactSecrets(line), line);
    });

    test('also covers the error and stack trace of a record', () {
      final entry = AppLogger.formatRecord(LogRecord(Level.SEVERE, 'boom', 'x',
          Exception('password=hunter2'), StackTrace.current));
      expect(entry, isNot(contains('hunter2')));
      expect(entry, contains('error:'));
    });
  });

  group('static guards', () {
    final sources = {
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !RegExp(r'app_localizations.*\.dart').hasMatch(f.path))
          f.path: f.readAsLinesSync(),
    };

    // The catch line through the brace that closes its block.
    String catchBody(List<String> lines, int start) {
      final body = StringBuffer();
      var depth = 0;
      for (final (n, raw) in lines.skip(start).indexed) {
        // On the catch line only what follows `catch` belongs to the handler.
        final line = n == 0 ? raw.substring(raw.indexOf('catch')) : raw;
        body.writeln(line);
        depth += '{'.allMatches(line).length - '}'.allMatches(line).length;
        if (depth <= 0 && line.contains('{')) break;
      }
      return body.toString();
    }

    test('no exception text is interpolated into UI', () {
      final leaks = [
        for (final MapEntry(:key, :value) in sources.entries)
          if (key.startsWith('lib/ui/'))
            for (final (i, line) in value.indexed)
              if (RegExp(r'\bcatch\s*\(').hasMatch(line) &&
                  RegExp(r'\$e\b|\$\{e[.}]|e\.toString\(\)|\.runtimeType')
                      .hasMatch(catchBody(value, i)))
                '$key:${i + 1}',
      ];
      expect(leaks, isEmpty);
    });

    test('screens go through describeError, never errorText', () {
      final bypass = [
        for (final MapEntry(:key, :value) in sources.entries)
          if (key != 'lib/l10n/messages.dart')
            for (final (i, line) in value.indexed)
              if (line.contains('.errorText(')) '$key:${i + 1}',
      ];
      expect(bypass, isEmpty);
    });

    // Catch sites that neither log nor rethrow, per file. Reviewed; shrinks
    // as each is classified (keep and log / narrow / remove) and must end
    // empty. A count lower than listed fails too, so the list cannot go stale.
    const silentCatchAllowList = <String, int>{
      'lib/ui/admin/topup_screen.dart': 1,
      'lib/app/credential_store.dart': 1,
      'lib/app/providers.dart': 1,
      'lib/app/canteen_book.dart': 1,
      'lib/services/settings_service.dart': 1,
    };

    test('no catch swallows an error without logging or rethrowing', () {
      final handled = RegExp(r'log|reportError|describeError|rethrow|throw',
          caseSensitive: false);
      final silent = <String, int>{};
      for (final MapEntry(:key, :value) in sources.entries) {
        for (final (i, line) in value.indexed) {
          if (!RegExp(r'\bcatch\s*\(').hasMatch(line) ||
              line.trimLeft().startsWith('///') ||
              line.trimLeft().startsWith('//')) {
            continue;
          }
          final body = catchBody(value, i);
          if (!handled.hasMatch(body)) silent[key] = (silent[key] ?? 0) + 1;
        }
      }
      expect(silent, silentCatchAllowList);
    });
  });
}
