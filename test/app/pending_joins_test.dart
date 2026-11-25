import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiffin/app/providers.dart';
import 'package:tiffin/core/role.dart';
import 'package:tiffin/data/access.dart';

void main() {
  Device phone(String uid, String status) =>
      Device(uid: uid, name: uid, status: status, role: Role.scanner);
  OnlineAccount person(String uid, String status) =>
      OnlineAccount(uid: uid, email: uid, role: Role.scanner, status: status);

  // The admin's only cue that someone is at the door: both ways of asking
  // to join count, and nothing already let in or turned away does.
  test('counts waiting phones and waiting people, nothing else', () async {
    final c = ProviderContainer(overrides: [
      devicesProvider.overrideWith((ref) => Stream.value([
            phone('admin', 'approved'),
            phone('gate', 'pending'),
            phone('old', 'removed'),
          ])),
      onlineAccountsProvider.overrideWith((ref) => Stream.value([
            person('cook', 'pending'),
            person('clerk', 'pending'),
            person('owner', 'active'),
            person('gone', 'inactive'),
          ])),
    ]);
    addTearDown(c.dispose);
    c.listen(pendingJoinsProvider, (_, __) {});
    await c.read(devicesProvider.future);
    await c.read(onlineAccountsProvider.future);

    expect(c.read(pendingJoinsProvider), (devices: 1, accounts: 2));
  });
}
