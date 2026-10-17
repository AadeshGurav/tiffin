import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/core/errors.dart';
import 'package:tiffin/core/role.dart';
import 'package:tiffin/domain/ops.dart';

import 'support/fake_backend.dart';

/// First-run setup and offline accounts.
///
/// The first bug these cover: the initial admin used to be created with a
/// generated password shown once, in memory only — miss it and the canteen was
/// unreachable. The newer one: with the canteen in Firebase, sign-in happens
/// on the phone against synced accounts, and a phone's approved role must cap
/// who can sign in on it.
void main() {
  group('first-run setup', () {
    test('a fresh canteen owes setup and creates no account on its own',
        () async {
      final (:backend, :db) = await fakeBackend();
      expect(await backend.auth.needsSetup(), isTrue);
      expect((await db.collection('users').get()).docs, isEmpty);
    });

    test('setup creates the admin with the chosen credentials', () async {
      final (:backend, db: _) = await fakeBackend();
      await backend.auth
          .createInitialAdmin(username: 'boss', password: 'lunchtime99');
      expect(await backend.auth.needsSetup(), isFalse);
      final session = await backend.login('boss', 'lunchtime99');
      expect(session.role, Role.admin);
    });

    test('setup cannot mint a second admin on a live canteen', () async {
      final (:backend, db: _) = await fakeBackend();
      await backend.auth
          .createInitialAdmin(username: 'admin', password: 'lunchtime99');
      await expectLater(
        backend.auth
            .createInitialAdmin(username: 'sneak', password: 'password1'),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.alreadySetUp)),
      );
    });

    test('a short password is refused with the minimum in the error', () async {
      final (:backend, db: _) = await fakeBackend();
      await expectLater(
        backend.auth.createInitialAdmin(username: 'admin', password: 'short'),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCode.passwordTooShort)
            .having((e) => e.args['min'], 'min', 8)),
      );
    });
  });

  group('offline sign-in', () {
    test('wrong password and unknown user fail the same way', () async {
      final (:backend, db: _) = await fakeBackend();
      await signInAdmin(backend);
      for (final attempt in [('admin', 'nope'), ('ghost', 'lunchtime99')]) {
        await expectLater(
          backend.login(attempt.$1, attempt.$2),
          throwsA(isA<AuthException>()
              .having((e) => e.code, 'code', ErrorCode.badCredentials)),
        );
      }
    });

    test('a scanner phone refuses an admin account', () async {
      final (:backend, :db) = await fakeBackend(deviceRole: Role.scanner);
      await backend.auth
          .createInitialAdmin(username: 'admin', password: 'lunchtime99');
      await expectLater(
        backend.login('admin', 'lunchtime99'),
        throwsA(isA<ForbiddenException>()
            .having((e) => e.code, 'code', ErrorCode.roleNotAllowedOnDevice)),
      );
    });

    test('a counter phone lets counter and scanner accounts in', () async {
      final (backend: admin, :db) = await fakeBackend();
      await signInAdmin(admin);
      await admin.createUser(const UserDraft(
          username: 'till', password: 'password12', role: Role.counter));
      await admin.createUser(const UserDraft(
          username: 'gate', password: 'password12', role: Role.scanner));

      // A second phone on the same canteen, approved as a counter phone.
      final (backend: counter, db: _) =
          await fakeBackend(deviceRole: Role.counter, db: db);
      expect((await counter.login('till', 'password12')).role, Role.counter);
      expect((await counter.login('gate', 'password12')).role, Role.scanner);
      await expectLater(counter.login('admin', 'lunchtime99'),
          throwsA(isA<ForbiddenException>()));
    });

    test('a saved session resumes, and stops once the account is off',
        () async {
      final (:backend, db: _) = await fakeBackend();
      await signInAdmin(backend);
      final user = await backend.createUser(const UserDraft(
          username: 'till', password: 'password12', role: Role.counter));
      final session = await backend.login('till', 'password12');

      expect(await backend.resumeSession(session.token), isNotNull);

      await backend.login('admin', 'lunchtime99');
      await backend.updateUser(user.id, const UserPatch(status: 'inactive'));
      expect(await backend.resumeSession(session.token), isNull);
    });

    test('a password reset revokes sessions made with the old one', () async {
      final (:backend, db: _) = await fakeBackend();
      await signInAdmin(backend);
      final session = await backend.login('admin', 'lunchtime99');
      await backend.auth.resetPasswordFor('admin', 'brandnew123');
      expect(await backend.resumeSession(session.token), isNull);
      expect((await backend.login('admin', 'brandnew123')).role, Role.admin);
    });
  });
}
