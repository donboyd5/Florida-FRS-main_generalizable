
# overview
# fm_env$get funding data(...)
#   lm_env$get_liability_data(...)
#     bm_env$get_benefit_data(...)
#        get_class_salary_growth_table(class_name, params$salary_growth_table_) [within bm_env]

# get_class_salary_growth_table <- function(class_name, salary_growth_table){
#   
#   class_salary_growth_table <- salary_growth_table %>% 
#     select(yos, contains(class_name)) %>% 
#     rename(cumprod_salary_increase = 2)
#   
#   return(class_salary_growth_table)
# }


# make liability model available
lm_env <- new.env()
source(fs::path(rdir, "FRS_liability_model_functions.R"), local = lm_env)

# load(fs::path(wddir, "wf_data_env.RData"))
# load wf data -- 4 table types per 7 classes

# key inputs to the model (stacked)
source(here::here("refactor", "functions_unpack_stack.R"))

# key inputs to the liability model ----
# funding_list_stacked <- bind_rows(funding_list, .id = "class")
funding_list_stacked <- readRDS(fs::path(wddir, "funding_list_stacked.rds"))

# class_name 
# wf_data 
# ben_payment_current 
# retiree_pop_current
# pvfb_term_current
# entrant_profile_table
# salary_headcount_table
# mort_table
# mort_retire_table
# separation_rate_table
# params


#.. workforce data, return list of 4 stacked data frames ----
# wf_active, wf_term, wf_refund, wf_retire
# each will have class, entry_age, age, year, and then vars such as  n_active

# this needs special handling because of the nested sets of 4 tibbles

# wf_data_list <- params$wf_data_list
# element_name <- paste0(class_name, "_wf_data")
# wf_data <- wf_data_list[[element_name]]

wf_data_stacked_list <- ups_wfdata(params$wf_data_list)
names(wf_data_stacked_list)
wf_data_stacked_list$wf_active_stacked

#.. unpack scalars into a tibble ----
#.... scalar groups are c("_ben_payment_current_", "_retiree_pop_current_", "_retiree_pop_current_") ----
scalar_groups <- c("_ben_payment_current_", "_retiree_pop_current_", "_retiree_pop_current_")
scalar_names <- outer(params$class_names_no_drop_frs_, scalar_groups, paste0) |> as.vector()
scalar_names

selected_elements <- mget(scalar_names, envir = params)

scalars_stacked <- enframe(selected_elements, name = "name", value = "value") |> 
  mutate(value=unlist(value)) |> 
  separate_class(col = "name", into = c("class", "variable")) |> 
  select(class, variable, value)

scalars_stacked

#.. entrant_profile_table ----
# ns(params$entrant_profile_table_list) |> str_subset("entrant_profile_table")
entrant_profile_table_stacked <- stack_list(params$entrant_profile_table_list, "_entrant_profile_table")

#.. salary_growth_table ----
salary_growth_table_stacked <- pendata::frs$salary_growth |> 
  select(class, yos, cumprod_salary_increase = cumprod_increase)

#.. salary_headcount_table ----
# ns(params$salary_headcount_table_list) |> str_subset("_salary_headcount_table")
salary_headcount_table_stacked <- stack_list(params$salary_headcount_table_list, "_salary_headcount_table")
count(salary_headcount_table_stacked, class)
params$salary_headcount_table_list$admin_salary_headcount_table # 26 admin rows

#.. mort_table ----
# ns(params$mort_table_list) |> str_subset("_mort_table")
mort_table_stacked <- stack_list(params$mort_table_list, "_mort_table")

#.. mort_retire_table ----
# ns(params$mort_retire_table_list) |> str_subset("_mort_retire_table")
mort_retire_table_stacked <- stack_list(params$mort_retire_table_list, "_mort_retire_table")

#.. separation_rate_table ----
# ns(params$separation_rate_table_list) |> str_subset("_separation_rate_table")
separation_rate_table_stacked <- stack_list(params$separation_rate_table_list, "_separation_rate_table")

# create a stacked environment ----
stack_env <- new.env()
stack_env$scalars_stacked <- scalars_stacked
list2env(wf_data_stacked_list, envir = stack_env)
other_list <- named_list(
  entrant_profile_table_stacked,
  salary_growth_table_stacked,
  salary_headcount_table_stacked,
  mort_table_stacked,
  mort_retire_table_stacked,
  separation_rate_table_stacked)
list2env(other_list, envir = stack_env)
ns(stack_env)
system.time(save(stack_env, file = fs::path(wddir, "stack_env.RData")))


