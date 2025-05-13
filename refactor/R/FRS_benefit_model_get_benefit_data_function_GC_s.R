
# Benefit Model Function --------------------------------------------------

# here is where Reason selectively sets global variables, presumably to test the function

# class_name = class_name_
# dr_current = dr_current_
# dr_new = dr_new_
# cola_tier_1_active = cola_tier_1_active_
# cola_tier_2_active = cola_tier_2_active_
# cola_tier_3_active = cola_tier_3_active_
# cola_current_retire = cola_current_retire_
# cola_current_retire_one = cola_current_retire_one_
# one_time_cola = one_time_cola_
# retire_refund_ratio = retire_refund_ratio_
# cal_factor = cal_factor_

get_agg_norm_cost_table_s <- function(
    indv_norm_cost_table_s,
    salary_headcount_table_s,
    salary_benefit_table_s){
  
  agg_norm_cost_table_s <- indv_norm_cost_table_s %>% 
    left_join(salary_headcount_table_s, by = c("class", "entry_year", "entry_age")) %>%
    left_join(salary_benefit_table_s %>% select(class, entry_year, entry_age, yos, salary), by = c("class", "entry_year", "entry_age", "yos")) %>%
    filter(!is.na(count)) %>%
    group_by(class) %>%
    summarise(
      agg_normal_cost = sum(indv_norm_cost * salary * count) / sum(salary * count)
    )
  return(agg_norm_cost_table_s)
}


get_annuity_factor_retire_table_s <- function(
    mort_retire_table_s,
    params) {
  ann_factor_retire_table_s <- mort_retire_table_s %>% 
    mutate(
      dr = params$dr_current_,
      cola_type = if_else(params$one_time_cola_ == TRUE, "one_time", "normal"),
      cola = if_else(cola_type == "one_time", 
                     if_else(year == params$new_year_, params$cola_current_retire_one_, 0),
                     params$cola_current_retire_)
    ) %>% 
    group_by(class, base_age) %>% 
    mutate(
      cum_dr = cumprod(1 + lag(dr, default = 0)),
      cum_mort = cumprod(1 - lag(mort_final, default = 0)),
      cum_mort_dr = cum_mort / cum_dr,
      ann_factor_retire = pentools::annfactor(cum_mort_dr, cola_vec = cola, one_time_cola = params$one_time_cola_)
    ) %>%
    ungroup()
    
  return(ann_factor_retire_table_s)
}



get_annuity_factor_table_s <- function(
    mort_table_s,
    salary_benefit_table_s,
    params
) {
  ann_factor_table_s <- mort_table_s %>%
    semi_join(salary_benefit_table_s, by = c("entry_year", "entry_age", "class")) %>%
    left_join(frs_data_env$dr_lookup, by = c("tier_at_dist_age")) %>%
    left_join(frs_data_env$cola_lookup, 
              by = c("tier_at_dist_age", "entry_year", "yos")) %>%
    group_by(class, entry_year, entry_age, yos) %>% 
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
  
  return(ann_factor_table_s)
}


get_benefit_table_s <- function(ann_factor_table_s, 
                                salary_benefit_table_s,
                                params){
  
  benefit_table_s <- ann_factor_table_s %>%
    mutate(
      term_age = entry_age + yos, .before = term_year
    ) %>%
    # dist_age is distribution age, and dist_year is distribution year.
    # distribution age means the age when the member starts to accept benefits (either a refund or a pension)
    left_join(salary_benefit_table_s,
              by = c("entry_year", "entry_age", "yos", "term_age", "class")) %>%
    left_join(frs_data_env$ben_mult_lookup %>% select(-system),
              by = join_by(class, 
                           tier_at_dist_age,
                           dist_age >= dist_age_min_ge,
                           dist_age < dist_age_max_lt,
                           yos >= yos_min_ge,
                           yos < yos_max_lt,
                           dist_year >= dist_year_min_ge,
                           dist_year < dist_year_max_lt)) %>%
    left_join(frs_data_env$reduce_factor_lookup,
              by = c("tier_at_dist_age", "dist_age", "class")) %>%
    mutate(db_benefit = yos * ben_mult * fas * reduce_factor,
           
           #cal_factor is a calibration factor added to match the normal cost from the val report
           db_benefit = db_benefit * params$cal_factor_,
           
           #calculate the annuity factor at termination day
           ann_factor_term = ann_factor * cum_mort_dr,
           
           #calculate the actuarial present value of future DB benefits at termination day (discount the annual DB benefits back to termination day)
           pvfb_db_at_term_age = db_benefit * ann_factor_term
           
    ) %>%
    ungroup()
  
  
  return(benefit_table_s)  
}


