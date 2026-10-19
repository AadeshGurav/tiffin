# ADR 0005 — Firebase as the database, offline-first; the LAN host retired

Status: accepted · 2026-10-17

Supersedes PRD §13 (one phone hosts a LAN server) and the "local-network
first, no managed cloud" lines of PRD §7 and §13.3. PRD §15 is the new
architecture section; this ADR records why, and what was turned down.

---

## 1. Every phone talks to Firestore directly

**Context.** v2 put one phone at the centre: drift/SQLite, a shelf server,
mDNS discovery, a self-signed TLS option, an Android hotspot and a
foreground service, plus a hand-written web admin. Every other phone was an
HTTP client. The host was a single point of failure (asleep, off Wi-Fi,
backgrounded on iOS) and the code to keep it serving was most of the
complexity in the app.

**Decision.** The canteen's data lives in the canteen's own Firebase
project. Each phone reads and writes Cloud Firestore directly; there is no
host. The server, discovery, TLS, hotspot, foreground service, web admin and
drift are deleted (≈ 15k lines including generated code).

**Rejected.**
- *Keep the LAN host and swap only its database for Firestore.* Pays for the
  cloud and keeps all of the LAN machinery. No benefit either way.
- *Cloud Functions for the business rules.* Needs the paid Blaze plan and a
  second (TypeScript) codebase, and functions don't run offline — the one
  property the canteen asked for.

## 2. Offline is the normal case, so writes are batches

**Context.** The user's requirement: it must work with no internet and sync
when it comes back, scans included. The FlutterFire / Firestore docs are
explicit that **transactions fail when the client is offline**; batched
writes run offline and stay atomic.

**Decision.**
- All writes are `WriteBatch`es (`Store.commit`). Online, the commit waits up
  to 4 s for the server so a refused write reaches the screen that made it;
  offline it returns at once and syncs later. Firestore persists the queue
  across app restarts.
- Balances and stock use `FieldValue.increment`, so changes from phones that
  sync in any order add up instead of overwriting each other.
- The collections the counter needs at speed (members, settings, menu,
  kitchen, accounts, notifications, today's and yesterday's scans) are kept
  synced by snapshot listeners (`CacheWarmer`) and read from the cache
  (`Store.cached`), which is instant and correct offline. History screens
  read server-first with cache fallback.
- The only transaction is the first-owner claim (§4), which needs the network
  anyway.

**Consequence — the duplicate scan.** Each accepted scan's document id is
`{member}_{day}_{meal}`, and the rules allow *creating* it but never
overwriting it. If two offline phones serve the same person the same meal,
the second batch is refused when it syncs — balance decrement and stock use
included, because a batch is all-or-nothing — and that phone raises a
"scan not counted" notification. Tested on the emulator
(`tool/rules-test`).

**Consequence — the accepted cost.** Balance checks use the cached member.
Two offline phones can each let the same person spend their last unit on
different meals, taking the balance below the grace limit. Reports show it.
That is the price of scanning without a network, and it was chosen over
"no scans while offline".

**Known ceiling.** If a phone is killed before an offline scan syncs and the
server later refuses it, Firestore rolls the scan back silently — there is
no callback left to raise the notification. Add a reconcile pass if that
turns up in practice.

## 3. The only setting is the Firebase config file, imported at runtime

**Decision.** On first launch the operator picks the file the Firebase
console downloads for this app (`google-services.json` / 
`GoogleService-Info.plist`). It is parsed into `FirebaseOptions` and stored
on the phone (`FirebaseConfig`); `Firebase.initializeApp(options:)` needs no
Gradle plugin and no file in the repo. One build serves any canteen.

**Rejected.** *Build-time config (`flutterfire configure`).* A build per
canteen, and a config file in source control.

Switching project needs an app restart: Firebase's default app can't be
re-pointed in place, and a terminated Firestore can't be reused.

## 4. Access: approved phones, offline accounts, optional online accounts

**Context.** Firestore rules can only trust a Firebase identity. Staff sign in
with a username and password that must work offline, and Firebase Auth can't
sign a new user in offline. The user asked for both kinds of account.

**Decision.**
- **Phones.** Each phone gets an anonymous Firebase identity (once, online)
  and asks to join by writing `devices/{uid}` as *pending*. An admin phone
  approves it with a role. **The phone's role is what the rules enforce.**
- **Bootstrap.** The first phone on a fresh project claims `meta/owner` in a
  transaction and becomes the first admin phone.
- **Offline accounts** (always on) keep v2's model: PBKDF2-SHA256 hashes in
  `users`, synced to every approved phone and checked on the phone. Sessions
  live on the phone only. A phone refuses a user whose role is wider than its
  own (an admin account can't sign in on a scanner phone).
- **Online accounts** (Settings toggle) are Firebase email/password users with
  their role in `onlineUsers/{uid}`; they work on any phone without
  approving it, and need internet to sign in. The admin creates them through
  a secondary `FirebaseApp` so the admin isn't signed out.

**Security posture, stated plainly.**
- Within one phone, which *person* is signed in is enforced by the app, not
  the rules. The rules cap the phone. Approve phones with the narrowest role
  they need.
- Every approved phone holds the offline accounts' password hashes (260k
  PBKDF2 rounds). A lost phone should be **removed** in Settings ▸ Devices.
- Without Cloud Functions the admin can't reset or delete an online account's
  password; online accounts reset by email, and the admin can turn one off.

## 5. Backups and the way across from v2

**Decision.** A `.tiffin` file is now a zip of a manifest and `data.json`
(every data collection plus settings), optionally AES-GCM encrypted as
before. Format-1 files — v2's SQLite snapshot — are still read
(`LegacyImport`), mapping integer ids to string ids, so an existing canteen
is moved by exporting a backup on the old app and importing it on first-run
setup. `sqlite3` stays as an import-only dependency for that. Restore needs
the network: it is thousands of writes, and half a restore queued on one
phone is worse than "connect first".

## 6. Words live in the UI, never in the data

**Decision.** Services return codes — `ErrorCode` + args, `ReversalCode`,
`ScanOutcome`, notifications as `{type, params}` — and the UI words them
through the ARB files (`l10n/messages.dart`). With every phone writing to one
shared database, a sentence stored in one phone's language would be shown in
that language on every other phone.

The bill is drawn by Flutter (`BillView`) and shared as an image inside a
PDF: the `pdf` package lays text out itself and doesn't shape Devanagari
conjuncts, so Hindi and Marathi — names included — would print broken.

## 7. Dependencies

Added `firebase_core`, `firebase_auth`, `cloud_firestore` (6.x: the newest
line `fake_cloud_firestore` supports, which the service tests run on) and
`sqlite3`. Removed shelf ×3, drift, drift_dev, sqlite3_flutter_libs, nsd,
basic_utils, flutter_foreground_task, http, crypto, riverpod_annotation,
riverpod_generator, build_runner. The rules tests pin `firebase-tools` 13.x,
the last line that runs its emulator on Java 17.