system.time(load(file = fs::path(wddir, "stack_env.RData")) )
ns(stack_env)
stack_env$scalars_stacked
stack_env$entrant_profile_table_stacked

# END stacked environment ----


#.. get_benefit_data ----

# overview of tables to stack
# fm_env$get funding data(...)
#   lm_env$get_liability_data(...)
#     bm_env$get_benefit_data(...)
#        y get_class_salary_growth_table(class_name, params$salary_growth_table_) [within bm_env]
#        y get_salary_benefit_table(class_name, entrant_profile_table, class_salary_growth_table, salary_headcount_table, params)
#        y ann_factor_table
#        benefit_table
#        dist_age_table
#        final_benefit_table
#        benefit_val_table
#        indv_norm_cost_table
#        agg_norm_cost_table

#  return:
    # ann_factor_table       
    # ann_factor_retire_table
    # benefit_table          
    # final_benefit_table    
    # benefit_val_table      
    # indv_norm_cost_table   
    # agg_norm_cost_table    


#.... salary benefit table ----


# stacked salary benefit table ----
# this is fast and, based on testing, equivalent to the Reason approach


stubs <- crossing(stack_env$entrant_profile_table_stacked |> 
                    select(class, entry_age),
                  entry_year = params$entry_year_range_,
                  yos = params$yos_range_) |> 
  mutate(term_age = entry_age + yos) |> 
  filter(term_age <= params$max_age_)
count(stubs, class)

# we need max_entry_year of JUST the records in the headcount table
max_entry_year <- stack_env$salary_headcount_table_stacked |> 
  summarise(max_entry_year = max(entry_year, na.rm = TRUE),
         .by=class)

salary_benefit_table_stacked <- stubs |> 
  left_join(stack_env$entrant_profile_table_stacked,
            by = join_by(class, entry_age)) |> 
  left_join(stack_env$salary_growth_table_stacked,
            by = join_by(class, yos)) |> 
  filter(term_age <= params$max_age_) |> 
  mutate(tier_at_term_age = bm_env$get_tier(class, entry_year, term_age, yos, params$new_year_)) |> 
  # Join salary_head_count_table_stacked by entry_year and entry_age only to get historical entry_salary
  left_join(stack_env$salary_headcount_table_stacked |> 
              select(class, entry_year, entry_age, entry_salary),
            by = join_by(class, entry_age, entry_year)) |>
  left_join(max_entry_year, by = join_by(class)) |> 
  # if_else respects grouping, ifelse does not
  # but we don't need grouping below because we merged in proper class max_entry_year above
  mutate(salary = if_else(entry_year <= max_entry_year, # max(entry_year), # max_entry_year, max(entry_year)
                          entry_salary * cumprod_salary_increase,
                          start_sal * cumprod_salary_increase * (1 + params$payroll_growth_)^(entry_year - max_entry_year)), # max(entry_year)
         fas_period = if_else(str_detect(tier_at_term_age, "tier_1"), 5, 8)) |> 
  mutate(
    # this rolling mean is faster than the Reason approach but equivalent
    fas = RcppRoll::roll_mean(c(NA, salary[-length(salary)]), # drop the current value
                               n = max(fas_period), align="right", fill = NA),
    db_ee_cont = params$db_ee_cont_rate_ * salary,
    db_ee_balance = pentools::get_cum_fv(params$db_ee_interest_rate_, db_ee_cont),
    .by=c(class, entry_year, entry_age)) |> 
  filter(!is.na(salary))


# explore
skim(salary_benefit_table_stacked)
count(salary_benefit_table_stacked, class)
count(salary_benefit_table_stacked, tier_at_term_age)
count(salary_benefit_table_stacked, tier_at_term_age, class) |> 
  pivot_wider(names_from = class, values_from = n) # ?? why are eco and judges the same??

# stacked ann_factor_table ----
stack_env$mort_table_stacked
salary_benefit_table_stacked

# semi_join() return all rows from x with a match in y.
# here all rows from mort_table_stacked (16m recs) with a match in salary_benefit_table (158k rows)

# create tier lookup tables
dr_lookup <- tibble(
  tier_at_dist_age = unique(mort_table_stacked$tier_at_dist_age)
) |> 
  mutate(dr = if_else(str_detect(tier_at_dist_age, "tier_3"), params$dr_new_, params$dr_current_))
dr_lookup

cola_lookup <- tibble(
  tier_at_dist_age = unique(mort_table_stacked$tier_at_dist_age)
) |> 
  mutate(tier = str_sub(tier_at_dist_age, 6, 6),
         basecola=case_when(
           tier == "1" ~ params$cola_tier_1_active_,
           tier == "2" ~ params$cola_tier_2_active_,
           tier == "3" ~ params$cola_tier_3_active_,
           .default = 0
         ),
         tier1mult = if_else(tier == "1" & params$cola_tier_1_active_constant_ == "no",
                             TRUE, FALSE))
