entrant_profile_table_s = frs_data_env$entrant_profile_table
salary_headcount_table_s = frs_data_env$salary_headcount_table
mort_table_s = frs_data_env$mort_table
mort_retire_table_s = frs_data_env$mort_retire_table
separation_rate_table_s = frs_data_env$separation_rate_table
mort_table_s <- frs_data_env$mort_table

entrant_profile_table = frs_data_env$admin_entrant_profile_table
salary_headcount_table = frs_data_env$admin_salary_headcount_table
mort_table = frs_data_env$admin_mort_table
mort_retire_table = frs_data_env$admin_mort_retire_table
separation_rate_table = frs_data_env$admin_separation_rate_table
class_salary_growth_table = frs_data_env$salary_growth_table %>% filter(class == "admin")

salary_growth_table_s <- params$salary_growth_table


# testing entrant_profile ---------------------------------------------------------

entrant_profile_table_s %>% filter(class == "admin") %>%
  left_join(frs_data_env$admin_entrant_profile_table, by = c("entry_age", "start_sal")) 

identical(entrant_profile_table_s %>% filter(class == "admin") %>% select(-class), frs_data_env$admin_entrant_profile_table)

# testing salary_headcount --------------------------------------------------------

salary_headcount_table_s %>% filter(class == "admin") %>%
  left_join(frs_data_env$admin_salary_headcount_table, by = c("entry_year", "entry_age", "age", "yos"))

identical(salary_headcount_table_s %>% filter(class == "admin") %>% select(-class), frs_data_env$admin_salary_headcount_table)

# mort --------------------------------------------------------------------
mort_table_s %>% filter(class == "admin") %>%
  left_join(frs_data_env$admin_mort_table, by = c("entry_year", "entry_age", "dist_year", "dist_age", "yos", "term_year", "tier_at_dist_age")) 

identical(mort_table_s %>% filter(class == "admin") %>% select(-class), frs_data_env$admin_mort_table)

# mort_retire -------------------------------------------------------------
mort_retire_table_s %>% filter(class == "admin") %>%
  left_join(frs_data_env$eso_mort_retire_table, by = c("base_age", "age", "year")) 

identical(mort_retire_table_s %>% filter(class == "admin") %>% select(-class), frs_data_env$admin_mort_retire_table)

# separation_rate --------------------------------------------------------
bind_rows(
  frs_data_env$admin_separation_rate_table %>% mutate(class = "admin"), 
  frs_data_env$eso_separation_rate_table %>% mutate(class = "eso"),
  frs_data_env$admin_separation_rate_table %>% mutate(class = "admin"),
  frs_data_env$judges_separation_rate_table %>% mutate(class = "judges"),
  frs_data_env$senior_management_separation_rate_table %>% mutate(class = "senior_management"),
  frs_data_env$special_separation_rate_table %>% mutate(class = "special"),
  frs_data_env$regular_separation_rate_table %>% mutate(class = "regular")
) %>%
  left_join(separation_rate_table_s,
            by = c("entry_year", "entry_age", "term_age", "yos", "term_year", "class"),
            suffix = c(".y", ".x")) %>%
  mutate(
    mismatch = separation_rate.x != separation_rate.y | xor(is.na(separation_rate.x), is.na(separation_rate.y)),
    mismatch_2 = remaining_prob.x != remaining_prob.y | xor(is.na(remaining_prob.x), is.na(remaining_prob.y)),
    mismatch_3 = separation_prob.x != separation_prob.y | xor(is.na(separation_prob.x), is.na(separation_prob.y))
  ) %>%
  filter(mismatch | mismatch_2 | mismatch_3)

identical(separation_rate_table_s %>% filter(class == "admin") %>% select(-class), frs_data_env$admin_separation_rate_table)

