# Legacy → Better Data Structure Mapping

**Created**: 2026-02-16
**Purpose**: Map legacy pendata objects to better formal structures for migration
**Status**: Week 1 - Initial Inventory

---

## Summary Statistics

- **Total unique params objects found**: 91
- **Active R files analyzed**: 10 core files + 2 alternative workflow
- **Archive files** (excluded from analysis): 23
- **Total params references**: ~800+ occurrences

---

## Object Categories

### A. Core Population Tables (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `salary_headcount_table` | 2 direct<br>11 in list | `headcount_salary` | ✓ Exists | Legacy: 329 rows, point values<br>Better: 847 rows, ranges + metadata |
| `entrant_profile_table` | 2 direct<br>11 in list | `headcount_salary` (subset?) | ⚠️ Partial | May need separate `entrants` table |
| `mort_table` | 2 direct<br>11 in list | ❓ Unknown | ✗ Gap | Need mortality table in better format |
| `mort_retire_table` | 1 direct<br>11 in list | `retirees` (partial) | ⚠️ Partial | Current retiree mortality |
| `separation_rate_table` | 2 direct<br>11 in list | `withdrawal` | ✓ Exists | Better: 2,982 rows with ranges |

**Finding**: Core tables have some better equivalents, but gaps exist for mortality tables.

---

### B. Benefit Calculation Lookups (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `tier_table` | 1 | `benefit_rules` (partial) | ⚠️ Partial | Tier assignment logic<br>Legacy: 4.2M rows (huge!)<br>Better: 89 rows |
| `ben_mult_lookup` | 1 | `benefit_rules` | ✓ Exists | Benefit multipliers by tier |
| `reduce_factor_lookup` | 1 | `benefit_rules` | ✓ Exists | Early retirement reductions |
| `cola_lookup` | 1 | `benefit_rules` | ✓ Exists | COLA rates by tier |
| `dr_lookup` | 2 | `benefit_rules` | ✓ Exists | Discount rates by tier |
| `fas_period_lookup` | 1 | `benefit_rules` | ✓ Exists | Final average salary period |

**Finding**: All benefit lookups consolidated into `benefit_rules` table (89 rows). This is a major improvement over separate lookup tables.

---

### C. Retirement Rate Tables (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `early_retire_rate_tier_1_table_list` | 2 | ❓ Unknown | ✗ Gap | Tier 1 early retirement rates |
| `early_retire_rate_tier_2_table_list` | 2 | ❓ Unknown | ✗ Gap | Tier 2 early retirement rates |
| `normal_retire_rate_tier_1_table_list` | 2 | ❓ Unknown | ✗ Gap | Tier 1 normal retirement rates |
| `normal_retire_rate_tier_2_table_list` | 2 | ❓ Unknown | ✗ Gap | Tier 2 normal retirement rates |
| `early_retirement_tier_1_table_` | 1 | ❓ Unknown | ✗ Gap | |
| `early_retirement_tier_2_table_` | 1 | ❓ Unknown | ✗ Gap | |
| `normal_retirement_tier_1_table_` | 1 | ❓ Unknown | ✗ Gap | |
| `normal_retirement_tier_2_table_` | 1 | ❓ Unknown | ✗ Gap | |

**Finding**: **MAJOR GAP** - Retirement rate tables don't have better equivalents. Need to create.

---

### D. Salary Growth Tables (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `salary_growth_table` | 5 | `salarygrowth` | ✓ Exists | Better: 217 rows with ranges |
| `salary_growth_table_` | 8 | `salarygrowth` | ✓ Exists | Same as above (underscore variant) |
| `salary_growth_table_original_` | 6 | `salarygrowth` | ✓ Exists | Pre-adjustment version |

**Finding**: Salary growth has good better equivalent.

---

### E. Termination/Mortality Rate Tables (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `term_rate_male_table_list` | 4 | ❓ Unknown | ✗ Gap | Male termination rates |
| `term_rate_female_table_list` | 4 | ❓ Unknown | ✗ Gap | Female termination rates |
| `base_general_mort_table_` | 1 | ❓ Unknown | ✗ Gap | General employee mortality |
| `base_safety_mort_table_` | 1 | ❓ Unknown | ✗ Gap | Safety employee mortality |
| `base_teacher_mort_table_` | 1 | ❓ Unknown | ✗ Gap | Teacher mortality |
| `male_mp_table_` | 1 | ❓ Unknown | ✗ Gap | Male mortality improvement |
| `female_mp_table_` | 1 | ❓ Unknown | ✗ Gap | Female mortality improvement |