cola_lookup

library(dtplyr)
setDTthreads(0L) # use all available threads

# chatgpt ----

aa <- proc.time()

# Convert to data.table if not already
setDT(mort_table_stacked)
setDT(salary_benefit_table_stacked)
setDT(dr_lookup)
setDT(cola_lookup)

# Extract distinct keys from salary_benefit_table_stacked
salary_benefit_keys <- unique(
  salary_benefit_table_stacked[, .(class, entry_year, entry_age)]
)

# Now set keys on all tables
setkey(mort_table_stacked, class, entry_year, entry_age)
setkey(salary_benefit_keys, class, entry_year, entry_age) 
setkey(dr_lookup, tier_at_dist_age)
setkey(cola_lookup, tier_at_dist_age)

# Set index if you often filter/join on these columns
setindex(mort_table_stacked, dist_year, dist_age)

# semi_join equivalent: keep only rows in mort_table_stacked that match the keys
ann_factor_table_stacked <- mort_table_stacked[
  salary_benefit_keys, 
  on = .(class, entry_year, entry_age), 
  nomatch=0L
]

# Left joins
ann_factor_table_stacked <- ann_factor_table_stacked[
  dr_lookup,
  on = .(tier_at_dist_age), 
  nomatch = NA
]

ann_factor_table_stacked <- ann_factor_table_stacked[
  cola_lookup,
  on = .(tier_at_dist_age), 
  nomatch = NA
]

# Compute yos_b4_2011 and cola
ann_factor_table_stacked[, yos_b4_2011 := pmin(pmax(2011 - entry_year, 0), yos)]
ann_factor_table_stacked[, cola := fifelse(
  tier1mult & yos > 0, 
  basecola * (yos_b4_2011 / yos), 
  0
)]

# Order data for cumulative operations
setorder(ann_factor_table_stacked, class, entry_year, entry_age, yos, dist_year, dist_age)

# Perform grouped calculations by (class, entry_year, entry_age, yos)
ann_factor_table_stacked[, cum_dr := cumprod(1 + shift(dr, fill=0)), 
                         by = .(class, entry_year, entry_age, yos)]
ann_factor_table_stacked[, cum_mort := cumprod(1 - shift(mort_final, fill=0)), 
                         by = .(class, entry_year, entry_age, yos)]
ann_factor_table_stacked[, cum_cola := cumprod(1 + shift(cola, fill=0)), 
                         by = .(class, entry_year, entry_age, yos)]

# Derived columns
ann_factor_table_stacked[, cum_mort_dr := cum_mort / cum_dr]
ann_factor_table_stacked[, cum_mort_dr_cola := cum_mort_dr * cum_cola]

# ann_factor calculation
ann_factor_table_stacked[, ann_factor := {
  x <- cum_mort_dr_cola
  rev(cumsum(rev(x))) / x
}, by = .(class, entry_year, entry_age, yos)]

# Final select
ann_factor_table_stacked <- ann_factor_table_stacked[, .(
  class, entry_year, entry_age, dist_year, dist_age, yos, term_year,
  mort_final, tier_at_dist_age, dr, yos_b4_2011, cola,
  cum_dr, cum_mort, cum_cola, cum_mort_dr, cum_mort_dr_cola, ann_factor
)]

ann_factor_table_stacked <- as_tibble(ann_factor_table_stacked)

bb <- proc.time()
bb - aa

# for checking ----
ann_factor_table <- mort_table %>% 
  #Semi join the salary_benefit_able to reduce the size of the data that needs to be calculated
  semi_join(salary_benefit_table, by = c("entry_year", "entry_age")) %>%
  mutate(
    dr = if_else(str_detect(tier_at_dist_age, "tier_3"), params$dr_new_, params$dr_current_),
    yos_b4_2011 = pmin(pmax(2011 - entry_year, 0), yos),
    cola = case_when(
      #Tier 1 cola (current policy) = 3% * YOS before 2011 / Total YOS
      str_detect(tier_at_dist_age, "tier_1") & params$cola_tier_1_active_constant_ == "no" ~ 
        if_else(yos > 0, params$cola_tier_1_active_ * yos_b4_2011 / yos, 0),
      str_detect(tier_at_dist_age, "tier_1") & params$cola_tier_1_active_constant_ == "yes" ~ 
        params$cola_tier_1_active_,
      str_detect(tier_at_dist_age, "tier_2") ~ 
        params$cola_tier_2_active_,
      str_detect(tier_at_dist_age, "tier_3") ~ 
        params$cola_tier_3_active_
    )
  ) %>% 
  group_by(entry_year, entry_age, yos) %>% 
  mutate(
    cum_dr = cumprod(1 + lag(dr, default = 0)),
    cum_mort = cumprod(1 - lag(mort_final, default = 0)),
    cum_cola = cumprod(1 + lag(cola, default = 0)),
    cum_mort_dr = cum_mort / cum_dr,
    cum_mort_dr_cola = cum_mort_dr * cum_cola,
    # ann_factor below is the annuity factor at distribution (retirement) age
    ann_factor = rev(cumsum(rev(cum_mort_dr_cola))) / cum_mort_dr_cola
  ) %>% 
  ungroup()