# test salary_benefit_table ------------------------------------------
get_salary_benefit_table <- function(class_name,
                                     entrant_profile_table,
                                     class_salary_growth_table,
                                     salary_headcount_table,
                                     params){
  #Create a long-form table of entry year, entry age, and yos and merge with salary data
  #Note that "age" in the salary_table is active age
  # entry_age = entrant_profile_table$entry_age
  salary_benefit_table <- expand_grid(entry_year = params$entry_year_range_, 
                                      entry_age = entrant_profile_table$entry_age, 
                                      yos = params$yos_range_) %>% 
    mutate(
      term_age = entry_age + yos#,
      # term_year = entry_year + yos,
      #tier_at_term_age = frs_data_env$get_tier(class_name, entry_year, term_age, yos, params$new_year_)
    ) %>% 
    left_join(frs_data_env$tier_table %>% filter(class == class_name) , by = c("entry_year", "yos", "term_age"= "age")) %>%
    mutate(tier_at_term_age = tier) %>%
    filter(term_age <= params$max_age_) %>% 
    arrange(entry_year, entry_age, yos) %>% 
    left_join(entrant_profile_table, by = "entry_age") %>% 
    left_join(class_salary_growth_table, by = "yos") %>%
    #Join salary_head_count_table by entry_year and entry_age only to get historical entry_salary
    left_join(salary_headcount_table %>% select(entry_year, entry_age, entry_salary), 
              by = c("entry_year", "entry_age")) %>%
    mutate(
      salary = if_else(entry_year <= max(salary_headcount_table$entry_year), 
                       entry_salary * cumprod_salary_increase,
                       start_sal * cumprod_salary_increase * (1 + params$payroll_growth_)^(entry_year - max(salary_headcount_table$entry_year)))
      # ,
      # fas_period = if_else(str_detect(tier_at_term_age, "tier_1"), 5, 8)
    ) %>% 
    left_join(frs_data_env$fas_period_lookup, by = c("tier_at_term_age")) %>%
    group_by(entry_year, entry_age) %>%
    mutate(
      # fas = baseR.rollmean(salary, fas_period),
      # code below is much faster than baseR.rollmean
      fas = RcppRoll::roll_mean(c(NA, salary[-length(salary)]), # drop the current value
                                n = max(fas_period), align="right", fill = NA),
      db_ee_cont = params$db_ee_cont_rate_ * salary,
      db_ee_balance = pentools::get_cum_fv(params$db_ee_interest_rate_, db_ee_cont),
    ) %>%
    ungroup() %>%
    filter(!is.na(salary)) %>%
    distinct()
  
  return(salary_benefit_table)
}

salary_benefit_table <- get_salary_benefit_table("admin",
                                                 frs_data_env$admin_entrant_profile_table,
                                                 frs_data_env$salary_growth_table %>% 
                                                   filter(class == "admin"),
                                                 frs_data_env$admin_salary_headcount_table,
                                                 params)

get_salary_benefit_table_s <- function(entrant_profile_table_s = entrant_profile_table_s,
                                       salary_growth_table_s = salary_growth_table_s,
                                       salary_headcount_table_s = salary_headcount_table_s,
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
      salary = if_else(entry_year <= ref_year, #the max entry_year in salary_headcount_table is 2015 for admin; but it is 2020 for all other
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
    select(-ref_year)
  
  return(salary_benefit_table_s)
}

salary_benefit_table_s <- get_salary_benefit_table_s(entrant_profile_table_s,
                                                     salary_growth_table_s,
                                                     salary_headcount_table_s,
                                                     params) 

identical(salary_benefit_table_s %>% filter(class == "admin") %>% select(-class), salary_benefit_table %>% select(-starts_with("class")))

salary_benefit_table_s %>% filter(class == "admin") %>% select(-class)
salary_benefit_table %>% select(-starts_with("class"))

# get_ann_table -----------------------------------------------------------
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

ann_factor_table_s <- get_annuity_factor_table_s(
  mort_table_s,
  salary_benefit_table_s,
  params)

get_annuity_factor_table <- function(
    mort_table,
    salary_benefit_table,
    params
) {
  # Survival Probability and Annuity Factor for active members
  ann_factor_table <- mort_table %>% 
    #Semi join the salary_benefit_able to reduce the size of the data that needs to be calculated
    semi_join(salary_benefit_table, by = c("entry_year", "entry_age")) %>%
    left_join(frs_data_env$dr_lookup, by = c("tier_at_dist_age")) %>%
    left_join(frs_data_env$cola_lookup, 
              by = c("tier_at_dist_age", "entry_year", "yos")) %>%
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
  
  return(ann_factor_table)
}


ann_factor_table <- get_annuity_factor_table(
  mort_table,
  salary_benefit_table,
  params)

identical(ann_factor_table_s %>% filter(class == "admin") %>% select(-class), ann_factor_table %>% select(-starts_with("class")))
# get_annuity_factor_retire_table -----------------------------------------

get_annuity_factor_retire_table <- function(
    mort_retire_table,
    params) {
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
    )
  return(ann_factor_retire_table)
}


