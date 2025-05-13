

# Reason's return tables
#   ann_factor_table_stacked
#   ann_factor_retire_table_stacked
#   benefit_table_stacked
#   final_benefit_table_stacked   
#   benefit_val_table_stacked
#   indv_norm_cost_table_stacked
#   agg_norm_cost_table_stacked

# Boyd's additional return tables
# salary_benefit_table_stacked


# stacked salary benefit table ----
# this is fast and, based on testing, equivalent to the Reason approach

stubs <- crossing(inputs_stacked_env$entrant_profile_table_stacked |> 
                    select(class, entry_age),
                  entry_year = params$entry_year_range_,
                  yos = params$yos_range_) |> 
  mutate(term_age = entry_age + yos) |> 
  filter(term_age <= params$max_age_)
count(stubs, class)

# we need max_entry_year of JUST the records in the headcount table
max_entry_year <- inputs_stacked_env$salary_headcount_table_stacked |> 
  summarise(max_entry_year = max(entry_year, na.rm = TRUE),
            .by=class)

salary_benefit_table_stacked <- stubs |> 
  left_join(inputs_stacked_env$entrant_profile_table_stacked,
            by = join_by(class, entry_age)) |> 
  left_join(inputs_stacked_env$salary_growth_table_stacked,
            by = join_by(class, yos)) |> 
  filter(term_age <= params$max_age_) |> 
  mutate(tier_at_term_age = bm_env$get_tier(class, entry_year, term_age, yos, params$new_year_)) |> 
  # Join salary_head_count_table_stacked by entry_year and entry_age only to get historical entry_salary
  left_join(inputs_stacked_env$salary_headcount_table_stacked |> 
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

rm(max_entry_year, stubs)

# ann_factor_table_stacked ----
# Survival Probability and Annuity Factor for current retirees
source(fs::path(altdir, "make_ann_factor_table_stacked.R")) # modularize this -- it's too long

# ann_factor_retire_table_stacked ----
ann_factor_retire_table_stacked <- inputs_stacked_env$mort_retire_table_stacked |> 
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


# benefit_table_stacked ----
source(fs::path(altdir, "make_benefit_table_stacked.R"))

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

# benefit_val_table_stacked ----
source(fs::path(altdir, "make_benefit_val_table_stacked.R"))

# indv_norm_cost_table_stacked ----

indv_norm_cost_table_stacked <- benefit_val_table_stacked |> 
  filter(yos == 0) |> 
  select(class, entry_year, entry_age, indv_norm_cost)

# agg_norm_cost_table_stacked ----

agg_norm_cost_table_stacked <- indv_norm_cost_table_stacked |> 
  select(class, entry_year, entry_age, indv_norm_cost) |> 
  left_join(inputs_stacked_env$salary_headcount_table_stacked, 
            by = join_by(class, entry_year, entry_age)) |>
  left_join(salary_benefit_table_stacked  |> 
              select(class, entry_year, entry_age, yos, salary),
            by = join_by(class, entry_year, entry_age, yos)) |>
  filter(!is.na(count)) %>% 
  summarise(agg_normal_cost = sum(indv_norm_cost * salary * count) / sum(salary * count),
            .by=class) |> 
  as_tibble()


# create and save a stacked environment ----

data_list <- named_list(
  agg_norm_cost_table_stacked,
  ann_factor_table_stacked,
  ann_factor_retire_table_stacked,
  benefit_table_stacked,
  benefit_val_table_stacked,
  dist_age_table_stacked,
  final_benefit_table_stacked,
  indv_norm_cost_table_stacked,
  salary_benefit_table_stacked
)

benefit_data_stacked_env <- new.env()
list2env(data_list, envir = benefit_data_stacked_env)
ns(benefit_data_stacked_env)
system.time(save(benefit_data_stacked_env, file = fs::path(stackdir, "benefit_data_stacked_env.RData")))


# delete intermediate objects ----
rm(list=names(data_list))
rm(data_list)

gc()


