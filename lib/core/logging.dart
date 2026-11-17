import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'config.dart';

/// Application logging — a first-class feature, not an afterthought (PRD §7,
/// CLAUDE.md §8). Every scan decision, top-up, refund, and admin action is
/// logged here with enough identifiers to debug without reproducing.
///
/// Every phone writes its own `logs/app.log` (docs/LOGGING.md). Lines are
/// appended synchronously, so the tail survives a crash or a force-quit — the
/// moments the log matters most. Volume is a few lines per user action, so the
/// cost is negligible.
class AppLogger {
  AppLogger._();

  static bool _configured = false;
  static File? _logFile;
  static StreamSubscription<LogRecord>? _subscription;
  static int _bytesWritten = 0;

  /// Marks where each app launch begins in the file, so `grep` and eyes can
  /// split a long file into runs.
  static const sessionBanner = '=== session start';

  /// Debug builds log everything (FINE and below included); release builds
  /// keep INFO and above so the file stays readable and small.
  static Level get defaultLevel => kReleaseMode ? Level.INFO : Level.ALL;

  /// [toFile] is false in tests that only want the console. [directory]
  /// overrides the documents directory and [console] silences stdout (tests).
  static Future<void> configure({
    required bool toFile,
    Directory? directory,
    bool console = true,
  }) async {
    if (_configured) return;
    _configured = true;

    Logger.root.level = defaultLevel;
    _subscription = Logger.root.onRecord.listen((record) {
      final entry = formatRecord(record);
      // stdout is what a developer watching `flutter run` sees.
      // ignore: avoid_print
      if (console) print(entry);
      _append(entry);
    });

    if (toFile) {
      await _openFile(directory ?? await getApplicationDocumentsDirectory());
      _append(sessionHeader());
    }
  }

  /// One log entry: a fixed-width line a developer can scan down a column,
  /// then the error and its stack trace indented beneath it. Redacted after
  /// formatting, so a secret inside an exception's text or a trace is covered
  /// as well as one in the message.
  static String formatRecord(LogRecord r) {
    final time = r.time.toUtc().toIso8601String().replaceFirst('T', ' ');
    final buffer = StringBuffer(
        '$time ${r.level.name.padRight(7)} ${r.loggerName.padRight(14)} '
        '${r.message}');
    if (r.error != null) buffer.write('\n    error: ${r.error}');
    if (r.stackTrace != null) {
      buffer.write('\n${_indent(r.stackTrace.toString().trimRight())}');
    }
    return redactSecrets(buffer.toString());
  }

  /// What a developer needs first when handed someone's log: which build, on
  /// what, in which mode.
  static String sessionHeader() => [
        '',
        '$sessionBanner ${DateTime.now().toUtc().toIso8601String()} ===',
        '    app      ${AppConfig.appVersion} (${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'})',
        '    platform ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        '    locale   ${Platform.localeName}',
        '    level    ${Logger.root.level.name}',
        '',
      ].join('\n');

  static String _indent(String block) =>
      block.split('\n').map((l) => '    $l').join('\n');

  static Future<void> _openFile(Directory documents) async {
    final logsDir = Directory(p.join(documents.path, 'logs'));
    await logsDir.create(recursive: true);
    final file = File(p.join(logsDir.path, 'app.log'));
    _logFile = file;
    _bytesWritten = file.existsSync() ? file.lengthSync() : 0;
  }

  static void _append(String entry) {
    final file = _logFile;
    if (file == null) return;
    try {
      if (_bytesWritten >= AppConfig.logFileMaxBytes) _rotate(file);
      file.writeAsStringSync('$entry\n', mode: FileMode.append);
      _bytesWritten += entry.length + 1;
    } on FileSystemException catch (e) {
      // Logging must never take the app down; the console copy still exists.
      // ignore: avoid_print
      print('log file write failed: $e');
    }
  }

  /// Shifts app.log → app.log.1 → … so the budget holds mid-run, not only at
  /// launch: a phone left open for weeks must not grow one unbounded file.
  static void _rotate(File file) {
    final oldest = File('${file.path}.${AppConfig.logFileBackupCount}');
    if (oldest.existsSync()) oldest.deleteSync();
    for (var i = AppConfig.logFileBackupCount - 1; i >= 1; i--) {
      final src = File('${file.path}.$i');
      if (src.existsSync()) src.renameSync('${file.path}.${i + 1}');
    }
    file.renameSync('${file.path}.1');
    _bytesWritten = 0;
  }

  /// Absolute path of the current log file.
  static String? get logFilePath => _logFile?.path;

  /// Every write is already on disk; kept so callers that want a complete
  /// file (share) say so explicitly.
  static Future<void> flush() async {}

  /// Test hook: forget configuration so a test can point at a temp directory.
  @visibleForTesting
  static void resetForTest() {
    _subscription?.cancel();
    _configured = false;
    _logFile = null;
    _bytesWritten = 0;
  }
}

/// Convenience: `log('scan').info(...)` — one named logger per domain, matching
/// the usual per-module logger convention.
Logger log(String domain) => Logger(domain);

// Shapes of credential material that must never reach a log file. Matched on
// the formatted text, where exception messages and stack traces already are.
final _secretShapes = [
  RegExp(r'AIza[0-9A-Za-z_\-]{35}'), // Firebase / Google API key
  RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), // JWT
  RegExp(r'Bearer\s+[\w.~+/=-]+', caseSensitive: false),
];
final _secretAssignment = RegExp(
    r'(password|passphrase|passwd|secret|token|api[_-]?key)(["\x27]?\s*[=:]\s*)("[^"]*"|\x27[^\x27]*\x27|[^\s,;)}\]]+)',
    caseSensitive: false);

/// Masks API keys, tokens and `password=…`-style values in [text].
String redactSecrets(String text) {
  var out = text;
  for (final shape in _secretShapes) {
    out = out.replaceAll(shape, '[redacted]');
  }
  return out.replaceAllMapped(
      _secretAssignment, (m) => '${m[1]}${m[2]}[redacted]');
}