#.. END get_benefit_data ----

# ann_factor_retire_table_stacked ----

ann_factor_retire_table_stacked <- stack_env$mort_retire_table_stacked |> 
  mutate(
    dr = params$dr_current_,
    cola_type = if_else(params$one_time_cola_ == TRUE, "one_time", "normal"),
    cola = if_else(cola_type == "one_time", 
                   if_else(year == params$new_year_, params$cola_current_retire_one_, 0),
                   params$cola_current_retire_)
  )  |>  
  group_by(class, base_age) %>% 
  mutate(
    cum_dr = cumprod(1 + lag(dr, default = 0)),
    cum_mort = cumprod(1 - lag(mort_final, default = 0)),
    cum_mort_dr = cum_mort / cum_dr,
    ann_factor_retire = pentools::annfactor(cum_mort_dr, cola_vec = cola, one_time_cola = params$one_time_cola_)
  ) |> 
  ungroup()


# Survival Probability and Annuity Factor for current retirees
ann_factor_retire_table <- mort_retire_table %>% 
  mutate(
    dr = params$dr_current_,
    cola_type = if_else(params$one_time_cola_ == TRUE, "one_time", "normal"),
    cola = if_else(cola_type == "one_time", 
                   if_else(year == params$new_year_, params$cola_current_retire_one_, 0),
                   params$cola_current_retire_)
  ) %>% 
  group_by(base_age) %>% 
  mutate(
    cum_dr = cumprod(1 + lag(dr, default = 0)),
    cum_mort = cumprod(1 - lag(mort_final, default = 0)),
    cum_mort_dr = cum_mort / cum_dr,
    ann_factor_retire = pentools::annfactor(cum_mort_dr, cola_vec = cola, one_time_cola = params$one_time_cola_)
  ) |> 
  ungroup() # djb addition

# END ann_factor_retire_table_stacked ----


# benefit_table_stacked ----
# 816,713 × 36 for class admin
# reason table for current class_name:
benefit_table <- bm_env$get_benefit_table(class_name, ann_factor_table, salary_benefit_table, params)

tier1 <- function(class, dist_age, dist_year, yos, term_status){
  
  regular <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 65 & yos >= 6) | (yos >= 33) ~ 0.0168,
      (dist_age >= 64 & yos >= 6) | (yos >= 32) ~ 0.0165,
      (dist_age >= 63 & yos >= 6) | (yos >= 31) ~ 0.0163,
      (dist_age >= 62 & yos >= 6) | (yos >= 30) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }
  
  special <- function(dist_year){
    case_when(dist_year <= 1974 ~ 0.02,
              .default = 0.03)
  }
  
  admin <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 58 & yos >= 6) | (yos >= 28) ~ 0.0168,
      (dist_age >= 57 & yos >= 6) | (yos >= 27) ~ 0.0165,
      (dist_age >= 56 & yos >= 6) | (yos >= 26) ~ 0.0163,
      (dist_age >= 55 & yos >= 6) | (yos >= 25) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }
  
  case_when(class=="regular" ~ regular(dist_age, yos, term_status),
            class=="special" ~ special(dist_year),
            class=="admin" ~ admin(dist_age, yos, term_status),
            class=="eco" ~.03,
            class=="eso" ~ .03,
            class=="judges" ~ 0.0333,
            class=="senior_management" ~ 0.02,
            .default = NA_real_
  )
}

