import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/shared_widgets/search_sort_list.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

void main() {
  Widget app() => MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        theme: buildTiffinTheme(TiffinThemeId.values.first, Brightness.light),
        home: Scaffold(
          body: SearchSortList<String>(
            items: const ['Béla', 'Asha', 'Chitra'],
            searchLabel: 'Search people',
            searchFields: (n) => [n],
            sorts: [
              SortOption('A to Z', (a, b) => a.compareTo(b)),
              SortOption('Z to A', (a, b) => b.compareTo(a)),
            ],
            builder: (context, visible) => ListView(
              children: [for (final n in visible) Text(n)],
            ),
          ),
        ),
      );

  testWidgets('filters ignoring accents, shows an empty state, clears',
      (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Asha'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bela');
    await tester.pump();
    expect(find.text('Béla'), findsOneWidget);
    expect(find.text('Asha'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Nothing matches "zzz"'), findsOneWidget);

    await tester.tap(find.text('Clear search').last);
    await tester.pump();
    expect(find.text('Asha'), findsOneWidget);
  });

  testWidgets('sort menu reorders', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Z to A'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Chitra')).dy,
        lessThan(tester.getTopLeft(find.text('Asha')).dy));
  });
}
