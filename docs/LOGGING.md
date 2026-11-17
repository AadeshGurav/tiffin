# Logging — reading what the app did

Errors and their reference codes: [ERRORS.md](ERRORS.md). This page is about the
log file itself.

## Getting the file

| Where the app runs | How |
| --- | --- |
| iOS simulator / Android device or emulator (debug build) | `make logs` → `./app.log` |
| Real iPhone | In the app: **Settings ▸ Share log**. Or Xcode ▸ Window ▸ Devices and Simulators ▸ the app ▸ Download Container, then `AppData/Documents/logs/app.log` |
| `flutter run` | the same lines stream to the terminal |

## Reading it

```
=== session start 2026-11-18T02:41:07.120Z ===     ← one per app launch
    app      3.0.0 (debug)
    platform ios 26.0
    locale   en_IN
    level    ALL

2026-11-18 02:41:09.311Z INFO    lifecycle      resumed
2026-11-18 02:41:12.870Z WARNING scan           rejected reason=unknown_code qr=…
2026-11-18 02:41:15.002Z SEVERE  error          [ref K7F2-9QXA] flutter framework error
    error: Bad state: …
    #0  …stack trace, indented…
```

Times are UTC, columns are fixed width, so scanning down the level column finds
problems fast:

```bash
grep -E "SEVERE|WARNING" app.log        # what went wrong
grep "K7F2-9QXA" app.log                # one failure, by the code the screen showed
grep " scan " app.log                   # one area (logger name)
awk '/=== session start/{n++} n==3' app.log   # the third launch only
```

A gap followed by a new `session start` with no `lifecycle paused/detached`
before it means the app was killed or crashed.

## What gets logged for free

Every Firestore write goes through `Store.commit`, which logs it by name:
`wrote menu.add ms=84`, `queued scan.record (offline, will sync)`, later
`synced …`, or `WARNING server rejected …`. Grep `wrote|queued|synced|rejected`
to see exactly what a phone did to the data and whether it reached the server.
Services add their own business lines (`created member_id=…`) on top.

## Behaviour

- **Levels:** debug/profile builds log everything (`ALL`); release logs `INFO`
  and above. Use `log('area').fine(...)` for developer detail that should not
  reach a release file.
- **Durable:** each line is appended straight to disk, so the last line before
  a crash is in the file.
- **Size:** at 5 MB `app.log` rotates to `app.log.1` … `.5`, mid-run too
  (`AppConfig.logFileMaxBytes`, `logFileBackupCount`).
- **Private:** API keys, tokens and passwords are masked; member names can
  still appear. Don't post a log publicly.
- **Writing a line:** `final _log = log('area');` then `_log.info('what
  happened key=value')` — identifiers (ids, never secrets) so it can be
  debugged without reproducing.
