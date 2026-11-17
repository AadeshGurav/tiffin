# ADR 0007 — Plain-language, traceable, leak-free errors

Status: accepted · 2026-11-18

## Context

Errors have two readers with opposite needs. The canteen operator is not
technical and needs to know what happened and what to try. Anyone probing the
app must learn nothing about its internals. Before this change the app already
had typed `AppException`s, a localized sentence per `ErrorCode`, and a rotating
log file. What it lacked: unexpected failures told the person to look in "the
log" they could not open or match to anything; stack traces never reached the
file; secrets were not redacted; seven screens swallowed unexpected errors
without logging them; one showed `'$e'` to the user.

## Decision

- **A reference code joins screen and log.** Every unanticipated failure is
  logged in full under a fresh 8-character `XXXX-XXXX` code (crypto RNG, no
  look-alike characters, not derived from anything) and the same code is shown
  to the person with a *Copy code* button. Anticipated failures (validation, a
  refused write, no internet) are a plain sentence with no code.
- **One entry point.** `AppText.describeError(error, stack)` turns any caught
  failure into an `ErrorNotice(message, ref?)`; `reportError` writes the log
  line. Screens never format an exception themselves.
- **Logs are complete and safe.** Entries include the error and stack trace;
  API-key shapes, JWTs, bearer tokens and `password=…`-style values are masked
  on the *formatted* text, so traces are covered.
- **IT can get the log.** Settings ▸ Share log with IT opens the share sheet
  with `logs/app.log` (adds the `share_plus` dependency).
- **No failure is invisible.** An uncaught async error shows a snackbar with
  its code; a failing startup shows a plain last-resort screen with a code; a
  camera that won't start says why. Error panels scroll so the code stays
  reachable at large text sizes.
- **Guarded by tests.** `test/error_handling_test.dart` fails on interpolated
  exception text in UI, on `errorText` used outside `describeError`, and on any
  `catch` that neither logs nor rethrows.

## Rejected

- **A hosted error tracker (Sentry, Crashlytics).** Sends operators' data to a
  third party and needs the network that is often absent.
- **Rewording messages only.** Leaves unlogged crashes and leaks open.
- **RFC 9457 Problem Details / HTTP status mapping.** There is no HTTP API in
  this app; the typed-exception → localized-sentence path is the equivalent.
- **`runZonedGuarded`.** `PlatformDispatcher.onError` already catches uncaught
  errors in any zone on current Flutter.
- **Copy-last-N-lines instead of a share sheet.** Weaker: the admin cannot
  attach it to a message, and long traces get truncated.

## Consequences

- Logs stay on the phone and are lost on uninstall or data clear; the share
  action is the only way off the device.
- Log rotation runs when the app starts, not mid-session (5 MB × 5 files).
- A per-user field on log lines is not included (no session lookup in the
  logger); the code plus time identify the failure.
