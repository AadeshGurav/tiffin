import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffin/app/bootstrap.dart';
import 'package:tiffin/core/role.dart';
import 'package:tiffin/data/access.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/auth/connect_firebase_screen.dart';
import 'package:tiffin/ui/auth/device_setup_screen.dart';
import 'package:tiffin/ui/auth/waiting_screen.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

/// The screens a phone sees before it may read anything — the first thing
/// every new canteen and every new phone meets — in each language, at the
/// 320px reflow floor (CLAUDE.md §11.6.9). Text expansion in Hindi/Marathi is
/// what overflows first.
void main() {
  const device = Device(
      uid: 'abcdef123456',
      name: 'Counter 1',
      status: 'pending',
      role: Role.scanner);

  final screens = <String, Widget>{
    'connect': const ConnectFirebaseScreen(),
    'join': const DeviceSetupScreen(newCanteen: false, signedIn: false),
    'new canteen': const DeviceSetupScreen(newCanteen: true, signedIn: true),
    'waiting': const WaitingScreen(device: device),
    'removed': const WaitingScreen(device: device, removed: true),
    'online refused': const WaitingScreen.onlineRefused(email: 'a@b.c'),
  };

  for (final locale in AppText.supportedLocales) {
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      testWidgets('$name renders in ${locale.languageCode} at 320px',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppText.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppText.supportedLocales,
            theme:
                buildTiffinTheme(TiffinThemeId.defaultTheme, Brightness.light),
            home: screen,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the waiting screen shows the code the admin matches',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        theme: buildTiffinTheme(TiffinThemeId.defaultTheme, Brightness.light),
        home: const WaitingScreen(device: device),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('ABCDEF'), findsOneWidget);
  });
}
