# note on gang's code ----
# what does this code do

# params_env <- new.env()
# params <- list2env(as.list(pendata::frs$params_env))

# R 4.5.2
# Positron Assistant
# This code creates model parameters from the pendata package:

# params_env <- new.env() - Creates a new, empty environment called params_env (though this isn't actually used in the next line)

# params <- list2env(as.list(pendata::frs$params_env)) - Takes parameters from the pendata package and converts them to an environment:

# pendata::frs$params_env accesses a params environment stored in the frs dataset from the pendata package
# as.list() converts that environment to a list
# list2env() converts the list back into a new environment
# The result is assigned to params
# The first line creating params_env appears to be unused, since the second line creates params as a fresh environment without referencing params_env. You could simplify this to just:

# This pattern effectively copies/clones the parameter environment from the package data so you can work with it without modifying the original.

# Items I added for gang
needed <- c(
    "salary_headcount_table",
    "mort_table",
    "mort_retire_table",
    "separation_rate_table",
    "entrant_profile_table",
    "dr_lookup",
    "cola_lookup",
    "ben_mult_lookup",
    "reduce_factor_lookup",
    "tier_table",
    "fas_period_lookup"
)


rm(list = ls())

# --- Libraries ---------------------------------------------------------------
library(tidyverse)
library(data.table)
library(purrr)
# remove.packages("pentools");devtools::install_github("gchen3/pentools")
library(pentools)
# remove.packages("pendata"); devtools::install_github("donboyd5/pendata")
library(pendata)

# --- Paths -------------------------------------------------------------------
iddir <- here::here("refactor", "interim_data")
rdir <- here::here("refactor", "R")
sddir <- here::here("refactor", "source_data")
tooldir <- here::here("refactor", "tools")
wddir <- here::here("refactor", "working_data")
xidir <- here::here("refactor", "source_data", "Reports", "extracted inputs")
stackdir <- here::here("refactor", "stacked_data")
outdir <- here::here("refactor", "new_results")

# Figure out what to change in FRS constants and assumptions -------------------

names(frs) # [1] "plan_shortname" "params_env"
djb <- pendata::frs$params_env
names(djb) # see below -- 188 objects
map_chr(djb, ~ class(.x)[1]) |> table() # table of types
#  character data.frame    integer       list    logical    numeric     tbl_df
#          8          5          7          3          1         93         71

map_chr(djb, ~ class(.x)[1]) |> sort() # which objects are which type

# get details (not shown)
details <- map_dfr(
    names(djb),
    ~ tibble(
        name = .x,
        class = class(djb[[.x]])[1],
        type = typeof(djb[[.x]]),
        length = length(djb[[.x]])
    )
) |>
    mutate(global = stringr::str_ends(name, "_"),
gangadd=name %in% needed) |>
    arrange(global, class, type)


doi <- details |> filter(!global) |> arrange(gangadd, name)

loinames <- details |> filter(!global) |> pull(name)
loi <- djb[loinames |> sort()] # list of interest


count(details, class, type)
# # A tibble: 7 × 3
#   class      type          n
#   <chr>      <chr>     <int>
# 1 character  character     8
# 2 data.frame list          5
# 3 integer    integer       7
# 4 list       list          3
# 5 logical    logical       1
# 6 numeric    double       93
# 7 tbl_df     list         71
details |>
    mutate(is_env = map_lgl(names(djb), ~ is.environment(djb[[.x]]))) |>
    filter(is_env) # no environments!

# salary headcount ---------
summary(loi$salary_headcount_table)
summary(loi$headcount_salary)

# OLD -----------------------------------------
ns(pendata::frs)
tmp <- pendata::frs$params_env
ns(tmp) |> str_subset("cal")
ns(tmp) |> str_subset("constant")
tmp$constants_assumptions

constants_tbl <- tmp$constants_assumptions_tbl