ann_factor_retire_table <- get_annuity_factor_retire_table(
  mort_retire_table,
  params
)


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


ann_factor_retire_table_s <- get_annuity_factor_retire_table_s(
  mort_retire_table_s,
  params
)


identical(ann_factor_retire_table_s %>% filter(class == "admin") %>% select(-class), ann_factor_retire_table %>% ungroup() %>% select(-starts_with("class")))

# get benefit table -------------------------------------------------------
get_benefit_table <- function(class_name,
                              ann_factor_table, 
                              salary_benefit_table,
                              params){
  benefit_table <- ann_factor_table %>%
    mutate(
      term_age = entry_age + yos, .before = term_year,
      class = class_name
    ) %>%
    # dist_age is distribution age, and dist_year is distribution year.
    # distribution age means the age when the member starts to accept benefits (either a refund or a pension)
    left_join(salary_benefit_table,
              by = c("entry_year", "entry_age", "yos", "term_age")) %>%
    left_join(frs_data_env$ben_mult_lookup %>% filter(class == class_name) %>% select(-system),
              by = join_by(class, 
                           tier_at_dist_age,
                           dist_age >= dist_age_min_ge,
                           dist_age < dist_age_max_lt,
                           yos >= yos_min_ge,
                           yos < yos_max_lt,
                           dist_year >= dist_year_min_ge,
                           dist_year < dist_year_max_lt)) %>%
    left_join(frs_data_env$reduce_factor_lookup %>% filter(class == class_name),
              by = c("tier_at_dist_age", "dist_age")) %>%
    mutate(db_benefit = yos * ben_mult * fas * reduce_factor,
           
           #cal_factor is a calibration factor added to match the normal cost from the val report
           db_benefit = db_benefit * params$cal_factor_,
           
           #calculate the annuity factor at termination day
           ann_factor_term = ann_factor * cum_mort_dr,
           
           #calculate the actuarial present value of future DB benefits at termination day (discount the annual DB benefits back to termination day)
           pvfb_db_at_term_age = db_benefit * ann_factor_term
           
    ) %>%
    ungroup()
  
  return(benefit_table)  
}

benefit_table <- get_benefit_table(
  "admin",
  ann_factor_table,
  salary_benefit_table,
  params)

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


benefit_table_s <- get_benefit_table_s(
  ann_factor_table_s,
  salary_benefit_table_s,
  params)

identical(benefit_table_s %>% filter(class == "admin") %>% select(-class), benefit_table %>% select(-starts_with("class")))

# test dist age table -----------------------------------------------------
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
    select(class, entry_year, entry_age, term_age, dist_age)
  
  return(dist_age_table_s)
}


get_dist_age_table <- function(benefit_table){
  # Determine the ultimate distribution age for each member (the age when they're assumed to retire/get a refund, given their termination age)
  dist_age_table <- benefit_table %>% 
    mutate(is_norm_retire_elig = str_detect(tier_at_dist_age, "norm")) %>%
    summarise(
      earliest_norm_retire_age = n() - sum(is_norm_retire_elig) + min(dist_age),
      term_status = tier_at_term_age[1],
      .by=c(entry_year, entry_age, term_age)
    ) %>% 
    mutate(
      dist_age = if_else(
        str_detect(term_status, "vested") & !str_detect(term_status, "non_vested"),
        earliest_norm_retire_age, 
        term_age
      )
    ) %>% 
    select(entry_year, entry_age, term_age, dist_age)
  
  return(dist_age_table)
}

dist_age_table_s <- get_dist_age_table_s(benefit_table_s)

dist_age_table <- get_dist_age_table(benefit_table)

identical(dist_age_table_s %>% filter(class == "admin") %>% ungroup() %>% select(-class), dist_age_table)

# get_final_benefit_table -------------------------------------------------

get_final_benefit_table <- function(benefit_table, dist_age_table){
  
  #Retain only the final distribution ages in the final_benefit_table
  final_benefit_table <- benefit_table %>% 
    semi_join(dist_age_table,
              by = join_by(entry_year, entry_age, dist_age, term_age)) %>% 
    select(entry_year, entry_age, term_age, dist_age, db_benefit, pvfb_db_at_term_age, ann_factor_term) %>% 
    mutate(
      #NA benefit values (because the member is not vested) are replaced with 0
      db_benefit = if_else(is.na(db_benefit), 0, db_benefit),
      pvfb_db_at_term_age = if_else(is.na(pvfb_db_at_term_age), 0, pvfb_db_at_term_age)
    )
  
  return(final_benefit_table)
}

