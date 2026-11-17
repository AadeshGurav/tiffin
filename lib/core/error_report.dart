import 'dart:math';

import 'package:logging/logging.dart';

import 'errors.dart';

/// What a person is shown for a failure: a sentence, plus a [ref] only when
/// the failure is one they cannot fix and IT must look up in the log.
class ErrorNotice {
  const ErrorNotice(this.message, {this.ref});

  final String message;
  final String? ref;
}

// No 0/O/1/I/L: a code read aloud or copied by hand must survive being misread.
const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
final _random = Random.secure();

/// A fresh `XXXX-XXXX` code. Random on purpose: it cannot be guessed, and it
/// reveals nothing about the user, the time or the failure.
String newReferenceCode() {
  String chunk() => String.fromCharCodes(
      List.generate(4, (_) => _alphabet.codeUnitAt(_random.nextInt(31))));
  return '${chunk()}-${chunk()}';
}

final _log = Logger('error');

/// Reference codes of errors already reported, keyed by the error object, so
/// a handler that only sees the object later (the crash widget) can show the
/// same code the log line carries.
final Expando<String> reportedRefs = Expando<String>();

/// Writes [error] and [stack] to the log under a fresh reference code and
/// returns that code. The single entry point for every failure nobody
/// anticipated — the code is what joins the screen to the log line.
String reportError(Object error, StackTrace? stack,
    {String context = 'unexpected failure'}) {
  final ref = newReferenceCode();
  _log.severe('[ref $ref] $context', error, stack);
  // Expando rejects primitives; and an AppException may be a shared const, so
  // one code per instance would wrongly merge separate failures.
  if (error is! AppException &&
      error is! num &&
      error is! String &&
      error is! bool) {
    reportedRefs[error] = ref;
  }
  return ref;
}