# [1] "min_age_"                                      "senior_management_outflow_"                    "senior_management_val_norm_cost_"              "normal_retirement_tier_2_table_"
#   [5] "early_retirement_tier_1_table_"                "cola_current_retire_"                          "special_db_new_ratio_"                         "retire_refund_ratio_"
#   [9] "senior_management_er_dc_cont_rate_"            "eco_term_rate_female_table_"                   "year_range_"                                   "judges_retiree_pop_current_"
#  [13] "judges_val_norm_cost_"                         "db_dc_legacy_table"                            "pop_growth_"                                   "return_scen_index"
#  [17] "eco_er_dc_cont_rate_"                          "regular_total_active_member_"                  "cola_tier_3_active_"                           "admin_val_norm_cost_"
#  [21] "funding_lag_"                                  "female_mp_table_"                              "cola_tier_2_active_"                           "eso_salary_table_"
#  [25] "drop_entry_tier_2_table_"                      "eco_nc_cal_"                                   "age_range_"                                    "entrant_profile_table"
#  [29] "mort_retire_table"                             "judges_outflow_"                               "amo_term_growth_"                              "amo_period_term_"
#  [33] "class_names_no_frs_"                           "retirees"                                      "cal_factor_"                                   "admin_outflow_"
#  [37] "regular_val_norm_cost_"                        "special_db_legacy_after_2018_ratio_"           "inflation_"                                    "separation_rate_table"
#  [41] "judges_term_rate_female_table_"                "model_return_"                                 "headcount_salary"                              "regular_ben_payment_current_"
#  [45] "senior_management_pvfb_term_current_"          "special_headcount_table_"                      "entry_year_range_"                             "male_mp_table_"
#  [49] "eco_pvfb_term_current_"                        "regular_er_dc_cont_rate_"                      "class_names_"                                  "regular_retiree_pop_current_"
#  [53] "ben_mult_lookup"                               "salary_table_"                                 "judges_er_dc_cont_rate_"                       "one_time_cola_"
#  [57] "special_pvfb_term_current_"                    "benefit_rules"                                 "constants_assumptions_tbl"                     "eco_term_rate_male_table_"
#  [61] "eso_outflow_"                                  "eso_headcount_table_"                          "regular_salary_table_"                         "senior_management_term_rate_female_table_"
#  [65] "dr_lookup"                                     "base_safety_mort_table_"                       "eco_outflow_"                                  "admin_expense_"
#  [69] "regular_term_rate_female_table_"               "admin_nc_cal_"                                 "eco_salary_table_"                             "current_amort_layers_table_"
#  [73] "yos_range_"                                    "admin_term_rate_female_table_"                 "init_funding_data"                             "regular_nc_cal_"
#  [77] "special_total_active_member_"                  "dr_new_"                                       "current_year_table"                            "senior_management_ben_payment_current_"
#  [81] "retiree_distribution"                          "term_rate_"                                    "reduce_factor_lookup"                          "eso_pvfb_term_current_"
#  [85] "max_age_"                                      "admin_salary_table_"                           "admin_ben_payment_current_"                    "eso_val_norm_cost_"
#  [89] "pension_payment_"                              "judges_ben_payment_current_"                   "salary_growth_table"                           "senior_management_retiree_pop_current_"
#  [93] "term_rate_male_table_list"                     "return_scenarios"                              "senior_management_headcount_table_"            "nc_cal_"
#  [97] "eco_retiree_pop_current_"                      "senior_management_total_active_member_"        "eso_er_dc_cont_rate_"                          "ben_payment_ratio_"
# [101] "salary_growth_table_"                          "tier_table"                                    "fas_period_lookup"                             "special_salary_table_"
# [105] "admin_er_dc_cont_rate_"                        "eso_term_rate_male_table_"                     "cola_lookup"                                   "amo_period_new_"
# [109] "special_term_rate_male_table_"                 "eco_eso_judges_total_active_member_"           "return_scenarios_original_"                    "constants_assumptions"
# [113] "db_ee_cont_rate_"                              "disbursement_to_ip_"                           "retirement_rates"                              "headcount_table_"
# [117] "db_dc_new_table"                               "eco_headcount_table_"                          "amo_pay_growth_"                               "payroll_growth_"
# [121] "eco_ben_payment_current_"                      "regular_pvfb_term_current_"                    "eso_term_rate_female_table_"                   "non_special_db_new_ratio_"
# [125] "max_year_"                                     "db_ee_interest_rate_"                          "eco_val_norm_cost_"                            "salary_growth_table_original_"
# [129] "special_er_dc_cont_rate_"                      "normal_retirement_tier_1_table_"               "amo_method_"                                   "admin_total_active_member_"
# [133] "admin_pvfb_term_current_"                      "eso_retiree_pop_current_"                      "admin_headcount_table_"                        "class_names_no_drop_frs_"
# [137] "special_ben_payment_current_"                  "withdrawal"                                    "return_2023_"                                  "special_outflow_"
# [141] "special_retiree_pop_current_"                  "funding_policy_"                               "dr_current_"                                   "special_db_legacy_before_2018_ratio_"
# [145] "judges_pvfb_term_current_"                     "eco_eso_judges_active_member_adjustment_ratio" "salary_headcount_table"                        "regular_outflow_"
# [149] "amortization_bases"                            "cola_tier_1_active_constant_"                  "benefit_rules_test_cases"                      "senior_management_salary_table_"
# [153] "judges_headcount_table_"                       "term_rate_female_table_list"                   "dr_old_"                                       "term_rate_male_table_"
# [157] "class_name_"                                   "new_year_"                                     "senior_management_nc_cal_"                     "regular_headcount_table_"
# [161] "judges_term_rate_male_table_"                  "model_period_"                                 "cola_current_retire_one_"                      "cola_tier_1_active_"
# [165] "return_scen_"                                  "admin_retiree_pop_current_"                    "base_teacher_mort_table_"                      "early_retirement_tier_2_table_"
# [169] "judges_salary_table_"                          "admin_term_rate_male_table_"                   "non_special_db_legacy_before_2018_ratio_"      "special_nc_cal_"
# [173] "eso_ben_payment_current_"                      "min_year_"                                     "eso_nc_cal_"                                   "special_term_rate_female_table_"
# [177] "mort_table"                                    "drop_entry_tier_1_table_"                      "judges_nc_cal_"                                "special_val_norm_cost_"
# [181] "salarygrowth"                                  "senior_management_term_rate_male_table_"       "regular_term_rate_male_table_"                 "non_special_db_legacy_after_2018_ratio_"
# [185] "term_rate_female_table_"                       "base_general_mort_table_"                      "start_year_"                                   "contribution_refunds_"
