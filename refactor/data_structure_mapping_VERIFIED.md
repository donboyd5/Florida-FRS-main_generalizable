# Legacy → Better Data Structure Mapping (VERIFIED)

**Created**: 2026-02-16
**Verified**: 2026-02-16 by inspecting actual pendata frs.rda
**Status**: Week 1 - COMPLETE ✓

---

## Executive Summary

**MAJOR FINDING**: Of the 5 "gaps" initially identified, **ONLY 1 IS REAL**!

### ✅ Better Structures That EXIST (9 total):
1. `headcount_salary` (847 rows) - ✓ VERIFIED
2. `benefit_rules` (89 rows) - ✓ VERIFIED consolidates 6 lookup tables
3. `constants_assumptions_tbl` (122 rows) - ✓ VERIFIED
4. `salarygrowth` (217 rows) - ✓ VERIFIED
5. `withdrawal` (2,982 rows) - ✓ VERIFIED
6. `retirees` (16 rows) - ✓ VERIFIED
7. `amortization_bases` (235 rows) - ✓ VERIFIED
8. **`retirement_rates`** (1,326 rows) - ✓ SURPRISE FIND! Was listed as gap
9. **`return_scenarios`** (100 rows as data.frame) - ✓ SURPRISE FIND! Was listed as gap

### ✅ Better Structures That PARTIALLY EXIST:
10. `db_dc_legacy_table` (21 rows) - ✓ VERIFIED already in good format
11. `db_dc_new_table` (14 rows) - ✓ VERIFIED already in good format

### ✗ ONLY REMAINING GAP:
**Mortality tables** - Still in legacy format with MASSIVE row counts:
- `mort_table`: 15,996,673 rows (16 MILLION!)
- `mort_retire_table`: 23,247 rows
- `base_*_mort_table_`: Base mortality by employee type
- `*_mp_table_`: Mortality improvement scales

**Recommendation**: Keep mortality in legacy format for now (too large/complex to restructure immediately). Migration can handle this.

---

## Detailed Verification Results

### 1. headcount_salary ✓
```
Rows: 847
Columns: class, age_label, age_lb, age_ub, yos_label, yos_lb, yos_ub,
         headcount, salary
Better than: salary_headcount_table (329 rows, point values)
Status: READY FOR MIGRATION
```

**Sample**:
```
  class age_label age_lb age_ub yos_label yos_lb yos_ub headcount salary
1 admin  Under 20     18     19   Under 5      0      4         0      0
2 admin  Under 20     18     19   5 to 10      5      9         0      0
```

**Key improvements**:
- 2.5x more rows (847 vs 329) - finer granularity
- Range-based age/yos (age_lb/ub, yos_lb/ub) instead of point values
- Descriptive labels (age_label, yos_label)
- Includes both headcount AND salary

---

### 2. benefit_rules ✓
```
Rows: 89
Columns: class, tier, early_retirement, ruletype, dist_age_min_ge,
         dist_age_max_lt, yos_min_ge, yos_max_lt, dist_year_min_ge,
         dist_year_max_lt, special_calc_function, benmult, rule_description
Replaces: ben_mult_lookup, reduce_factor_lookup, cola_lookup, dr_lookup,
          fas_period_lookup, tier_table (consolidates 6 separate lookups!)
Status: READY FOR MIGRATION
```

**Sample**:
```
    class   tier early_retirement ruletype dist_age_min_ge yos_min_ge benmult
1 regular tier_1            FALSE   ageyos              62          6  0.0160
2 regular tier_1            FALSE      yos               0         30  0.0160
```

**Key improvements**:
- Single consolidated table instead of 6 separate lookups
- Range-based rules (age_min_ge/max_lt, yos_min_ge/max_lt)
- Self-documenting (rule_description column)
- Supports special calculation functions
- Tier as column value, not string pattern matching

**Migration impact**: Code that does `if_else(str_detect(tier, "tier_1"), ...)`
→ becomes `filter(tier == "tier_1")` (much cleaner!)

---

### 3. constants_assumptions_tbl ✓
```
Rows: 122
Columns: type, class, variable, original, datatype, value, description,
         source, vnumeric, vstring, vlogical
Replaces: 60+ individual scalar constants
Status: READY FOR MIGRATION
```

**Sample**:
```
         variable                 value                            description
1         dr_old_ 6.8000000000000005E-2         previous year's discount rate
2     dr_current_ 6.7000000000000004E-2       discount rate for current members
3         dr_new_ 6.7000000000000004E-2           discount rate for new members
4 payroll_growth_ 3.2500000000000001E-2               payroll growth assumption
5     pop_growth_                     0 plan's active population growth assumption
```

