rm(list = ls())
.libPaths("C:/Users/Don-business/R/win-library/4.5")  # personal library path

# --- Libraries ---------------------------------------------------------------
library(tidyverse)
library(data.table)
library(purrr)
# remove.packages("pentools");devtools::install_github("gchen3/pentools")
library(pentools)
# remove.packages("pendata"); devtools::install_github("donboyd5/pendata")
library(pendata)

# --- Paths -------------------------------------------------------------------
iddir    <- here::here("refactor", "interim_data")
rdir     <- here::here("refactor", "R")
sddir    <- here::here("refactor", "source_data")
tooldir  <- here::here("refactor", "tools")
wddir    <- here::here("refactor", "working_data")
xidir    <- here::here("refactor", "source_data", "Reports", "extracted inputs")
stackdir <- here::here("refactor", "stacked_data")
outdir   <- here::here("refactor", "new_results")

if (!dir.exists(outdir)) dir.create(outdir, recursive = TRUE)

# --- Load model parameters from Pandata -----------------------------------
params_env <- new.env()
params <- list2env(as.list(pendata::frs$params_env))

params$component_meta <- readxl::read_excel(
  here::here("refactor","R","component.xlsx"),
  sheet = "component_meta"
)

params$plan_alloc <- readxl::read_excel(
  here::here("refactor","R","component.xlsx"),
  sheet = "plan_alloc"
)

params$ref_year <- readxl::read_excel(
  path  = here::here("refactor", "R", "component.xlsx"),
  sheet = "salary_proj_reference_year"
)

params$get_fas <- function(salary_vec, fas_period) {
  x <- c(NA_real_, salary_vec[-length(salary_vec)])  # lag 1, preserve length
  RcppRoll::roll_mean(x, n = fas_period, align = "right", fill = NA_real_)
}

params$tier_table <- params$tier_table %>%
  dplyr::mutate(
    is_norm_retire_elig = tier %in% c("tier_1_norm", "tier_2_norm", "tier_3_norm"),
    vested_at_term = grepl("vested", tier, fixed = TRUE) &
      !grepl("non_vested", tier, fixed = TRUE)
  )

# --- TIER 1 MIGRATION: Load helpers and convert better structures to legacy format ---
message("Loading helper functions and applying Tier 1 adapters...")
source(fs::path(rdir, "FRS_helper_functions.R"))

# Apply adapters to convert better structures to legacy format
# This allows existing functions to work unchanged while using better pendata internally
params$salary_growth_table  <- convert_salarygrowth_to_legacy(params$salarygrowth)
message("  ✓ Migrated salary_growth_table from better structure 'salarygrowth'")

params$retiree_distribution <- convert_retirees_to_legacy(params$retirees)
message("  ✓ Migrated retiree_distribution from better structure 'retirees'")

# --- TIER 2 MIGRATION: benefit_rules and computed lookup tables ---------------
# Replace Gang's legacy lookup tables with versions built from pendata better
# structures or computed from existing params constants.

# 1. ben_mult_lookup <- benefit_rules (adapter: column reshape + tier expansion)
# ---------------------------------------------------------------------------
# TEMP PATCH: pendata benefit_rules has incorrect/incomplete data for tier_2
# (all classes) and is missing tier_3 entirely.  Only tier_1 data is reliable.
# Save the legacy tier_2 + tier_3 rows BEFORE overwriting params$ben_mult_lookup,
# then supplement the adapter output (which covers tier_1 only) with them.
# TODO (pendata): Fix benefit_rules for all classes:
#   - tier_2 regular/admin/special: only partial multipliers extracted
#   - tier_3 all classes: missing entirely
#   After fixing and reinstalling pendata, remove this supplement block.
#   See: OPEN_ISSUES.md — benefit_rules missing / incomplete tier_2 and tier_3
# ---------------------------------------------------------------------------
# TODO (pendata data quality): benefit_rules has incomplete/wrong data for:
#   - tier_1: slight overlap-vs-non-overlap discrepancy in joined results (~8e-6)
#   - tier_2: wrong multipliers for regular/admin/special (e.g. regular only has 0.016)
#   - tier_3: missing entirely for all classes
# Until pendata is fixed, keep the FULL legacy ben_mult_lookup unchanged.
# The adapter function convert_benefit_rules_to_legacy() is tested and ready;
# activate it here after pendata benefit_rules is corrected.
# See: OPEN_ISSUES.md — benefit_rules missing / incomplete tier_2 and tier_3
# ---------------------------------------------------------------------------
# params$ben_mult_lookup <- convert_benefit_rules_to_legacy(params$benefit_rules)
message("  ⚠ ben_mult_lookup: using full legacy (pendata benefit_rules data quality pending)")

