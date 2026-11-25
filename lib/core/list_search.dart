/// Client-side search and sort over a list that is already loaded — no new
/// queries or indexes. Pure so the matching rules can be tested without a UI.

const _accented = 'àáâãäåāçćčèéêëēėęìíîïīłñńòóôõöøōšśùúûüūýÿžźż';
const _plain = 'aaaaaaacccceeeeeeeiiiilnnooooooosssuuuuuyyzzz';

/// Lower-cases and strips common Latin diacritics so "José" matches "jose".
/// Other scripts (Devanagari etc.) pass through unchanged and match as typed.
String foldForSearch(String input) {
  final out = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    final i = _accented.indexOf(ch);
    out.write(i < 0 ? ch : _plain[i]);
  }
  return out.toString();
}

/// True when every whitespace-separated word of [query] occurs somewhere in
/// the combined [fields] — order-free, so "sharma 7b" finds "7B · Sharma".
bool matchesQuery(String query, Iterable<String?> fields) {
  final words = foldForSearch(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final haystack = foldForSearch(fields.whereType<String>().join(' '));
  return words.every(haystack.contains);
}

/// Items matching [query], ordered by [compare] (loaded order when null).
/// Ties keep their loaded order: Dart's List.sort is not stable on its own.
List<T> searchAndSort<T>(
  List<T> items, {
  required String query,
  required List<String?> Function(T item) searchFields,
  Comparator<T>? compare,
}) {
  final indexed = [
    for (var i = 0; i < items.length; i++)
      if (matchesQuery(query, searchFields(items[i]))) (i, items[i]),
  ];
  if (compare != null) {
    indexed.sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  }
  return [for (final e in indexed) e.$2];
}

/// Name order that ignores case and diacritics.
int compareNames(String a, String b) =>
    foldForSearch(a).compareTo(foldForSearch(b));