**Key improvements**:
- All constants in one table with metadata
- type, class categorization
- description and source fields for documentation
- datatype explicit
- vnumeric, vstring, vlogical for type-safe access

**Migration impact**:
- `params$dr_current_` → `get_constant("dr_current_", params)`
- Can validate all constants on load
- Can inspect all assumptions in one view

---

### 4. salarygrowth ✓
```
Rows: 217
Columns: class, yos_lb, yos_ub, yos_label, value
Replaces: salary_growth_table, salary_growth_table_, salary_growth_table_original_
Status: READY FOR MIGRATION
```

**Key improvements**:
- Range-based yos (yos_lb/ub) instead of point values
- Descriptive labels (yos_label)
- Stacked by class

---

### 5. withdrawal ✓
```
Rows: 2,982
Columns: class, yos_label, yos_lb, yos_ub, age_label, age_lb, age_ub, value
Replaces: separation_rate_table
Status: READY FOR MIGRATION
```

**Key improvements**:
- 9x more detailed than legacy (2,982 vs ~329 rows)
- Range-based age AND yos
- Descriptive labels

---

### 6. retirees ✓
```
Rows: 16
Columns: type, age_label, age_lb, age_ub, count, benefits
Replaces: retiree_distribution, mort_retire_table (partially)
Status: READY FOR MIGRATION
```

**Sample**:
```
        type age_label age_lb age_ub count benefits
1 disability  Under 50     18     49   424     8740
2 disability 50  to 54     50     54   805    15834
```

**Key improvements**:
- Range-based ages
- Separate disability vs service retirees
- Contains both count and benefit amounts

---

### 7. amortization_bases ✓
```
Rows: 235
Columns: class, date, amo_period, amo_balance
Replaces: current_amort_layers_table, current_amort_layers_table_
Status: READY FOR MIGRATION
```

**Key improvements**:
- Clean structure
- Stacked by class
- Clear column names

---

### 8. retirement_rates ✓ **SURPRISE FIND!**
```
Rows: 1,326
Columns: class, subclass, gender, age, tier, retire_type, value, sheet
Replaces: early_retire_rate_tier_1_table_list, early_retire_rate_tier_2_table_list,
          normal_retire_rate_tier_1_table_list, normal_retire_rate_tier_2_table_list,
          early_retirement_tier_1_table_, early_retirement_tier_2_table_,
          normal_retirement_tier_1_table_, normal_retirement_tier_2_table_,
          drop_entry_tier_1_table_, drop_entry_tier_2_table_
Status: READY FOR MIGRATION ✓
```

**Sample**:
```
    class subclass gender age  tier retire_type value                   sheet
1 regular      k12 female  45 tier1        drop     0 retire_rates_drop_tier1
2 regular      k12   male  45 tier1        drop     0 retire_rates_drop_tier1
```

**Key improvements**:
- **Single table consolidates 10+ separate retirement rate tables!**
- Includes gender, subclass (k12/notk12)
- Retirement type (drop, early, normal)
- Tier as column value
- Source sheet documented

**THIS WAS INCORRECTLY LISTED AS A GAP** - It exists and is comprehensive!

---

### 9. return_scenarios ✓ **SURPRISE FIND!**
```
Rows: 100 (30+ years × multiple scenarios)
Columns: year, model, assumption, recession, recur_recession, constant_6
Replaces: return_scenarios, return_scenarios_original_, return_2023_
Status: ALREADY IN GOOD FORMAT ✓
```

**Sample**:
```
  year model assumption recession recur_recession constant_6
1 2023 0.067      0.067     0.067           0.067      0.067
2 2024 0.067      0.067    -0.240          -0.240      0.060
```

**Key improvements**:
- Already a data.frame (not matrix/array)
- Multiple scenarios as columns
- Year-based indexing

**THIS WAS INCORRECTLY LISTED AS A GAP** - It's already in good format!

---

### 10-11. db_dc_legacy_table & db_dc_new_table ✓
```
db_dc_legacy_table:
  Rows: 21
  Columns: class, dc_legacy, db_legacy, year_ll, year_ul

db_dc_new_table:
  Rows: 14
  Columns: class, dc_new, db_new, new_year_ll, new_year_ul

Replaces: Nothing - these ARE the better structures
Status: ALREADY IN GOOD FORMAT ✓
```