get_benefit_val_table_s <- function(
    salary_benefit_table_s,
    final_benefit_table_s,
    separation_rate_table_s,
    params){
  
  benefit_val_table_s <- salary_benefit_table_s %>% 
    left_join(final_benefit_table_s, by = c("class", "entry_year", "entry_age", "term_age")) %>%
    left_join(separation_rate_table_s,
              by = c("class", "entry_year", "entry_age", "yos", "term_age")) %>%
    left_join(frs_data_env$dr_lookup, by = c("tier" = "tier_at_dist_age")) %>%
    mutate(
      #note that the tier below applies at termination age only
      #dr = if_else(str_detect(tier_at_term_age, "tier_3"), params$dr_new_, params$dr_current_),
      # sep_type = get_sep_type(tier_at_term_age),
      # ben_decision = if_else(yos == 0, 
      #                        NA, 
      #                        if_else(sep_type == "retire", "retire",
      #                                if_else(sep_type == "vested", "mix", "refund"))),
      sep_type = case_when(
        str_detect(tier_at_term_age, "early|norm|reduced") ~ "retire",
        str_detect(tier_at_term_age, "non_vested") ~ "non_vested",
        str_detect(tier_at_term_age, "vested") & !str_detect(tier_at_term_age, "non_vested") ~ "vested",
        TRUE ~ NA
      ),
      ben_decision = case_when(
        yos == 0 ~ NA,
        sep_type == "retire" ~ "retire",
        sep_type == "vested" ~ "mix",
        TRUE ~ "refund"
      ),
      pvfb_db_wealth_at_term_age = case_when(
        sep_type == "retire" ~ pvfb_db_at_term_age,
        sep_type == "vested" ~ (params$retire_refund_ratio_ * pvfb_db_at_term_age + (1 - params$retire_refund_ratio_) * db_ee_balance),
        sep_type == "non_vested" ~ db_ee_balance
      )
    ) %>% 
    group_by(class, entry_year, entry_age) %>%
    mutate(
      #calculate the present value of future DB benefits at current age (discount the annual DB benefits back to current age)
      pvfb_db_wealth_at_current_age = pentools::get_pvfb(sep_rate_vec = separation_rate, interest_vec = dr, value_vec = pvfb_db_wealth_at_term_age),
      
      #calculate the present value of future salary at current age (discount the annual salary back to current age)
      pvfs_at_current_age = pentools::get_pvfs(remaining_prob_vec = remaining_prob, interest_vec = dr, sal_vec = salary),
      
      #calculate the individual normal cost rate at current age
      indv_norm_cost = pvfb_db_wealth_at_current_age[yos == 0] / pvfs_at_current_age[yos == 0],
      
      #calculate the present value of future normal cost at current age (discount the annual normal cost back to current age)
      pvfnc_db = indv_norm_cost * pvfs_at_current_age
    ) %>% 
    ungroup()
  
  return(benefit_val_table_s)
}



# get_class_salary_growth_table <- function(class_name, salary_growth_table){
#   
#   class_salary_growth_table <- salary_growth_table %>% 
#     select(yos, contains(class_name)) %>% 
#     rename(cumprod_salary_increase = 2)
#   
#   return(class_salary_growth_table)
# }


get_dist_age_table_s <- function(benefit_table_s){
  # Determine the ultimate distribution age for each member (the age when they're assumed to retire/get a refund, given their termination age)
  
  dist_age_table_s <- benefit_table_s %>%
    mutate(is_norm_retire_elig = tier_at_dist_age %in% c("tier_1_norm", "tier_2_norm", "tier_3_norm")) %>%
    group_by(class, entry_year, entry_age, term_age) %>%
    summarise(
      earliest_norm_retire_age = n() - sum(is_norm_retire_elig) + min(dist_age),    
      term_status = tier_at_term_age[1]) %>%
    mutate(
      dist_age = if_else(
        str_detect(term_status, "vested") & !str_detect(term_status, "non_vested"),
        earliest_norm_retire_age, 
        term_age
      )
    ) %>% 
    select(class, entry_year, entry_age, term_age, dist_age) %>%
    ungroup()
  
  return(dist_age_table_s)
}