**Finding**: **MAJOR GAP** - Gender-specific and class-specific mortality tables missing from better structures.

---

### F. DROP (Deferred Retirement Option) Tables (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `drop_entry_tier_1_table_` | 1 | ❓ Unknown | ✗ Gap | DROP entry rates tier 1 |
| `drop_entry_tier_2_table_` | 1 | ❓ Unknown | ✗ Gap | DROP entry rates tier 2 |

**Finding**: DROP-specific tables missing (but DROP is FRS-specific, may not need better structure).

---

### G. Funding & Amortization Data (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `init_funding_data` | 6 | `amortization_bases` (partial) | ⚠️ Partial | Initial funding status by class |
| `current_amort_layers_table` | 10 | `amortization_bases` | ✓ Exists | Better: 235 rows |
| `current_amort_layers_table_` | 4 | `amortization_bases` | ✓ Exists | Same (underscore variant) |
| `funding_list` | 10 | N/A (output) | N/A | Generated output, not input |

**Finding**: Amortization has good better equivalent.

---

### H. Investment Return Scenarios (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `return_scenarios` | 20 | ❓ Unknown | ✗ Gap | Investment return scenarios |
| `return_scenarios_original_` | 2 | ❓ Unknown | ✗ Gap | Original return scenarios |
| `return_2023_` | 7 | ❓ Unknown | ✗ Gap | 2023 returns |

**Finding**: **GAP** - Return scenarios not in better structures.

---

### I. Retiree Distribution (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `retiree_distribution` | 2 | `retirees` | ✓ Exists | Better: 16 rows with ranges |
| `current_year_table` | 2 | `retirees` (partial?) | ⚠️ Partial | Current year retiree data |

**Finding**: Mostly covered by `retirees` table.

---

### J. DB/DC Split Tables (Legacy → Better)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `db_dc_legacy_table` | 4 | ❓ Unknown | ✗ Gap | Legacy plan DB/DC allocation |
| `db_dc_new_table` | 4 | ❓ Unknown | ✗ Gap | New plan DB/DC allocation |

**Finding**: **GAP** - DB/DC split tables missing from better structures.

---

### K. Scalar Constants (Legacy → Better)

**Note**: There are 60+ scalar constants. These should map to `constants_assumptions_tbl`.

| Category | Legacy Objects (sample) | Usage | Better Structure | Status |
|----------|------------------------|-------|------------------|--------|
| **Class Names** | `class_names_`<br>`class_names_no_drop_frs_`<br>`class_names_no_frs_` | 75, 57, 20 | `constants_assumptions_tbl` | ✓ Exists |
| **Discount Rates** | `dr_current_`<br>`dr_new_`<br>`dr_old_` | 73, 58, 5 | `constants_assumptions_tbl` | ✓ Exists |
| **COLA Rates** | `cola_tier_1_active_`<br>`cola_tier_2_active_`<br>`cola_tier_3_active_`<br>`cola_tier_1_active_constant_`<br>`one_time_cola_`<br>`cola_current_retire_`<br>`cola_current_retire_one_` | 15, 10, 10, 15, 13, 9, 9 | `constants_assumptions_tbl` | ✓ Exists |
| **Date/Period** | `start_year_`<br>`model_period_`<br>`new_year_`<br>`year_range_` | 57, 52, 27, 9 | `constants_assumptions_tbl` | ✓ Exists |
| **Age/YOS Ranges** | `age_range_`<br>`yos_range_`<br>`entry_year_range_`<br>`max_age_` | 22, 19, 13, 4 | `constants_assumptions_tbl` | ✓ Exists |
| **Growth Rates** | `payroll_growth_`<br>`pop_growth_`<br>`inflation_` | 22, 4, 10 | `constants_assumptions_tbl` | ✓ Exists |
| **Amortization** | `amo_period_new_`<br>`amo_period_term_`<br>`amo_pay_growth_`<br>`amo_pay_growth`<br>`amo_method_`<br>`funding_lag_` | 16, 8, 10, 5, 6, 31 | `constants_assumptions_tbl` | ✓ Exists |
| **Contribution Rates** | `db_ee_cont_rate_`<br>`db_ee_interest_rate_` | 14, 4 | `constants_assumptions_tbl` | ✓ Exists |
| **Asset Smoothing** | `ava_smooth_years_`<br>`ava_cap_upper_`<br>`ava_cap_lower_` | 2, 2, 2 | `constants_assumptions_tbl` | ✓ Exists |
| **Calibration** | `cal_factor_`<br>`nc_cal_` | 4, 7 | `constants_assumptions_tbl` | ✓ Exists |
| **Return Scenarios** | `return_scen_`<br>`return_scen_index`<br>`model_return_` | 7, 8, 7 | `constants_assumptions_tbl` | ✓ Exists |
| **Retirement** | `retire_refund_ratio_` | 11 | `constants_assumptions_tbl` | ✓ Exists |
| **Feature Flags** | `enable_drop_` | 6 | `constants_assumptions_tbl` | ✓ Exists |
| **DB/DC Ratios** | `special_db_new_ratio_`<br>`non_special_db_new_ratio_`<br>`special_db_legacy_before_2018_ratio_`<br>`special_db_legacy_after_2018_ratio_`<br>`non_special_db_legacy_before_2018_ratio_`<br>`non_special_db_legacy_after_2018_ratio_` | 6, 6, 1, 1, 1, 1 | `constants_assumptions_tbl` | ✓ Exists |
| **Adjustments** | `eco_eso_judges_total_active_member_`<br>`eco_eso_judges_active_member_adjustment_ratio` | 4, 2 | `constants_assumptions_tbl` | ✓ Exists |