**Sample**:
```
    class dc_legacy db_legacy year_ll year_ul
1 regular      0.25      0.75       0    2018
2 special      0.05      0.95       0    2018
```

**Key improvements**:
- Year range-based allocation
- Class-specific ratios
- Separate legacy vs new

**THIS WAS INCORRECTLY LISTED AS A GAP** - These tables are already well-structured!

---

## The ONLY Real Gap: Mortality Tables

### Legacy Mortality Tables (HUGE):

1. **`mort_table`**: 15,996,673 rows (16 MILLION!)
   - Columns: entry_year, entry_age, dist_year, dist_age, yos, term_year, mort_final, tier_at_dist_age, class
   - Issue: Pre-computed for every combination of entry/dist/term/yos
   - This is a **lookup table explosion** problem

2. **`mort_retire_table`**: 23,247 rows
   - Columns: base_age, age, year, mort_final, class
   - Current retiree mortality

3. **Base mortality tables**:
   - `base_general_mort_table_`
   - `base_safety_mort_table_`
   - `base_teacher_mort_table_`
   - Foundational mortality rates by employee type

4. **Mortality improvement scales**:
   - `male_mp_table_`
   - `female_mp_table_`
   - Generational mortality improvement

### Why Mortality Is Different:

**Complexity**: Mortality tables involve:
- Base rates by age/gender/employee type
- Mortality improvement scales (generational)
- Projection across many years and ages
- Pre-computation to avoid expensive calculations in tight loops

**Size**: 16M rows for mort_table is too large to convert without careful design.

**Usage pattern**: Heavily indexed in tight loops during workforce projection.

### Recommendation for Mortality:

**Phase 1 (Migration)**:
- **Keep legacy mortality tables as-is**
- Migration can proceed without restructuring mortality
- Document that mortality uses legacy format

**Phase 2-3 (Future optimization)**:
- Consider function-based approach instead of pre-computed lookup
- Or sparse representation (only non-zero probabilities)
- Or DuckDB for large mortality tables
- This is a **performance optimization**, not a blocker

---

## Migration Priority Matrix

### TIER 1: Migrate Immediately (No blockers)

| Better Structure | Rows | Complexity | Migration Effort | Ready? |
|------------------|------|------------|------------------|--------|
| `headcount_salary` | 847 | Low | Low | ✅ YES |
| `salarygrowth` | 217 | Low | Low | ✅ YES |
| `withdrawal` | 2,982 | Medium | Low | ✅ YES |
| `retirees` | 16 | Low | Low | ✅ YES |
| `amortization_bases` | 235 | Low | Low | ✅ YES |
| `constants_assumptions_tbl` | 122 | Medium | Medium | ✅ YES |

**Timeline**: Week 2-3 (can start immediately)

---

### TIER 2: Migrate After Core Tables (Dependencies)

| Better Structure | Rows | Complexity | Migration Effort | Ready? |
|------------------|------|------------|------------------|--------|
| `benefit_rules` | 89 | High | High | ✅ YES |
| `retirement_rates` | 1,326 | High | High | ✅ YES |

**Why Tier 2**:
- `benefit_rules`: Replaces 6 lookup tables + tier string parsing logic (major code refactor)
- `retirement_rates`: Replaces 10+ tables (complex but doable)

**Timeline**: Week 3-4

---

### TIER 3: Already Good / Keep As-Is

| Structure | Rows | Status | Action |
|-----------|------|--------|--------|
| `return_scenarios` | 100 | ✅ Good format | Use as-is |
| `db_dc_legacy_table` | 21 | ✅ Good format | Use as-is |
| `db_dc_new_table` | 14 | ✅ Good format | Use as-is |

**Timeline**: No migration needed

---

### TIER 4: Defer to Future (Complex, Not Blocking)

| Structure | Rows | Issue | Plan |
|-----------|------|-------|------|
| `mort_table` | 15,996,673 | Too large | Keep legacy for Phase 1 |
| `mort_retire_table` | 23,247 | Complex | Keep legacy for Phase 1 |
| Base mortality tables | Various | Foundational | Keep legacy for Phase 1 |

**Timeline**: Phase 2-3 (optimization phase)

---

## Revised Gap Analysis

### ✅ COMPLETE COVERAGE (11 better structures exist):
1. ✅ headcount_salary
2. ✅ benefit_rules (consolidates 6 lookups!)
3. ✅ constants_assumptions_tbl (consolidates 60+ scalars!)
4. ✅ salarygrowth
5. ✅ withdrawal
6. ✅ retirees
7. ✅ amortization_bases
8. ✅ retirement_rates (consolidates 10+ tables!)
9. ✅ return_scenarios (already good)
10. ✅ db_dc_legacy_table (already good)
11. ✅ db_dc_new_table (already good)