get_final_benefit_table_s <- function(benefit_table_s, dist_age_table_s){
  
  #Retain only the final distribution ages in the final_benefit_table
  final_benefit_table_s <- benefit_table_s %>% 
    semi_join(dist_age_table_s,
              by = join_by(class, entry_year, entry_age, dist_age, term_age)) %>% 
    select(class, entry_year, entry_age, term_age, dist_age, db_benefit, pvfb_db_at_term_age, ann_factor_term) %>% 
    mutate(
      #NA benefit values (because the member is not vested) are replaced with 0
      db_benefit = if_else(is.na(db_benefit), 0, db_benefit),
      pvfb_db_at_term_age = if_else(is.na(pvfb_db_at_term_age), 0, pvfb_db_at_term_age)
    )
  
  return(final_benefit_table_s)
}



get_salary_benefit_table_s <- function(entrant_profile_table_s,
                                       salary_growth_table_s,
                                       salary_headcount_table_s,
                                       params){
  
  salary_benefit_table_s <- expand_grid(entry_year = params$entry_year_range_, 
                                        entry_age = entrant_profile_table_s$entry_age, 
                                        yos = params$yos_range_,
                                        class = params$class_names_no_drop_frs_) %>%
    mutate(
      term_age = entry_age + yos) %>%
    left_join(frs_data_env$tier_table, by = c("entry_year", "yos", "term_age"= "age", "class")) %>%
    mutate(tier_at_term_age = tier) %>%
    filter(term_age <= params$max_age_) %>% 
    arrange(entry_year, entry_age, yos) %>% 
    left_join(entrant_profile_table_s, by = c("entry_age", "class")) %>%
    filter(is.na(start_sal) == FALSE) %>%
    left_join(salary_growth_table_s, by = c("yos", "class")) %>%
    left_join(salary_headcount_table_s %>% select(entry_year, entry_age, entry_salary, class), 
              by = c("entry_year", "entry_age", "class")) %>%
    mutate(ref_year = if_else(class == "admin", 2015, 2020)) %>%
    mutate(
      salary = if_else(entry_year <= ref_year, 
                       entry_salary * cumprod_salary_increase,
                       start_sal * cumprod_salary_increase * (1 + params$payroll_growth_)^(entry_year - ref_year))
    ) %>% 
    left_join(frs_data_env$fas_period_lookup, by = c("tier_at_term_age")) %>%
    group_by(class, entry_year, entry_age) %>%
    distinct() %>%
    mutate(
      fas = RcppRoll::roll_mean(c(NA, salary[-length(salary)]), # drop the current value
                                n = max(fas_period), align="right", fill = NA),
      db_ee_cont = params$db_ee_cont_rate_ * salary,
      db_ee_balance = pentools::get_cum_fv(params$db_ee_interest_rate_, db_ee_cont),
    ) %>%
    ungroup() %>%
    filter(!is.na(salary)) %>%
    filter(!is.na(start_sal)) %>%
    select(-ref_year)
  
  return(salary_benefit_table_s)
}


# get_benefit_data -- primary function ------------------------------------

get_benefit_data_s <- function(
    entrant_profile_table_s,
    salary_headcount_table_s,
    mort_table_s,
    mort_retire_table_s,
    separation_rate_table_s,
    params
) {
  
  salary_growth_table_s <- params$salary_growth_table
  
  # class_salary_growth_table <- get_class_salary_growth_table(class_name, params$salary_growth_table_)
  salary_benefit_table_s <- get_salary_benefit_table_s(entrant_profile_table_s,
                                                       salary_growth_table_s,
                                                       salary_headcount_table_s,
                                                       params)
  
  ann_factor_table_s <- get_annuity_factor_table_s(
    mort_table_s,
    salary_benefit_table_s,
    params)
  
  ann_factor_retire_table_s <- get_annuity_factor_retire_table_s(
    mort_retire_table_s,
    params
  )
  
  benefit_table_s <- get_benefit_table_s(
    ann_factor_table_s,
    salary_benefit_table_s,
    params)
  
  dist_age_table_s <- get_dist_age_table_s(benefit_table_s)
  
  final_benefit_table_s <- get_final_benefit_table_s(benefit_table_s, dist_age_table_s)
  
  ## Benefit Accrual & Normal Cost #######
  
  benefit_val_table_s <- get_benefit_val_table_s(
    salary_benefit_table_s,
    final_benefit_table_s,
    separation_rate_table_s,
    params)
  
  # next step too small to need its own function
  indv_norm_cost_table_s <- benefit_val_table_s %>% 
    filter(yos == 0) %>% 
    select(class, entry_year, entry_age, indv_norm_cost)
  
  agg_norm_cost_table_s <- get_agg_norm_cost_table_s(
    indv_norm_cost_table_s,
    salary_headcount_table_s,
    salary_benefit_table_s)
  
  # return list of tables ----
  output <- list(
    ann_factor_table_s         = ann_factor_table_s,
    ann_factor_retire_table_s  = ann_factor_retire_table_s,
    benefit_table_s            = benefit_table_s,
    final_benefit_table_s      = final_benefit_table_s,
    benefit_val_table_s        = benefit_val_table_s,
    indv_norm_cost_table_s     = indv_norm_cost_table_s,
    agg_norm_cost_table_s      = agg_norm_cost_table_s
  )
  
  return(output)
}

