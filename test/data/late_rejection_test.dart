import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/app/providers.dart';
import 'package:tiffin/data/store.dart';
import 'package:tiffin/l10n/app_localizations.dart';
import 'package:tiffin/ui/shared_widgets/app_shell.dart';
import 'package:tiffin/ui/theme/app_theme.dart';
import 'package:tiffin/ui/theme/theme_catalog.dart';

/// fake_cloud_firestore never refuses a write, so the server's late "no" is
/// a batch whose commit fails after the store has stopped waiting.
class _RefusedBatch implements WriteBatch {
  @override
  Future<void> commit() => Future<void>.delayed(
      Duration.zero,
      () => throw FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Store _offlineStore() =>
    Store(FakeFirebaseFirestore(), 'test-canteen')..online = false;

void main() {
  test('a late rejection nobody handles reaches the rejections sink', () async {
    final store = _offlineStore();
    final seen = store.rejections.first;
    await store.commit(_RefusedBatch(), 'refunds.create r1');
    final rejection = await seen;
    expect(rejection.what, 'refunds.create r1');
    expect(rejection.ref, matches(RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$')));
  });

  test('a caller with its own onRejected handles it instead', () async {
    final store = _offlineStore();
    final sunk = <WriteRejection>[];
    store.rejections.listen(sunk.add);
    Object? heard;
    await store.commit(_RefusedBatch(), 'devices.request',
        onRejected: (e) => heard = e);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(heard, isA<FirebaseException>());
    expect(sunk, isEmpty);
  });

  testWidgets('the shell tells the person which save was undone, with a code',
      (tester) async {
    final store = _offlineStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [storeProvider.overrideWithValue(store)],
      child: MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        theme: buildTiffinTheme(TiffinThemeId.values.first, Brightness.light),
        home: const WriteRejectionNotices(child: Scaffold(body: SizedBox())),
      ),
    ));

    await tester.runAsync(() async {
      await store.commit(_RefusedBatch(), 'refunds.create r1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('A refund you saved earlier was refused'),
        findsOneWidget);
    expect(find.textContaining('Code: '), findsOneWidget);

    // It stays until the person dismisses it.
    await tester.pump(const Duration(minutes: 5));
    expect(find.byType(MaterialBanner), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
  });
}