**Finding**: All scalar constants should be in `constants_assumptions_tbl` (122 rows). Need to verify complete coverage.

---

### L. List Objects (Collections of tables by class)

| Legacy Object | Usage Count | Better Structure | Status | Notes |
|---------------|-------------|------------------|--------|-------|
| `wf_data_list` | 11 | N/A (internal) | N/A | Generated internally, not input |
| `salary_headcount_table_list` | 11 | `headcount_salary` | ✓ Exists | List of per-class tables → stacked |
| `entrant_profile_table_list` | 11 | Need entrants table | ✗ Gap | |
| `mort_table_list` | 11 | Need mortality table | ✗ Gap | |
| `mort_retire_table_list` | 11 | `retirees` (partial) | ⚠️ Partial | |
| `separation_rate_table_list` | 11 | `withdrawal` | ✓ Exists | |
| `term_rate_male_table_list` | 4 | Need termination table | ✗ Gap | |
| `term_rate_female_table_list` | 4 | Need termination table | ✗ Gap | |
| `early_retire_rate_tier_1_table_list` | 2 | Need retirement rate table | ✗ Gap | |
| `early_retire_rate_tier_2_table_list` | 2 | Need retirement rate table | ✗ Gap | |
| `normal_retire_rate_tier_1_table_list` | 2 | Need retirement rate table | ✗ Gap | |
| `normal_retire_rate_tier_2_table_list` | 2 | Need retirement rate table | ✗ Gap | |

**Finding**: Lists are per-class versions. Better structures should stack these with `class` column.

---

## Gap Analysis

### ✓ Well Covered (Better structures exist)
1. **Headcount/Salary**: `headcount_salary` (847 rows)
2. **Benefit rules**: `benefit_rules` (89 rows) - consolidates 6 lookup tables
3. **Salary growth**: `salarygrowth` (217 rows)
4. **Withdrawal/Separation**: `withdrawal` (2,982 rows)
5. **Amortization**: `amortization_bases` (235 rows)
6. **Retirees**: `retirees` (16 rows)
7. **Constants**: `constants_assumptions_tbl` (122 rows)

### ⚠️ Partial Coverage (Exists but incomplete)
1. **Entrant profiles**: May be subset of headcount_salary or need separate table
2. **Current year retirees**: Partially in `retirees` but may need enhancement
3. **Initial funding data**: Partially in amortization_bases

### ✗ Major Gaps (Missing from better structures)

#### Priority 1 - Critical for model operation:
1. **Mortality tables** (active and retired members)
   - `mort_table` - active member mortality by class
   - `mort_retire_table` - retiree mortality
   - Gender-specific: `base_general_mort_table_`, `base_safety_mort_table_`, `base_teacher_mort_table_`
   - Mortality improvement: `male_mp_table_`, `female_mp_table_`

