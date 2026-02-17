# Session Notes - FRS Pension Model Rationalization

**Last Updated**: 2026-02-17 (Week 3 Tier 2 Migration COMPLETE ✓)
**Current Status**: Week 1 COMPLETE ✓ | Week 2 Tier 1 Migration COMPLETE ✓ | Week 3 Partial: 4/5 Tier 2 tables migrated (160/160 tests pass)

---

## Naming Convention and Key Terms

- **pendata** — the R package/project at `D:\R_projects\pendata` that stores all FRS input data
- **penmodel** — short name for this repo (`Florida-FRS-main_generalizable`), the pension model itself
- **AV** — Actuarial Valuation, the annual report produced by the plan's actuary (Milliman for FRS).
  All FRS source data traces back to the AV. When a file or table cites "AV2022" it means the
  July 1, 2022 actuarial valuation.

## Open Issues / Design Questions

See [`OPEN_ISSUES.md`](OPEN_ISSUES.md) for a tracked list of architectural decisions and
design questions that are deferred while penmodel-only changes are in progress. Key items:

1. Dollar unit convention in pendata (`benefits` in retirees is in thousands — needs resolution)
2. Single-year data format — pendata's responsibility (merged from old issues 2 & 3)
3. Class name inconsistency in `amortization_bases` ("senior management" vs "senior_management")
4. Salary growth rate error yos=7 regular (tracked in upstream issue #6)
5. **`benefit_rules` data quality in pendata** (discovered Week 3, see OPEN_ISSUES.md for full details):
   - tier_2 multipliers incomplete/wrong for regular, admin, special classes
   - tier_3 missing entirely for all 7 classes
   - tier_1 has slight overlap-join discrepancy (~8.8e-6 relative); needs sentinel fix review

---

## Quick Resume Guide

**If starting a new Claude session**, read these files in order:
1. This file (SESSION_NOTES.md) - current status and all key findings
2. `OPEN_ISSUES.md` - deferred issues and pendata data quality problems
3. `pension_model_analysis.qmd` - overall plan and architecture (if deeper context needed)
4. `data_structure_mapping_VERIFIED.md` - Week 1 results (reference only)

**Current state (2026-02-17 end of session)**:
- 160/160 tests pass
- Week 2 Tier 1 (3 tables) + Week 3 Tier 2 (4 computed tables) migrated
- `ben_mult_lookup` migration blocked on pendata data quality (see OPEN_ISSUES #5)
- Next: fix pendata `benefit_rules`, then investigate `tier_table` in pendata

Then say: *"I see we're at Week 3, 160/160 tests pass. The next priority is fixing pendata's benefit_rules (tier_2/tier_3 completeness) to unblock ben_mult_lookup migration."*

---

## Current Status: Week 1 COMPLETE ✓

### What We Accomplished (2026-02-16):

1. ✅ **Analyzed model architecture** - 4 main components (Benefit, Workforce, Liability, Funding)
2. ✅ **Explored pendata dual structure** - Found 188 objects in params_env
3. ✅ **Explored pentools** - 19 general-purpose actuarial functions
4. ✅ **Created comprehensive inventory** - 91 unique params objects, 800+ references
5. ✅ **Verified better structures exist** - 11 better structures ready!
6. ✅ **Identified actual gaps** - Only 1 real gap (mortality tables, deferred)

### Key Discovery:

**Of 5 initially suspected gaps, only 1 is real!**
- ✅ 11 better structures exist in pendata
- ⚠️ Only mortality tables need optimization (defer to Phase 2-3)
- 🎉 Migration can start immediately!

### Documents Created:

| File | Purpose | Status |
|------|---------|--------|
| `pension_model_analysis.qmd` | Master analysis & plan | ✅ Complete |
| `data_structure_mapping_VERIFIED.md` | Week 1 verified mapping | ✅ Complete |
| `explore_pendata.R` | Script to explore pendata | ✅ Helper |
| `check_table_structures.R` | Verify table schemas | ✅ Helper |

---

## Week 2: Tier 1 Migration — COMPLETE ✓

### What We Accomplished (2026-02-16):

1. ✅ **Created helper functions** ([FRS_helper_functions.R](R/FRS_helper_functions.R)):
   - `get_constant()` - Access constants from constants_assumptions_tbl
   - `validate_better_structure()` - Schema validation
   - `get_better_table_name()` - Map legacy to better structure names

2. ✅ **Created adapter functions (Option A approach)**:
   - `convert_salarygrowth_to_legacy()` - Converts range-based salary growth to cumulative products
   - `convert_amortization_to_legacy()` - Handles type/class-name normalization for amortization

3. ✅ **Migrated 3 Tier 1 tables**:
   - ✅ `salary_growth_table` ← `salarygrowth` (better structure)
   - ✅ `current_amort_layers_table` ← `amortization_bases` (better structure)
   - ✅ `retiree_distribution` ← `retirees` (better structure, done as Option C bonus before Week 3)

4. ✅ **Integrated adapters into workflow** ([FRS_new_workflow.R](R/FRS_new_workflow.R))

5. ✅ **Full model run: 160/160 tests pass** — exact match with legacy baseline

6. ✅ **Data discrepancy investigated and resolved** (see below)

### Key Discovery: Better structures are NOT drop-in replacements

- Better structures use **range-based** age/yos (age_lb/ub, yos_lb/ub)
- Legacy uses **point values** (age, yos)
- Better structures often lack year-based columns (entry_year, term_year)
- **Solution**: Adapter functions convert better → legacy format (Option A)

### Bugs Fixed in Adapters

| Bug | Symptom | Fix |
|-----|---------|-----|
| `cumprod` off-by-one | cumprod=1.037 at yos=0 instead of 1.0 | `c(1.0, cumprod(1+rates[-length(rates)]))` |
| `amo_period` type mismatch | integer vs character "n/a" | `as.character()` + NA→"n/a" |
| Class name `"senior management"` | 0 rows matched for senior_management | `gsub(" ", "_", result$class)` |

### Data Discrepancy: salary growth yos=7 regular (IMPORTANT)

**Summary**: A transcription error exists in the legacy input file. pendata has the correct value.

| Source | yos=7 Regular | Status |
|--------|---------------|--------|
| Milliman AV2022 p.A-22 (authoritative PDF) | **0.045** | ✅ Correct |
| `frs_extracted_data_v6.xlsm` → pendata `salarygrowth` | **0.045** | ✅ Correct |
| `Florida FRS inputs.xlsx` sheet "Salary Growth" | **0.044** | ❌ Transcription error |

**Authoritative source**: `refactor/source_data/Reports/Florida FRS Valuation 2022.pdf`, page A-22
(Table: "Individual Member Salary Increase Assumptions, Based on 2.40% inflation assumption")

**Resolution**: In `convert_salarygrowth_to_legacy()`, a deliberate backward-compat patch
overrides the correct pendata value (0.045) with the legacy error (0.044) at yos=7, regular class.
This preserves exact backward compatibility during the refactor.

- The patch has a prominent 15-line TODO comment block with issue reference
- **pendata was NOT modified** — it retains the correct value (0.045)
- Tracked in: **https://github.com/gchen3/Florida-FRS-main_generalizable/issues/6**
- To remove eventually: delete the TODO block in `convert_salarygrowth_to_legacy()`,
  then update the test baseline (~0.096% change in `baseline_funding` for regular class)

### Tier 1 Table Migration Status

| Table | Better Structure | Status | Notes |
|-------|-----------------|--------|-------|
| `salary_growth_table` | `salarygrowth` | ✅ Done | Backward-compat patch for yos=7 (issue #6) |
| `current_amort_layers_table` | `amortization_bases` | ✅ Done | Type + class-name fixes |
| `retiree_distribution` | `retirees` | ✅ Done | 80+ band split weights hardcoded |
| `salary_headcount_table` | `headcount_salary` | ⏸ Deferred | Needs entry_year generation + range expansion |
| `separation_rate_table` | `withdrawal` | ⏸ Deferred | 362K→3K row inversion, complex |

#### retirees adapter key notes:
- Better structure has 2 types (disability, normearly) combined into one total per age band
- `benefits` column in better structure is in **thousands of dollars** (×1000 for legacy)
- "Under 50" band (age_lb=18) maps to **ages 45–49 only** (legacy minimum retiree age = 45)
- "80 & Up" band splits into 5 legacy sub-bands with **hardcoded weights**: 80-84=50%, 85-89=25%, 90-94=12.5%, 95-99=2.5%, 100-120=10%

---

## Week 3: Tier 2 Migration — PARTIALLY COMPLETE ✓

### What We Accomplished (2026-02-17):

1. ✅ **Written `convert_benefit_rules_to_legacy()` adapter** in FRS_helper_functions.R
   - Expands non-early tiers to 3 status suffixes (_norm, _vested, _non_vested)
   - Converts sentinel values (model max → 9999 for unbounded ranges)
   - slice_max fix in `get_benefit_table_s` for overlapping benefit_rules conditions

2. ✅ **Built 4 computed lookup tables from pendata constants** (all 160 tests pass):
   - `dr_lookup` ← `constants_assumptions_tbl` (dr_current_, dr_new_)
   - `fas_period_lookup` ← plan provisions (tier_1=5yr, others=8yr)
   - `reduce_factor_lookup` ← plan provisions with _norm→1, _early→formula, _vested/_non_vested→NA
   - `cola_lookup` ← `constants_assumptions_tbl` (4 COLA constants)

3. ⚠️ **ben_mult_lookup: deferred** — `benefit_rules` in pendata has data quality issues:
   - tier_1: slight join-overlap discrepancy (8.8e-6 relative difference)
   - tier_2: wrong/incomplete multipliers for regular/admin/special classes
   - tier_3: missing entirely for all 7 classes
   - Currently using full legacy ben_mult_lookup unchanged (adapter code is ready)
   - See OPEN_ISSUES.md #5 for full details

4. ✅ **Documented all pendata data quality issues** in OPEN_ISSUES.md

5. ✅ **160/160 tests pass** with all Tier 2 changes

### Key Discovery: Rscript Execution Requirements

- **Personal library path**: `C:/Users/Don-business/R/win-library/4.5`
- `--vanilla` flag causes segfaults when loading packages (avoids .Rprofile)
- Use `Rscript` without `--vanilla` and ensure .Rprofile sets library path
- For standalone scripts: add `.libPaths("C:/Users/Don-business/R/win-library/4.5")` as first line
- **SEGFAULT RISK**: Loading `pendata::frs$params_env` in non-interactive R segfaults (16M-row mort_table). Use `load("D:/R_projects/pendata/data/frs.rda")` ONLY loads the full object — also segfaults! Use staged files: `readRDS("D:/R_projects/pendata/data-raw/plans/frs/staged_data/benefit_rules.rds")` or Gang's `load("D:/R_projects/pendata/data-raw/gang/frs_data_env_bf_cal.RData")` instead.

### Tier 2 Table Migration Status

| Table | Better Structure | Status | Notes |
|-------|-----------------|--------|-------|
| `dr_lookup` | `constants_assumptions_tbl` | ✅ Done | Pure formula; 0 mismatches |
| `fas_period_lookup` | Plan provision | ✅ Done | tier_1=5yr, others=8yr |
| `reduce_factor_lookup` | Plan provisions | ✅ Done | _norm→1, _early→formula, _vested/_non_vested→NA |
| `cola_lookup` | `constants_assumptions_tbl` | ✅ Done | 4 COLA constants, 0 mismatches |
| `ben_mult_lookup` | `benefit_rules` | ⚠️ Deferred | pendata data quality issues (see OPEN_ISSUES #5) |

### Week 4 Preview:
- Fix pendata `benefit_rules` data quality issues (tier_2 completeness, tier_3 missing)
- Then activate `convert_benefit_rules_to_legacy()` adapter in FRS_new_workflow.R
- Investigate `tier_table` (the 6th remaining legacy lookup) — trace data source in pendata

---

## Important Context

### Decisions Made:

1. **Focus**: Phase 1 first (data migration)
2. **Scope**: DB plans only initially
3. **Backward compatibility**: Yes, unless errors found
4. **Data source**: pendata only
5. **Performance**: Get generality right, then optimize
6. **User preference**: When presenting choices, use letter identifiers (A, B, ...) for easy response

### Key Files in This Repo:

```
refactor/
├── R/
│   ├── FRS_new_workflow.R                        # Main orchestrator (Tier 1+2 migration wired here)
│   ├── FRS_helper_functions.R                    # All adapter/builder functions (Week 2-3 work)
│   ├── FRS_benefit_model_functions.R             # Benefit calcs (slice_max fix added Week 3)
│   ├── FRS_benefit_model_get_and_save_bendata.R  # Benefit data prep
│   ├── FRS_workforce_model_functions_V3.R        # Workforce projection
│   ├── FRS_workforce_model_get_and_save_wfdata_GC_s.R  # Workforce data prep
│   ├── FRS_liability_model_functions.R           # AAL calculations
│   ├── FRS_liability_model_get_and_save_liabdata.R  # Liability data prep
│   ├── FRS_funding_amort.R                       # Amortization
│   ├── FRS_funding_model_functions_loop_without_drop_V5.R  # Funding calcs
│   └── FRS_funding_model_functions_drop_only.R   # DROP module
├── OPEN_ISSUES.md                                # Tracked design issues / pendata gaps
├── pension_model_analysis.qmd                    # Master plan
├── data_structure_mapping_VERIFIED.md            # Week 1 results
└── SESSION_NOTES.md                              # This file
```

### External Dependencies:

- **pendata** (D:\R_projects\pendata): Source of FRS data
  - Contains `data/frs.rda` with params_env (188 objects)
  - Has both legacy and better structures
  - ⚠️ **Segfault risk in non-interactive Rscript**: BOTH `pendata::frs$params_env` AND
    `load('D:/R_projects/pendata/data/frs.rda')` segfault in non-interactive R because
    the full object contains `mort_table` (16M rows) which causes a crash.
  - ✅ **Safe alternatives for diagnostics**:
    - Staged individual files: `readRDS("D:/R_projects/pendata/data-raw/plans/frs/staged_data/<table>.rds")`
    - Gang's legacy env: `load("D:/R_projects/pendata/data-raw/gang/frs_data_env_bf_cal.RData")`
      (gives `frs_data_env` with legacy lookup tables — safe, loads quickly)
  - Key staged files available: `benefit_rules.rds`, `constants_assumptions_tbl.rds`, etc.

- **pentools** (GitHub: gchen3/pentools): Actuarial functions
  - 19 general-purpose functions
  - No FRS-specific logic

- **Personal R library path**: `C:/Users/Don-business/R/win-library/4.5`
  - NOT the default R library path — packages installed here by the user
  - Must set with `.libPaths('C:/Users/Don-business/R/win-library/4.5')` before loading packages
  - FRS_new_workflow.R has `.libPaths()` as line 2 — already handled
  - ⚠️ Using `Rscript --vanilla` SEGFAULTS when loading tidyverse (avoids .Rprofile entirely).
    Use `Rscript` WITHOUT `--vanilla` so .Rprofile loads the library path OR add `.libPaths()` as
    first line of the script (as done in FRS_new_workflow.R)
  - For diagnostic scripts: write to a .R file and run `Rscript <file>` (NOT `-e "..."` with multiline)

---

## How to Resume Work

### If I (Claude) need to resume:

1. Read SESSION_NOTES.md (this file) — most important, has all key context
2. Read OPEN_ISSUES.md — see which issues are blocking and what pendata needs
3. Check `git log --oneline -10` for recent changes
4. Say: "I see we're at Week 3, 160/160 tests pass, 4/5 Tier 2 tables migrated.
   The blocking issue is pendata benefit_rules data quality (OPEN_ISSUES #5).
   Next step is to fix benefit_rules in pendata for all tiers."

### If you (User) need to resume after a break:

1. Read this file for current status
2. Check OPEN_ISSUES.md for the benefit_rules pendata data quality issues
3. Tell me: "Let's continue" — I'll pick up from where we left off

---

## Backup Strategy

### To save work:
```bash
cd d:\R_projects\Florida-FRS-main_generalizable
git add refactor/*.md refactor/*.qmd refactor/*.R
git commit -m "Week 1 complete: data structure mapping and verification"
git push origin rebuild-test
```

### What's backed up:
- All analysis documents (.md, .qmd)
- Helper scripts (.R)
- Updates to existing files
- Git history shows progression

---

## Quick Reference: Better Structures

| Better Structure | Rows | Replaces | Migration Status |
|------------------|------|----------|-----------------|
| `headcount_salary` | 847 | salary_headcount_table | ⏸ Deferred |
| `benefit_rules` | 89 | ben_mult_lookup | ⚠️ Data quality issues (see OPEN_ISSUES #5) |
| `constants_assumptions_tbl` | 122 | 60+ scalars | ✅ Used for 4 computed tables |
| `salarygrowth` | 217 | salary_growth_table | ✅ Done (Tier 1) |
| `withdrawal` | 2,982 | separation_rate_table | ⏸ Deferred |
| `retirees` | 16 | retiree_distribution | ✅ Done (Tier 1) |
| `amortization_bases` | 235 | current_amort_layers | ✅ Done (Tier 1) |
| `retirement_rates` | 1,326 | 10+ retirement tables | ⏸ Not started |
| `return_scenarios` | 100 | return_scenarios (already good) | — |
| `db_dc_legacy_table` | 21 | (already good) | — |
| `db_dc_new_table` | 14 | (already good) | — |

**Total**: 70+ legacy objects → 11 better structures (85% reduction target)

---

## Performance Notes

### Current Issues:
- HUGE arrays (up to 4D) are memory hogs
- `mort_table`: 16 MILLION rows!
- `wf_retire` array: 139M elements (~1+ GB)

### Optimization Strategy:
1. **Tier 1**: Restructure to sparse/tibble representations (try first)
2. **Tier 2**: DuckDB, data.table optimizations (if needed)
3. **Tier 3**: Julia/Python (only if R fundamentally limited)

**Decision**: Tier 1 restructuring before considering language migration

---

## Contact Points

### If stuck or have questions:

1. **Model architecture**: See pension_model_analysis.qmd sections 4-7
2. **Data structures**: See data_structure_mapping_VERIFIED.md
3. **Better structures**: Use staged files (NOT frs.rda — segfault risk!):
   - `readRDS("D:/R_projects/pendata/data-raw/plans/frs/staged_data/<table>.rds")`
   - For legacy comparison: `load("D:/R_projects/pendata/data-raw/gang/frs_data_env_bf_cal.RData")`
4. **pendata source**: D:\R_projects\pendata
5. **This repo**: D:\R_projects\Florida-FRS-main_generalizable

---

**Last session end**: 2026-02-17 (Week 3 Tier 2 migration partially complete)
**Status**: ✅ 160/160 tests pass. All work committed and documented.
**Git branch**: rebuild-test
**Last commit**: `99d14a9` — "Tier 2: build 4 computed lookup tables from pendata constants (160/160 pass)"

### pendata changes: NONE
pendata was not modified at any point. The backward-compat patches live entirely in this repo.
Data quality issues found in pendata benefit_rules are documented in OPEN_ISSUES.md #5.

### Summary of all adapter/builder functions in FRS_helper_functions.R:

| Function | Purpose | Status |
|----------|---------|--------|
| `get_constant(tbl, name)` | Look up typed value from constants_assumptions_tbl | ✅ Active |
| `validate_better_structure()` | Schema validation helper | ✅ Active |
| `get_better_table_name()` | Legacy → better structure name map | ✅ Active |
| `convert_salarygrowth_to_legacy()` | salarygrowth → salary_growth_table | ✅ Active (Tier 1) |
| `convert_amortization_to_legacy()` | amortization_bases → current_amort_layers | ✅ Active (Tier 1) |
| `convert_retirees_to_legacy()` | retirees → retiree_distribution | ✅ Active (Tier 1) |
| `convert_benefit_rules_to_legacy()` | benefit_rules → ben_mult_lookup | ⚠️ Written, not active (pendata data quality) |
| `build_dr_lookup()` | constants → dr_lookup | ✅ Active (Tier 2) |
| `build_fas_period_lookup()` | plan provision → fas_period_lookup | ✅ Active (Tier 2) |
| `build_reduce_factor_lookup()` | plan provisions → reduce_factor_lookup | ✅ Active (Tier 2) |
| `build_cola_lookup()` | constants → cola_lookup | ✅ Active (Tier 2) |
