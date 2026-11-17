# Errors — for developers and for whoever troubleshoots

Why and what was rejected: [ADR 0007](adr/0007-plain-traceable-errors.md).
What the operator sees: [User Guide §4](USER_GUIDE.md#4-if-somethings-wrong).

## Adding an error (developer)

1. Add a value to `ErrorCode` in `lib/core/errors.dart`.
2. Raise it with the facts the sentence needs, never prose:
   `throw ValidationException(ErrorCode.menuEntryExists, {'meal': m, 'category': c})`.
3. Add its sentence (what happened + what to try) to `app_en.arb`, `app_hi.arb`
   and `app_mr.arb`, and one case in `_appError` in `lib/l10n/messages.dart`.
4. In a screen, catch with the stack and let `describeError` decide:

   ```dart
   } catch (e, st) {
     setState(() => _error = AppText.of(context).describeError(e, st));
   }
   ```

   Render it with `ErrorNoticeView`, `showNbSnack(..., ref: notice.ref)` or
   `runGuarded`. Never write `'$e'`, `e.toString()` or `e.runtimeType` into UI.
5. A `catch` that deliberately carries on (a fallback) must still log a line.
   `test/error_handling_test.dart` fails on a silent one.

Anything without its own sentence (an unknown Firebase code, a bug) is
unexpected: it gets a reference code and a full log entry automatically.

## Finding a failure by code (operator / IT)

1. The person reads out or sends the code (`K7F2-9QX` style) shown under the
   message. They can tap **Copy code**.
2. Ask them to open **Settings ▸ Share log with IT** and send the file.
3. Search it for the code: `grep "K7F2-9QX" app.log`. The entry has the time,
   the area, the error and the full stack trace; the line above shows what
   the phone was doing.

**Where logs live:** `logs/app.log` in the app's documents directory on each
phone. At 5 MB it rotates to `app.log.1` … `.5` (checked at app start); older
files are deleted. The log is lost when the app is uninstalled or its data is
cleared. Secrets (API keys, tokens, passwords) are masked, but member names
can appear in log lines — treat the file as private.
