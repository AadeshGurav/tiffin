import 'package:flutter/material.dart';

import '../../core/list_search.dart';
import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'nb_feedback.dart';

/// One way to order a list: a menu label and a comparator.
class SortOption<T> {
  const SortOption(this.label, this.compare);
  final String label;
  final Comparator<T> compare;
}

/// A search field + sort menu above a list that is already loaded. Owns the
/// query and sort choice, so a screen only supplies the rows and what text of
/// each row is searchable; [builder] gets the filtered, sorted list.
class SearchSortList<T> extends StatefulWidget {
  const SearchSortList({
    super.key,
    required this.items,
    required this.searchLabel,
    required this.searchFields,
    required this.builder,
    this.sorts = const [],
  });

  final List<T> items;

  /// Visible field label (never placeholder-only, CLAUDE.md §11.6.7).
  final String searchLabel;
  final List<String?> Function(T item) searchFields;

  /// The first option is the default. The sort menu shows only for 2+.
  final List<SortOption<T>> sorts;
  final Widget Function(BuildContext context, List<T> visible) builder;

  @override
  State<SearchSortList<T>> createState() => _SearchSortListState<T>();
}

class _SearchSortListState<T> extends State<SearchSortList<T>> {
  final _query = TextEditingController();
  var _sortIndex = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = AppText.of(context);
    final visible = searchAndSort(
      widget.items,
      query: _query.text,
      searchFields: widget.searchFields,
      compare: widget.sorts.isEmpty ? null : widget.sorts[_sortIndex].compare,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              NbSpace.md, NbSpace.sm, NbSpace.sm, NbSpace.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  style: t.text.body,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: widget.searchLabel,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: text.searchClear,
                            onPressed: () => setState(_query.clear),
                          ),
                  ),
                ),
              ),
              if (widget.sorts.length > 1)
                PopupMenuButton<int>(
                  icon: const Icon(Icons.sort),
                  tooltip: text.searchSortTooltip,
                  onSelected: (i) => setState(() => _sortIndex = i),
                  itemBuilder: (_) => [
                    for (var i = 0; i < widget.sorts.length; i++)
                      CheckedPopupMenuItem(
                        value: i,
                        checked: i == _sortIndex,
                        child: Text(widget.sorts[i].label),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? NbEmpty(
                  icon: Icons.search_off,
                  title: text.searchNoMatches(_query.text.trim()),
                  quips: [text.searchNoMatchesHint],
                  actionLabel: text.searchClear,
                  onAction: () => setState(_query.clear),
                )
              : widget.builder(context, visible),
        ),
      ],
    );
  }
}
