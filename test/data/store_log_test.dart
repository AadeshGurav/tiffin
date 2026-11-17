import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import '../support/fake_backend.dart';

void main() {
  test('every write is logged once with what it was and how long it took',
      () async {
    Logger.root.level = Level.ALL;
    final lines = <String>[];
    final sub = Logger.root.onRecord.listen((r) => lines.add(r.message));
    addTearDown(sub.cancel);

    final fake = await fakeBackend();
    await signInAdmin(fake.backend);
    lines.clear();

    await fake.backend.menu.createCategory('Veg', null);

    final writes =
        lines.where((l) => l.startsWith('wrote menuCategories.create'));
    expect(writes, hasLength(1));
    expect(writes.single, matches(RegExp(r'ms=\d+$')));
  });

  test('a failed sign-in logs why, while the caller learns nothing', () async {
    final lines = <String>[];
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen((r) => lines.add(r.message));
    addTearDown(sub.cancel);

    final fake = await fakeBackend();
    await signInAdmin(fake.backend);
    await fake.backend.logout();

    expect(lines, contains('logout username=admin'));
    expect(fake.backend.login('admin', 'wrong'), throwsA(anything));
    await Future<void>.delayed(Duration.zero);
    expect(
        lines, contains('login_failed username=admin reason=wrong_password'));
    expect(lines.where((l) => l.contains('wrong')).join(),
        isNot(contains('wrongpw')));
  });
}
