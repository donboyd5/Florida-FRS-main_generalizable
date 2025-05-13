rm(list = ls())

#Load required libraries ------------------
library(readxl)
library(tidyverse)
library(zoo)
library(profvis)
library(data.table)
library(openxlsx)
library(janitor)
library(rio)
library(parallel)
library(janitor)
library(gt)
library(purrr)
#devtools::install_github("donboyd5/btools")
library(btools) # ns, ht

# load pension-specific libraries
# For first time installing package, or each time package is updated, install as follows
# remove.packages("pentools")
devtools::install_github("gchen3/pentools")
library(pentools) # use this instead of sourcing "FRS_utility_functions.R"
# remove.packages("pendata")
# devtools::install_github("donboyd5/pendata")
library(pendata)


# define directories -------------------------------------------------------------

iddir <- here::here("refactor", "interim_data")
rdir <- here::here("refactor", "R")
sddir <- here::here("refactor", "source_data")
tooldir <- here::here("refactor", "tools")
wddir <- here::here("refactor", "working_data")
xidir <- here::here("refactor", "source_data", "Reports", "extracted inputs")
stackdir <- here::here("refactor", "stacked_data")

# if a full run, create model parameters and frs_data environments --------

# Get FRS model parameters, constants, raw initial data, and derived initial data

print("This is a full run using GC version, so creating model parameters and frs_data environments from scratch...")
  
modparm_data_env <- new.env()
# 48 objects - scalars and vectors
source(fs::path(rdir, "FRS_model_parameters_GC.R"), local = modparm_data_env) 
save(modparm_data_env, file = fs::path(wddir, "modparm_data_env.RData"))

frs_data_env <- new.env()
# 13 secs only reads data and sets variable values - no functions
# 102 objects - mostly scalars and lists that are tables
source(fs::path(rdir, "FRS_data_cleaning_functions.R"), local = frs_data_env) # put data, params into frs_data_env
source(fs::path(rdir, "FRS_data_cleaning.R"), local = frs_data_env) # put data, params into frs_data_env
source(fs::path(rdir, "FRS_stacked_tables.R"), local = frs_data_env) # put data, params into frs_data_env
#source(fs::path(rdir, "FRS_rules_functions.R"), local = frs_data_env) # put data, params into frs_data_env
source(fs::path(rdir, "FRS_rules_tables.R"), local = frs_data_env) # put data, params into frs_data_env
save(frs_data_env, file = fs::path(wddir, "frs_data_env.RData"))
# ls(envir = modparm_data_env)


# create params environment -----------------------------------------------
# create params environment BEFORE FRS_benefit_model_actions.R, as it is needed
# for that
load(fs::path(wddir, "modparm_data_env.RData"))
load(fs::path(wddir, "frs_data_env.RData")) # this gets init_funding_data

source(fs::path(rdir, "FRS_create_params_env_GC.R")) 
params <- get_params(frs_data_env, modparm_data_env)
ns(params)


# Get benefit model environment -----------------------------------------------
print("sourcing FRS_benefit_model_helper_functions.R and FRS_benefit_model_get_benefit_data_function.R...")
bm_env <- new.env()
#source(fs::path(rdir, "FRS_benefit_model_helper_functions.R"), local = bm_env) # only creates functions - no live code, puts them into the bm_env environment
source(fs::path(rdir, "FRS_benefit_model_get_benefit_data_function_GC_s.R"), local = bm_env) # only creates functions - no live code, also into the bm_env environment
save(bm_env, file = fs::path(wddir, "bm_env.RData"))


# create derived data -----------------------------------------------

# get initial data derived from raw model data - does NOT require modeling assumptions
# print("sourcing FRS_benefit_model_actions.R...") 
# 
# benefit_model_data_env <- new.env()
# # uses: bm_env and params
# source(fs::path(rdir, "FRS_benefit_model_actions.R"), local = benefit_model_data_env)
# save(benefit_model_data_env, file = fs::path(wddir, "benefit_model_data_env.RData"))
# 
# load(fs::path(wddir, "benefit_model_data_env.RData"))
# list2env(as.list(benefit_model_data_env), envir = .GlobalEnv)
# rm(benefit_model_data_env)
# creates for each class: salary_headcount, entrant_profile, mort, retire_mort, drop entry, retire, early retire, sep rates


# Load workforce, liability, and funding model functions into separate environments -------------------------------

print("Loading model functions...")

# Note: do not load actuarial and financial functions as they are now in pentools

# Get workforce model
print("sourcing FRS_workforce_model_functions....")
wfm_env <- new.env()
source(fs::path(rdir, "FRS_workforce_model_functions_s.R"), local = wfm_env) # only creates function - no live code

#Get liability model
print("sourcing FRS_liability_model.R...")
lm_env <- new.env()
source(fs::path(rdir, "FRS_liability_model_functions.R"), local = lm_env) # only creates function - no live code

#Get funding model
print("sourcing FRS_funding_model_functions.R...")
fm_env <- new.env()
source(fs::path(rdir, "FRS_funding_model_functions.R"), local = fm_env) # only creates function - no live code
save(fm_env, file = fs::path(wddir, "fm_env.RData"))
load(fs::path(wddir, "fm_env.RData")) # funding model functions

# Prepare data for modeling -----------------------------------------------

