# ADR 0006 — Many canteens in one shared Firebase project

Status: accepted · 2026-11-03

Supersedes the "each canteen imports its own Firebase project file" part of
ADR 0005 §3. Everything else in ADR 0005 (Firestore direct, offline-first
batches, devices + offline accounts) stands.

---

## Context

With one project per canteen, a phone belongs to one canteen for life.
Leaving it, switching to another, or creating a new one all meant going
through the Firebase console (Google account, Firestore, sign-in methods,
rules). The sign-in screen was a dead end: a phone signed out as admin could
not become a client of another canteen.

How the canteen actually works: a manager/admin prepares the day (members,
QR codes, menu, accounts, approvals); a scanner person scans at the counter;
a counter person serves. Phones are not tied to a person or role — the
manager's phone may scan, a scanner may use a personal or a canteen phone.

## Decision

1. **One Firebase project, run by the app owner, config built into the app.**
   The "Connect Firebase" import step is removed.
2. **A canteen is a document, `canteens/{code}`; every existing collection
   moves under it.** `code` is a short random id that is also the join code
   and QR payload. `Store` is the only place that builds paths, so the move
   is one class plus the rules.
3. **A phone keeps a `CanteenBook`:** the canteens it has joined, which is
   active, and the saved logins per canteen. Switching the active canteen
   rebuilds the store/cache/backend providers; no restart.
4. **One Firebase identity per person/phone across all canteens;** a person's
   role in a canteen is `onlineUsers/{uid}` there. Sign-in methods: Google,
   Apple, Microsoft, email/password, phone; anonymous remains the temporary
   identity of a phone that has not signed in. Anonymous upgrades with
   `linkWithProvider`, keeping its uid.
5. **Devices and offline accounts are unchanged inside a canteen.** Rules
   cannot see which offline account holds a phone, so the device's role cap
   still bounds them; an admin on a shared phone signs in with an online
   identity.
6. **Taking over is a backup import into a newly created canteen.**

## Rejected

- *Phone-hosted server again (v2).* Single point of failure; see ADR 0005.
- *Bring-your-own project, scripted.* Creating a project, database and rules
  from a phone needs Google Cloud OAuth scopes and often billing; not one tap.
- *A second membership system replacing devices/offline accounts.* Offline
  shared-phone switching works today and is tested; replacing it buys nothing.
- *One Firebase app per canteen.* The default app cannot be re-pointed; paths
  under one project avoid the restart entirely.

## Consequences

- The app owner pays for, and is trusted by, every canteen. Rules must
  isolate canteens (tested on the emulator); App Check and a canteen-creation
  guard are required before a public release.
- Apple, Microsoft and phone sign-in each need external setup (paid Apple
  Developer account, Azure registration, APNs); they ship as separate phases.
- Existing data in a per-canteen project is not migrated (test data only at
  the time of writing).