tier2 <- function(class, dist_age, dist_year, yos, term_status){
  
  regular <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 68 & yos >= 8) | (yos >= 36) ~ 0.0168,
      (dist_age >= 67 & yos >= 8) | (yos >= 35) ~ 0.0165,
      (dist_age >= 66 & yos >= 8) | (yos >= 34) ~ 0.0163,
      (dist_age >= 65 & yos >= 8) | (yos >= 33) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }  
  
  special <- function(dist_year){
    case_when(dist_year <= 1974 ~ 0.02,
              .default = 0.03)
  }
  
  admin <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 63 & yos >= 8) | (yos >= 33) ~ 0.0168,
      (dist_age >= 62 & yos >= 8) | (yos >= 32) ~ 0.0165,
      (dist_age >= 61 & yos >= 8) | (yos >= 31) ~ 0.0163,
      (dist_age >= 60 & yos >= 8) | (yos >= 30) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }  
  
  case_when(class=="regular" ~ regular(dist_age, yos, term_status),
            class=="special" ~ special(dist_year),
            class=="admin" ~ admin(dist_age, yos, term_status),
            class=="eco" ~.03,
            class=="eso" ~ .03,
            class=="judges" ~ 0.0333,
            class=="senior_management" ~ 0.02,
            .default = NA_real_
  )  
}


tier3 <- function(class, dist_age, dist_year, yos, term_status){
  
  regular <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 68 & yos >= 8) | (yos >= 36) ~ 0.0168,
      (dist_age >= 67 & yos >= 8) | (yos >= 35) ~ 0.0165,
      (dist_age >= 66 & yos >= 8) | (yos >= 34) ~ 0.0163,
      (dist_age >= 65 & yos >= 8) | (yos >= 33) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }  
  
  special <- function(dist_year){
    case_when(dist_year <= 1974 ~ 0.02,
              .default = 0.03)
  }
  
  admin <- function(dist_age, yos, term_status){
    case_when(
      dist_age >= 63 & yos >= 8 ~ 0.0168,
      dist_age >= 62 & yos >= 8 ~ 0.0165,
      dist_age >= 61 & yos >= 8 ~ 0.0163,
      dist_age >= 60 & yos >= 8 ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }  
  
  case_when(class=="regular" ~ regular(dist_age, yos, term_status),
            class=="special" ~ special(dist_year),
            class=="admin" ~ admin(dist_age, yos, term_status),
            class=="eco" ~.03,
            class=="eso" ~ .03,
            class=="judges" ~ 0.0333,
            class=="senior_management" ~ 0.02,
            .default = NA_real_
  )  
}


benmult <- function(class, tier, dist_age, dist_year, yos, term_status){
  case_when(tier=="1" ~ tier1(class, dist_age, dist_year, yos, term_status),
            tier=="2" ~ tier2(class, dist_age, dist_year, yos, term_status),
            tier=="3" ~ tier3(class, dist_age, dist_year, yos, term_status),
            .default = NA_real_
  )
}

get_reduce_factor <- function(class, tier, term_status, dist_age){
  # get the reduction factor -- early retirement benefit as 
  # proportion of normal retirement benefit
  early_forumula <- function(reduction_rate, normal_age, dist_age){
    1 - reduction_rate*(normal_age - dist_age)
  }
  case_when(term_status == "norm" ~ 1,
            term_status == "early" & class == "special" ~ 
              case_when(tier=="1" ~ early_forumula(0.05, 55, dist_age),
                        tier=="2" ~ early_forumula(0.05, 60, dist_age),
                        tier=="3" ~ early_forumula(0.05, 60, dist_age),
                        .default = NA_real_),
            term_status == "early" & class != "special" ~ 
              case_when(tier=="1" ~ early_forumula(0.05, 62, dist_age),
                        tier=="2" ~ early_forumula(0.05, 65, dist_age),
                        tier=="3" ~ early_forumula(0.05, 65, dist_age),
                        .default = NA_real_),
            .default = NA_real_
  )
}

tier_lookup <- tibble(tier_at_dist_age = 
                        unique(ann_factor_table_stacked$tier_at_dist_age)) |> 
  mutate(tier = str_sub(tier_at_dist_age, 6, 6),
         term_status=str_sub(tier_at_dist_age, 8, -1),
         is_norm_retire_elig=str_ends(tier_at_dist_age, "norm"))
tier_lookup

# define names exactly as they are in reason's benefit_table (plus class) although their are a lot
keep_names <- rlang::quos(class, entry_year, entry_age, dist_year, dist_age, yos, term_age, class_name, is_norm_retire_elig, term_year, mort_final, tier_at_dist_age, dr, yos_b4_2011, cola, cum_dr, cum_mort, cum_cola, cum_mort_dr, cum_mort_dr_cola, ann_factor, tier_at_term_age, start_sal, entrant_dist, cumprod_salary_increase, entry_salary, max_entry_year, salary, fas_period, fas, db_ee_cont, db_ee_balance, ben_mult, reduce_factor, db_benefit, ann_factor_term, pvfb_db_at_term_age)
# select(!!!keep_names)