##This is temporary code to test the function
benefit_data_s <- get_benefit_data_s(
  frs_data_env$entrant_profile_table,
  frs_data_env$salary_headcount_table,
  frs_data_env$mort_table,
  frs_data_env$mort_retire_table,
  frs_data_env$separation_rate_table,
  params
)

##This is temporary code to test the function
get_benefit_data <- function(
    class_name,
    entrant_profile_table_s,
    salary_headcount_table_s,
    mort_table_s,
    mort_retire_table_s,
    separation_rate_table_s,
    params) {

  force(entrant_profile_table_s)
  force(salary_headcount_table_s)
  force(mort_table_s)
  force(mort_retire_table_s)
  force(separation_rate_table_s)

  benefit_data <- list(
    ann_factor_table        = bm_env$benefit_data_s$ann_factor_table_s %>% ungroup() %>% filter(class == class_name) %>% select(-class),
    ann_factor_retire_table = bm_env$benefit_data_s$ann_factor_retire_table_s %>% ungroup() %>% filter(class == class_name) %>% select(-class),
    benefit_table           = bm_env$benefit_data_s$benefit_table_s %>% ungroup() %>% filter(class == class_name) %>% select(-class),
    final_benefit_table     = bm_env$benefit_data_s$final_benefit_table_s %>% ungroup() %>% filter(class == class_name) %>% select(-class),
    benefit_val_table       = bm_env$benefit_data_s$benefit_val_table_s %>% ungroup() %>% filter(class == class_name) %>% select(-class),
    indv_norm_cost_table    = bm_env$benefit_data_s$indv_norm_cost_table_s %>% ungroup() %>% filter(class == class_name) %>% select(-class),
    agg_norm_cost_table     = bm_env$benefit_data_s$agg_norm_cost_table_s %>% ungroup() %>% filter(class == class_name) %>% select(-class)
  )

  return(benefit_data)

}

