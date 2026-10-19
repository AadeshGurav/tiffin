# ADR 0002 — Kitchen setup consolidation and numeric recipe quantities

Status: accepted · 2026-09-08

Records the changes from the client-feedback pass that touched the kitchen
domain, so the structure and the schema v6 bump aren't relitigated.

---

## 1. Ingredients + Recipes folded into one "Kitchen setup" screen

**Context.** The client (the contractor who runs the canteen) said the
ingredients/recipes/purchase-schedule split was confusing — "I really don't
get it… we have purchase schedule that will set the ingredients available
right?" Three dashboard tiles for what is one setup job, done once.

**Decision.** Ingredients and Recipes become two tabs of a single
`KitchenSetupScreen`. The purchase schedule stays its own screen — it's a
recurring weekly task, not setup. The auto-generation chain (menu calendar +
recipes → schedule) is unchanged.

**Alternatives rejected.**
- *Drop Recipes; make the schedule fully manual.* Loses "generate the week's
  shopping from the menu", which is the feature's point.
- *Put the ingredient list on each menu entry.* Ties shopping data to the
  calendar and re-enters the same ingredients on every entry.
- *Leave three tiles.* Doesn't address the complaint.

**Consequences.** `IngredientsScreen`/`RecipesScreen` became body-only
`IngredientsTab`/`RecipesTab`; their add/edit forms are now top-level
`openIngredientForm` / `openRecipeForm` so the tab rows and the shared FAB
call the same code. Two dashboard tiles removed, one added.

## 2. Recipe lines carry a numeric quantity, not a free-text note

**Context.** A recipe line was `{ingredientId, quantityNote}` where the note
was free text ("2kg per 50 servings"). The client wanted to pick the unit and
type a number, not compose a sentence.

**Decision.** A line is `{ingredientId, quantity}` — a plain number. The unit
already lives on the `Ingredient`, so a line renders as "Rice — 2 kg". The
purchase schedule formats generated items the same way
(`"$quantity $unit"`); its own `quantity_note` column is unchanged and now
holds that formatted string (plus any free-text one-off items).

**Alternatives rejected.**
- *Keep the free-text note.* What the client asked us to move away from.
- *Add a numeric column to `purchase_schedule_items` too.* The schedule is a
  printed checklist — a formatted string is enough, and it avoids a
  table-rebuild migration.

**Consequences.** Schema v6: no column changes (recipe lines are a JSON
blob), but a data migration (`from5To6`) rewrites each blob, pulling the
leading number out of the old note and defaulting to 1. `RecipeIngredient.
fromJson` also tolerates the old shape as a safety net.
`migration_test.dart` covers the conversion; `host_server_test.dart` covers
the formatted schedule output.

## 3. Ingredient unit is a picked value, not raw text

**Context.** Free-text units fragment: "kg" / "Kg" / "kilo" become three
distinct units, and generated shopping lines then don't group.

**Decision.** `NbUnitField` — a dropdown of common units
(kg, g, litre, ml, pcs, packet, dozen, bunch, bottle, can, box) with a
"Custom…" escape hatch. No schema change; the column is still free text, the
UI just constrains what goes in.

## 4. Users & Hosting moved off the dashboard into Settings

Both are configuration, touched rarely. Hosting was already linked from
Settings (with a redundant tile); Users gets a row there too. Dashboard tiles
removed. No code beyond navigation.

## 5. Settings became a hub; Reports and Backup split apart

**Context.** `SettingsScreen` had grown to ~400 lines and one `ListView` with
~10 stacked sections plus a `Save` button stranded mid-scroll. "Reports &
backup" was a single screen doing two unrelated jobs (an export-only
spreadsheet for people, and a restore-capable machine backup).

**Decision.**
- Settings is now a short menu of `SettingsRow`s (icon, title, one-line
  description, chevron), grouped Canteen / This host / Device. The config
  form moved wholesale to `SettingsConfigScreen` with its `Save` pinned to a
  bottom bar.
- `ReportsScreen` keeps only the spreadsheet. `BackupScreen` is new and holds
  export + restore (and the typed-`REPLACE` confirm dialog). Both are rows
  under Settings ▸ *This host*; the dashboard's "Reports & backup" tile is
  gone.

**Alternatives rejected.**
- *Collapsible sections on one screen.* Still one giant file and one save
  scope; expand/collapse state is fiddly on a form.
- *Splitting the config form into four sub-screens.* Four save buttons or a
  shared draft object — more moving parts than the cramming was worth.

**Consequences.** Four files where there were two; each is well under the
size limit and single-purpose. No behaviour change to what any of the forms
do.

## 6. Two more dashboard tiles folded in

- **Top-up history** was its own tile opening its own screen. It's the same
  subject as taking a payment, so `TopUpScreen` is now a two-tab screen
  (Charge / History); the old `TopupHistoryScreen` became `TopupHistoryTab`
  (body only).
- **Menu categories** was a tile for a small CRUD list. Removed; reachable
  from the Menu calendar's app-bar (**⊞**) and from Settings ▸ Menu
  categories. Inline "New category" in the add-entry dialog already covered
  the common case.

The dashboard is down to eleven tiles, all daily-work destinations.