a <- proc.time()
benefit_table_stacked <- ann_factor_table_stacked |> 
  # filter(class=="regular") |>
  mutate(term_age = entry_age + yos) |> 
  left_join(tier_lookup,
            by = join_by(tier_at_dist_age)) |>
  left_join(salary_benefit_table_stacked,
            by = join_by(class, entry_year, entry_age, yos, term_age)) |> 
  mutate(ben_mult = benmult(class, tier, dist_age, dist_year, yos, term_status),
         reduce_factor = get_reduce_factor(class, tier, term_status, dist_age),
         
         db_benefit = yos * ben_mult * fas * reduce_factor,
         db_benefit = db_benefit * params$cal_factor_, # calibrate normal cost to val report
         
         ann_factor_term = ann_factor * cum_mort_dr, # annuity factor at termination day
         
         pvfb_db_at_term_age = db_benefit * ann_factor_term # discount future DB benefits back to termination day
         )
b <- proc.time()
b - a # 7.6 secs
  
benefit_table_stacked |> 
  #filter(tier=="1", term_status=="normal") |> 
  select(ben_mult) |>
  skim_without_charts()

count(benefit_table_stacked, tier)
count(benefit_table_stacked, term_status)

check <- benefit_table_stacked |> 
  filter(tier=="1", rtype=="normal") |>
  filter(is.na(ben_mult)) |> 
  select(class, tier_at_dist_age, tier, dist_age, dist_year, yos, rtype, ben_mult)

# END benefit_table_stacked ----


# dist_age_table_stacked ----

get_dist_age_table_stacked <- function(benefit_table_stacked){
  # Determine the ultimate distribution age for each member (the age when they're assumed to retire/get a refund, given their termination age)
  dist_age_table_stacked <- benefit_table_stacked |> 
    summarise(
      earliest_norm_retire_age = n() - sum(is_norm_retire_elig) + min(dist_age),
      term_status = first(term_status),
      .by=c(class, entry_year, entry_age, term_age)
    ) |> 
    mutate(
      dist_age = if_else(
        term_status == "vested",
        earliest_norm_retire_age, 
        term_age)
    ) |> 
    select(class, entry_year, entry_age, term_age, dist_age)
  
  return(dist_age_table_stacked)
}

system.time(dist_age_table_stacked <- get_dist_age_table_stacked(benefit_table_stacked)) # 2.3 secs
# dist_age_table <- bm_env$get_dist_age_table(benefit_table) # for checking

# END dist_age_table_stacked ----


# final_benefit_table_stacked ----

get_final_benefit_table_stacked <- function(benefit_table_stacked, dist_age_table_stacked){
  
  # Retain only the final distribution ages in the final_benefit_table
  final_benefit_table_stacked <- benefit_table_stacked |> 
    semi_join(dist_age_table_stacked,
              by = join_by(class, entry_year, entry_age, dist_age, term_age)) %>% 
    select(class, entry_year, entry_age, term_age, dist_age, db_benefit, pvfb_db_at_term_age, ann_factor_term) %>% 
    mutate(
      # NA benefit values (because the member is not vested) are replaced with 0
      db_benefit = if_else(is.na(db_benefit), 0, db_benefit),
      pvfb_db_at_term_age = if_else(is.na(pvfb_db_at_term_age), 0, pvfb_db_at_term_age)
    )
  
  return(final_benefit_table_stacked)
}

system.time(final_benefit_table_stacked <- get_final_benefit_table_stacked(benefit_table_stacked, dist_age_table_stacked))
# final_benefit_table <- bm_env$get_final_benefit_table(benefit_table, dist_age_table)  # checks

# END final_benefit_table_stacked ----


# benefit_val_table_stacked ----
benefit_val_table <- bm_env$get_benefit_val_table(
  salary_benefit_table,
  final_benefit_table,
  separation_rate_table,
  params)

tierterm_lookup <- salary_benefit_table_stacked |> 
  select(tier_at_term_age) |> 
  distinct() |> 
  as_tibble() |> 
  mutate(tier = str_sub(tier_at_term_age, 6, 6),
         term_status=str_sub(tier_at_term_age, 8, -1),
         sep_type = case_when(
           str_detect(tier_at_term_age, "early|norm|reduced") ~ "retire",
           str_detect(tier_at_term_age, "non_vested") ~ "non_vested",
           str_detect(tier_at_term_age, "vested") ~ "vested",
           .default = NULL # Reason did not give an explicit default, which means it is NULL; perhaps NA_character_ would be better
           ))
tierterm_lookup

library(data.table)

