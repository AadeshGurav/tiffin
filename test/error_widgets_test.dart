import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/shared_widgets/nb_feedback.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

/// What a person actually sees when something fails (docs/ERRORS.md): the
/// sentence, a code only when IT is needed, a working Copy button, and a
/// layout that survives the narrowest phone.
void main() {
  Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        theme: buildTiffinTheme(TiffinThemeId.values.first, Brightness.light),
        home: Scaffold(body: Center(child: child)),
      );

  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('an expected error shows its sentence and no code',
      (tester) async {
    await tester.pumpWidget(app(const ErrorPanel(
        error: ValidationException(ErrorCode.usernameRequired))));
    expect(find.textContaining('Code:'), findsNothing);
    expect(find.text('Copy code'), findsNothing);
  });

  testWidgets(
      'an unexpected error shows a code and Copy puts it on the '
      'clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(app(ErrorPanel(error: StateError('boom'))));
    final label = tester.widget<SelectableText>(find.byType(SelectableText));
    final code = label.data!.replaceFirst('Code: ', '');
    expect(code, matches(RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$')));

    await tester.tap(find.text('Copy code'));
    await tester.pump();
    expect(copied, code);
    expect(find.text('Code copied'), findsOneWidget);
  });

  testWidgets('the code stays the same when the panel rebuilds',
      (tester) async {
    final error = StateError('boom');
    Future<String> shownCode() async {
      await tester.pumpWidget(app(ErrorPanel(error: error)));
      return tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    }

    final first = await shownCode();
    await tester.pump(const Duration(milliseconds: 50));
    expect(await shownCode(), first,
        reason: 'a rebuild must not mint a second code for one failure');
  });

  for (final locale in const ['en', 'hi', 'mr']) {
    testWidgets('$locale: the coded error fits 320px with 2x text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 640), textScaler: TextScaler.linear(2)),
        child: app(
            AsyncView<int>(
              value: AsyncError(StateError('boom'), StackTrace.empty),
              builder: (_) => const SizedBox(),
              onRetry: () {},
            ),
            locale: Locale(locale)),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflow or clipping');
    });
  }

  testWidgets('an uncaught error is announced with its code', (tester) async {
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: rootMessengerKey,
      localizationsDelegates: AppText.localizationsDelegates,
      supportedLocales: AppText.supportedLocales,
      theme: buildTiffinTheme(TiffinThemeId.values.first, Brightness.light),
      home: const Scaffold(body: SizedBox()),
    ));
    showUncaughtError('ABCD-2345');
    await tester.pump();
    expect(find.textContaining('ABCD-2345'), findsOneWidget);
  });

  test('showUncaughtError before the app exists does nothing', () {
    expect(() => showUncaughtError('ABCD-2345'), returnsNormally);
  });
}
