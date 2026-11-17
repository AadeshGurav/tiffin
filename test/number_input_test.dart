import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/core/number_input.dart';

/// A mistyped number must be refused, not quietly saved as 0 (a free meal, a
/// zero price). Blank is a deliberate "none" and keeps its default.
void main() {
  final refused = throwsA(isA<ValidationException>()
      .having((e) => e.code, 'code', ErrorCode.numberInvalid));

  group('parseWholeNumber', () {
    test('reads digits, ignoring surrounding spaces', () {
      expect(parseWholeNumber(' 12 '), 12);
    });

    test('blank is the default, not an error', () {
      expect(parseWholeNumber(''), 0);
      expect(parseWholeNumber('  ', ifBlank: 10), 10);
    });

    test('refuses anything that is not a whole number', () {
      for (final bad in ['abc', '1.5', '12a', '-', '1 2']) {
        expect(() => parseWholeNumber(bad), refused, reason: bad);
      }
    });
  });

  group('parseAmount', () {
    test('reads decimals with a point or a comma', () {
      expect(parseAmount('12.5'), 12.5);
      expect(parseAmount('12,5'), 12.5);
      expect(parseAmount('40'), 40);
    });

    test('blank is the default, not an error', () {
      expect(parseAmount(''), 0);
      expect(parseAmount(' ', ifBlank: 3), 3);
    });

    test('refuses text, NaN and infinity', () {
      for (final bad in ['abc', '1.2.3', 'NaN', '1e999', '--5']) {
        expect(() => parseAmount(bad), refused, reason: bad);
      }
    });
  });
}