final_benefit_table <- get_final_benefit_table(benefit_table, dist_age_table)


get_final_benefit_table_s <- function(benefit_table, dist_age_table){
  
  #Retain only the final distribution ages in the final_benefit_table
  final_benefit_table <- benefit_table %>% 
    semi_join(dist_age_table,
              by = join_by(class, entry_year, entry_age, dist_age, term_age)) %>% 
    select(class, entry_year, entry_age, term_age, dist_age, db_benefit, pvfb_db_at_term_age, ann_factor_term) %>% 
    mutate(
      #NA benefit values (because the member is not vested) are replaced with 0
      db_benefit = if_else(is.na(db_benefit), 0, db_benefit),
      pvfb_db_at_term_age = if_else(is.na(pvfb_db_at_term_age), 0, pvfb_db_at_term_age)
    )
  
  return(final_benefit_table)
}


final_benefit_table_s <- get_final_benefit_table_s(benefit_table_s, dist_age_table_s)

identical(final_benefit_table_s %>% filter(class == "admin") %>% ungroup() %>% select(-class), final_benefit_table)

# get_benefit_val_table ---------------------------------------------------

get_benefit_val_table <- function(
    salary_benefit_table,
    final_benefit_table,
    separation_rate_table,
    params){
  
  benefit_val_table <- salary_benefit_table %>% 
    left_join(final_benefit_table, by = c("entry_year", "entry_age", "term_age")) %>%
    left_join(separation_rate_table,
              by = join_by(entry_year, entry_age, yos, term_age)) %>%
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
    group_by(entry_year, entry_age) %>%
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
  
  return(benefit_val_table)
}


benefit_val_table <- get_benefit_val_table(
  salary_benefit_table,
  final_benefit_table,
  separation_rate_table,
  params)


