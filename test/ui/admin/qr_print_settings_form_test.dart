import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/print_layout.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/admin/people/qr_print_settings_form.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

/// The print layout form states the computed grid, and says in words why a
/// combination can't print, at the narrowest supported phone width.
void main() {
  Widget app(PrintSettings settings, ValueChanged<PrintSettings> onChanged) =>
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        theme: buildTiffinTheme(TiffinThemeId.values.first, Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: QrPrintSettingsForm(
                settings: settings, cardCount: 40, onChanged: onChanged),
          ),
        ),
      );

  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('shows the grid and the page count', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const PrintSettings(), (_) {}));
    expect(find.textContaining('16 cards per page (4 × 4)'), findsOneWidget);
    expect(find.textContaining('3 pages to print'), findsOneWidget); // 40 / 16
    expect(tester.takeException(), isNull); // no overflow at 320 px
  });

  testWidgets('explains a card that cannot fit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(
        const PrintSettings(
            paper: PaperPreset.roll58, card: CardPreset.id, margin: 4),
        (_) {}));
    expect(find.textContaining('does not fit'), findsOneWidget);
    expect(find.textContaining('85.6 × 54 mm card'), findsOneWidget);
  });

  testWidgets('typing a margin reports the new layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PrintSettings? latest;
    await tester.pumpWidget(app(const PrintSettings(), (s) => latest = s));
    await tester.enterText(find.widgetWithText(TextField, '8'), '12.5');
    expect(latest?.margin, 12.5);
  });
}
