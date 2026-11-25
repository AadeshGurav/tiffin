import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffin/app/providers.dart';
import 'package:tiffin/core/role.dart';
import 'package:tiffin/data/access.dart';
import 'package:tiffin/data/store.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/settings/devices_screen.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

class _App extends Fake implements FirebaseApp {}

void main() {
  // Regression: an admin signed in online has no phone record, so the one
  // waiting phone was listed under "No other phones yet." — which read as
  // nobody asking at all.
  testWidgets('an online admin sees a waiting phone, not "no other phones"',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'owner', email: 'a@b.c'));
    final access =
        AccessService(_App(), auth, Store(FakeFirebaseFirestore(), 'GATE2345'));
    const waiting = Device(
        uid: 'abcdef123456',
        name: 'Counter 1',
        status: 'pending',
        role: Role.scanner);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accessServiceProvider.overrideWithValue(access),
        devicesProvider.overrideWith((ref) => Stream.value(const [waiting])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        theme: buildTiffinTheme(TiffinThemeId.defaultTheme, Brightness.light),
        home: const DevicesScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    final text = AppText.of(tester.element(find.byType(DevicesScreen)));
    expect(find.text('Counter 1'), findsOneWidget);
    expect(find.text(text.devicesApproveButton), findsOneWidget);
    expect(find.text(text.devicesEmpty), findsNothing);
  });
}