npv <- function(cashflows, rate, immediate=FALSE) {
  n <- length(cashflows)
  if (immediate) { # cash flows at beginning of period
    powers <- 0:(n-1)
  } else {  # cash flows at end of period
    powers <- 1:n
  }
  sum(cashflows / (1 + rate)^powers)
}

get_pvfb <- function(sep_rate_vec, interest_vec, value_vec){ 
  pv <- function(i){
    sep_prob <- cumprod(1 - data.table::shift(sep_rate_vec[i:end], n = 2, fill = 0)) * 
      data.table::shift(sep_rate_vec[i:end], n = 1, fill = 0)
    cashflow <- sep_prob * value_vec[i:end]
    npv(cashflow, interest_vec[i], immediate = TRUE)
  }
  end <- length(sep_rate_vec)
  # loop below has proven to be faster than purrr::map()
  pvfb <- double(length = end)
  for (i in 1:end) {
    pvfb[i] <- pv(i)
  }
  # CAUTION: temporary treatment to replace zeros with NAs to match FRS model results
  pvfb[pvfb == 0] <- NA
  pvfb
}

get_pvfs <- function(remaining_prob_vec, interest_vec, sal_vec){ 
  pv <- function(i){
    saladj <- sal_vec[i:end] * remaining_prob_vec[i:end] /  remaining_prob_vec[i]
    npv(saladj, interest_vec[i], immediate = FALSE)
  }
  end <- length(sal_vec)
  pvfs <- double(length = end)
  for (i in 1:end) {
    pvfs[i] <- pv(i)
  }
  pvfs
}

get_benefit_val_table_stacked <- function(
    salary_benefit_table_stacked,
    final_benefit_table_stacked,
    separation_rate_table_stacked,
    params){
  
  benefit_val_table_stacked <- salary_benefit_table_stacked |> 
    left_join(final_benefit_table_stacked,
              by = join_by(class, entry_age, entry_year, term_age)) |> 
    left_join(separation_rate_table_stacked,
              by = join_by(class, entry_year, entry_age, yos, term_age))  |> 
    left_join(tierterm_lookup |> 
                select(tier_at_term_age, tier, sep_type),
              by = join_by(tier_at_term_age)) |>
    mutate(
      # note that the tier below applies at termination age only
      dr = if_else(tier=="3", params$dr_new_, params$dr_current_),
      ben_decision = case_when(
        yos == 0 ~ NA_character_,
        sep_type == "retire" ~ "retire",
        sep_type == "vested" ~ "mix",
        sep_type == "non_vested" ~ "refund",
        .default = NA_character_
      ),
      pvfb_db_wealth_at_term_age = case_when(
        sep_type == "retire" ~ pvfb_db_at_term_age,
        sep_type == "vested" ~ (params$retire_refund_ratio_ * pvfb_db_at_term_age + 
                                  (1 - params$retire_refund_ratio_) * db_ee_balance),
        sep_type == "non_vested" ~ db_ee_balance
      ))|> 
    mutate(
      # instead of pentools::get_pvfb
      pvfb_db_wealth_at_current_age = get_pvfb(sep_rate_vec = separation_rate,
                                                         interest_vec = dr,
                                                         value_vec = pvfb_db_wealth_at_term_age),
      
      # calculate the present value of future salary at current age (discount the annual salary back to current age)
      # instead of pentools::get_pvfs
      pvfs_at_current_age = get_pvfs(remaining_prob_vec = remaining_prob,
                                               interest_vec = dr,
                                               sal_vec = salary),
      
      # calculate the individual normal cost rate at current age
      indv_norm_cost = pvfb_db_wealth_at_current_age[yos == 0] / pvfs_at_current_age[yos == 0],
      
      # calculate the present value of future normal cost at current age (discount the annual normal cost back to current age)
      pvfnc_db = indv_norm_cost * pvfs_at_current_age,
      .by = c(class, entry_year, entry_age)
    )
  
  return(benefit_val_table_stacked)
}

a <- proc.time()
benefit_val_table_stacked <- get_benefit_val_table_stacked(
  salary_benefit_table_stacked,
  final_benefit_table_stacked,
  separation_rate_table_stacked,
  params)
b <- proc.time()
b - a

# END benefit_val_table_stacked ----


# indv_norm_cost_table_stacked ----

indv_norm_cost_table_stacked <- benefit_val_table_stacked
  filter(yos == 0) |> 
  select(class, entry_year, entry_age, indv_norm_cost)

# END indv_norm_cost_table_stacked ----


# agg_norm_cost_table_stacked ----
# agg_norm_cost_table <- get_agg_norm_cost_table(
#   indv_norm_cost_table,
#   salary_headcount_table,
#   salary_benefit_table) # for checking

