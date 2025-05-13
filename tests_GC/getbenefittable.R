## define the parameters for tests
entrant_profile_table = frs_data_env$entrant_profile_table
salary_headcount_table = frs_data_env$salary_headcount_table
mort_table = frs_data_env$mort_table
mort_retire_table = frs_data_env$mort_retire_table
separation_rate_table = frs_data_env$separation_rate_table
params = params

##load the get_ann_factor_table function
class_salary_growth_table <- params$salary_growth_table

get_salary_benefit_table <- function(entrant_profile_table,
                                       class_salary_growth_table,
                                       salary_headcount_table,
                                       params){
  
  salary_benefit_table <- expand_grid(entry_year = params$entry_year_range_, 
                                      entry_age = entrant_profile_table$entry_age, 
                                      yos = params$yos_range_,
                                      class = params$class_names_no_drop_frs_) %>% 
    mutate(
      term_age = entry_age + yos) %>%
    left_join(frs_data_env$tier_table, by = c("entry_year", "yos", "term_age"= "age", "class")) %>%
    mutate(tier_at_term_age = tier) %>%
    filter(term_age <= params$max_age_) %>% 
    arrange(entry_year, entry_age, yos) %>% 
    left_join(frs_data_env$entrant_profile_table, by = c("entry_age", "class" = "employee_class")) %>%
    left_join(frs_data_env$salary_growth_table, by = c("yos", "class")) %>%
    left_join(frs_data_env$salary_headcount_table %>% select(entry_year, entry_age, entry_salary, employee_class), 
              by = c("entry_year", "entry_age", "class" = "employee_class")) %>%
    mutate(
      salary = if_else(entry_year <= max(salary_headcount_table$entry_year), 
                       entry_salary * cumprod_salary_increase,
                       start_sal * cumprod_salary_increase * (1 + params$payroll_growth_)^(entry_year - max(salary_headcount_table$entry_year)))
    ) %>% 
    left_join(frs_data_env$fas_period_lookup, by = c("tier_at_term_age")) %>%
    distinct() %>%
    group_by(class, entry_year, entry_age) %>%
    mutate(
      fas = RcppRoll::roll_mean(c(NA, salary[-length(salary)]), # drop the current value
                                n = max(fas_period), align="right", fill = NA),
      db_ee_cont = params$db_ee_cont_rate_ * salary,
      db_ee_balance = pentools::get_cum_fv(params$db_ee_interest_rate_, db_ee_cont),
    ) %>%
    ungroup() %>%
    filter(!is.na(salary))
  
  return(salary_benefit_table)
}

salary_benefit_table <- get_salary_benefit_table(entrant_profile_table,
                                                 class_salary_growth_table,
                                                 salary_headcount_table,
                                                 params)

get_annuity_factor_table <- function(
    mort_table,
    salary_benefit_table,
    params
) {
  ann_factor_table <- mort_table %>%
    semi_join(salary_benefit_table, by = c("entry_year", "entry_age", "employee_class" = "class")) %>%
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

get_benefit_table <- function(ann_factor_table, 
                              salary_benefit_table,
                              params){
  
  benefit_table <- ann_factor_table %>%
    mutate(
      term_age = entry_age + yos, .before = term_year
    ) %>%
    # dist_age is distribution age, and dist_year is distribution year.
    # distribution age means the age when the member starts to accept benefits (either a refund or a pension)
    left_join(salary_benefit_table,
              by = c("entry_year", "entry_age", "yos", "term_age", "employee_class" = "class"))
    left_join(frs_data_env$ben_mult_lookup %>% filter(class_name == !!class_name) %>% select(-system),
              by = join_by(class_name, 
                           tier_at_dist_age,
                           dist_age >= dist_age_min_ge,
                           dist_age < dist_age_max_lt,
                           yos >= yos_min_ge,
                           yos < yos_max_lt,
                           dist_year >= dist_year_min_ge,
                           dist_year < dist_year_max_lt)) %>%
    left_join(frs_data_env$reduce_factor_lookup %>% filter(class_name == !!class_name),
              by = c("tier_at_dist_age", "dist_age")) %>%
    mutate(db_benefit = yos * ben_mult * fas * reduce_factor,
           
           #cal_factor is a calibration factor added to match the normal cost from the val report
           db_benefit = db_benefit * params$cal_factor_,
           
           #calculate the annuity factor at termination day
           ann_factor_term = ann_factor * cum_mort_dr,
           
           #calculate the actuarial present value of future DB benefits at termination day (discount the annual DB benefits back to termination day)
           pvfb_db_at_term_age = db_benefit * ann_factor_term
           
    )
  return(benefit_table)  
}


unique(salary_benefit_table$entry_year)
unique(salary_benefit_table$entry_age)
unique(salary_benefit_table$yos)
unique(salary_benefit_table$term_age)
unique(salary_benefit_table$class)
salary_benefit_table %>% filter((entry_year == 2000) & (entry_age == 20) & (yos == 40) & (term_age == 60) & (class == "regular"))
