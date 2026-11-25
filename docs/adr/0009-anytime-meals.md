# ADR 0009 — Anytime meals (admin-defined, no window, no daily lock)

Status: accepted · 2026-11-25

Extends PRD §5 ("three balances", "one scan per meal window") and §6.3–§6.8.
ADR 0005 (offline batches, increments, the lock-by-document-id) and ADR 0006
(one shared project, one rules file) stand unchanged.

---

## Context

The user asked for "meals that have no time limit or any other limit but can
be categorised and planned". Decided with the user:

- The admin creates them (Tea, Snacks, Juice...). Each has its **own unit
  balance** and its own unit price.
- A scan of one deducts **one unit of that meal**, at **any time**, and there
  is **no limit per day**. There is no one-scan-per-day lock.
- They are planned on the menu like the built-in meals: one entry per
  `(date, meal, category)`, with items and a headcount (ADR 0003).

Today a meal is the fixed enum `MealType {breakfast, lunch, brunch}`, and
three things are hard-coded around it: the clock (windows, the Saturday
brunch rule), the lock (`scans/{member}_{day}_{meal}`), and the money
(`UnitCounts` and the `lunchUnits/breakfastUnits/brunchUnits` fields on
top-ups and refunds, `UnitPrices`). Every stored meal reference is already a
string (`mealType: 'lunch'`); only the Dart side is closed.

Hard constraints: existing data and `.tiffin` backups must keep working with
no migration; phones on an older build will share the project for a while
(ADR 0006: one rules file for every canteen); scanning must keep working
offline.

---

## Decision

### 1. A meal is identified by a string id. The three built-ins keep theirs.

`'breakfast' | 'lunch' | 'brunch'` stay exactly as they are: timed, windowed,
locked once per day, Saturday rule, localised names. `MealType` keeps
meaning "a timed built-in meal" and the clock code (`meal_window.dart`, prep
reminders) does not change.

An anytime meal has a generated id matching `^m[a-z0-9]{8}$`. The prefix
means it can never collide with a built-in, and lowercase alphanumerics are
safe as a Firestore field-path segment (`balances.m3k9x2p7q`) and inside the
existing `_`-joined ids (`menu/{day}_{meal}_{category}`).

Every stored reference to "which meal" (`scans.mealType`, `menu.mealType`,
notification params) keeps its field name; the value is now any meal id.
On the Dart side these become `String` with a `MealType? timedMeal` helper,
and the name is looked up as: built-in → localised label; catalogue → the
admin's name; unknown → the raw id.

*Failure this answers:* `MealType.fromWire` throws on an unknown value. Left
as is, the scan log, report and menu screen would crash on the first Tea
scan, and on any backup that carries a meal this build has not seen.

### 2. The catalogue lives in the settings document

```
meta/settings.anytimeMeals: [
  { id: 'm3k9x2p7q', name: 'Tea', price: 10, active: true, group: 'Drinks' },
  ...
]
```

`group` is optional free text (absent or blank = no group). See §7.

A list, replaced whole by the admin's save, in display order. No `kind`
field: in this design every catalogue entry is anytime and every built-in is
timed. Add `kind` when someone needs a custom *timed* meal.

*Why settings:* it is already read on every scan, already cached by
`CacheWarmer`, already admin-write / everyone-read in the rules, already in
every backup, and already merged with defaults (a canteen that never saves
it reads `[]`). A new collection would need a rules block, a cache listener,
a backup entry and a second read on the scan path.

**Meals are retired, never deleted.** `SettingsService.update` refuses a
list that drops an existing id; `active: false` hides a meal from the
scanner, top-up and menu pickers, while balances, refunds and reports still
show it. *Failure this answers:* deleting "Tea" while members hold paid Tea
units would strand money that a refund could no longer find.

Validation (in `SettingsService.update`, like the meal windows): names
non-blank and unique ignoring case, price ≥ 0, ids well-formed and unique.

### 3. Balances: the member map just gains keys

`members/{id}.balances` is already a map. An anytime balance is another key:
`{lunch: 3, breakfast: 0, brunch: 0, m3k9x2p7q: 12}`. A missing key reads as
0, and `FieldValue.increment` on a missing field creates it, so **no existing
member document changes**.

`UnitCounts` keeps its three typed fields (and its `const` constructor, so no
call site changes) and gains `Map<String, int> anytime`, with
`operator [](String mealId)`, `byMeal` (every non-zero entry) and `+`.
`fromJson` puts any numeric key other than the three into `anytime`; `toJson`
writes all of them. `MemberService.balanceDelta` loops over `byMeal`.

