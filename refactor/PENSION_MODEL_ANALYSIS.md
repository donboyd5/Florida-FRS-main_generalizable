# Florida FRS Pension Simulation Model - Analysis & Rationalization Plan

**Date**: 2026-02-16
**Branch**: rebuild-test
**Status**: Initial analysis complete, pendata/pentools analyzed
**Updated**: 2026-02-16 with dual data structure analysis

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Critical Context: pendata Dual Structure](#critical-context-pendata-dual-structure)
3. [pentools Actuarial Library](#pentools-actuarial-library)
4. [Model Architecture](#model-architecture)
5. [Data Inputs from pendata](#data-inputs-from-pendata)
6. [Current Data Structures](#current-data-structures)
7. [Model Components](#model-components)
8. [Data Flow](#data-flow)
9. [Generalization Assessment](#generalization-assessment)
10. [Performance & Language Considerations](#performance-and-language-considerations)
11. [Rationalization Plan](#rationalization-plan)
12. [Decisions Made](#decisions-made)

---

## Executive Summary

The Florida FRS pension simulation model is a sophisticated actuarial projection system that forecasts:
- Workforce dynamics (entries, exits, retirements, deaths)
- Benefit calculations and normal costs
- Actuarial liabilities (AAL) using Entry Age Normal method
- Asset returns (MVA and smoothed AVA)
- Employer/employee contributions
- Funded ratios over 30+ year horizon

### Current State
- **Architecture**: Well-structured with 4 main modules (Benefit, Workforce, Liability, Funding)
- **Data Format**: **DUAL STRUCTURE** - pendata contains both legacy and improved formats
- **Generalizability**: Core actuarial logic is universal; ~30% of code is FRS-specific
- **Key Barrier**: Currently uses legacy data format; needs migration to better pendata structures

### Critical Discovery
**pendata has TWO sets of FRS data:**
1. **Legacy format** "as currently needed" - what this repo expects now (e.g., `headcount_table_` with 329 rows)
2. **Better formal structures** "as we would like it" - improved, self-documenting format (e.g., `headcount_salary` with 847 rows, age/yos ranges, metadata)

**The transition challenge:** This repo currently uses legacy format. A major goal is migrating to better structures and improving them further.

### Goal
Transform into a **general pension model** where any pension plan with proper data can run through the system, using well-structured, self-documenting data formats.

---

## Critical Context: pendata Dual Structure

**Repository**: https://github.com/donboyd5/pendata (main branch)

### The Dual Data Problem

pendata currently maintains **TWO complete representations** of FRS data in `frs$params_env` (188 objects total):

#### Structure 1: Legacy Format (Gang's data)
**Source**: `data-raw/gang/` (Git-ignored, from Reason/Gang analyst)
- **Purpose**: What the current modeling repo expects
- **Format**: Entry-year based, minimal metadata
- **Example**: `headcount_table_` (329 rows) - simple age/yos/count structure
- **Issues**:
  - Coarse granularity
  - No self-documentation
  - No provenance tracking
  - Unclear validation

**Key legacy objects:**
- `salary_headcount_table`, `mort_table`, `separation_rate_table`
- Lookup tables: `dr_lookup`, `cola_lookup`, `ben_mult_lookup`, `tier_table`, etc.
- 110+ scalar constants as separate named objects

#### Structure 2: Better Formal Structures
**Source**: `data-raw/plans/frs/` (created by pendata processing pipeline)
- **Purpose**: Improved, self-documenting structures for future use
- **Format**: Age/YOS range-based with rich metadata
- **Example**: `headcount_salary` (847 rows) - includes age_label, age_lb/ub, yos_label, yos_lb/ub, descriptions

**Better structures include:**
```r
headcount_salary         # 847 rows (vs. 329 legacy) - detailed age×yos grid
constants_assumptions_tbl # 122 rows - all constants with metadata (type, class, variable,
                         #           datatype, value, description, source)
benefit_rules           # 89 rows - formalized benefit calculation rules
retirees                # 16 rows - retiree distribution with ranges
withdrawal              # 2,982 rows - detailed termination rates
salarygrowth            # 217 rows - merit increases by class/yos
amortization_bases      # 235 rows - layered amortization structure
```

**What makes them "better":**
| Aspect | Legacy | Better |
|--------|--------|--------|
| **Self-documentation** | Minimal | Rich metadata: labels, bounds, descriptions, sources |
| **Granularity** | Coarse (entry_year) | Detailed (age×yos ranges) |
| **Age/YOS** | Point values (age=20) | Ranges (age_lb=18, age_ub=19, age_label="Under 20") |
| **Constants** | Named list only | Both list (for code) AND table (for inspection) |
| **Validation** | External/unclear | Built-in test suites |
| **Provenance** | Unknown | Documented source/description fields |

### Data Creation Pipeline

```
Source Excel (xlsm from Gang)
  ↓
[1] Extract → work_data/frs_inputs_raw.rds
  ↓
[2] Process (via .qmd files) → work_data/*.rds
  ↓
[3] Test → work_data/tests_*.csv
  ↓
[4] Stage → staged_data/*.rds
  ↓
[5] Assemble → data/frs.rda
```

**Key transformation functions** (in `data-raw/R/functions.R`):
- `flip()`: Converts wide Excel tables to long format with age/yos labels and bounds
- `flip_stack()`: Applies flip() to multiple sheets and stacks them
- `all_tests_passed()`: Validates test results

**Processing scripts per component** (in `data-raw/plans/frs/qmd/`):
- `constants_assumptions.qmd` → creates both list and table formats
- `headcount_salary.qmd` → transforms wide data to tidy long format
- `benefit_rules.qmd` → validates benefit calculation rules
- `retirees.qmd`, `withdrawal.qmd`, `salary_growth.qmd`, etc.

### Current Reality

**Both structures coexist because:**
1. The modeling repo (this repo) currently expects Gang's legacy format
2. pendata is building better structures for future use
3. Transition period requires maintaining both
4. Once this repo is updated, legacy formats can be eliminated

### Implications for This Project

**Critical insight:** Part of the rationalization work is:
1. **Review** the better pendata structures
2. **Improve** them further if needed (schema formalization, validation, etc.)
3. **Migrate** this repo to use better structures instead of legacy
4. **Eliminate** duplication once migration is complete

This is not just about making the model general - it's about **using the better data structures that already exist** in pendata.

---

## pentools Actuarial Library

**Repository**: https://github.com/gchen3/pentools (main branch)

### Overview

pentools is a **well-engineered, general-purpose actuarial mathematics library** that has been successfully extracted from FRS-specific code. It contains **19 core functions** organized into logical categories.

**Key characteristic:** Completely plan-agnostic - no FRS-specific logic embedded.

### Function Categories

#### 1. Present Value Calculations (6 functions)
- `get_pv(rate, t)` - Basic PV discount factor
- `get_pv_pmt(rate, t)` - PV of $1 annuity
- `get_pv_gpmt(rate, growth, t)` - PV of growing annuity
- `pv(rate, g, nper, pmt, t)` - Comprehensive PV for growing annuities
- `npv(rate, cashflows)` - Net present value
- `get_pv_cf_roll(rate, cf)` - Rolling PV of future cash flows

#### 2. Payment Calculations (4 functions)
- `get_pmt(r, g, nper, pv, t)` - Payment for growing annuity given PV
- `get_pmt0(r, nper, pv)` - First payment of annuity due
- `get_pmt_due(rate, t)` - Payment factor for annuity due
- `get_pmt_growth(rate, growth, t)` - First payment for growing annuity due

#### 3. Actuarial/Pension Functions (4 functions)
- **`get_pvfb(sep_rate_vec, interest_vec, value_vec)`** - Present value of future benefits
- **`get_pvfs(remaining_prob_vec, interest_vec, sal_vec)`** - Present value of future salaries
- **`annfactor(surv_DR_vec, cola_vec, one_time_cola)`** - Annuity factors with survival/COLA
- `roll_pv(rate, g, nper, pmt_vec, t)` - Rolling present value

#### 4. Future Value & Growth (4 functions)
- `get_cum_fv(interest, cashflow, first_value)` - Cumulative future values
- `recur_grow(x, g)` - Recursive growth with lag
- `recur_grow2(x, g)` - Recursive growth without lag
- `recur_grow3(x, g, nper)` - Recursive growth with fixed rate

#### 5. Workforce Planning (1 function)
- `add_new_entrants(g, ne_dist, wf1, wf2, ea, age, position_matrix)` - Calculate/distribute entrants

### Key Strengths

✓ **General-purpose** - works for any pension plan
✓ **Well-documented** - Roxygen documentation with examples
✓ **Comprehensive testing** - 40+ unit tests
✓ **Vectorized** - handles time-series efficiently
✓ **Flexible rates** - supports period-by-period variation
✓ **Clean separation** - pure computational functions, no embedded business logic

### Integration with FRS Model

**Clean architectural separation:**
- **pentools handles**: "How to calculate" - the math
- **FRS model handles**: "What to calculate" - benefit formulas, assumptions, business rules

**Current usage in FRS model:**
- `get_pvfb()` - Core actuarial PV calculations
- `annfactor()` - Annuity factors with mortality/COLA
- `get_pvfs()` - Salary valuations
- Time-value functions for discounting/growth

**What's NOT in pentools (still in FRS code):**
- FRS-specific benefit formulas
- Mortality/separation tables (data, not functions)
- COLA rules and tier logic
- Funding method implementations
- Plan-specific business rules

### Conclusion

pentools represents **successful generalization** - a model for what we want to achieve with the data structures and modeling code.

---

## Model Architecture

### Overall Structure
```
FRS_new_workflow.R (main orchestrator, 82 lines)
├── Parameters (pendata::frs$params_env - 188 objects)
├── Benefit Model (bm_env)
├── Workforce Model (wfm_env)
├── Liability Model (lm_env)
└── Funding Model (fm_env)
```

### Execution Flow
```
1. Load parameters from pendata::frs
   ↓
2. Benefit Model → benefit_val_table (normal costs, PVFB)
   ↓
3. Workforce Model → population projections (active, term, refund, retire)
   ↓
4. Liability Model → AAL, aggregate NC, benefit payments
   ↓
5. Funding Model → contributions, MVA, AVA, funded ratios
   ↓
6. Output → workspace saved to new_results/
```

### Key Files

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| **Workflow** | `FRS_new_workflow.R` | 82 | Main orchestration |
| **Benefit Functions** | `FRS_benefit_model_functions.R` | ~500 | Benefit formulas, annuities, normal costs |
| **Benefit Data** | `FRS_benefit_model_get_and_save_bendata.R` | ~200 | Prep benefit inputs |
| **Workforce Functions** | `FRS_workforce_model_functions_V3.R` | ~800 | Array-based population projection |
| **Workforce Data** | `FRS_workforce_model_get_and_save_wfdata_GC_s.R` | ~300 | Prep workforce inputs |
| **Liability Functions** | `FRS_liability_model_functions.R` | ~600 | AAL calculations, roll-forward |
| **Liability Data** | `FRS_liability_model_get_and_save_liabdata.R` | ~150 | Prep liability inputs |
| **Funding - Amort** | `FRS_funding_amort.R` | ~200 | Layered amortization bases |
| **Funding - Main** | `FRS_funding_model_functions_loop_without_drop_V5.R` | ~900 | Contribution & asset projection |
| **Funding - DROP** | `FRS_funding_model_functions_drop_only.R` | ~400 | FRS-specific DROP program |

---

## Data Inputs from pendata

### params_env Contents (188 objects)
- **71 tibbles**: Actuarial tables (mortality, separation, salary, benefits)
- **93 numeric scalars**: Rates, factors, percentages (e.g., `dr_current_`, `cola_tier_1_active_`)
- **8 character strings**: Class names, identifiers
- **7 integers**: Years, periods
- **5 data.frames**: Legacy format tables
- **3 lists**: Nested structures (funding data, amortization layers)
- **1 logical**: Boolean flags

### Critical Stacked Tables
Tables with `class` column (already generalizable structure):

#### 1. **entrant_profile_table**
```r
# Entry age distribution for new hires
Columns: class, entry_age, start_sal, entrant_dist
Purpose: Generate new entrants each year
```

#### 2. **salary_headcount_table**
```r
# Current active population (as of valuation date)
Columns: class, entry_year, entry_age, age, yos, entry_salary, count
Purpose: Starting point for workforce projection
```

#### 3. **mort_table**
```r
# Mortality rates for active and terminated members
Columns: class, entry_year, entry_age, dist_year, dist_age, yos,
         term_year, tier_at_dist_age, mort_final
Purpose: Calculate annuity factors and project deaths
```

#### 4. **mort_retire_table**
```r
# Mortality for current retirees
Columns: class, base_age, age, year, mort_final
Purpose: Project retiree population
```

#### 5. **separation_rate_table**
```r
# Termination and retirement probabilities
Columns: class, entry_year, entry_age, term_age, yos,
         separation_rate, remaining_prob
Purpose: Workforce transitions
```

#### 6. **salary_growth_table**
```r
# Merit-based salary increases by years of service
Columns: class, yos, cumprod_salary_increase
Purpose: Project individual salary trajectories
```

### Benefit Rule Lookup Tables

#### 7. **tier_table**
```r
# Assigns tier/status to each member based on hire date, age, YOS
Columns: class, entry_year, age, yos, tier
Values: "tier_1_non_vested", "tier_2_early", "tier_3_norm", etc.
Issue: Tier is encoded as STRING, not ID - hard to generalize
```

**Tier System** (FRS-specific):
- **3 tiers** based on hire date (roughly: pre-2011, 2011-2018, post-2018)
- **5 vesting statuses**: `non_vested`, `vested`, `early`, `norm`, `reduced`
- **15 combinations**: Cartesian product of tier × status

#### 8. **ben_mult_lookup**
```r
# Benefit multipliers for pension formula
Columns: class, tier_at_dist_age, dist_age_min_ge, dist_age_max_lt,
         yos_min_ge, yos_max_lt, dist_year_min_ge, dist_year_max_lt,
         ben_mult
Purpose: Determine accrual rate (e.g., 1.6% per year of service)
Example: Special class tier_1_norm has 3.0% multiplier
```

#### 9. **reduce_factor_lookup**
```r
# Early retirement reduction factors
Columns: class, tier_at_dist_age, dist_age, reduce_factor
Purpose: Reduce benefits for early retirement (e.g., 5% per year before NRA)
```

#### 10. **dr_lookup**
```r
# Discount rates by tier
Columns: tier_at_dist_age, dr
Logic: tier_3 uses dr_new_ (6.9%), others use dr_current_ (7.0%)
```

#### 11. **cola_lookup**
```r
# COLA rates by tier, entry year, YOS
Columns: tier_at_dist_age, entry_year, yos, cola
Purpose: Post-retirement benefit increases
```

#### 12. **fas_period_lookup**
```r
# Final Average Salary period (e.g., highest 5 or 8 years)
Columns: tier_at_dist_age, fas_period
```

#### 13. **db_dc_legacy_table** & **db_dc_new_table**
```r
# Allocation to DB vs. DC plans by hire year
Columns: class, year_ll, year_ul, db_legacy, db_new, dc_legacy, dc_new
Purpose: Split population into 4 sub-groups with different funding
Note: Legacy uses dr_current_, new uses dr_new_
```

### Key Scalars (Sample)
```r
dr_current_               # 0.070 - discount rate for legacy members
dr_new_                   # 0.069 - discount rate for new members
dr_old_                   # Historical rate
cola_tier_1_active_       # 0.03 - COLA for tier 1
cola_tier_2_active_       # 0.03
cola_tier_3_active_       # 0.00 - No COLA for tier 3
db_ee_cont_rate_          # 0.03 - Employee contribution rate
special_er_dc_cont_rate_  # 0.03 - ER DC contrib for special class
admin_er_dc_cont_rate_    # 0.065
payroll_growth_           # 0.0325 - System-wide payroll growth
amo_period_new_           # 30 - Amortization period for new bases
smooth_years_             # 5 - Asset smoothing period
return_scen_              # 1 - Which return scenario to use
init_funded_ratio_        # 0.84 - Starting funded ratio
```

---

## Current Data Structures

### Hard-Coded FRS Elements

#### Employee Classes
```r
# Defined in params:
class_names_no_drop_frs_ <- c("regular", "special", "admin", "eco",
                               "eso", "judges", "senior_management")
class_names_ <- c(class_names_no_drop_frs_, "drop")
```
**Issue**: 7 classes are hard-coded; code filters/loops over these explicitly.

#### Tier System as Strings
```r
# Logic scattered throughout:
if_else(str_detect(tier_at_dist_age, "tier_1"), cola_tier_1_active_, ...)
if_else(str_detect(tier_at_term_age, "early|norm|reduced"), 1, 0)
filter(tier_at_dist_age == "tier_2_early")
```
**Issue**: String pattern matching prevents easy addition of new tiers/benefit structures.

#### Class-Specific Logic
```r
# In benefit model:
mutate(ref_year = if_else(class == "admin", 2015, 2020))

# Special class early retirement:
case_when(
  term_status == "early" & class == "special" ~ [special formula],
  ...
)

# DC contribution rates:
special_er_dc_cont_rate_
admin_er_dc_cont_rate_
eco_er_dc_cont_rate_
# ... separate scalar for each class
```
**Issue**: Adding a new class requires code changes, not just data updates.

#### DROP (Deferred Retirement Option Program)
```r
# Entire file: FRS_funding_model_functions_drop_only.R
# DROP members are retirees who remain "active" for accounting
# Highly FRS-specific feature
```
**Issue**: DROP is mandatory, not optional. Other plans won't have this.

### Generalizable Structures

#### Population Arrays (Workforce Model V3)
```r
# Universal to all pension models:
wf_active[entry_age, age, year]                          # 3D
wf_term[entry_age, age, year, term_year]                 # 4D
wf_refund[entry_age, age, year, term_year]               # 4D
wf_retire[entry_age, age, year, term_year, retire_year]  # 5D
```
These dimensions are plan-agnostic.

#### Benefit Calculation Pipeline
```r
# All stacked tibbles with class column:
salary_benefit_table  # Salary projections by entry cohort
annuity_factor_table  # Annuity factors with mort/DR/COLA
benefit_table         # DB benefits at all term/dist ages
benefit_val_table     # PV calculations with separation probs
```
Structure works for any DB plan with different parameter values.

#### Actuarial Methods
```r
# Entry Age Normal - Cost Proration (universal method):
indv_norm_cost = pvfb_db_wealth_at_entry_age / ann_factor_at_entry_age

# AAL Roll-Forward (standard actuarial approach):
AAL[t] = AAL[t-1] × (1 + dr) + (NC - Ben - Ref) × (1 + dr)^0.5 + Gain/Loss

# Asset Smoothing (common public plan approach):
AVA[t] = expected_AVA + (MVA - expected_AVA) / smooth_years
AVA[t] = cap(AVA, MVA × [0.80, 1.20])  # Corridor
```

---

## Model Components

### 1. BENEFIT MODEL
**File**: `FRS_benefit_model_functions.R`
**Environment**: `bm_env`

#### Purpose
Calculate individual normal costs and benefit values for each entry cohort (age × entry_year).

#### Key Functions

##### `get_salary_benefit_table_s()`
Projects salary trajectories for all cohorts:
```r
# For each entry_age × entry_year × age × yos:
salary[a] = entry_salary × cumprod_salary_increase[yos] × (1 + payroll_growth)^years_since_entry

# Final Average Salary:
fas = mean(highest N salaries)  # N from fas_period_lookup
```

##### `get_annuity_factor_table_s()`
Builds annuity factors incorporating mortality, discount rate, COLA:
```r
# Temporary life annuity:
ann_temp = sum_{k=0}^{death} (1 + cola)^k / [(1 + dr)^k × survival_prob_k]

# Permanent annuity for retirement:
ann_factor = sum_{age=dist_age}^{120} (1 + cola)^(age-dist_age) /
                                        [(1 + dr)^(age-dist_age) × survival_prob]
```

##### `get_benefit_table_s()`
Calculates DB benefits using FRS formula:
```r
annual_benefit = yos × ben_mult × fas × reduce_factor × cal_factor

# Where:
# - ben_mult: From ben_mult_lookup (e.g., 1.6% for regular, 3.0% for special)
# - reduce_factor: From reduce_factor_lookup (e.g., 0.95 for 1 year early)
# - cal_factor: Calibration to match valuation report (e.g., 0.93)
```

##### `get_benefit_val_table_s()`
Computes present values and normal costs:
```r
# PV of future benefits at termination age:
pvfb_db_wealth_at_term_age = annual_benefit × ann_factor / (1 + dr)^(dist_age - term_age)

# Normal cost (Entry Age Normal method):
indv_norm_cost = pvfb_db_wealth_at_entry_age / ann_factor_at_entry_age

# Expected PV at current age (incorporates separation probabilities):
pvfb_db_wealth_at_current_age = sum_{term_age} [pvfb_at_term × prob_separate_at_term]
```

#### Outputs
- **`salary_benefit_table`**: Salary projections for all cohorts
- **`benefit_val_table`**: Has columns:
  - `indv_norm_cost`: Individual normal cost (annual)
  - `pvfb_db_wealth_at_current_age`: Expected PVFB
  - `annual_benefit`: Benefit at each termination age
  - `separation_rate`, `remaining_prob`: For weighting
- **`agg_norm_cost_table`**: Aggregated NC rate by class

#### FRS-Specific Elements
- `cal_factor_`: Applied to all benefits to calibrate to valuation
- Three discount rates: `dr_current_` (7.0%), `dr_new_` (6.9%), `dr_old_`
- Three COLA tiers: 3%, 3%, 0% for active members
- One-time COLA: `one_time_cola_`, `cola_current_retire_one_`
- Admin class uses 2015 reference year instead of 2020

---

### 2. WORKFORCE MODEL
**File**: `FRS_workforce_model_functions_V3.R`
**Environment**: `wfm_env`

#### Purpose
Project population flows year-by-year using fast array operations.

#### Architecture
Matrix-based approach with transition matrices (TM):
```r
# Aging via matrix multiplication:
population[age+1] = TM %*% population[age]

# Where TM is an identity matrix shifted by 1:
TM[i, i-1] = 1  # Moves age i-1 → age i
```

#### Core Loop: `propagate_workforce()`
```r
For each year t in 1:model_period:

  1. SEPARATE actives:
     new_separations = wf_active[ea, a, t] × sep_rate[ea, a, t]
     wf_active[ea, a, t] -= new_separations

  2. AGE all populations (via TM matrix multiplication):
     wf_active = shift_with_TM(wf_active)
     wf_term = shift_with_TM(wf_term)
     wf_retire = shift_with_TM(wf_retire)

  3. ADD new entrants:
     wf_active[ea, ea, t] = n_entrants × entrant_dist[ea]
     n_entrants = base_entrants × (1 + pop_growth)^t

  4. MORTALITY:
     wf_term -= wf_term × mort_rate_term
     wf_retire -= wf_retire × mort_rate_retire

  5. SPLIT separations → refunds vs. deferred:
     wf_refund[ea, a, t, t] = new_separations × refund_ratio
     wf_term[ea, a, t, t] = new_separations × (1 - refund_ratio)

  6. RETIRE deferred vested when eligible:
     new_retirees = wf_term[ea, a, t, term_yr] × retire_rate[ea, a, term_yr]
     wf_retire[ea, a, t, term_yr, t] = new_retirees
     wf_term -= new_retirees
```

#### Probability Arrays
Built once before the loop, then indexed during projection:
```r
sep_array[entry_age, age, year]              # From separation_rate_table
mort_array_term[ea, age, year, term_year]    # From mort_table
retire_array[ea, age, year, term_year]       # Retirement election probs
refund_array[ea, age, year, term_year]       # Refund election probs
```

#### Helper Functions

##### `shift_with_TM()`
Ages population by 1 year via matrix multiplication:
```r
# For 3D array [entry_age, age, year]:
for (ea in entry_ages) {
  for (yr in years) {
    array[ea, , yr] = TM %*% array[ea, , yr]
  }
}
```

##### `make_position_matrix()`
Places new entrants at entry_age == age diagonal:
```r
PM[ea, ea] = 1  # All other elements = 0
wf_active += PM %*% new_entrants_vector
```

#### Outputs (DataFrames)
```r
wf_active_df:
  Columns: entry_age, age, year, n_active

wf_term_df:
  Columns: entry_age, age, year, term_year, n_term

wf_refund_df:
  Columns: entry_age, age, year, term_year, n_refund

wf_retire_df:
  Columns: entry_age, age, year, term_year, retire_year, n_retire
```

#### Key Parameters
- `retire_refund_ratio_`: Determines mix of vested separations (e.g., 0.25 = 25% take refund)
- `pop_growth_`: Annual growth rate for new entrants
- `one_year_overlap_`: Boolean for timing of transitions

#### Generalizability
**Highly generalizable**. The entire V3 architecture is plan-agnostic. Only the input tables (separation_rate_table, mort_table, etc.) are plan-specific. Any pension plan with similar data can use this engine.

---

### 3. LIABILITY MODEL
**File**: `FRS_liability_model_functions.R`
**Environment**: `lm_env`

#### Purpose
Calculate Actuarial Accrued Liability (AAL), normal costs, and benefit payments by aggregating workforce × benefit data.

#### Key Functions

##### `get_wf_active_df_final_s()`
Joins workforce and benefit tables, aggregates to class/year level:
```r
# Join:
wf_active_df + benefit_val_table
  → on (class, entry_age, age, year)

# Calculate:
payroll = n_active × salary
nc_dollars = n_active × indv_norm_cost
pvfb = n_active × pvfb_db_wealth_at_current_age
aal_active = pvfb - nc_dollars × ann_factor_remaining

# Split by DB/DC and legacy/new:
# Uses db_dc_legacy_table, db_dc_new_table to allocate populations
# → 4 sub-groups: db_legacy, db_new, dc_legacy, dc_new

# Aggregate by class, year:
sum(payroll), sum(nc_dollars), sum(aal_active)
```

##### `get_wf_term_df_final_s()`
Calculates AAL for deferred vested members:
```r
# For terminated members waiting to retire:
pvfb_term = n_term × annual_benefit_at_term × ann_factor_at_dist_age /
                                                (1 + dr)^(dist_age - current_age)

# AAL for term vested = PVFB (already accrued):
aal_term = pvfb_term
```

##### `get_wf_refund_df_final_s()`
Calculates refund payments:
```r
# Members who take lump-sum refund:
refund_payment = n_refund × employee_contributions_with_interest

# Simplified as:
refund_payment = n_refund × annual_benefit × constant_factor
```

##### `get_wf_retire_df_final_s()`
Projects benefit payments for new retirees:
```r
# COLA-adjusted benefits:
benefit_payment[retire_year + k] = annual_benefit_at_retire × (1 + cola)^k

# PVFB for new retirees (excludes current year payment):
pvfb_retire = annual_benefit × (ann_factor - 1)

# AAL = PVFB for retirees (no future NC)
```

##### `get_wf_retire_current_final_s()`
Projects current retirees (as of valuation date):
```r
# Starting from mort_retire_table (current retiree population):
benefit_payment = n_retirees × avg_benefit × (1 + cola)^(year - base_year)

# Apply mortality each year
pvfb_retire_current = sum of discounted future payments
```

##### `get_wf_term_current_s()`
Handles current term vested liability:
```r
# Amortize pre-existing term vested AAL:
# (Simplified treatment - gradually pays down over time)
```

##### `get_funding_df_s()`
**Master function** that combines all components and performs AAL roll-forward:

```r
# Combine all populations:
total_payroll = active_payroll
total_nc = active_nc
total_ben = retire_benefits
total_refund = refund_payments
total_aal = aal_active + aal_term + aal_retire

# Roll-forward logic:
For each year t:

  expected_aal[t] = aal[t-1] × (1 + dr) +
                    (nc[t] - ben[t] - refund[t]) × (1 + dr)^0.5

  # Mid-year assumption: (1 + dr)^0.5 for cash flows

  actual_aal[t] = sum(aal_active, aal_term, aal_retire, aal_term_current)

  gain_loss[t] = expected_aal[t] - actual_aal[t]

  # (Positive gain_loss = favorable experience)
```

#### Outputs
- **`funding_df_s`**: DataFrame with columns:
  - `class`, `year`
  - `payroll`, `nc_rate`, `nc_dollar`
  - `aal`, `ben`, `refund`
  - `gain_loss`
  - Separate columns for db_legacy, db_new, dc_legacy, dc_new

#### FRS-Specific Elements
- **Legacy vs. New split**: Parallel accounting with different discount rates
- **DB and DC tracking**: Though DC is unfunded (no AAL), still tracked for reporting
- **Current populations**: Separate handling of existing retirees/term vested vs. projections

#### Roll-Forward Formula
```r
AAL[t] = AAL[t-1] × (1 + dr) + (NC - Benefits - Refunds) × (1 + dr)^0.5 + Gain/Loss
```
This is standard actuarial practice (not FRS-specific).

---

### 4. FUNDING MODEL
**Files**:
- `FRS_funding_model_functions_loop_without_drop_V5.R` (main)
- `FRS_funding_model_functions_drop_only.R` (DROP module)
- `FRS_funding_amort.R` (amortization)

**Environment**: `fm_env`

#### Purpose
Project employer/employee contributions, investment returns, asset values (MVA and AVA), and funded ratios.

#### Architecture
Three-phase nested loop with optional DROP module:
```
Outer loop: years 1..model_period_
├── Phase 1: Liability side (per-class)
├── [Optional: DROP calculations]
├── Phase 2: Funding flows (per-class)
├── FRS-wide AVA smoothing
└── Phase 3: AVA allocation back to classes
```

#### Phase 1: Liability Side
**Function**: `inner_loop1_payroll_benefits()`

```r
For each class:
  For each year t:

    # Grow payroll:
    payroll[t] = payroll[t-1] × (1 + payroll_growth)

    # Extract from liability model:
    nc[t] = nc_rate × payroll[t]
    ben[t] = benefit_payments from funding_df_s
    refund[t] = refund_payments from funding_df_s

    # AAL roll-forward:
    aal_expected[t] = aal[t-1] × (1 + dr) +
                      (nc - ben - refund) × (1 + dr)^0.5

    aal[t] = from liability model (actual AAL)

    gain_loss[t] = aal_expected[t] - aal[t]
```

#### Phase 2: Funding Flows
**Function**: `inner_loop2_funding()`

```r
For each class:
  For each year t:

    # Contribution rates:
    nc_rate = nc_dollar / payroll
    ee_rate = db_ee_cont_rate_  # Constant (e.g., 3%)
    er_nc_rate = nc_rate - ee_rate + admin_exp_rate

    # Amortization payment:
    uaal[t] = aal[t] - ava[t]  # Unfunded liability
    amo_payment[t] = sum(amortization_layer_payments)  # From layered bases
    amo_rate[t] = amo_payment / payroll

    # Total ER rate:
    er_rate[t] = er_nc_rate + amo_rate + dc_er_rate

    # Cash flows:
    ee_cont = ee_rate × payroll
    er_cont = er_rate × payroll
    net_cf = ee_cont + er_cont - ben - refund - admin_exp

    # Investment return:
    roa = return_scenarios$roa[year, return_scen_]  # From scenarios table

    # Market Value of Assets (MVA):
    invest_income_mva = mva[t-1] × roa + net_cf × roa/2  # Mid-year
    mva[t] = mva[t-1] + invest_income_mva + net_cf

    # Solvency check:
    if (mva[t] < 0) {
      solvency_contribution = -mva[t]
      mva[t] = 0
    }
```

**Key**: MVA is calculated per-class, but AVA requires system-wide smoothing first (Phase 3).

#### Phase 3: AVA Smoothing & Allocation
**Function**: `inner_loop3_ava_development()`

**Step 1: FRS-Wide AVA** (`inner_frs_fund2()`):
```r
# Aggregate to system level:
frs_mva[t] = sum(class_mva[t] for all classes)
frs_net_cf[t] = sum(class_net_cf[t])

# Expected return on AVA:
expected_invest_income = ava[t-1] × dr_smooth + net_cf × dr_smooth/2

# Expected AVA:
expected_ava[t] = ava[t-1] + expected_invest_income + net_cf

# Actual market return:
actual_invest_income = mva[t] - mva[t-1] - net_cf

# Smoothing:
unexpected_return = actual_invest_income - expected_invest_income
recognized_gain = unexpected_return / smooth_years_  # 1/5 per year

# Smoothed AVA:
ava[t] = expected_ava + recognized_gain

# Corridor (80-120% of MVA):
ava[t] = pmin(pmax(ava[t], mva[t] × 0.80), mva[t] × 1.20)
```

**Step 2: Allocate AVA to Classes**:
```r
# Investment earnings to allocate:
frs_total_earnings = ava[t] - ava[t-1] - frs_net_cf[t]

# Allocate proportionally by class MVA:
class_ava_earnings[c] = frs_total_earnings × (class_mva[c] / frs_mva)

# Class AVA:
class_ava[c, t] = class_ava[c, t-1] + class_ava_earnings[c] + class_net_cf[c]
```

#### Amortization (`FRS_funding_amort.R`)

**Layered Amortization**:
```r
# Each year, create new amortization base for UAAL change:
new_base[t] = uaal[t] - uaal[t-1] + bases_paid_off[t]

# Current hire bases: closed period
# Future hire bases: open period = amo_period_new_ + funding_lag_

# Payment for each layer:
payment[layer] = base_amount × (1 + amo_pay_growth_)^age /
                                annuity_factor(period, dr, growth)

# Total amortization payment:
total_amo_payment[t] = sum(payment[layer] for all active layers)
```

**Key Parameters**:
- `amo_period_new_`: 30 years for new bases
- `amo_pay_growth_`: Payment growth rate (often = payroll_growth_)
- `funding_lag_`: Delay before starting payments (e.g., 2 years)

#### DROP Module (`FRS_funding_model_functions_drop_only.R`)

**What is DROP?**
- Deferred Retirement Option Program (FRS-specific)
- Members who are eligible to retire can "freeze" their pension and stay working
- Pension payments go into a DROP account (earning interest) instead of being paid out
- After leaving, member gets lump sum DROP account + monthly pension

**How it's modeled**:
```r
# DROP treated as separate "class" but inherits rates from Regular class:
drop_db_legacy_share = regular_db_legacy_ratio + regular_dc_legacy_ratio
drop_ben[t] = drop_ben[t-1] × (1 + regular_growth_rate)
drop_nc_rate = frs_nc_rate  # System-wide rate

# DROP assets reallocated to maintain funded ratios:
# Complex rebalancing logic to ensure system-wide consistency
```

**FRS-Specificity**: Entire module is highly FRS-specific. Most plans don't have DROP.

#### Outputs
- **`funding_list`**: List of DataFrames, one per class:
  - `year`, `payroll`, `nc_rate`, `ee_rate`, `er_rate`, `amo_rate`
  - `aal`, `mva`, `ava`, `uaal`, `funded_ratio_mva`, `funded_ratio_ava`
  - `ben`, `refund`, `ee_cont`, `er_cont`, `net_cf`
  - `invest_income_mva`, `roa`

- **`frs_fund`**: System-wide totals (aggregated across classes)

#### FRS-Specific Elements
1. **Dual discount rates**: `dr_current_` for legacy, `dr_new_` for new hires
2. **Four plan designs**: db_legacy, db_new, dc_legacy, dc_new
3. **DROP integration**: Separate calculations, reallocation of assets
4. **Class-specific DC rates**: `special_er_dc_cont_rate_`, `admin_er_dc_cont_rate_`, etc.

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ INPUTS (pendata::frs)                                           │
│ ├── Actuarial tables (stacked by class)                         │
│ ├── Parameters (scalars, lookups)                               │
│ └── Initial funding data                                        │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ BENEFIT MODEL (once, all classes together)                      │
│ ├── get_salary_benefit_table_s()                                │
│ ├── get_annuity_factor_table_s()                                │
│ ├── get_benefit_table_s()                                       │
│ └── get_benefit_val_table_s()                                   │
│                                                                  │
│ Output: benefit_val_table (with indv_norm_cost, pvfb)           │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ WORKFORCE MODEL (loop over classes)                             │
│ For each class:                                                 │
│   ├── Filter benefit_val_table → class-specific                 │
│   ├── Build probability arrays                                  │
│   ├── propagate_workforce() → population projections            │
│   └── Stack results with `class` column                         │
│                                                                  │
│ Output: wf_active_df, wf_term_df, wf_refund_df, wf_retire_df    │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ LIABILITY MODEL                                                  │
│ ├── Join workforce × benefits                                   │
│ ├── Split by DB/DC, legacy/new                                  │
│ ├── Aggregate by class/year                                     │
│ └── AAL roll-forward with gain/loss                             │
│                                                                  │
│ Output: funding_df_s (AAL, NC, benefits by class)               │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ FUNDING MODEL (nested loops with class lists)                   │
│ Outer loop: years 1..model_period_                              │
│   ├── Inner loop 1: Per-class liabilities, payroll              │
│   ├── Summarize to FRS-wide totals                              │
│   ├── [Optional: DROP calculations]                             │
│   ├── Inner loop 2: Per-class contributions, MVA                │
│   ├── FRS-wide AVA smoothing                                    │
│   └── Inner loop 3: Allocate AVA back to classes                │
│                                                                  │
│ Output: funding_list (by class), frs_fund (system totals)       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Generalization Assessment

### What's Already Generalizable ✓

#### 1. **Workforce Model V3** (100% generalizable)
- Array-based architecture is plan-agnostic
- Only inputs are actuarial tables (separation, mortality, etc.)
- Any pension plan can use this engine with different data

#### 2. **Core Benefit Calculations** (95% generalizable)
- PV formulas: `benefit × annuity_factor / discount_factor` → universal
- Annuity factors with mortality/DR/COLA → standard actuarial math
- Normal cost method (EAN-CP) → common public plan approach
- Only FRS-specific: calibration factors, admin class reference year

#### 3. **Liability Roll-Forward** (90% generalizable)
- AAL roll-forward formula is standard: `AAL[t] = AAL[t-1]×(1+dr) + NC - Ben + G/L`
- Aggregation logic (sum by class/year) → universal
- FRS-specific: legacy/new split with dual discount rates

#### 4. **Asset Smoothing** (95% generalizable)
- 5-year smoothing with 80-120% corridor → common method
- Two-step process (system-wide then allocate) → works for any multi-class plan
- Only FRS-specific: exact corridor percentages are parameters

#### 5. **Amortization** (80% generalizable)
- Layered amortization with closed periods → standard practice
- Growing payments → configurable
- FRS-specific: current vs. future hire split

### What's FRS-Specific ✗

#### 1. **DROP Module** (0% generalizable)
- Entire file `FRS_funding_model_functions_drop_only.R` is FRS-specific
- DROP is a unique Florida program (similar programs exist elsewhere but rare)
- **Fix**: Make DROP optional via feature flag

#### 2. **Tier System as Strings** (20% generalizable)
- `"tier_1_early"`, `"tier_2_norm"` → hard-coded string patterns
- Logic: `if_else(str_detect(tier, "tier_1"), ...)` scattered throughout
- **Fix**: Replace with `tier_id` integer + lookup table for tier properties

#### 3. **Hard-Coded Class Names** (10% generalizable)
- `class_names_ <- c("regular", "special", "admin", ...)`
- Code filters: `filter(class == "special")`, `if_else(class == "admin", ...)`
- **Fix**: Load class list from data, remove class-specific logic

#### 4. **Class-Specific Parameters** (30% generalizable)
- `special_er_dc_cont_rate_`, `admin_er_dc_cont_rate_`, etc. → one scalar per class
- **Fix**: Create `class_parameters` table: `class | param_name | param_value`

#### 5. **Legacy/New Split** (40% generalizable)
- FRS has 4 sub-populations: db_legacy, db_new, dc_legacy, dc_new
- Dual discount rates: `dr_current_` vs. `dr_new_`
- Separate amortization policies
- **Fix**: Generalize to `cohort_definitions` table with flexible sub-population tracking

#### 6. **Embedded Business Rules** (50% generalizable)
- Admin class has different reference year
- Special class has unique early retirement formula
- One-time COLA for current retirees
- **Fix**: Move all rules to lookup tables or configuration files

### Generalizability Score by Component

| Component | Generalizable | FRS-Specific | Notes |
|-----------|---------------|--------------|-------|
| **Workflow** | 80% | 20% | Just needs class list from data |
| **Benefit Model** | 75% | 25% | Core math is universal; tier logic is FRS |
| **Workforce Model** | 95% | 5% | Nearly perfect; only class loop is FRS |
| **Liability Model** | 85% | 15% | Legacy/new split is main FRS element |
| **Funding Model** | 60% | 40% | DROP and class-specific DC rates |
| **Amortization** | 80% | 20% | Standard method; current/future split is FRS |
| **Overall** | **75%** | **25%** | Core is solid; need to abstract FRS details |

---

## Rationalization Plan

### Vision
Create a **general pension model** where:
1. **Data-driven**: All plan-specific details in data files, not code
2. **Flexible**: Support variable number of classes, tiers, benefit formulas
3. **Modular**: Optional features (DROP, DC plans, special populations)
4. **Validated**: Schema for required data inputs with validation
5. **Portable**: Any plan with proper data can run through the model

### Phased Approach

---

### **PHASE 1: Foundation & Quick Wins** (4-6 weeks)
**Goal**: Migrate to better pendata structures and eliminate hard-coded FRS elements.

**Critical Priority**: Transition from legacy to better pendata structures before other refactoring. This is foundational - everything else builds on proper data structures.

---

#### 1.0 **Migrate to Better pendata Structures** (HIGHEST PRIORITY)

**Context**: pendata contains TWO sets of FRS data (see [Critical Context](#critical-context-pendata-dual-structure)):
- Legacy format (what this repo uses now)
- Better formal structures (what we should use)

**Task**: Review, improve, and migrate to better structures.

**Subtasks**:

**1.0.1 Inventory Current Usage**
- Document which legacy objects are used where in this repo
- Map: legacy object → better structure equivalent
- Identify gaps (objects used but no better equivalent yet)

**1.0.2 Review Better Structures**
- Examine `headcount_salary`, `benefit_rules`, `constants_assumptions_tbl`, etc.
- Validate they contain all needed information
- Identify improvements needed:
  - Missing columns?
  - Better age/yos granularity needed?
  - Additional metadata?
  - Schema formalization?

**1.0.3 Enhance Better Structures** (in pendata repo)
- Add any missing components
- Create explicit schema definitions (JSON/YAML)
- Add validation rules
- Document expected formats

**1.0.4 Update Model Code** (in this repo)
- Modify data prep files (*get_and_save*.R) to use better structures
- Update function signatures if needed
- Test that results match baseline (backward compatibility)

**1.0.5 Eliminate Legacy Structures** (in pendata repo)
- Once migration is complete and tested
- Remove legacy objects from `frs$params_env`
- Simplify pendata processing pipeline

**Example Migration**:
```r
# Legacy (current):
headcount_table_ <- params$headcount_table_  # 329 rows, coarse
# Columns: age, class, yos, count

# Better (target):
headcount_salary <- params$headcount_salary  # 847 rows, detailed
# Columns: class, age_label, age_lb, age_ub, yos_label, yos_lb, yos_ub,
#          headcount, salary

# Code changes needed:
# - Update data prep to handle range-based age/yos
# - Use age_lb/age_ub for binning instead of point values
# - Leverage richer metadata for validation
```

**Impact**:
- Foundation for all generalization work
- Eliminates data duplication in pendata
- Enables better validation and documentation
- Makes schema explicit and enforceable

**Timeline**: 2-3 weeks (this is the critical path)

---

#### 1.1 Replace Hard-Coded Class Lists
**Current**:
```r
class_names_ <- c("regular", "special", "admin", "eco", "eso", "judges", "senior_management", "drop")
```

**New**:
```r
# In pendata::frs$params_env, add:
class_list <- tibble(
  class = c("regular", "special", ...),
  class_display_name = c("Regular", "Special Risk", ...),
  is_active = TRUE  # For phasing out classes
)

# In model code:
class_names_ <- class_list %>% filter(is_active) %>% pull(class)
```

**Impact**: Any plan can now define its own class list in data.

---

#### 1.2 Create Class Parameters Table
**Current**:
```r
special_er_dc_cont_rate_ <- 0.030
admin_er_dc_cont_rate_ <- 0.065
eco_er_dc_cont_rate_ <- 0.030
...
```

**New**:
```r
# In pendata::frs$params_env:
class_parameters <- tibble(
  class = c("special", "special", "admin", ...),
  parameter = c("er_dc_cont_rate", "ee_cont_rate", "er_dc_cont_rate", ...),
  value = c(0.030, 0.03, 0.065, ...)
)

# Helper function:
get_class_param <- function(class_name, param_name, params) {
  params$class_parameters %>%
    filter(class == class_name, parameter == param_name) %>%
    pull(value)
}

# Usage:
er_dc_rate <- get_class_param("special", "er_dc_cont_rate", params)
```

**Impact**: Adding a new class requires data entry, not code changes.

---

#### 1.3 Add Benefit Rule ID to tier_table
**Current**:
```r
tier_table:
  class | entry_year | age | yos | tier
  special | 2010 | 30 | 5 | "tier_1_early"

# Logic in code:
if_else(str_detect(tier, "tier_1"), cola_tier_1, ...)
```

**New**:
```r
tier_table:
  class | entry_year | age | yos | tier_name | tier_id | status_id
  special | 2010 | 30 | 5 | "tier_1_early" | 1 | 3

benefit_rules:
  tier_id | status_id | cola_rate | discount_rate | fas_period | ...
  1 | 3 | 0.03 | 0.070 | 5 | ...

# Logic in code:
tier_info <- benefit_rules %>% filter(tier_id == t_id, status_id == s_id)
cola <- tier_info$cola_rate
```

**Impact**: Tiers are now extensible; can add tier_4, tier_5 without code changes.

---

#### 1.4 Remove Embedded Business Rules
**Current**:
```r
mutate(ref_year = if_else(class == "admin", 2015, 2020))
```

**New**:
```r
# Add to class_parameters:
class_parameters %>% add_row(class = "admin", parameter = "ref_year", value = 2015)
class_parameters %>% add_row(class = "regular", parameter = "ref_year", value = 2020)

# In code:
ref_year <- get_class_param(class_name, "ref_year", params)
```

**Impact**: All class-specific rules now in data, discoverable by inspection.

---

#### 1.5 Make DROP Optional
**Current**:
```r
# DROP is always calculated
source("FRS_funding_model_functions_drop_only.R")
# ... DROP logic runs regardless
```

**New**:
```r
# Add to params:
enable_drop_ <- TRUE  # Set to FALSE for non-FRS plans

# In funding model:
if (params$enable_drop_) {
  source("FRS_funding_model_functions_drop_only.R")
  drop_results <- calculate_drop(...)
} else {
  drop_results <- NULL  # Skip DROP
}
```

**Impact**: Non-FRS plans can disable DROP module entirely.

---

### **PHASE 2: Medium Effort** (1-2 months)
**Goal**: Generalize benefit formulas and data structures.

#### 2.1 Flexible Benefit Formula Structure
**Current**:
```r
# Hardcoded formula:
annual_benefit = yos × ben_mult × fas × reduce_factor × cal_factor
```

**New**:
```r
# Define formula types:
benefit_formulas:
  formula_id | formula_type | description
  1 | "flat_mult_fas" | "YOS × Mult × FAS"
  2 | "tiered_mult" | "Different mult by YOS ranges"
  3 | "high_3_avg" | "Average of highest 3 years"

# Link tiers to formulas:
benefit_rules:
  tier_id | formula_id | multiplier | fas_period | ...

# In code:
benefit <- switch(formula_type,
  "flat_mult_fas" = yos * mult * fas * reduce * cal,
  "tiered_mult" = calculate_tiered_benefit(yos, mult_table, fas),
  ...
)
```

**Impact**: Can support different benefit formulas (final average, career average, hybrid).

---

#### 2.2 Variable Number of Tiers/Cohorts
**Current**:
```r
# Assumes exactly 3 tiers
cola <- case_when(
  tier == 1 ~ cola_tier_1,
  tier == 2 ~ cola_tier_2,
  tier == 3 ~ cola_tier_3
)
```

**New**:
```r
# benefit_rules table already handles arbitrary tiers
cola <- benefit_rules %>%
  filter(tier_id == current_tier_id) %>%
  pull(cola_rate)
```

**Impact**: Plans can have 2, 3, 5, or any number of tiers.

---

#### 2.3 Generalize Legacy/New Split
**Current**:
```r
# Hard-coded 4 sub-populations:
db_dc_legacy_table, db_dc_new_table
→ db_legacy, db_new, dc_legacy, dc_new
```

**New**:
```r
# Flexible sub-population definitions:
population_cohorts:
  cohort_id | class | hire_year_min | hire_year_max |
  plan_type | discount_rate | amortization_policy
  1 | regular | 1980 | 2011 | DB | 0.070 | legacy_closed
  2 | regular | 2012 | 2017 | DB | 0.069 | new_open
  3 | regular | 2018 | 2030 | Hybrid | 0.069 | new_open

# In code:
# Assign cohort to each member:
member_cohort <- population_cohorts %>%
  filter(class == m_class,
         hire_year_min <= m_hire_year,
         hire_year_max >= m_hire_year)

# Use cohort's DR and amortization policy
```

**Impact**: Can track any number of sub-populations with different funding.

---

#### 2.4 Separate pendata from Model Logic
**Current**:
```r
# Model directly accesses pendata::frs$params_env
params <- list2env(as.list(pendata::frs$params_env))
```

**New**:
```r
# Generic data loading function:
load_plan_data <- function(plan_name, data_source = "pendata") {
  if (data_source == "pendata") {
    # Load from R package
    data <- pendata::get_plan_data(plan_name)
  } else if (data_source == "csv") {
    # Load from CSV files
    data <- read_plan_csv(plan_name)
  } else if (data_source == "excel") {
    # Load from Excel
    data <- read_plan_excel(plan_name)
  }

  # Validate schema
  validate_plan_data(data)

  return(data)
}

# Usage:
params <- load_plan_data("frs", "pendata")  # FRS from package
params <- load_plan_data("calpers", "csv")  # CalPERS from files
```

**Impact**: Model can work with any data source, not just pendata package.

---

### **PHASE 3: Major Refactor** (2-3 months)
**Goal**: Full abstraction of benefit formulas, funding policies, and plan features.

#### 3.1 Abstract Benefit Formula Evaluation
**Current**:
```r
# Single formula type hardcoded:
annual_benefit = yos × ben_mult × fas × reduce_factor × cal_factor
```

**New**:
```r
# Benefit formula engine:
calculate_benefit <- function(member, benefit_rule, salary_history) {

  formula_type <- benefit_rule$formula_type

  result <- switch(formula_type,

    "db_final_average" = {
      fas <- calculate_fas(salary_history, benefit_rule$fas_period)
      yos <- member$years_of_service
      mult <- benefit_rule$multiplier
      reduce <- get_reduction_factor(member, benefit_rule)
      yos * mult * fas * reduce
    },

    "db_career_average" = {
      avg_sal <- mean(salary_history)
      yos * benefit_rule$multiplier * avg_sal
    },

    "hybrid" = {
      db_portion <- calculate_benefit(member, benefit_rule$db_component)
      dc_portion <- member$dc_account_balance
      db_portion + dc_portion
    },

    "cash_balance" = {
      member$cash_balance_account * benefit_rule$annuity_factor
    },

    stop("Unknown formula type: ", formula_type)
  )

  return(result)
}
```

**Impact**: Can model DB, DC, hybrid, cash balance plans with different formulas.

---

#### 3.2 Configurable Funding Policies
**Current**:
```r
# EAN-CP method hardcoded
indv_norm_cost = pvfb_at_entry / ann_factor_at_entry
```

**New**:
```r
# Define funding methods:
funding_methods:
  method_id | method_name | description
  1 | "EAN-CP" | "Entry Age Normal - Cost Proration"
  2 | "EAN-LP" | "Entry Age Normal - Level Percent"
  3 | "PUC" | "Projected Unit Credit"
  4 | "FIL" | "Frozen Initial Liability"

# In code:
nc <- switch(params$funding_method_id,
  1 = calculate_ean_cp(member, benefit),
  2 = calculate_ean_lp(member, benefit),
  3 = calculate_puc(member, benefit),
  ...
)
```

**Impact**: Support multiple actuarial cost methods.

---

#### 3.3 Plan Configuration Schema (YAML/JSON)
**Goal**: Define entire plan in a human-readable config file.

**Example**: `frs_config.yaml`
```yaml
plan:
  name: "Florida Retirement System"
  abbrev: "FRS"
  state: "FL"

classes:
  - name: "regular"
    display_name: "Regular Class"
    ee_contrib_rate: 0.03
    er_dc_contrib_rate: 0.0665

  - name: "special"
    display_name: "Special Risk"
    ee_contrib_rate: 0.03
    er_dc_contrib_rate: 0.030

tiers:
  - tier_id: 1
    name: "Tier 1 (pre-2011)"
    hire_date_max: "2011-06-30"
    discount_rate: 0.070
    cola_rate: 0.03
    fas_period: 5

  - tier_id: 2
    name: "Tier 2 (2011-2017)"
    hire_date_min: "2011-07-01"
    hire_date_max: "2017-06-30"
    discount_rate: 0.070
    cola_rate: 0.03
    fas_period: 8

benefit_formulas:
  regular:
    formula_type: "db_final_average"
    tier_1:
      multiplier: 0.016
      early_retirement_age: 62
      normal_retirement_age: 65
      reduction_rate: 0.05
    tier_2:
      multiplier: 0.016
      early_retirement_age: 65
      normal_retirement_age: 67
      reduction_rate: 0.05

features:
  enable_drop: true
  enable_dc: true
  enable_hybrid: false

funding:
  method: "EAN-CP"
  amortization_period: 30
  smoothing_period: 5
  corridor: [0.80, 1.20]
```

**Impact**: Complete plan definition in config; model code reads and executes.

---

#### 3.4 Data Validation Framework
**Goal**: Ensure data inputs meet requirements before running model.

```r
validate_plan_data <- function(params) {

  required_tables <- c(
    "entrant_profile_table",
    "salary_headcount_table",
    "separation_rate_table",
    "mort_table",
    "tier_table",
    "benefit_rules"
  )

  for (tbl_name in required_tables) {
    if (!tbl_name %in% names(params)) {
      stop("Missing required table: ", tbl_name)
    }
  }

  # Check columns:
  required_cols <- list(
    entrant_profile_table = c("class", "entry_age", "entrant_dist"),
    salary_headcount_table = c("class", "entry_year", "age", "count"),
    ...
  )

  for (tbl_name in names(required_cols)) {
    tbl <- params[[tbl_name]]
    missing_cols <- setdiff(required_cols[[tbl_name]], names(tbl))
    if (length(missing_cols) > 0) {
      stop("Table ", tbl_name, " missing columns: ", paste(missing_cols, collapse = ", "))
    }
  }

  # Check ranges:
  if (any(params$entrant_profile_table$entrant_dist < 0)) {
    stop("entrant_dist cannot be negative")
  }

  # Check class consistency:
  class_list <- unique(params$class_list$class)
  for (tbl_name in c("entrant_profile_table", "salary_headcount_table")) {
    tbl_classes <- unique(params[[tbl_name]]$class)
    invalid <- setdiff(tbl_classes, class_list)
    if (length(invalid) > 0) {
      stop("Table ", tbl_name, " has invalid classes: ", paste(invalid, collapse = ", "))
    }
  }

  message("✓ All data validation checks passed")
  return(TRUE)
}
```

**Impact**: Catch data errors before running expensive calculations; clear error messages.

---

### **PHASE 4: Documentation & Testing** (Ongoing)
**Goal**: Ensure model is usable, maintainable, and correct.

#### 4.1 Data Dictionary
Create comprehensive documentation of all required data inputs:

**Example**: `DATA_DICTIONARY.md`
```markdown
## Required Input Tables

### entrant_profile_table
**Purpose**: Distribution of entry ages for new hires

**Columns**:
- `class` (character): Employee class identifier
- `entry_age` (integer): Age at hire [20-70]
- `start_sal` (numeric): Starting salary for this entry age
- `entrant_dist` (numeric): Probability of entering at this age [0-1]

**Validation**:
- sum(entrant_dist) should equal 1.0 for each class
- All entry_ages should be between 20 and 70
- start_sal should be positive

**Example**:
| class | entry_age | start_sal | entrant_dist |
|-------|-----------|-----------|--------------|
| regular | 25 | 45000 | 0.15 |
| regular | 30 | 52000 | 0.25 |
```

#### 4.2 Example Plan
Create a minimal example plan for testing:

```r
# example_plan/
# ├── config.yaml
# ├── data/
# │   ├── entrant_profile.csv
# │   ├── current_active.csv
# │   ├── mortality.csv
# │   └── ...
# └── run_example.R

# run_example.R:
params <- load_plan_data("example", data_source = "csv",
                         data_dir = "example_plan/data/")
results <- run_pension_model(params)
```

#### 4.3 Unit Tests
Test core functions with known inputs/outputs:

```r
test_that("EAN-CP normal cost is correct", {
  member <- list(entry_age = 25, current_age = 30, salary = 50000)
  benefit <- list(annual_benefit = 20000, entry_pvfb = 100000)

  nc <- calculate_ean_cp(member, benefit, dr = 0.07)

  expect_equal(nc, expected_value, tolerance = 0.01)
})
```

#### 4.4 Regression Tests
Ensure refactoring doesn't break FRS results:

```r
# Save current FRS baseline:
baseline <- run_pension_model(pendata::frs)
saveRDS(baseline, "tests/frs_baseline.rds")

# After refactoring, compare:
test_that("Refactored model matches FRS baseline", {
  new_results <- run_pension_model(pendata::frs)
  baseline <- readRDS("tests/frs_baseline.rds")

  expect_equal(new_results$funded_ratio, baseline$funded_ratio, tolerance = 0.001)
  expect_equal(new_results$nc_rate, baseline$nc_rate, tolerance = 0.0001)
})
```

---

## Implementation Priorities

### **CRITICAL PATH: Phase 1.0 - Data Migration** (Weeks 1-3)
**Why critical**: All other work depends on proper data structures.

**Week 1: Inventory & Analysis**
1. ✓ **Create this document**
2. **Map legacy → better structures**: Document all legacy objects and their better equivalents
3. **Identify gaps**: What's in legacy but not in better structures?
4. **Review pendata better structures**: Deep dive into headcount_salary, benefit_rules, etc.

**Week 2: Enhancement & Schema**
1. **Enhance pendata better structures**: Add missing components, improve metadata
2. **Create schema definitions**: Formalize required tables/columns in JSON/YAML
3. **Add validation rules**: Ensure data quality at load time
4. **Document format specifications**: Clear guidance for future plans

**Week 3: Code Migration**
1. **Update data prep scripts**: Modify *get_and_save*.R files to use better structures
2. **Test backward compatibility**: Ensure results match baseline FRS outputs
3. **Create migration guide**: Document changes for future reference

### **Phase 1 Continuation** (Weeks 4-6)
**After data migration is complete:**

1. **Inventory hard-coded parameters**: Spreadsheet of every FRS-specific scalar/string
2. **Implement class_parameters table**: Move class-specific scalars to data
3. **Replace hard-coded class lists**: Load from data instead of code
4. **Add benefit_rule IDs**: Replace string pattern matching with lookup
5. **Make DROP optional**: Feature flag for FRS-specific module
6. **Test with variations**: Change class names, add tier, verify model adapts

### **Short-term: Phase 2** (Months 2-3)
1. **Flexible benefit formulas**: Support multiple formula types
2. **Variable tiers/cohorts**: Remove assumption of exactly 3 tiers
3. **Generalize legacy/new split**: Flexible sub-population tracking
4. **Create SimpleDB test plan**: Minimal plan with 1 class, 1 tier
5. **Data validation framework**: Catch errors before running model

### **Medium-term: Phase 3** (Months 4-6)
1. **Abstract benefit formula evaluation**: Engine for different formula types
2. **Configurable funding policies**: Support multiple actuarial methods
3. **Plan configuration files**: YAML/JSON for complete plan definition
4. **Add 2nd real plan**: Validate generalization with another public plan
5. **Performance optimization**: Array → tibble migration, benchmark improvements

### **Long-term: Production Ready** (Months 7-12)
1. **Performance Tier 1**: Restructure to sparse/tibble representations
2. **Performance benchmarking**: Compare to baseline, document any slowdowns
3. **Comprehensive testing**: Unit tests, integration tests, regression tests
4. **User documentation**: How to add a new plan, data format guide
5. **Julia exploration** (if needed): Prototype in Julia for performance comparison
6. **User interface**: Shiny app for scenario analysis (optional)

---

## Performance and Language Considerations

### Current Performance Challenges

**The Problem**: Original developers created **HUGE arrays** with up to 4 dimensions that become memory hogs and slow down execution.

**Example from Workforce Model V3**:
```r
wf_active[entry_age, age, year]                          # 3D array
wf_term[entry_age, age, year, term_year]                 # 4D array
wf_retire[entry_age, age, year, term_year, retire_year]  # 5D array
```

For FRS with:
- Entry ages: 20-70 (51 values)
- Ages: 20-120 (101 values)
- Years: 30 periods
- Term years: 30 values
- Retire years: 30 values

The `wf_retire` array alone: **51 × 101 × 30 × 30 × 30 = 139M elements** (potentially 1+ GB in memory)

### Optimization Strategy Hierarchy

**Before considering language migration, explore optimization in R:**

#### **Tier 1: Restructure to Avoid Massive Arrays** (Highest priority)
- Use **sparse representations** - most pension array elements are zero
- Convert arrays → **data.frames/tibbles** with only non-zero entries
- Example: Instead of 5D array, use tibble with columns: `entry_age, age, year, term_year, retire_year, n_retire`
- This could reduce memory from 139M floats to ~10K rows (>99% reduction)
- Trade-off: Indexing becomes joins/filters instead of array lookup

**Potential approach:**
```r
# Current (array):
n_retire_value <- wf_retire[ea, a, yr, term_yr, ret_yr]

# Sparse (tibble):
n_retire_value <- wf_retire_df %>%
  filter(entry_age == ea, age == a, year == yr,
         term_year == term_yr, retire_year == ret_yr) %>%
  pull(n_retire) %>%
  sum()  # Returns 0 if no rows match
```

**Benefits:**
- Massive memory savings
- Potentially faster (smaller working set)
- More transparent (can inspect data easily)
- Already moving this direction (V3 outputs are data.frames)

#### **Tier 2: Alternative Storage in R** (If restructuring insufficient)
- **DuckDB**: In-memory SQL database optimized for analytics
  - Columnar storage for large data
  - Fast aggregations and joins
  - Can handle data larger than RAM (spills to disk)
  - Integrates with R via `duckdb` package

- **data.table**: Already using this; could leverage more
  - Extremely fast for large data operations
  - Keys for fast lookups
  - Reference semantics (modify in place, no copies)

- **arrow/parquet**: For disk-based storage of large intermediate results
  - Columnar format, compressed
  - Fast read/write
  - Good for checkpointing during long runs

#### **Tier 3: Alternative Languages** (If R fundamentally limited)

**Julia** (most promising):
- **Pros**:
  - Fast as C, flexible as Python/R
  - Multiple dispatch (elegant for benefit formula variations)
  - Native arrays with excellent performance
  - Growing actuarial ecosystem
  - Can call R code via `RCall.jl`
  - Similar syntax to R (easier migration)

- **Cons**:
  - Smaller ecosystem than R
  - Team learning curve
  - Fewer pension-specific packages
  - Package precompilation delays

**Python** (alternative):
- **Pros**:
  - Huge ecosystem (NumPy, Pandas, Polars)
  - Excellent performance with Numba/JAX
  - Many actuarial tools emerging
  - Large community support

- **Cons**:
  - R → Python migration more disruptive
  - Different paradigms (less functional)

**Recommendation**: **Try Tier 1 first (restructuring)** before considering language migration. The array → tibble transition is already partially underway in V3.

### Backward Compatibility Strategy

**Decision**: Maintain backward compatibility unless we find errors or clearly better methods.

**Implementation**:
- Continue running tests against prior results
- Establish tolerance levels:
  - **Funded ratio**: within 0.1% (e.g., 84.0% vs. 84.1% acceptable)
  - **Normal cost rate**: within 0.01% (e.g., 5.23% vs. 5.24% acceptable)
  - **Absolute dollars**: within 0.1% or $1M, whichever is larger

**Challenge**: As data structures change, maintaining exact comparisons becomes difficult.

**Solution**:
- Save baseline results as **summary statistics** (funded ratio, NC rate, total AAL, etc.) not full arrays
- Compare outputs at aggregated level (class/year totals), not individual cells
- Document any intentional changes with rationale

### Data Source Strategy

**Decision**: Use pendata as primary source.

**Rationale**:
- pendata ensures data quality for "official" plans
- Version control for plan data
- Comprehensive testing and validation
- Can handle hard work of converting CSV/Excel to standard formats

**Implementation**:
- Plans are maintained in pendata repository
- This modeling repo depends on pendata package
- pendata does the ETL (Extract-Transform-Load) from source files
- Standard schema enforced by pendata processing pipeline

---

## Decisions Made

### 1. **Focus Area**: Phase 1 First (Low-Hanging Fruit)
**Decision**: Prioritize Phase 1 quick wins before Phase 2/3.

**Phase 1 priorities:**
- Replace hard-coded class lists with data-driven approach
- Create class_parameters table
- Add benefit_rule_id to tier_table
- Remove embedded business rules
- Make DROP optional

### 2. **Data Migration Priority**: Use Better pendata Structures
**Critical clarification**: "Separate data loading" in original Phase 2 was misunderstood.

**Actual task**:
- Migrate this repo from **legacy pendata structures** to **better pendata structures**
- Review better structures (headcount_salary, benefit_rules, constants_assumptions_tbl, etc.)
- Improve better structures further if needed
- Update model code to use better structures
- Eliminate legacy structures once migration complete

**This is now a Phase 1 priority** - foundational for everything else.

### 3. **Scope**: DB Plans First
**Decision**: Focus on defined benefit (DB) plans initially.

**Future expansion**:
- Eventually support DC, hybrid, and cash balance
- But not in initial generalization phase
- Ensures we get DB right before expanding

### 4. **Example Plan**: Create Simple Test Plan
**Decision**: Create a minimal test plan rather than finding existing simple plan.

**Rationale**: Hard to find sufficiently simple real plan.

**Approach**:
- Create "SimpleDB" plan with:
  - 1-2 employee classes
  - 1 tier
  - Simple benefit formula
  - Minimal complexity
- Use for testing generalization
- Validates that model works with non-FRS data

### 5. **Backward Compatibility**: Yes, Unless Errors Found
**Decision**: Maintain backward compatibility with FRS results.

**Exceptions**: If we find:
- Actual errors in calculations
- Clearly better methods that justify change
- Document and justify any deviations

**Testing approach**: Continue running tests against prior results (see Performance section above for tolerance levels).

### 6. **Data Source**: pendata Only
**Decision**: Use pendata as the authoritative data source.

**Implementation**: pendata handles CSV/Excel → standardized format conversion.

### 7. **Performance**: Get Generality Right, Then Optimize
**Decision**: Prioritize correctness and generality over raw speed initially.

**Strategy**: Look for speedups along the way, but don't sacrifice design for premature optimization.

**Long-term**: Restructure to avoid massive arrays (Tier 1) before considering Julia/Python (Tier 3).

---

## Next Steps

### **WEEK 1: Inventory & Map Data Structures** (Immediate Priority)

**Goal**: Understand the legacy → better structure mapping

1. **Create legacy object inventory**
   - List all objects from `params_env` used by this repo
   - Document where each is used (which files, which functions)
   - Categorize: tables, scalars, lookups, etc.

2. **Map to better structures**
   - For each legacy object, identify better structure equivalent
   - Example: `headcount_table_` → `headcount_salary`
   - Flag objects with no better equivalent (gaps)

3. **Analyze better structures** (in pendata repo)
   - Review `headcount_salary`, `benefit_rules`, `constants_assumptions_tbl`
   - Validate completeness (all needed data present?)
   - Identify enhancement opportunities

4. **Document findings**
   - Create mapping spreadsheet: legacy_name | better_name | differences | issues
   - List gaps that need to be filled in pendata
   - Propose enhancements to better structures

**Deliverable**: Data structure mapping document ready for Week 2 enhancements.

---

### **WEEK 2-3: Implement Data Migration**

After Week 1 mapping is complete:

1. **Enhance pendata structures** (in pendata repo)
   - Add missing tables/columns identified in Week 1
   - Create schema definitions (JSON/YAML)
   - Add validation tests

2. **Update data prep scripts** (in this repo)
   - Modify `FRS_benefit_model_get_and_save_bendata.R` to use better structures
   - Modify `FRS_workforce_model_get_and_save_wfdata_GC_s.R`
   - Modify `FRS_liability_model_get_and_save_liabdata.R`

3. **Test backward compatibility**
   - Run model with better structures
   - Compare results to baseline
   - Ensure outputs match within tolerance

4. **Document migration**
   - Create migration guide for future plans
   - Update this document with lessons learned

**Deliverable**: Model successfully running on better pendata structures.

---

### **WEEK 4-6: Complete Phase 1**

After data migration:

1. **Hard-coded parameter cleanup**
   - Create comprehensive parameter inventory spreadsheet
   - Implement `class_parameters` table
   - Move class-specific scalars to data
   - Replace hard-coded class lists

2. **Optional DROP**
   - Add `enable_drop_` feature flag
   - Test model without DROP
   - Verify non-FRS plans can disable it

3. **Testing & Validation**
   - Test with modified FRS (different class names, additional tier)
   - Verify model adapts to data changes
   - Update regression tests

**Deliverable**: Phase 1 complete - foundation for generalization established.

---

### **Ongoing: Analysis & Documentation**

**Performance Benchmarking**:
- Baseline: Time current model execution
- After each phase: Re-benchmark and document any slowdowns
- Identify bottlenecks for optimization

**Code Coverage Analysis**:
- Which files/functions still have FRS-specific hard-coding?
- Track progress toward full generalization
- Update refactor priority as work progresses

**Documentation Updates**:
- Keep this document current as insights emerge
- Document all architectural decisions
- Maintain data dictionary for better structures

---

## Appendices

### A. File Summary

| File | Lines | FRS-Specific % | Refactor Priority |
|------|-------|----------------|-------------------|
| `FRS_new_workflow.R` | 82 | 20% | Low - mostly scaffolding |
| `FRS_benefit_model_functions.R` | ~500 | 30% | Medium - tier logic |
| `FRS_workforce_model_functions_V3.R` | ~800 | 5% | Low - very general |
| `FRS_liability_model_functions.R` | ~600 | 20% | Medium - legacy split |
| `FRS_funding_amort.R` | ~200 | 25% | Medium - current/future |
| `FRS_funding_model_functions_loop_without_drop_V5.R` | ~900 | 40% | High - class loops |
| `FRS_funding_model_functions_drop_only.R` | ~400 | 100% | High - make optional |

### B. Parameter Inventory (Partial)
**Scalars** (93 total):
- Discount rates: `dr_current_`, `dr_new_`, `dr_old_`, `dr_current_retire_`, `dr_new_retire_`
- COLAs: `cola_tier_1_active_`, `cola_tier_2_active_`, `cola_tier_3_active_`, `one_time_cola_`
- Contribution rates: `db_ee_cont_rate_`, `special_er_dc_cont_rate_`, `admin_er_dc_cont_rate_`, ...
- Growth rates: `payroll_growth_`, `pop_growth_`, `amo_pay_growth_`
- Calibration: `cal_factor_`, `retire_refund_ratio_`
- Funding: `init_funded_ratio_`, `smooth_years_`, `amo_period_new_`
- Model control: `model_period_`, `return_scen_`, `enable_drop_`

**Strings** (8 total):
- `class_names_`, `class_names_no_drop_frs_`
- `one_year_overlap_` (character, not logical - strange!)

**Key insight**: Many scalars should be in class_parameters table (e.g., all `*_er_dc_cont_rate_`).

### C. Glossary
- **AAL**: Actuarial Accrued Liability - present value of benefits already earned
- **AVA**: Actuarial Value of Assets - smoothed asset value (reduces volatility)
- **DR**: Discount Rate - assumed investment return for PV calculations
- **EAN-CP**: Entry Age Normal - Cost Proration - actuarial funding method
- **FAS**: Final Average Salary - average of highest N years
- **MVA**: Market Value of Assets - actual current market value
- **NC**: Normal Cost - cost of benefits earned in current year
- **PVFB**: Present Value of Future Benefits
- **UAAL**: Unfunded AAL = AAL - AVA
- **YOS**: Years of Service

---

**End of Document**

**Created**: 2026-02-16
**Last Updated**: 2026-02-16 (Added pendata dual structure analysis, pentools review, decisions, and updated Phase 1 priorities)
