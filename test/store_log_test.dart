import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'support/fake_backend.dart';

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
}