get_benefit_val_table_s <- function(
    salary_benefit_table_s,
    final_benefit_table_s,
    separation_rate_table_s,
    params){
  
  benefit_val_table_s <- salary_benefit_table_s %>% 
    left_join(final_benefit_table_s, by = c("class" = "class", "entry_year", "entry_age", "term_age")) %>%
    left_join(separation_rate_table_s,
              by = c("class" = "class", "entry_year", "entry_age", "yos", "term_age")) %>%
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


benefit_val_table_s <- get_benefit_val_table_s(
  salary_benefit_table_s,
  final_benefit_table_s,
  separation_rate_table_s,
  params)

identical(benefit_val_table_s %>% filter(class == "admin") %>% ungroup() %>% select(-class), benefit_val_table %>% select(-starts_with("class")))

# small function -----------------------------------------------------

indv_norm_cost_table_s <- benefit_val_table_s %>% 
  filter(yos == 0) %>% 
  select(class, entry_year, entry_age, indv_norm_cost)

indv_norm_cost_table <- benefit_val_table %>% 
  filter(yos == 0) %>% 
  select(entry_year, entry_age, indv_norm_cost)

names(indv_norm_cost_table_s)

identical(indv_norm_cost_table_s %>% filter(class == "admin") %>% select(-class), indv_norm_cost_table %>% select(-starts_with("class")))
# get_agg_norm_cost_table -------------------------------------------------

get_agg_norm_cost_table <- function(
    indv_norm_cost_table,
    salary_headcount_table,
    salary_benefit_table){
  
  agg_norm_cost_table <- indv_norm_cost_table %>% 
    left_join(salary_headcount_table, by = c("entry_year", "entry_age")) %>% 
    left_join(salary_benefit_table %>% select(entry_year, entry_age, yos, salary), by = c("entry_year", "entry_age", "yos")) %>% 
    filter(!is.na(count)) %>% 
    summarise(
      agg_normal_cost = sum(indv_norm_cost * salary * count) / sum(salary * count)
    )
  return(agg_norm_cost_table)
}

agg_norm_cost_table <- get_agg_norm_cost_table(
  indv_norm_cost_table,
  salary_headcount_table,
  salary_benefit_table)


get_agg_norm_cost_table_s <- function(
    indv_norm_cost_table_s,
    salary_headcount_table_s,
    salary_benefit_table_s){
  
  agg_norm_cost_table_s <- indv_norm_cost_table_s %>% 
    left_join(salary_headcount_table_s, by = c("class" = "class", "entry_year", "entry_age")) %>%
    left_join(salary_benefit_table_s %>% select(class, entry_year, entry_age, yos, salary), by = c("class", "entry_year", "entry_age", "yos")) %>%
    filter(!is.na(count)) %>%
    group_by(class) %>%
    summarise(
      agg_normal_cost = sum(indv_norm_cost * salary * count) / sum(salary * count)
    )
  return(agg_norm_cost_table_s)
}

agg_norm_cost_table_s <- get_agg_norm_cost_table_s(
  indv_norm_cost_table_s,
  salary_headcount_table_s,
  salary_benefit_table_s)

identical(agg_norm_cost_table_s %>% filter(class == "admin") %>% select(-class), agg_norm_cost_table %>% select(-starts_with("class")))

# get_benefit_function_primary ---------------------------------------------
get_benefit_data_s <- function(
    entrant_profile_table_s,
    salary_headcount_table_s,
    mort_table_s,
    mort_retire_table_s,
    separation_rate_table_s,
    params
) {
  
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


benefit_data_s <- get_benefit_data_s(
  frs_data_env$entrant_profile_table,
  frs_data_env$salary_headcount_table,
  frs_data_env$mort_table,
  frs_data_env$mort_retire_table,
  frs_data_env$separation_rate_table,    
  params
)

get_benefit_data <- function(
    class_name,
    entrant_profile_table,
    salary_headcount_table,
    mort_table,
    mort_retire_table,
    separation_rate_table,
    params
) {
  
  # class_salary_growth_table <- get_class_salary_growth_table(class_name, params$salary_growth_table_)
  class_salary_growth_table <- params$salary_growth_table %>% filter(class == class_name)  #Used the stacked table
  
  salary_benefit_table <- get_salary_benefit_table(class_name,
                                                   entrant_profile_table,
                                                   class_salary_growth_table,
                                                   salary_headcount_table,
                                                   params)
  
  ann_factor_table <- get_annuity_factor_table(
    mort_table,
    salary_benefit_table,
    params)
  
  ann_factor_retire_table <- get_annuity_factor_retire_table(
    mort_retire_table,
    params
  )
  
  benefit_table <- get_benefit_table(
    class_name,
    ann_factor_table,
    salary_benefit_table,
    params)
  
  dist_age_table <- get_dist_age_table(benefit_table)
  
  final_benefit_table <- get_final_benefit_table(benefit_table, dist_age_table)
  
  ## Benefit Accrual & Normal Cost #######
  
  benefit_val_table <- get_benefit_val_table(
    salary_benefit_table,
    final_benefit_table,
    separation_rate_table,
    params)
  
  # next step too small to need its own function
  indv_norm_cost_table <- benefit_val_table %>% 
    filter(yos == 0) %>% 
    select(entry_year, entry_age, indv_norm_cost)
  
  agg_norm_cost_table <- get_agg_norm_cost_table(
    indv_norm_cost_table,
    salary_headcount_table,
    salary_benefit_table)
  
  # return list of tables ----
  output <- list(
    ann_factor_table         = ann_factor_table,
    ann_factor_retire_table  = ann_factor_retire_table,
    benefit_table            = benefit_table,
    final_benefit_table      = final_benefit_table,
    benefit_val_table        = benefit_val_table,
    indv_norm_cost_table     = indv_norm_cost_table,
    agg_norm_cost_table      = agg_norm_cost_table
  )
  
  return(output)
}

# test admin, judges, admin, and senior_management ----------------------------------

benefit_data_admin <- get_benefit_data(
  "admin",
  frs_data_env$admin_entrant_profile_table,
  frs_data_env$admin_salary_headcount_table,
  frs_data_env$admin_mort_table,
  frs_data_env$admin_mort_retire_table,
  frs_data_env$admin_separation_rate_table,    
  params
)


identical(benefit_data_s$ann_factor_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$ann_factor_table)
identical(benefit_data_s$ann_factor_retire_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$ann_factor_retire_table %>% ungroup())
identical(benefit_data_s$benefit_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$benefit_table %>% select(-starts_with("class")))
identical(benefit_data_s$final_benefit_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$final_benefit_table)
identical(benefit_data_s$benefit_val_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$benefit_val_table %>% select(-starts_with("class")))
identical(benefit_data_s$indv_norm_cost_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$indv_norm_cost_table)
identical(benefit_data_s$agg_norm_cost_table %>% filter(class == "admin") %>% select(-class), benefit_data_admin$agg_norm_cost_table)

