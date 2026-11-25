import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/data/access.dart';
import 'package:tiffin/data/store.dart';

class _App extends Fake implements FirebaseApp {}

/// Two phones on one canteen: the one asking to join, and the admin's.
void main() {
  late FakeFirebaseFirestore db;
  AccessService phone(MockFirebaseAuth auth) =>
      AccessService(_App(), auth, Store(db, 'GATE2345'));

  setUp(() => db = FakeFirebaseFirestore());

  test('a phone that asks to join is what the admin sees waiting', () async {
    final joiner = phone(MockFirebaseAuth());
    await joiner.requestApproval('  Counter 1 ');

    final admin = phone(MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'owner', email: 'a@b.c')));
    final devices = await admin.devices().first;
    expect(devices, hasLength(1));
    expect(devices.single.name, 'Counter 1');
    expect(devices.single.status, 'pending');
    expect(devices.single.uid, joiner.user!.uid);
  });

  test('the joining phone sees its own request as waiting', () async {
    final joiner = phone(MockFirebaseAuth());
    await joiner.requestApproval('Counter 1');
    expect(await joiner.watch().first, isA<PendingApproval>());
  });
}
