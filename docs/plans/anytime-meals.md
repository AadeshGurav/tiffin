# Plan — Anytime meals (ADR 0009)

Each step is one commit. Each one leaves the app building, `flutter test`
green, and current behaviour unchanged unless the step says otherwise. Tests
live at the path that mirrors their subject (ADR 0008). New strings go into
all three ARB files (`en`, `hi`, `mr`); `test/l10n/l10n_parity_test.dart`
enforces this.

## Order and lanes

```
S1 rules ───────────────────────────────────────────────┐ (deploy before any release)
S2 catalogue ─┬─ S7 settings UI                          │
S3 balances ──┤                                          │
S4 meal ids ──┴─ S5 scan service ── S6 scanner UI        │
              ├─ S8 top-up service ── S9 top-up/bill UI  │
              ├─ S10 menu UI                             │
              └─ S11 reports (after S8)                  │
S12 refunds (after S2, S3, and after the ledger agent's refund work is merged)
S13 docs + graphify (last)
```

- **Parallel:** S1 runs alongside anything. S2, S3 and S4 touch different
  files and can be written in parallel, but they merge in order S2 → S3 → S4.
  Once S2–S4 are in, S5, S7, S8 and S10 can run in parallel. S6 follows S5,
  S9 follows S8, and S11 follows S8.
- **Wait for the ledger agent:** S12 is the only step that touches
  `lib/services/money/refund_service.dart`, `lib/ui/admin/people/refunds_screen.dart`
  and the `Refund*` classes in `lib/domain/ledger.dart`. Start it only after
  the ledger agent's refund fix is on `main`, then rebase. S3 keeps the
  `UnitCounts` constructor exactly as it is, so the steps before S12 never
  touch the refund code.

---

## S1 — Rules: a scanner phone lowers only the one balance it names

- `firestore.rules`: `members` update as in ADR 0009 §6. Add `lastScanMeal`
  to the billing and staff `onlyChanges` lists and add `scanLowersOne()`.
  Tighten the legacy branch with `affectedKeys().hasOnly(['lunch','breakfast','brunch'])`,
  and mark that branch for removal once no pre-0009 build scans. Update the
  `scans` comment: anytime scans use auto ids, and the lock is only on timed
  ids.
- `tool/rules-test/rules.test.js`, new cases:
  - a scanner lowers `balances.mtea00001` by 1 with `lastScanMeal: 'mtea00001'`: allowed
  - a scanner raises an anytime balance (with or without `lastScanMeal`): refused
  - a scanner lowers two keys in one write, or a key other than `lastScanMeal`: refused
  - a scanner lowers a key that didn't exist before (grace, so it goes to -1): allowed
  - a pre-0009-shaped scan (lunch −1, no `lastScanMeal`): still allowed
  - a pre-0009-shaped write that also touches an anytime key: refused
  - a counter phone credits an anytime balance: allowed
- **Risk:** this is one rules file for every canteen (ADR 0006). Run the
  emulator suite, then deploy. It must be live before S5 ships to any phone
  (ADR 0009 §6, deploy order).

## S2 — The catalogue in settings

- `lib/domain/settings.dart`: `AnytimeMeal {id, name, price, active}`,
  `SettingsSnapshot.anytimeMeals` (default `const []`), `priceOf(String mealId)`,
  `anytimeMeal(String id)`, `activeAnytimeMeals`.
- `lib/services/system/settings_service.dart`: `SettingsPatch.anytimeMeals`
  (replaces the whole list) and validation: blank or duplicate name, bad or
  duplicate id, negative price, and **removing an existing id** (retire
  instead). Add `static String newAnytimeMealId()` (`m` + 8 of `[a-z0-9]`).
- `lib/core/errors.dart` + ARB: the new codes (`mealNameBlank`,
  `mealNameTaken`, `mealCannotBeRemoved`, `unknownMeal`).
- `lib/core/meal_type.dart`: `static MealType? tryWire(String)`.
- Test `test/services/system/settings_service_test.dart`: each validation
  branch, retiring allowed, defaults read `[]` when the document lacks the key,
  and `priceOf` for built-in, anytime and unknown ids.

## S3 — Balances carry anytime keys

- `lib/domain/member.dart`: `UnitCounts` gains `anytime` (`const {}`
  default), `operator []`, `byMeal`, `+`, `single(String mealId)`, and
  `isAllZero` that covers the map. `fromJson` puts any unrecognised numeric
  key into `anytime`, and `toJson` writes it back.
