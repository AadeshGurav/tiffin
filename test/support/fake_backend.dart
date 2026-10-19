import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiffin/core/role.dart';
import 'package:tiffin/data/backend.dart';
import 'package:tiffin/data/store.dart';

/// A [Backend] over an in-memory Firestore, for service tests.
///
/// The store waits for every write (the fake acknowledges at once), which is
/// what a phone with a connection does too — so these tests exercise the
/// online path; the offline difference is only *when* a write is confirmed.
///
/// Pass [db] to put a second phone on the same canteen.
Future<({Backend backend, FakeFirebaseFirestore db})> fakeBackend({
  Role deviceRole = Role.admin,
  FakeFirebaseFirestore? db,
}) async {
  if (db == null) SharedPreferences.setMockInitialValues({});
  db ??= FakeFirebaseFirestore();
  final backend = Backend(
    Store(db),
    await SharedPreferences.getInstance(),
    deviceRole: deviceRole,
    scratch: Directory.systemTemp.createTempSync('tiffin-test'),
  );
  return (backend: backend, db: db);
}

/// Signs [backend] in as a fresh admin, so "who did this" fields are stamped.
Future<void> signInAdmin(Backend backend) async {
  await backend.auth
      .createInitialAdmin(username: 'admin', password: 'lunchtime99');
  await backend.login('admin', 'lunchtime99');
}