# 2. dr_lookup: tier_3 -> dr_new_, all others -> dr_current_ (two constants)
params$dr_lookup <- build_dr_lookup(params)
message("  ✓ Built dr_lookup from params constants (dr_current_, dr_new_)")

# 3. fas_period_lookup: tier_1 -> 5 yrs, all others -> 8 yrs (plan provision)
params$fas_period_lookup <- build_fas_period_lookup()
message("  ✓ Built fas_period_lookup from plan provisions (tier_1=5yr, others=8yr)")

# 4. reduce_factor_lookup: formula-based early retirement reduction factors
params$reduce_factor_lookup <- build_reduce_factor_lookup(params)
message("  ✓ Built reduce_factor_lookup from plan provisions")

# 5. cola_lookup: COLA rates by tier/yos/entry_year using 4 params COLA constants
#    NOTE: this is the largest computed table — 12 tiers x many yos x many years
message("  Building cola_lookup (large table, may take a moment)...")
params$cola_lookup <- build_cola_lookup(params)
message("  ✓ Built cola_lookup from COLA constants (cola_tier_1/2/3_active_)")

# DIAGNOSTIC: temporarily keep legacy for computed tables to isolate differences
# Uncomment to test isolation:
# params$dr_lookup            <- pendata::frs$params_env$dr_lookup
# params$fas_period_lookup    <- pendata::frs$params_env$fas_period_lookup
# params$reduce_factor_lookup <- pendata::frs$params_env$reduce_factor_lookup
# params$cola_lookup          <- pendata::frs$params_env$cola_lookup

# --- Benefit model helpers ----------------------------------------------------
message("sourcing FRS_benefit_model_helper_functions and data function...")
bm_env <- new.env()
source(fs::path(rdir, "FRS_benefit_model_functions_2.R"), local = bm_env)

# --- Load workforce, liability, funding functions -----------------------------
message("Loading model functions...")

# Workforce
message("sourcing FRS_workforce_model_functions....")
wfm_env <- new.env()
source(fs::path(rdir, "FRS_workforce_model_functions_V3.R"), local = wfm_env)

# Liability
message("sourcing FRS_liability_model_functions...")
lm_env <- new.env()
source(fs::path(rdir, "FRS_liability_model_functions_2.R"), local = lm_env)

# Funding
message("sourcing funding model functions...")
fm_env <- new.env()
source(fs::path(rdir, "FRS_funding_amort.R"),                                local = fm_env)
source(fs::path(rdir, "FRS_funding_model_functions_loop_without_drop_V5.R"), local = fm_env)
source(fs::path(rdir, "FRS_funding_model_functions_drop_only.R"),            local = fm_env)

# --- Prepare benefit data for modeling -------------------------------------------------
message("sourcing FRS_benefit_get_saved_data.R...")
bf_data_env <- new.env()
source(fs::path(rdir, "FRS_benefit_model_get_and_save_bendata.R"), local = bf_data_env)

# --- Prepare workforce data for modeling -------------------------------------------------
message("sourcing FRS_workforce_get_saved_data.R...")
wf_data_env <- new.env()
source(fs::path(rdir, "FRS_workforce_model_get_and_save_wfdata_GC_s.R"), local = wf_data_env)

# --- Prepare liability data for modeling -------------------------------------------------
message("sourcing FRS_liability_get_saved_data.R...")
liab_data_env <- new.env()
source(fs::path(rdir, "FRS_liability_model_get_and_save_liabdata.R"), local = liab_data_env)

# --- Funding & amortization inputs --------------------------------------------
params$funding_list <- fm_env$get_all_classes_funding_list(params$init_funding_data, params)
# TIER 1: Use better structure 'amortization_bases' instead of legacy 'current_amort_layers_table_'
current_amort_temp <- convert_amortization_to_legacy(params$amortization_bases)
params$current_amort_layers_table <- fm_env$get_current_amort_layers_summary_table(current_amort_temp)
message("  ✓ Migrated current_amort_layers_table from better structure 'amortization_bases'")

# --- Baseline results ----------------------------------------------------------
message("Calculating baseline funding results...")
params$enable_drop_ <- TRUE
baseline_funding <- fm_env$get_funding_data(liab_data_env, params)

# Save full workspace 
save.image(fs::path(outdir, "new_workspace.RData")) 

# --- Tests ---------------------------------------------------------------------
source(fs::path(tooldir, "run_allobjects_tests.R"))
