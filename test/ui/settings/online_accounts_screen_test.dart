import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffin/app/bootstrap.dart';
import 'package:tiffin/app/providers.dart';
import 'package:tiffin/core/role.dart';
import 'package:tiffin/data/access.dart';
import 'package:tiffin/data/store.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/settings/online_accounts_screen.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

class _App extends Fake implements FirebaseApp {}

void main() {
  // Regression: someone joining with Google or email is a pending online
  // account, and it showed as "Scanner · pending" with a "Turn on" button —
  // nothing an admin reads as "somebody is waiting for me".
  testWidgets('a join request reads as waiting, with an Approve button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final access = AccessService(
        _App(), MockFirebaseAuth(), Store(FakeFirebaseFirestore(), 'GATE2345'));
    const asking = OnlineAccount(
        uid: 'u1', email: 'cook@b.c', role: Role.scanner, status: 'pending');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accessServiceProvider.overrideWithValue(access),
        onlineAccountsEnabledProvider.overrideWith((ref) async => true),
        onlineAccountsProvider
            .overrideWith((ref) => Stream.value(const [asking])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        theme: buildTiffinTheme(TiffinThemeId.defaultTheme, Brightness.light),
        home: const OnlineAccountsScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    final text = AppText.of(tester.element(find.byType(OnlineAccountsScreen)));
    expect(find.textContaining(text.statusPending), findsOneWidget);
    expect(find.text(text.onlineAccountsApprove), findsOneWidget);
    expect(find.text(text.onlineAccountsTurnOn), findsNothing);
  });
}
