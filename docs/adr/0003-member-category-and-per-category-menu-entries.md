# ADR 0003 — Member category, per-category menu entries, per-plate recipes

Status: accepted · 2026-09-09

Phase 1 of the "track who eats what" work. Phase 2 (inventory columns,
auto-consume on scan, low-stock and headcount-overrun alerts) is a later
schema bump.

---

## 1. A menu entry is now one meal / one date / one category

**Context.** An entry was `(date, meal, categories[], items[])`. That can't
say how many Jain vs Normal plates, and if a Jain member scans it can't say
what a Jain plate contains. The client wants planned-vs-actual counts per
category and a purchase schedule scaled by real headcount.

**Decision.** One entry per `(date, meal, category)` (unique), carrying a
single `category`, an integer `headcount`, and the items one plate of that
category gets. A meal serving three groups is three entries.

**Alternatives rejected.**
- *`headcountByCategory` map on a shared entry.* Keeps the ambiguity about
  which items a given category's plate contains.
- *One entry per `(date, meal, category, dish)`.* Too granular — a plate is
  usually several items.

**Consequences.** Schema v7 rebuilds `menu_entries` and the `from6To7` step
fans each old row out into one row per category (`headcount = 0`,
`INSERT OR IGNORE` on the new unique key). `MenuService.addEntry` takes the
new draft and rejects a duplicate with a "edit it instead" conflict; a new
`updateEntry` (+ `PATCH /menu/<id>`) changes headcount/items.

## 2. Members carry a category; type is now editable

**Decision.** `members.category` (TEXT, default `'Normal'`), from the same
menu-category list, set at creation and editable. An accepted scan stamps
`scans.member_category` (as-of-scan, so a later category change doesn't
rewrite history). Student/staff `type` became editable too — converting one
clears the fields that don't apply to the new type.

**Consequences.** Additive columns in v7. `MemberPatch` gains `type` and
`category`. A shared `menuCategoriesProvider` feeds the member form and the
menu screen.

## 3. Recipe quantities are per plate; purchase = qty × headcount

**Decision.** The recipe line number (added in v6) is now defined as
**per plate / one serving**. No storage change — only the label and the
generation maths: `need per ingredient = Σ(per-plate qty) × headcount`,
summed per `(date, ingredient)`, rounded **up to 2 dp**. Re-running
recomputes un-purchased `auto` rows so a headcount edit updates the list;
purchased and `manual` rows are untouched.

**Consequences.** `PurchaseScheduleService.generate` rewritten to accumulate
into a `(date, ingredientId) -> double` map, then upsert. Entries with
`headcount <= 0` contribute nothing.