2. **Retirement rate tables**
   - `early_retire_rate_tier_1_table_list`, `early_retire_rate_tier_2_table_list`
   - `normal_retire_rate_tier_1_table_list`, `normal_retire_rate_tier_2_table_list`
   - `early_retirement_tier_1_table_`, `early_retirement_tier_2_table_`
   - `normal_retirement_tier_1_table_`, `normal_retirement_tier_2_table_`

3. **Termination rate tables** (gender-specific)
   - `term_rate_male_table_list`, `term_rate_female_table_list`

4. **DB/DC allocation tables**
   - `db_dc_legacy_table`, `db_dc_new_table`

5. **Investment return scenarios**
   - `return_scenarios`, `return_scenarios_original_`, `return_2023_`

#### Priority 2 - FRS-specific features:
1. **DROP tables** (may not need better structure if DROP is optional)
   - `drop_entry_tier_1_table_`, `drop_entry_tier_2_table_`

---

## Recommended Better Structures to Create

### 1. `mortality` table
```
Columns: class, member_type (active/retired), gender, age, base_rate,
         improvement_scale, tier, effective_year
Rows: ~5,000-10,000 (detailed by class × gender × age × tier)
Purpose: Consolidate all mortality tables
```

### 2. `retirement_rates` table
```
Columns: class, tier, retirement_type (early/normal/DROP), age, yos,
         rate, effective_date
Rows: ~2,000-5,000
Purpose: Consolidate retirement election rates
```

### 3. `termination_rates` table (or expand `withdrawal`)
```
Columns: class, gender, age, yos, term_type (termination/retirement/death),
         rate
Rows: ~5,000-10,000
Purpose: Detailed termination rates with gender
Note: May be same as `withdrawal` with gender added
```

### 4. `plan_design_allocation` table
```
Columns: class, hire_year_min, hire_year_max, plan_design (db_legacy,
         db_new, dc_legacy, dc_new), allocation_pct
Rows: ~50-100
Purpose: Replace db_dc_legacy_table and db_dc_new_table
```

### 5. `return_scenarios` table
```
Columns: scenario_id, year, return_rate, scenario_name, probability,
         effective_date
Rows: ~100-500 (multiple scenarios × 30+ years)
Purpose: Investment return assumptions
```

### 6. `entrant_distribution` table (if separate from headcount_salary)
```
Columns: class, entry_age, entry_age_label, entry_salary, distribution_pct,
         effective_year
Rows: ~200-500
Purpose: New entrant age distribution
Note: May already be covered by headcount_salary
```

---

## Next Steps

### Immediate (This Week):
1. ✓ **Complete this inventory** (DONE)
2. **Verify constants coverage**: Check if all 60+ scalars are in `constants_assumptions_tbl`
3. **Document better structure schemas**: For existing better structures, document exact columns
4. **Identify which gaps are blockers**: Which missing tables prevent migration?

### Week 2:
1. **Create missing better structures in pendata**:
   - Priority 1: mortality, retirement_rates, plan_design_allocation
   - Priority 2: return_scenarios
2. **Enhance existing better structures** if needed
3. **Create schema definitions** (JSON/YAML)

### Week 3:
1. **Update model code** to use better structures
2. **Test backward compatibility**
3. **Document migration process**

---

## Files Using Each Legacy Object

### Most Critical Files to Update (use params$ heavily):

1. **`FRS_workforce_model_functions_V3.R`**:
   - Uses: entrant_profile_table, salary_headcount_table, mort_table, separation_rate_table
   - Plus: age_range_, year_range_, retire_refund_ratio_, pop_growth_

2. **`FRS_benefit_model_functions.R`**:
   - Uses: Benefit lookup tables (tier_table, ben_mult_lookup, etc.)
   - Plus: DR constants, COLA constants

3. **`FRS_funding_model_functions_loop_without_drop_V5.R`**:
   - Uses: funding_list, return_scenarios, amortization params
   - Plus: Many funding/amortization constants

4. **`FRS_liability_model_functions.R`**:
   - Uses: db_dc_legacy_table, db_dc_new_table
   - Plus: DR constants

5. **Data prep files** (*get_and_save*.R):
   - Create derived tables from legacy structures
   - Will need significant updates

---

**End of Mapping Document**

**Status**: Initial inventory complete. Ready for Week 1 verification and gap analysis.