#Get workforce data (run this model only when workforce data is updated, otherwise use the rds files)
print("sourcing FRS_workforce_model_get_and_save_wfdata.R...")
system.time(source(fs::path(rdir, "FRS_workforce_model_get_and_save_wfdata_GC_s.R")))


# depends on assumptions in the model: 

cat("\n")
print("sourcing FRS_workforce_model_get_saved_data.R...")
wf_data_env <- new.env()
# djb NEXT: stack the workforce data ----
system.time(source(fs::path(rdir, "FRS_workforce_model_get_saved_data.R"), local = wf_data_env)) # < 1 sec -- only gets saved data - no functions
save(wf_data_env, file = fs::path(wddir, "wf_data_env.RData")) # only saves objects - no functions
load(fs::path(wddir, "wf_data_env.RData"))
# simply loads wf data -- 4 table types per 7 classes

# prepare global lists to pass as needed - eventually replace with stacked data frames

# update params with new lists --------------------------------------------

# wf_data_list: each class has 4 tables: entrant_profile_table, salary_headcount_table, mort_table, separation_rate_table
params$wf_data_list <- mget(paste0(params$class_names_no_drop_frs_, "_wf_data"), envir = wf_data_env) # does not waste memory because R is copy on modify
params$entrant_profile_table_list <- frs_data_env$entrant_profile_table_list # previously created

params$salary_headcount_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_salary_headcount_table"), envir = frs_data_env)

params$mort_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_mort_table"), envir = frs_data_env)
params$mort_retire_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_mort_retire_table"), envir = frs_data_env)

params$separation_rate_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_separation_rate_table"), envir = frs_data_env)

params$normal_retire_rate_tier_1_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_normal_retire_rate_tier_1_table"), envir = frs_data_env) # defined in benefit model actions
params$normal_retire_rate_tier_2_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_normal_retire_rate_tier_2_table"), envir = frs_data_env) # defined in benefit model actions

params$early_retire_rate_tier_1_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_early_retire_rate_tier_1_table"), envir = frs_data_env) # defined in benefit model actions
params$early_retire_rate_tier_2_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_early_retire_rate_tier_2_table"), envir = frs_data_env) # defined in benefit model actions

# get funding and amortization data --------------------------------------------

params$funding_list <- fm_env$get_all_classes_funding_list(params$init_funding_data, params)
params$current_amort_layers_table <- fm_env$get_current_amort_layers_summary_table(params$current_amort_layers_table_)
save(params, file = fs::path(wddir, "params.RData"))

load(fs::path(wddir, "params.RData"))

# ns(.GlobalEnv) |> str_subset("separation_rate_table")
# ns(benefit_model_data_env)

print("Done building model...")

##############################################TESTING############################################

# baseline_funding <- get_funding_data(funding_list, current_amort_layers_table, params=params)

# baseline_funding <- get_funding_data()
# 
# funding_72return <- get_funding_data(return_scen = "model",
#                                      model_return = 0.072)
# 
# funding_62return <- get_funding_data(return_scen = "model",
#                                      model_return = 0.062)
# 
# 
# check_72 <- funding_72return$frs %>% 
#   select(year, total_ual_mva, total_ual_ava, fr_mva, fr_ava)
# 
# 
# check_62 <- funding_62return$frs %>% 
#   select(year, total_ual_mva, total_ual_ava, fr_mva, fr_ava)
# 
# 
# export(baseline_funding, "baseline_funding.xlsx") OLD LOCATION
# 
# 
# baseline_liability <- get_liability_data()
# 
# cola1_constant_liability <- get_liability_data(cola_tier_1_active_constant = "yes")

# baseline_liability <- get_liability_data()
# baseline <- get_funding_data()
# 
# lower_amo <- get_funding_data(funding_policy = "ADC",
#                               amo_period_current = 23,
#                               amo_period_new = 23)
# 
# 
# anthony_scen2 <- get_funding_data(cola_current_active = 0.0071,
#                                  cola_new_active = 0.0071,
#                                  cola_current_retire = 0.0071,
#                                  funding_policy = "ADC",
#                                  amo_period_current = 50,
#                                  amo_period_new = 15,
#                                  dr_new = 0.06)
# 
# 
# anthony_scen_liab2 <- get_liability_data(cola_current_active = 0.0071,
#                                         cola_new_active = 0.0071,
#                                         cola_current_retire = 0.0071,
#                                         dr_new = 0.06)
# 
# write.csv(lower_amo, "lower_amo.csv")
# test_nc <- get_benefit_data(retire_refund_ratio = 0.3)
# 
# test_nc$nc_agg$normal_cost_aggregate_DB
# 
# test_liability <- get_liability_data(retire_refund_ratio = 0.3,
#                                      cal_factor = 10.6/12.9)
# 
# baseline <- get_liability_data()
# lower_dr_new <- get_liability_data(dr_new = 0.06)
# lower_dr <- get_liability_data(dr_new = 0.06, dr_current = 0.06)
# cola_everyone <- get_liability_data(cola_current_active = 0.03,
#                                     cola_new_active = 0.03,
#                                     cola_current_retire = 0.03)
# 
# cola_one <- get_liability_data(one_time_cola = T, cola_current_retire_one = 0.03, cal_factor = 10.8 / 13)
