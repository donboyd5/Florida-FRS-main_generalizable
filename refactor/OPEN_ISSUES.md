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

**Discovered:** During `retirees` adapter (Week 2)

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

**Deferred:** Must not change results until model structure is stable and all 160 tests pass.

---

## ISSUE 2: Single-year data format — pendata's responsibility

**Discovered:** Throughout Tier 1 adapter work (Week 2); refined as architectural vision

### Architecture decision (not yet implemented):

**penmodel should assume all input data is in single-year-of-age and
single-year-of-service format, with no missing years.** This is a simpler,
more uniform contract for model functions to work with.

**It is pendata's job** to convert grouped data from pension AVs (age bands,
yos bands) to single-year format before exposing it to penmodel. This conversion
must happen in pendata, not in penmodel adapters.

### Why this matters:
- AV sources present data in grouped bands (e.g., 5-year age bands, variable yos ranges)
- Band cutpoints differ across plans and across AVs for the same plan
- Simple uniform distribution within bands (e.g., equal value at each age 50–54)
  is often wrong — it ignores the true within-band distribution
- A proper conversion is an **optimization problem**: single-year values must
  simultaneously satisfy all known constraints (group sums, total sums, group
  averages for salary, etc.) while deviating as little as possible from a
  plausible actuarial distribution

### Current stopgap in penmodel adapters:
The adapter functions (`convert_retirees_to_legacy()`, etc.) currently hand-code
their own band-expansion logic as a temporary measure:
- `retirees` "Under 50" band (age_lb=18) maps to ages 45-49 only (minimum age cutoff)
- `retirees` "80 & Up" band uses hardcoded sub-band weights: 80-84=50%, 85-89=25%,
  90-94=12.5%, 95-99=2.5%, 100-120=10% — a legacy modeling artifact, not a data feature
- Band cutpoints differ across plans (FRS uses 5-year bands; other plans may differ)

These stopgaps are acceptable during the refactor but encode assumptions that belong
in pendata, not penmodel.

### When to implement:
**Deferred until after model structure is stable and all 160 tests pass.**
Any change to how grouped data is expanded to single-year values will change model
results and require updating test baselines. This should be a deliberate, coordinated
change in pendata with corresponding test updates in penmodel.

### Action needed (future):
1. Design the optimization approach in pendata for band-to-single-year conversion
2. Ensure the optimization hits all known targets (sums, averages, etc.)
3. Expose single-year data from pendata; remove expansion logic from penmodel adapters
4. Update penmodel test baselines after pendata is updated

---

## ISSUE 3: Class name inconsistency in amortization_bases

**Discovered:** `convert_amortization_to_legacy()` (Week 2)

**Observation:** The `amortization_bases` better structure uses `"senior management"`
(space) while all other better structures and all model code use `"senior_management"`
(underscore). The adapter patches this with `gsub(" ", "_", fixed=TRUE)`.

**Action needed:** Fix the source data in pendata's `amortization_bases` to use
`"senior_management"` (underscore), then remove the gsub patch from the adapter.
This is a pendata data quality issue. Low priority — fix when convenient.

---

## ISSUE 4: Salary growth rate transcription error (yos=7, regular class)

**Tracked in:** https://github.com/gchen3/Florida-FRS-main_generalizable/issues/6

**See also:** SESSION_NOTES.md, Data Discrepancy section

**Summary:** Legacy `Florida FRS inputs.xlsx` has 4.4% at yos=7 regular; authoritative
source (Milliman AV2022 p.A-22) and pendata both have the correct value 4.5%.
A deliberate backward-compat patch in `convert_salarygrowth_to_legacy()` preserves
the error temporarily. See issue #6 for full details and resolution steps.

---

## Future Design Questions (no action yet)

- **Multi-plan generalization:** When a second plan is added to pendata, its grouped data
  (age/yos bands) may use different cutpoints than FRS. The optimization approach for
  band-to-single-year conversion (Issue 2) must be plan-aware.

- **Adapter removal strategy:** The long-term goal is to refactor model functions to
  consume better structures directly (no adapters needed once pendata provides single-year
  data). Likely sequence: funding model first (simplest), then liability, then workforce.