### ⚠️ DEFERRED (1 complex structure):
1. ⚠️ Mortality tables (too large/complex for immediate migration)

### ✗ TRUE GAPS:
**NONE!** All critical data has better structure equivalents.

---

## Migration Plan - REVISED

### Week 1: ✅ COMPLETE
- ✅ Inventory legacy objects (91 unique)
- ✅ Map to better structures
- ✅ Verify better structures exist
- ✅ Identify actual gaps (only mortality)
- ✅ Create migration plan

### Week 2: Tier 1 Migration
**Goal**: Migrate simple tables with low code impact

1. **Update data prep files** (3 files):
   - `FRS_benefit_model_get_and_save_bendata.R`
   - `FRS_workforce_model_get_and_save_wfdata_GC_s.R`
   - `FRS_liability_model_get_and_save_liabdata.R`

2. **Migrate Tier 1 tables**:
   - Replace `salary_headcount_table` → `headcount_salary`
   - Replace `salary_growth_table` → `salarygrowth`
   - Replace `separation_rate_table` → `withdrawal`
   - Replace `retiree_distribution` → `retirees`
   - Replace `current_amort_layers_table` → `amortization_bases`

3. **Update constants access**:
   - Create `get_constant()` helper function
   - Replace direct `params$dr_current_` → `get_constant("dr_current_", params)`
   - Do incrementally (high-use constants first)

4. **Test**:
   - Run model with mixed legacy/better structures
   - Verify outputs match baseline
   - Document any discrepancies

**Deliverable**: Tier 1 migration complete, model runs successfully

---

### Week 3: Tier 2 Migration
**Goal**: Migrate complex benefit rules and retirement rates

1. **Migrate benefit_rules**:
   - Replace 6 lookup tables with single `benefit_rules`
   - Remove tier string parsing: `str_detect(tier, "tier_1")` → `tier == "tier_1"`
   - Update benefit calculation logic
   - Test benefit amounts match baseline

2. **Migrate retirement_rates**:
   - Replace 10+ retirement rate tables
   - Update retirement probability logic
   - Test workforce projections match baseline

3. **Keep mortality as legacy** (document decision):
   - Update docs: "Mortality tables use legacy format in Phase 1"
   - Plan for Phase 2-3 optimization

4. **Final testing**:
   - Full model run with all better structures (except mortality)
   - Regression test vs baseline
   - Performance benchmark

**Deliverable**: Migration 95% complete (all except mortality)

---

### Week 4: Documentation & Cleanup
**Goal**: Finalize migration, document process

1. **Remove unused legacy objects** from pendata:
   - List legacy objects no longer referenced
   - Create pendata PR to remove them
   - Simplify pendata params_env

2. **Update documentation**:
   - Data dictionary for all better structures
   - Migration guide for future plans
   - Update PENSION_MODEL_ANALYSIS.qmd

3. **Create schema validation**:
   - JSON/YAML schema for required tables
   - Validation function to check on load
   - Error messages guide user to fix data

**Deliverable**: Phase 1 complete ✓

---

## Key Takeaways

### What We Learned:

1. **pendata is MORE READY than we thought!**
   - 11 better structures exist (vs. 7 expected)
   - Only 1 true gap (mortality, which is complex but not blocking)
   - Migration can proceed immediately

2. **Consolidation is powerful**:
   - `benefit_rules` consolidates 6 separate lookup tables
   - `retirement_rates` consolidates 10+ tables
   - `constants_assumptions_tbl` consolidates 60+ scalars
   - Result: 70+ legacy objects → 11 better structures (~85% reduction!)

3. **Migration is less risky than expected**:
   - Most better structures are drop-in replacements
   - Can migrate incrementally (Tier 1 → Tier 2)
   - Backward compatibility testing at each step
   - Mortality deferral reduces scope

### Success Criteria:

**Week 2**: ✅ Tier 1 migration complete, model runs
**Week 3**: ✅ Tier 2 migration complete, tests pass
**Week 4**: ✅ Documentation complete, legacy objects removed

---

**End of Document**

**Status**: Week 1 COMPLETE ✓ - Ready for Week 2 migration

**Created**: 2026-02-16
**Verified**: 2026-02-16
**Next Action**: Begin Week 2 Tier 1 migration