- `lib/services/people/member_service.dart`: `balanceDelta` loops over `byMeal`.
- Tests:
  - `test/domain/member_test.dart`: an old `{lunch, breakfast, brunch}`
    document reads exactly as before, an anytime key round-trips, a missing
    key reads 0, and `+` adds both the built-ins and the map.
  - `test/data/backup_test.dart` (one added case): a backup holding a
    catalogue and an anytime balance restores both, and a pre-0009 fixture
    still restores. No change to `backup_service.dart`.

## S4 — Meal references become string ids (no behaviour change)

- `lib/domain/menu.dart`: `MenuEntry`/`MenuEntryDraft` `mealType` →
  `String meal` (JSON key stays `mealType`).
- `lib/domain/ledger.dart`: `ScanResult.mealType`, `ScanRecord.mealType`,
  `ReversalResult.mealType` → `String? meal` / `String meal`. Touch only the
  scan classes, not the `Refund*` ones.
- `lib/l10n/labels.dart`: `mealName(String id, List<AnytimeMeal> catalogue)`.
  It returns the built-in label, then the catalogue name, then the raw id.
  Replace `mealLabel(MealType)` call sites with it.
- Mechanical call-site updates: `lib/services/scanning/scan_service.dart`
  (`reverseScan`'s `fromWire`), `lib/services/kitchen/menu_service.dart`
  (`entryId(String day, String meal, ...)`),
  `lib/services/system/notification_service.dart`
  (`raiseScanRejectedOnSync({String meal})`), `lib/l10n/messages.dart`,
  `lib/ui/admin/system/scan_log_screen.dart`, `lib/ui/admin/menu/menu_screen.dart`,
  `lib/services/money/report_service.dart`, and `test/support/fake_backend.dart`
  if it builds these models.
- Test `test/domain/ledger_test.dart` (or a new `test/domain/scan_record_test.dart`
  to stay clear of the ledger agent): a `ScanRecord`/`MenuEntry` with an
  unknown meal id parses, and `mealName` falls back to the id.
- **Risk:** this step touches the most files. It is still a rename with no
  logic change, so a green suite plus the analyzer is the proof.

## S5 — Scan service: the anytime path

- `lib/services/scanning/scan_service.dart`: add `processScan(..., {String? anytimeMealId})`,
  which asserts it is not combined with `mealTypeOverride`. The anytime path
  checks unknown or inactive meals, skips the window and the lock, applies
  the same balance and grace check, and commits one batch: the scan at
  `_store.newId(Col.scans)`, `balanceDelta(UnitCounts.single(id), sign: -1)`,
  the stock used, and `lastScanMeal`. Timed scans also write `lastScanMeal`.
  The `onRejected` handler on the anytime path raises
  `raiseAnytimeScanRejectedOnSync` (a new type with its own copy). The
  ADR 0005 doc comment on the class gets one paragraph on anytime scans.
- `lib/services/system/notification_service.dart` + ARB: the new
  notification type.
- `lib/data/backend.dart`: pass `anytimeMealId` through `scan()`.
- Test `test/services/scanning/anytime_scan_test.dart` (a new file, so it
  doesn't collide with `ledger_test.dart`):
  - three scans of the same meal on the same day are all accepted, with the
    balance falling by 3
  - a scan outside every window, and on a Saturday, is accepted
  - a spent balance is rejected, and grace allows exactly the configured
    negative
  - an unknown or retired meal throws `unknownMeal`
  - reversing an anytime scan puts the unit and stock back
  - a lunch scan after a Tea scan still holds the once-a-day lunch lock
  - the menu entry for `(today, tea, category)` drives stock use and the
    planned/served counts
  - the member document carries `lastScanMeal`

## S6 — Scanner screen: the meal mode bar

- `lib/ui/scanner/scanner_screen.dart`: a bottom mode bar (`By time` plus the
  active anytime meals), shown only when there is at least one. Touch targets
  are 48px or more, with safe-area padding (§11.6.4–5). Show the mode in the
  app-bar subtitle, and on the verdict as name plus remaining balance. A
  saved mode that is no longer active resets to `By time` with a snackbar. If
  the file grows past about 300 lines (§5), move the bar into
  `lib/ui/scanner/meal_mode_bar.dart`.
- Per-phone persistence of the mode: next to the existing per-phone
  preferences, `lib/app/session_memory.dart` or its prefs store, keyed by
  canteen.
- ARB strings for the bar, the subtitle and the reset notice.
- Test `test/ui/scanner/meal_mode_bar_test.dart`: hidden with no catalogue,
  the selection is passed to `scan()`, and a retired saved mode resets.

## S7 — Settings: manage anytime meals

- A new `lib/ui/admin/system/anytime_meals_section.dart`, used from
  `settings_config_screen.dart` (which is already 227 lines). The section
  lists the meals with name, price and an active switch, and has an "Add
  meal" button. There is no delete button, only Retire, with copy explaining
  that balances are kept.
- ARB strings.
- Test `test/ui/admin/system/anytime_meals_section_test.dart`: add, rename
  and retire produce the expected `SettingsPatch.anytimeMeals`.

## S8 — Top-ups with anytime units

- `lib/domain/ledger.dart` (`Topup`, `TopupDraft` only): add `anytimeUnits`
  (wire key `anytimeUnits`, absent reads as `{}`) and `UnitCounts get units`.
- `lib/services/money/topup_service.dart`: compute the amount with
  `priceOf`, reject unknown or retired ids (`unknownMeal`), set
  `balancesAfter = balances + units`, and make the reversal's "units already
  spent" check loop over `units.byMeal`.
- `lib/data/backend.dart`: map the draft through.
- Tests in a new `test/services/money/topup_service_test.dart`:
  - the amount includes the anytime price
  - reversal is refused once an anytime unit has been spent
  - a pre-0009 top-up document (with no `anytimeUnits`) still parses
  - the new document still carries the three flat fields

## S9 — Top-up, bill, history and members UI

- `lib/ui/admin/people/topup_screen.dart`: a unit row per active anytime
  meal, labelled with its price, after the three built-ins. The submit button
  is enabled as soon as any meal has units.
- `lib/ui/admin/money/bill_view.dart`: one line per non-zero meal, for both
  the units bought and `balancesAfter`. The current fixed three-line string
  goes away.
- `lib/ui/admin/people/topup_history_screen.dart` and
  `lib/ui/admin/people/members_screen.dart` (the balances summary): include
  any non-zero anytime balances.
- ARB strings. Widget test for the bill lines.

## S10 — Menu planning

- `lib/ui/admin/menu/menu_screen.dart`: the meal dropdown offers the three
  built-ins plus the active anytime meals. Day tags use `mealName`, and
  anytime meals get a neutral token colour (today's colour comes from a
  `switch` on `MealType`). Existing entries for retired meals still show.
- Test: a widget test or a `menu_service` test showing that an entry for an
  anytime meal can be added and that `entryId` is unique per meal.

## S11 — Report columns

- `lib/services/money/report_service.dart`: the Balances and Top-ups sheets
  add one column per catalogue meal (retired ones included), and the totals
  include them. The Refunds sheet's columns wait for S12, which owns the
  `Refund` model.
- Test `test/services/money/report_service_test.dart`: with a two-meal
  catalogue, the headers and a row line up.

## S12 — Refunds with anytime units (after the ledger agent)

- `lib/domain/ledger.dart` (`Refund`, `RefundDraft`): the same pattern as S8.
- `lib/services/money/refund_service.dart`: the over-refund check and the
  amount loop over `units.byMeal`, and unknown ids are rejected.
- `lib/ui/admin/people/refunds_screen.dart`: a row per anytime meal the
  member holds (active or retired), pre-filled with and capped at the
  balance, as PRD §6.7 already says for built-ins.
- `lib/services/money/report_service.dart`: the Refunds sheet columns (from
  S11).
- Tests: a refund of anytime units, an over-refund refused, a retired meal
  still refundable, and an old refund document still parses.

## S13 — Docs and code map

- `docs/PRD.md`: §5 (Unit — "three built-in balances plus admin-defined
  anytime meals", and the lock applies to timed meals only), §6.3, §6.4 (the
  mode bar, and the order of checks for anytime), §6.5, §6.7, §6.8 (the
  catalogue), §8.
- `docs/USER_GUIDE.md`: how to add Tea, put a phone in Tea mode, top up, and
  refund. `docs/DEVELOPER_GUIDE.md`: meal ids and `UnitCounts.anytime`.
- Set ADR 0009's status to `accepted`.
- `graphify . --update`, committed with the docs (user standard §19.1).

---

## Risks

- **Rules before release.** If S5 ships before S1 is deployed, every scan is
  refused (`lastScanMeal` fails `onlyChanges`). Put the rules deploy in the
  release checklist.
- **Old builds during the rollout** can't serve or credit anytime meals, and
  they show Tea-only top-ups as 0/0/0. That is acceptable. Remove the legacy
  rules branch in a later change, once every phone has updated.
- **Field-path safety:** an anytime id is used as `balances.<id>`. The id
  regex is checked in `SettingsService` and is the only gate, so never accept
  a meal id from anywhere else (an import, a URL) without that check.
- **Refund conflict:** described under S12. S3 deliberately leaves the
  `UnitCounts(lunch:, breakfast:, brunch:)` constructor unchanged.
- **Scanner mode mis-set:** a phone left on Tea charges Tea during lunch.
  The mitigations are the mode shown on every verdict and the always-visible
  subtitle. If it happens in practice, add an automatic return to `By time`
  when a timed window opens.
