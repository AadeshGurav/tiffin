# ADR 0004 — Ingredient inventory, auto-consumption, and alerts

Status: accepted · 2026-09-09

Phase 2 of "track who eats what". Builds on ADR 0003 (member category,
per-category menu entries, per-plate recipes).

---

## 1. Ingredients carry stock; the Ingredients tab *is* the inventory

**Decision.** `ingredients` gains `stock_qty` (REAL, default 0) and
`low_stock_at` (REAL, nullable — null disables the alert). No separate
"inventory" screen: the Kitchen setup ▸ Ingredients tab shows the level and a
LOW badge, the form edits stock + threshold, and a per-row action does a
logged manual correction (`IngredientService.adjustStock`).

**Alternatives rejected.** A `stock_movements` ledger table — useful for an
audit trail, but more than a one-canteen tool needs right now; the app log
records each change.

## 2. Stock moves automatically, with manual correction always available

- **Up:** ticking a purchase-schedule item *purchased* now takes an **actual
  quantity** (→ `stock_qty`) and an optional **actual cost** (→ an `expenses`
  row, id stored on the item so un-ticking deletes it). `updateItem` does the
  stock/expense changes in one transaction and reverses them on un-tick.
- **Down:** an accepted scan consumes the matching menu entry's per-plate
  recipes from `stock_qty` (`scans.consumed_json` records exactly what, so a
  reversal restores it). Unambiguous because a scan resolves to one
  `(date, meal, member.category)` entry (ADR 0003 §1).
- Manual `adjustStock(id, delta, reason)` covers everything else.

Stock is allowed to go negative — an honest signal that the records are
behind, not a hard error.

## 3. Two alerts, on the existing notification poll

`NotificationService.generateDue` (already called on every `GET
/notifications`) gains:
- **low_stock** — one per ingredient at/under threshold, keyed
  `(low_stock, "ing-<id>", null)`, visible to admin + counter + **scanner**
  (whoever is serving needs to know). Also a banner on the scan screen.
- **headcount_overrun** — one per `(day, meal, category)` whose accepted
  scans have met/passed the planned headcount, keyed
  `(headcount_overrun, "<ymd>-<category>", <meal>)`, admin + counter. The
  scan result also carries `plannedCount`/`servedCount` for an inline note.

No new scheduled job; the upserts are idempotent.

## 4. Schema v8

All additive (`m.addColumn`): `ingredients.stock_qty`,
`ingredients.low_stock_at`; `purchase_schedule_items.purchased_qty`,
`.purchased_cost`, `.expense_id`; `scans.consumed_json`.