### 4. Top-ups and refunds: built-ins stay flat, anytime units go in one map

```
topups/{id}:  lunchUnits, breakfastUnits, brunchUnits   (unchanged)
              anytimeUnits: { m3k9x2p7q: 5 }            (new, may be absent)
              balancesAfter: { ...all keys }            (already a map)
refunds/{id}: same pattern
```

The Dart models expose one `UnitCounts units`; only the JSON codec knows
about the split. Amount = Σ units × `settings.priceOf(mealId)` (built-in →
`unitPrices`, anytime → catalogue `price`), never typed in, as today.

*Failure this answers:* older builds read `j['lunchUnits'] as int`, which is
not nullable. Replacing the flat fields with a map would crash their top-up
history. Keeping them and adding one map means no data is stored twice and
old builds still read every record. They show a Tea-only top-up as 0/0/0
with the right amount, which is acceptable for a short rollout.

### 5. The scan: the operator picks an anytime meal on the scanner, and it stays picked

The scanner screen gets a **meal mode bar** at the bottom (thumb zone,
§11.6.5): `By time` (the default and today's behaviour) followed by each
active anytime meal. It only appears when the catalogue has an active meal,
so canteens that don't use the feature see no change. The choice is saved
**per phone** (next to the other per-phone preferences), so the tea counter
phone stays on Tea all afternoon, and it is always on screen (app-bar
subtitle and on every verdict: "Tea · 4 left").

`ScanService.processScan(qr, {mealTypeOverride, anytimeMealId})`. The new
parameter is additive (at most one of the two may be set). With an anytime
id, the order of checks is:

1. unknown code → reject; 2. inactive member → reject;
3. *(no window check)*; 4. *(no lock)*;
5. balance check, with the same grace rule as built-ins → reject when spent;
6. accept: one batch with the scan at an **auto id**, the
   `balances.<id>` decrement, the stock it uses, and `lastScanMeal`.

An anytime meal that is unknown or retired raises `ValidationException(unknownMeal)`.
The screen also drops a saved mode that is no longer active back to `By
time`, visibly, before any scan uses it.

Menu lookup, stock use and planned-vs-served headcount work unchanged with
the string id (`MenuService.entryId(day, mealId, category)`).
Reversal uses the same code path: archive a copy, delete the original,
restore the unit and stock.

*Failures this answers:* an extra tap per person (a pick-after-scan sheet)
slows exactly the queue this feature is for. A mode the operator can't see
would charge the wrong meal silently. Showing the mode on every verdict
makes a wrong pick obvious on the first scan.

**Offline:** anytime scans are plain batches with auto ids, so they work
offline and merge. Two phones can both serve the same person Tea, which is
what "unlimited" means. The cached-balance overspend that ADR 0005 accepted
applies here too. A refused anytime batch (only possible if the phone lost
its access) raises its own "scan not counted" notification. The existing
one says "already served", which is wrong for an anytime meal.

### 6. Rules: a scanner phone may lower exactly one balance, the one it names

Today a scanner-only phone may change `balances` as long as the three
built-in values don't rise. The rule doesn't look at other keys, so as
written it would let a scanner phone **credit itself Tea units**. Rules
can't loop over map keys, so the write names the meal it lowers:

```
function scanLowersOne() {
  let m = request.resource.data.lastScanMeal;
  return request.resource.data.balances.diff(resource.data.balances)
           .affectedKeys().hasOnly([m])
      && request.resource.data.balances[m] < resource.data.balances.get(m, 0);
}
// members update:
   isAdmin()
|| (isBilling() && onlyChanges(['balances', 'updatedAt', 'lastScanMeal']))
|| (isStaff()   && onlyChanges(['balances', 'updatedAt', 'lastScanMeal']) && scanLowersOne())
// pre-0009 builds: built-in keys only, none may rise. Remove once no old build scans.
|| (isStaff()   && onlyChanges(['balances', 'updatedAt'])
    && request.resource.data.balances.diff(resource.data.balances)
         .affectedKeys().hasOnly(['lunch', 'breakfast', 'brunch'])
    && <the three existing <= checks>)
```

New builds write `lastScanMeal` on **every** scan, timed or anytime, so a new
build has one way to scan. The `scans` rule does not change: the lock still
comes from the timed scan's id, and anytime scans use ids that never collide.

**Deploy order matters.** The rules must be live before any new build ships.
Under the old rules, `onlyChanges` refuses the new `lastScanMeal` field from
every role except admin.

### 7. Planning and categorising

The menu screen's meal dropdown lists the three built-ins plus the active
anytime meals. An entry is still one `(date, meal, category)` with items and
a headcount, so purchase-schedule generation, stock use on scan and the
headcount-overrun alert all work unchanged. Anytime meals can be planned on
any day (no Saturday rule). Prep reminders stay timed-only, because an
anytime meal has no start time to count down to.

"Categorised" means both (user decision, 2026-11-25):

- **Serving groups.** An anytime meal is planned per member category
  (Jain / Normal / Staff) exactly like a built-in (ADR 0003).
- **Meal groups.** Each catalogue entry has an optional `group` string
  (Drinks / Snacks / Desserts...). It is free text; the settings editor
  suggests the groups already in use so the admin doesn't type "Drink" and
  "Drinks". It only orders and labels: the scanner meal bar, the settings
  list and the report columns show meals grouped by it (ungrouped first,
  then groups in first-seen order). It has no effect on price, balance or
  scanning. Trimmed; compared ignoring case when grouping.

*Why a string on the entry and not a collection:* a group has no data of
its own (no price, no rules). A `mealGroups` collection would need its own
rules, cache, backup entry and a rename flow, for a label. Renaming a group
is editing the meals that carry it.

### 8. Reports and exports

The Balances, Top-ups and Refunds sheets get one column per catalogue meal,
retired ones included, after the three built-ins. The column set comes from
the catalogue, so every row has the same columns. Scans and Menu sheets name
the meal through the lookup in §1. The report stays export-only, as today.

---

## Alternatives rejected

- **Replace `MealType` with a sealed `Meal` (Timed | Anytime) everywhere.**
  Every switch would handle two cases, history with an unknown id would still
  need a third, and it touches every clock-rule call site, which this feature
  doesn't need.
- **A `meals` collection for the catalogue.** It needs a rules block, a cache
  listener, a backup entry and an extra read on the hot path, for a list of
  maybe five rows that only the admin edits.
- **`kind: timed | anytime` on catalogue entries (admin-defined timed meals).**
  Not asked for. It would need windows, locks and day rules for custom meals.
- **Turn `UnitCounts` into a bare `Map<String, int>`.** Every built-in call
  site would change (`UnitCounts(lunch: 2)`, `.lunch`, `const UnitCounts()`),
  including `refund_service.dart`, which another change is editing right now,
  for no behavioural gain.
- **A `units` map on top-ups and refunds that replaces the flat fields.**
  Older builds would crash reading history (§4). Writing both the map and
  the flat fields would store the same number twice.
- **Pick the meal after the scan (a bottom sheet).** One extra tap per
  person, at the counter where the queue is.
- **Infer the meal (e.g. the only anytime meal the member holds).** Implicit,
  and wrong the moment someone holds two.
- **Let only counter/admin phones serve anytime meals (no rules change).**
  The tea stall phone would have to be a top-up-capable phone, which breaks
  ADR 0005's "approve phones with the narrowest role".
- **Find the decremented key in rules via the scan document (`getAfter`).**
  It works, but costs an extra document read per scan and needs a scan-id
  pointer anyway. Naming the meal directly is enough, because the invariant is
  "a scanner phone only lowers one balance".
- **Hard-delete meals.** It strands paid units (§2).
- **A `mealGroups` collection (or a fixed group list).** A group is only a
  label; a collection costs rules, cache and backup for no behaviour (§7).

---

## Consequences and compatibility

- **No migration and no backup format bump.** Existing members, scans,
  top-ups, refunds, menu entries and settings read the same as before.
  `.tiffin` format 2 copies raw documents, so a new backup carries the
  catalogue and the anytime balances. A pre-0009 backup restores with an
  empty catalogue. `legacy_import.dart` (v1/v2 files) only ever had the three
  built-ins and is untouched.
- **Old builds sharing the project** keep working for built-in meals. They
  ignore `anytimeMeals`, the extra balance keys and `anytimeUnits`, and the
  legacy rules branch still accepts their scans. They cannot serve or credit
  anytime meals.
- **New app versions require the rules deploy first** (§6).
- **Grace** applies to anytime balances the same way as to built-ins: one
  balance rule (user decision, 2026-11-25). If a canteen wants no credit on
  Tea, make grace per-meal later.
- **Prices:** a top-up stores its computed amount, and a refund uses today's
  price, both as before.
- Cost: the meal name lookup needs the catalogue wherever a meal is shown
  (labels, report). It comes from the already-cached settings.

Implementation steps: `docs/plans/anytime-meals.md`.
