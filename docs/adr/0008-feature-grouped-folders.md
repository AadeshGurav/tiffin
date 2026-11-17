# 0008 — Feature-grouped folders; tests mirror lib/

**Context.** `lib/ui/admin` held 19 screens and `lib/services` 19 services in one flat folder; `test/` was flat and did not match `lib/`.

**Decision.** Group admin screens and services by the same domains (`people`, `money`, `kitchen`, `menu`, `system`; services also `scanning`), move `xlsx_writer` to `core/`, and make `test/` mirror `lib/`. Pure moves, no behaviour change; imports rewritten by script.

**Alternatives rejected.** Full feature-first (`features/<x>/{ui,service,data}`): a much larger churn for a one-team app. Leaving flat: keeps growing.

**Consequences.** New files go in the matching domain folder; a test lives at the mirrored path of its subject.