# # test --------------------------------------------------------------------
# 
# benefit_data_s <- get_benefit_data_s(
#   frs_data_env$entrant_profile_table,
#   frs_data_env$salary_headcount_table,
#   frs_data_env$mort_table,
#   frs_data_env$mort_retire_table,
#   frs_data_env$separation_rate_table,
#   params
# )
# #
# benefit_data_regular <- get_benefit_data(
#   "regular",
#   frs_data_env$regular_entrant_profile_table,
#   frs_data_env$regular_salary_headcount_table,
#   frs_data_env$regular_mort_table,
#   frs_data_env$regular_mort_retire_table,
#   frs_data_env$regular_separation_rate_table,
#   params
# )
# 
# identical(benefit_data_s$ann_factor_table %>% filter(class == "regular") %>% select(-class), benefit_data_regular$ann_factor_table)
# identical(benefit_data_s$ann_factor_retire_table %>% filter(class == "regular") %>% select(-class), benefit_data_regular$ann_factor_retire_table)
# identical(benefit_data_s$benefit_table %>% filter(class == "regular") %>% select(-class), benefit_data_regular$benefit_table %>% select(-starts_with("class")))
# identical(benefit_data_s$final_benefit_table %>% filter(class == "regular") %>% select(-class), benefit_data_regular$final_benefit_table)
# identical(benefit_data_s$benefit_val_table %>% filter(class == "regular") %>% select(-class), benefit_data_regular$benefit_val_table %>% select(-starts_with("class")))
# identical(benefit_data_s$indv_norm_cost_table %>% filter(class == "regular") %>% select(-class), benefit_data_regular$indv_norm_cost_table)
# identical(benefit_data_s$agg_norm_cost_table %>% filter(class == "regular") %>% select(-class), benefit_data_regular$agg_norm_cost_table)
# #
# benefit_data_special <- get_benefit_data(
#   "special",
#   frs_data_env$special_entrant_profile_table,
#   frs_data_env$special_salary_headcount_table,
#   frs_data_env$special_mort_table,
#   frs_data_env$special_mort_retire_table,
#   frs_data_env$special_separation_rate_table,
#   params
# )
# identical(benefit_data_s$ann_factor_table %>% filter(class == "special") %>% select(-class), benefit_data_special$ann_factor_table)
# identical(benefit_data_s$ann_factor_retire_table %>% filter(class == "special") %>% select(-class), benefit_data_special$ann_factor_retire_table)
# identical(benefit_data_s$benefit_table %>% filter(class == "special") %>% select(-class), benefit_data_special$benefit_table %>% select(-starts_with("class")))
# identical(benefit_data_s$final_benefit_table %>% filter(class == "special") %>% select(-class), benefit_data_special$final_benefit_table)
# identical(benefit_data_s$benefit_val_table %>% filter(class == "special") %>% select(-class), benefit_data_special$benefit_val_table %>% select(-starts_with("class")))
# identical(benefit_data_s$indv_norm_cost_table %>% filter(class == "special") %>% select(-class), benefit_data_special$indv_norm_cost_table)
# identical(benefit_data_s$agg_norm_cost_table %>% filter(class == "special") %>% select(-class), benefit_data_special$agg_norm_cost_table)
# 
# #
# benefit_data_admin <- get_benefit_data(
#   "admin",
#   frs_data_env$admin_entrant_profile_table,
#   frs_data_env$admin_salary_headcount_table,
#   frs_data_env$admin_mort_table,
#   frs_data_env$admin_mort_retire_table,
#   frs_data_env$admin_separation_rate_table,
#   params
# )
# 
# identical(frs_data_env$entrant_profile_table %>% filter(class == "admin") %>% select(-class),
#           frs_data_env$admin_entrant_profile_table)
# identical(frs_data_env$salary_headcount_table %>% filter(class == "admin") %>% select(-class),
#           frs_data_env$admin_salary_headcount_table)
# identical(frs_data_env$mort_table %>% filter(class == "admin") %>% select(-class),
#           frs_data_env$admin_mort_table)
# identical(frs_data_env$mort_retire_table %>% filter(class == "admin") %>% select(-class),
#           frs_data_env$admin_mort_retire_table)
# identical(frs_data_env$separation_rate_table %>% filter(class == "admin") %>% select(-class),
#           frs_data_env$admin_separation_rate_table)
# 
# identical(benefit_data_s$ann_factor_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$ann_factor_table %>% select(-starts_with("class")))
# identical(benefit_data_s$ann_factor_retire_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$ann_factor_retire_table)
# identical(benefit_data_s$benefit_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$benefit_table %>% select(-starts_with("class")))
# identical(benefit_data_s$final_benefit_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$final_benefit_table)
# identical(benefit_data_s$benefit_val_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$benefit_val_table %>% select(-starts_with("class")))
# identical(benefit_data_s$indv_norm_cost_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$indv_norm_cost_table)
# identical(benefit_data_s$agg_norm_cost_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$agg_norm_cost_table)
# 
# #
# benefit_data_eso <- get_benefit_data(
#   "eso",
#   frs_data_env$eso_entrant_profile_table,
#   frs_data_env$eso_salary_headcount_table,
#   frs_data_env$eso_mort_table,
#   frs_data_env$eso_mort_retire_table,
#   frs_data_env$eso_separation_rate_table,
#   params
# )
# identical(benefit_data_s$ann_factor_table %>% filter(class == "eso") %>% select(-class), benefit_data_eso$ann_factor_table)
# identical(benefit_data_s$ann_factor_retire_table %>% filter(class == "eso") %>% select(-class), benefit_data_eso$ann_factor_retire_table)
# identical(benefit_data_s$benefit_table %>% filter(class == "eso") %>% select(-class), benefit_data_eso$benefit_table %>% select(-starts_with("class")))
# identical(benefit_data_s$final_benefit_table %>% filter(class == "eso") %>% select(-class), benefit_data_eso$final_benefit_table)
# identical(benefit_data_s$benefit_val_table %>% filter(class == "eso") %>% select(-class), benefit_data_eso$benefit_val_table %>% select(-starts_with("class")))
# identical(benefit_data_s$indv_norm_cost_table %>% filter(class == "eso") %>% select(-class), benefit_data_eso$indv_norm_cost_table)
# identical(benefit_data_s$agg_norm_cost_table %>% filter(class == "eso") %>% select(-class), benefit_data_eso$agg_norm_cost_table)
# 
# #
# benefit_data_eco <- get_benefit_data(
#   "eco",
#   frs_data_env$eco_entrant_profile_table,
#   frs_data_env$eco_salary_headcount_table,
#   frs_data_env$eco_mort_table,
#   frs_data_env$eco_mort_retire_table,
#   frs_data_env$eco_separation_rate_table,
#   params
# )
# identical(benefit_data_s$ann_factor_table %>% filter(class == "eco") %>% select(-class), benefit_data_eco$ann_factor_table)
# identical(benefit_data_s$ann_factor_retire_table %>% filter(class == "eco") %>% select(-class), benefit_data_eco$ann_factor_retire_table)
# identical(benefit_data_s$benefit_table %>% filter(class == "eco") %>% select(-class), benefit_data_eco$benefit_table %>% select(-starts_with("class")))
# identical(benefit_data_s$final_benefit_table %>% filter(class == "eco") %>% select(-class), benefit_data_eco$final_benefit_table)
# identical(benefit_data_s$benefit_val_table %>% filter(class == "eco") %>% select(-class), benefit_data_eco$benefit_val_table %>% select(-starts_with("class")))
# identical(benefit_data_s$indv_norm_cost_table %>% filter(class == "eco") %>% select(-class), benefit_data_eco$indv_norm_cost_table)
# identical(benefit_data_s$agg_norm_cost_table %>% filter(class == "eco") %>% select(-class), benefit_data_eco$agg_norm_cost_table)
# 
# #
# benefit_data_judges <- get_benefit_data(
#   "judges",
#   frs_data_env$judges_entrant_profile_table,
#   frs_data_env$judges_salary_headcount_table,
#   frs_data_env$judges_mort_table,
#   frs_data_env$judges_mort_retire_table,
#   frs_data_env$judges_separation_rate_table,
#   params
# )
# identical(benefit_data_s$ann_factor_table %>% filter(class == "judges") %>% select(-class), benefit_data_judges$ann_factor_table)
# identical(benefit_data_s$ann_factor_retire_table %>% filter(class == "judges") %>% select(-class), benefit_data_judges$ann_factor_retire_table)
# identical(benefit_data_s$benefit_table %>% filter(class == "judges") %>% select(-class), benefit_data_judges$benefit_table %>% select(-starts_with("class")))
# identical(benefit_data_s$final_benefit_table %>% filter(class == "judges") %>% select(-class), benefit_data_judges$final_benefit_table)
# identical(benefit_data_s$benefit_val_table %>% filter(class == "judges") %>% select(-class), benefit_data_judges$benefit_val_table %>% select(-starts_with("class")))
# identical(benefit_data_s$indv_norm_cost_table %>% filter(class == "judges") %>% select(-class), benefit_data_judges$indv_norm_cost_table)
# identical(benefit_data_s$agg_norm_cost_table %>% filter(class == "judges") %>% select(-class), benefit_data_judges$agg_norm_cost_table)
# 
# #
# benefit_data_senior_management <- get_benefit_data(
#   "senior_management",
#   frs_data_env$senior_management_entrant_profile_table,
#   frs_data_env$senior_management_salary_headcount_table,
#   frs_data_env$senior_management_mort_table,
#   frs_data_env$senior_management_mort_retire_table,
#   frs_data_env$senior_management_separation_rate_table,
#   params
# )
# identical(benefit_data_s$ann_factor_table %>% filter(class == "senior_management") %>% select(-class), benefit_data_senior_management$ann_factor_table)
# identical(benefit_data_s$ann_factor_retire_table %>% filter(class == "senior_management") %>% select(-class), benefit_data_senior_management$ann_factor_retire_table)
# identical(benefit_data_s$benefit_table %>% filter(class == "senior_management") %>% select(-class), benefit_data_senior_management$benefit_table %>% select(-starts_with("class")))
# identical(benefit_data_s$final_benefit_table %>% filter(class == "senior_management") %>% select(-class), benefit_data_senior_management$final_benefit_table)
# identical(benefit_data_s$benefit_val_table %>% filter(class == "senior_management") %>% select(-class), benefit_data_senior_management$benefit_val_table %>% select(-starts_with("class")))
# identical(benefit_data_s$indv_norm_cost_table %>% filter(class == "senior_management") %>% select(-class), benefit_data_senior_management$indv_norm_cost_table)
# identical(benefit_data_s$agg_norm_cost_table %>% filter(class == "senior_management") %>% select(-class), benefit_data_senior_management$agg_norm_cost_table)
# 
