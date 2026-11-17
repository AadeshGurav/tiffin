import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:tiffin/core/config.dart';
import 'package:tiffin/core/logging.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('applog');
    AppLogger.resetForTest();
    await AppLogger.configure(toFile: true, directory: dir, console: false);
  });

  tearDown(() => dir.delete(recursive: true));

  File logFile() => File(AppLogger.logFilePath!);

  test('a launch starts with a header naming the build and platform', () {
    final text = logFile().readAsStringSync();
    expect(text, contains(AppLogger.sessionBanner));
    expect(text, contains(AppConfig.appVersion));
    expect(text, contains(Platform.operatingSystem));
  });

  test('entries are on disk immediately, one line plus indented detail', () {
    log('scan').info('accepted member_id=42');
    log('scan').severe('boom', StateError('bad'), StackTrace.current);

    final text = logFile().readAsStringSync();
    expect(text,
        matches(RegExp(r'\d{4}-\d\d-\d\d [\d:.]+Z INFO\s+scan\s+accepted')));
    expect(text, contains('\n    error: Bad state: bad'));
  });

  test('rotates mid-run once the size budget is passed', () {
    final filler = 'x' * 1000;
    for (var i = 0; i < AppConfig.logFileMaxBytes ~/ 1000 + 10; i++) {
      Logger('fill').info(filler);
    }
    expect(File('${logFile().path}.1').existsSync(), isTrue);
    expect(logFile().lengthSync(), lessThan(AppConfig.logFileMaxBytes));
  });

  test('an unusable log directory falls back to console-only', () async {
    final blocker = File('${dir.path}/blocker')..writeAsStringSync('x');
    AppLogger.resetForTest();
    await AppLogger.configure(
        toFile: true, directory: Directory(blocker.path), console: false);

    expect(AppLogger.logFilePath, isNull);
    log('scan').info('still works'); // must not throw
  });
}
