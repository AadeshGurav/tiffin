import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/list_search.dart';

void main() {
  group('matchesQuery', () {
    test('blank query matches everything', () {
      expect(matchesQuery('   ', ['anything']), isTrue);
    });

    test('ignores case, padding and diacritics', () {
      expect(matchesQuery('  JOSE ', ['José Álvarez']), isTrue);
    });

    test('every word must match, in any order, across fields', () {
      expect(matchesQuery('sharma 7b', ['Asha Sharma', '7B']), isTrue);
      expect(matchesQuery('sharma 8c', ['Asha Sharma', '7B']), isFalse);
    });

    test('null fields are skipped and Devanagari matches as typed', () {
      expect(matchesQuery('आशा', [null, 'आशा शर्मा']), isTrue);
    });
  });

  group('searchAndSort', () {
    final rows = [('b', 2), ('a', 2), ('c', 1)];

    test('filters, then orders by the comparator', () {
      final out = searchAndSort<(String, int)>(rows,
          query: '',
          searchFields: (r) => [r.$1],
          compare: (x, y) => x.$2.compareTo(y.$2));
      expect(out.map((r) => r.$1), ['c', 'b', 'a']); // ties keep loaded order
    });

    test('no comparator keeps loaded order', () {
      final out = searchAndSort<(String, int)>(rows,
          query: 'b', searchFields: (r) => [r.$1]);
      expect(out.map((r) => r.$1), ['b']);
    });
  });

  test('compareNames ignores case and accents', () {
    expect(compareNames('Émile', 'zed'), lessThan(0));
    expect(compareNames('bob', 'Bob'), 0);
  });
}
