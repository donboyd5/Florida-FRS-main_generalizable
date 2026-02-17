# Open Issues and Design Questions

This file tracks architectural decisions, data conventions, and questions that
need resolution but are deferred while penmodel-only changes are in progress.
Items here are NOT bugs — they are known design trade-offs or future work.

**Terminology note:**
- **AV** = Actuarial Valuation — the annual report produced by the plan's actuary
  (e.g., Milliman). All FRS source data traces back to the AV.
- **pendata** = the R package/project storing FRS (and eventually other plans') input data
- **penmodel** = this repo (`Florida-FRS-main_generalizable`), the pension model

---

## ISSUE 1: Dollar unit convention in pendata

**Discovered:** During `retirees` adapter (Week 2/3)

**Observation:** The `retirees` better structure stores `benefits` in **thousands of dollars**,
matching the AV source table which presents figures in thousands. This required a ×1000
conversion in `convert_retirees_to_legacy()`.

**Problem:** penmodel currently assumes some amounts are in dollars and some in thousands
depending on which table. This is fragile and error-prone, especially as new plans are added.

**Proposed convention (not yet decided):**
- pendata stores **all dollar amounts in actual dollars** (not thousands)
- penmodel always assumes dollar amounts are in dollars, never thousands
- This would require updating `retirees` in pendata (×1000 the benefits column)
  and removing the ×1000 conversion from the adapter

**Scope of change:** pendata change only — the adapter in penmodel would simplify.
Affects at least: `retirees$benefits`, possibly other pendata tables.

**Action needed:** Audit all dollar-amount columns across all better structures in pendata;
establish and document a universal unit convention before adding more plans.

---

## ISSUE 2: Grouped-to-point-value expansion utility

**Discovered:** Throughout Tier 1 adapter work (Week 2/3)

**Observation:** The better pendata structures use range-based age/yos bands
(e.g., age_lb/age_ub, yos_lb/yos_ub). The legacy model uses point values (one row per age
or yos). Each adapter currently hand-codes its own expansion logic.

**Complications observed so far:**
- The `retirees` "Under 50" band (age_lb=18) had to map to ages 45-49, not 18-49,
  because the legacy model's minimum retiree age is 45
- The `retirees` "80 & Up" band required hardcoded sub-band weights (50/25/12.5/2.5/10%)
  because pendata correctly aggregates but the legacy distributes within the band
- Band cutpoints will likely differ across plans (FRS uses 5-year bands, another plan
  might use decennial or irregular bands)

**Proposed direction:**
A general `expand_age_bands()` or `expand_yos_bands()` utility that:
- Takes a range-based tibble and a target age/yos sequence
- Distributes values evenly within each band by default
- Allows custom per-band distribution weights as an override
- Handles edge cases (open-ended top band, minimum age cutoffs)

**Benefit:** Would simplify all adapters and make the pattern explicit and testable.
Would also help when penmodel functions are eventually refactored to consume better
structures directly (removing the need for adapters altogether).

**Action needed:** Design the utility interface. Consider where it lives
(pentools? a new penmodel utility file?). Do not implement until adapter pattern
is no longer needed (i.e., when model functions consume better structures directly).

---

## ISSUE 3: Hardcoded 80+ sub-band distribution weights in retirees adapter

**Discovered:** `convert_retirees_to_legacy()` (Week 3)

**Observation:** The legacy `retiree_distribution` distributes the "80 & Up" retiree
population across ages 80-120 using weights (50/25/12.5/2.5/10%) that were baked into
the original Reason model. The pendata `retirees` better structure correctly stores a
single "80 & Up" band — the sub-band distribution is a legacy modeling artifact, not a
data feature.

**Risk:** If the plan updates its actuarial methods and changes how 80+ retirees are
distributed, the hardcoded weights in the adapter would silently produce wrong results.

**Action needed:** When model functions are eventually refactored to consume `retirees`
directly, the 80+ sub-band weights become irrelevant (the model would just use age bands).
Until then, the hardcoded weights are documented in `convert_retirees_to_legacy()`.
Low priority — remove when adapter is removed.

---

## ISSUE 4: Class name inconsistency in amortization_bases

**Discovered:** `convert_amortization_to_legacy()` (Week 2)

**Observation:** The `amortization_bases` better structure uses `"senior management"`
(space) while all other better structures and all model code use `"senior_management"`
(underscore). The adapter patches this with `gsub(" ", "_", fixed=TRUE)`.

**Action needed:** Fix the source data in pendata's `amortization_bases` to use
`"senior_management"` (underscore), then remove the gsub patch from the adapter.
This is a pendata data quality issue. Low priority — fix when convenient.

---

## ISSUE 5: Salary growth rate transcription error (yos=7, regular class)

**Tracked in:** https://github.com/gchen3/Florida-FRS-main_generalizable/issues/6

**See also:** SESSION_NOTES.md, Data Discrepancy section

**Summary:** Legacy `Florida FRS inputs.xlsx` has 4.4% at yos=7 regular; authoritative
source (Milliman AV2022 p.A-22) and pendata both have the correct value 4.5%.
A deliberate backward-compat patch in `convert_salarygrowth_to_legacy()` preserves
the error temporarily. See issue #6 for full details and resolution steps.

---

## Future Design Questions (no action yet)

- **Multi-plan generalization:** When a second plan is added to pendata, will its better
  structures use the same age/yos band cutpoints as FRS? If not, adapters will need to
  be plan-aware, not hardcoded.

- **Adapter removal strategy:** The long-term goal is to refactor model functions to
  consume better structures directly (no adapters). What is the right sequence? Probably:
  fund model functions first (simpler), then liability, then workforce (most complex).

- **pentools role:** Should the grouped-to-point-value utility (Issue 2) live in pentools
  (shared across plans/models) or in penmodel (specific to this model's needs)?