indv_norm_cost_table <- indv_norm_cost_table_stacked |> 
    filter(class=="admin") |>
    select(entry_year, entry_age, indv_norm_cost) |> 
    as_tibble()
salary_headcount_table <- params$salary_headcount_table_list$admin_salary_headcount_table   
salary_benefit_table <- salary_benefit_table_stacked |> 
  filter(class=="admin") |>
  select(-class) |> 
  as_tibble()
agg_norm_cost_table <- bm_env$get_agg_norm_cost_table(indv_norm_cost_table, salary_headcount_table, salary_benefit_table)
  
agg_norm_cost_table_stacked <- indv_norm_cost_table_stacked |> 
  select(class, entry_year, entry_age, indv_norm_cost) |> 
  left_join(salary_headcount_table_stacked, 
            by = join_by(class, entry_year, entry_age)) |>
  left_join(salary_benefit_table_stacked  |> 
              select(class, entry_year, entry_age, yos, salary),
            by = join_by(class, entry_year, entry_age, yos)) |>
  filter(!is.na(count)) %>% 
  summarise(agg_normal_cost = sum(indv_norm_cost * salary * count) / sum(salary * count),
            .by=class)  
  

# END agg_norm_cost_table_stacked ----


# return list of tables ----
# output <- list(
#   ann_factor_table         = ann_factor_table,
#   ann_factor_retire_table  = ann_factor_retire_table,
#   benefit_table            = benefit_table,
#   final_benefit_table      = final_benefit_table,
#   benefit_val_table        = benefit_val_table,
#   indv_norm_cost_table     = indv_norm_cost_table,
#   agg_norm_cost_table      = agg_norm_cost_table
# )

# names(params$wf_data_list)




# outputs from the model (stacked)
liability_list_stacked <- readRDS(fs::path(stackdir, "liability_list_stacked.rds"))



# current call in FRS_funding_model_functions.R ----
# Use mclapply to run the liability model in parallel. May not work properly
# with Windows OS or API. Switch back to lapply if needed. When working,
# mclapply will be about twice as fast as lapply.
a <- proc.time()


# get values of arguments to get_liability_data for this class and then call it
call_get_liability_data <- function(class_name) {
  # create lists of data frames so that get_liablity_data does not have to (dangerously) pull data from the global environment with assign
  
  element_name <- paste0(class_name, "_wf_data")
  wf_data <- wf_data_list[[element_name]]
  
  ben_payment_current <- params[[paste0(class_name, "_ben_payment_current_")]]
  retiree_pop_current <- params[[paste0(class_name, "_retiree_pop_current_")]]
  pvfb_term_current <- params[[paste0(class_name, "_pvfb_term_current_")]]
  
  element_name <- paste0(class_name, "_entrant_profile_table")
  entrant_profile_table <- entrant_profile_table_list[[element_name]]
  
  element_name <- paste0(class_name, "_salary_headcount_table")
  salary_headcount_table <- salary_headcount_table_list[[element_name]]    
  
  element_name <- paste0(class_name, "_mort_table")
  mort_table <- mort_table_list[[element_name]]     
  
  element_name <- paste0(class_name, "_separation_rate_table")
  separation_rate_table <- separation_rate_table_list[[element_name]]         
  
  element_name <- paste0(class_name, "_mort_retire_table")
  mort_retire_table <- mort_retire_table_list[[element_name]]         
  
  lm_env$get_liability_data(class_name, 
                            wf_data, 
                            ben_payment_current, 
                            retiree_pop_current,
                            pvfb_term_current,
                            entrant_profile_table,
                            salary_headcount_table,
                            mort_table,
                            mort_retire_table,
                            separation_rate_table,
                            params)
}

liability_list <- mclapply(
  X = params$class_names_no_drop_frs_, 
  FUN = call_get_liability_data,
  # Set mc.cores to 1 for compatibility with Windows
  mc.cores = 1
)
names(liability_list) <- params$class_names_no_drop_frs_
b <- proc.time()


# checks ----

#.. salary_growth_table_checks ----
class_name <- "regular"
sgt1 <- params$salary_growth_table_ |> 
  select(yos, contains(class_name)) |> 
  rename(cumprod_salary_increase = 2)

sgt2 <- pendata::frs$salary_growth |> 
  rename(cumprod_salary_increase = cumprod_increase)

check <- bind_rows(sgt1 |> mutate(src="reason"),
                   sgt2 |> 
                     filter(class=="regular") |> 
                     select(yos, cumprod_salary_increase) |>
                     mutate(src="pendata"))
check |> 
  pivot_wider(names_from = src, values_from = cumprod_salary_increase) |> 
  ht()

