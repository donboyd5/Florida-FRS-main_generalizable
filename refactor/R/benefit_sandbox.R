entrant_profile_table_s <- params$entrant_profile_table
salary_headcount_table_s <- params$salary_headcount_table
mort_table_s <- params$mort_table
mort_retire_table_s <- params$mort_retire_table
separation_rate_table_s <- params$separation_rate_table
salary_growth_table_s <- params$salary_growth_table

params

params$ref_year <- readxl::read_excel(
  path  = here::here("refactor", "R", "component.xlsx"),
  sheet = "salary_proj_reference_year"
)

params$get_fas <- function(salary_vec, fas_period) {
  x <- c(NA_real_, salary_vec[-length(salary_vec)])  # lag 1, preserve length
  RcppRoll::roll_mean(x, n = fas_period, align = "right", fill = NA_real_)
}

# Preprocessing the tier_table by added the normal retirement and vested qualification
params$tier_table <- params$tier_table %>%
  dplyr::mutate(
    is_norm_retire_elig = tier %in% c("tier_1_norm", "tier_2_norm", "tier_3_norm"),
    vested_at_term = grepl("vested", tier, fixed = TRUE) &
      !grepl("non_vested", tier, fixed = TRUE)
  )

# Benefit Model Function --------------------------------------------------
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
    left_join(params$tier_table, by = c("entry_year", "yos", "term_age"= "age", "class")) %>%
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
    left_join(params$fas_period_lookup, by = c("tier_at_term_age")) %>%
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

get_salary_benefit_table_s_2 <- function(entrant_profile_table_s,
                                       salary_growth_table_s,
                                       salary_headcount_table_s,
                                       params){
  
  # pre-cut the big input tables only
  entrant_small <- entrant_profile_table_s %>%
    select(entry_age, class, start_sal, entrant_dist) %>%
    filter(!is.na(start_sal))
  
  growth_small <- salary_growth_table_s %>%
    select(yos, class, cumprod_salary_increase)
  
  head_small <- salary_headcount_table_s %>%
    select(entry_year, entry_age, class, entry_salary)
  
  expand_grid(
    entry_year = params$entry_year_range_,
    entry_age  = unique(entrant_small$entry_age),
    yos        = params$yos_range_,
    class      = params$class_names_no_drop_frs_
  ) %>%
    mutate(term_age = entry_age + yos) %>%
    filter(term_age <= params$max_age_) %>%
    
    # tier at term age
    left_join(
      params$tier_table,
      by = c("entry_year", "yos", "term_age" = "age", "class")
    ) %>%
    mutate(tier_at_term_age = tier) %>%
    
    # entrant profile + growth + entry salary
    left_join(entrant_small, by = c("entry_age", "class")) %>%
    left_join(growth_small,  by = c("yos", "class")) %>%
    left_join(head_small,    by = c("entry_year", "entry_age", "class")) %>%
    
    # ref year + fas period
    left_join(params$ref_year, by = "class") %>%
    left_join(params$fas_period_lookup, by = c("tier_at_term_age")) %>%
    
    # salary path
    mutate(
      ref_year = as.integer(ref_year),
      salary = if_else(
        entry_year <= ref_year,
        entry_salary * cumprod_salary_increase,
        start_sal * cumprod_salary_increase *
          (1 + params$payroll_growth_)^(entry_year - ref_year)
      )
    ) %>%
    
    # grouped calcs: only order within group right before calcs
    group_by(class, entry_year, entry_age) %>%
    arrange(yos, .by_group = TRUE) %>%
    mutate(
      fas           = params$get_fas(salary, fas_period = max(fas_period)),
      db_ee_cont    = params$db_ee_cont_rate_ * salary,
      db_ee_balance = pentools::get_cum_fv(params$db_ee_interest_rate_, db_ee_cont)
    ) %>%
    ungroup() %>%
    select(-ref_year) %>%
    filter(!is.na(salary), !is.na(start_sal))

  return(salary_benefit_table_s)
}

keys <- c("class","entry_year","entry_age","yos")

salary_benefit_table_s <- get_salary_benefit_table_s(entrant_profile_table_s,
                                                     salary_growth_table_s,
                                                     salary_headcount_table_s,
                                                     params) %>% arrange(across(all_of(keys)))

salary_benefit_table_s_2 <- get_salary_benefit_table_s_2(entrant_profile_table_s,
                                                     salary_growth_table_s,
                                                     salary_headcount_table_s,
                                                     params) %>% arrange(across(all_of(keys)))


identical(salary_benefit_table_s, salary_benefit_table_s_2)


get_annuity_factor_table_s <- function(
    mort_table_s,
    salary_benefit_table_s,
    params
) {
  ann_factor_table_s <- mort_table_s %>%
    semi_join(salary_benefit_table_s, by = c("entry_year", "entry_age", "class")) %>%
    left_join(params$dr_lookup, by = c("tier_at_dist_age")) %>%
    left_join(params$cola_lookup, 
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

get_annuity_factor_table_s_2 <- function(
    mort_table_s,
    salary_benefit_table_s,
    params
) {
  # keep only the keys needed to filter mort_table_s
  salary_benefit_small <- salary_benefit_table_s %>%
    select(entry_year, entry_age, class) %>%
    distinct()
  
  mort_small <- mort_table_s %>%
    semi_join(salary_benefit_small, by = c("entry_year", "entry_age", "class"))
  
  ann_factor_table_s <- mort_small %>%
    left_join(params$dr_lookup, by = c("tier_at_dist_age")) %>%
    left_join(params$cola_lookup, by = c("tier_at_dist_age", "entry_year", "yos")) %>%
    arrange(class, entry_year, entry_age, yos, dist_age) %>%   # global sort once
    group_by(class, entry_year, entry_age, yos) %>%
    mutate(
      cum_dr   = cumprod(1 + dplyr::lag(dr, default = 0)),
      cum_mort = cumprod(1 - dplyr::lag(mort_final, default = 0)),
      cum_cola = cumprod(1 + dplyr::lag(cola, default = 0)),
      cum_mort_dr = cum_mort / cum_dr,
      cum_mort_dr_cola = cum_mort_dr * cum_cola,
      ann_factor = rev(cumsum(rev(cum_mort_dr_cola))) / cum_mort_dr_cola
    ) %>%
    ungroup()

  ann_factor_table_s
}

keys <- c("class","entry_year","entry_age","yos", "dist_year", "dist_age", "term_year")
ann_factor_table_s <- get_annuity_factor_table_s(mort_table_s, salary_benefit_table_s, params) %>% arrange(across(all_of(keys)))
ann_factor_table_s_2 <- get_annuity_factor_table_s_2(mort_table_s, salary_benefit_table_s, params) %>% arrange(across(all_of(keys)))

all.equal(ann_factor_table_s, ann_factor_table_s_2)

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

get_annuity_factor_retire_table_s_2 <- function(
    mort_retire_table_s,
    params) {

    ann_factor_retire_table_s <- mort_retire_table_s %>% 
      mutate(
        dr = params$dr_current_,
        cola = case_when(
          params$one_time_cola_ & year == params$new_year_ ~ params$cola_current_retire_one_,
          params$one_time_cola_                            ~ 0,
          TRUE                                             ~ params$cola_current_retire_
        )
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

annuity_factor_retire_table_s <- get_annuity_factor_retire_table_s(mort_retire_table_s, params)
annuity_factor_retire_table_s_2 <- get_annuity_factor_retire_table_s_2(mort_retire_table_s, params)

identical(annuity_factor_retire_table_s, annuity_factor_retire_table_s_2)

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
    left_join(params$ben_mult_lookup %>% select(-system),
              by = join_by(class, 
                           tier_at_dist_age,
                           dist_age >= dist_age_min_ge,
                           dist_age < dist_age_max_lt,
                           yos >= yos_min_ge,
                           yos < yos_max_lt,
                           dist_year >= dist_year_min_ge,
                           dist_year < dist_year_max_lt)) %>%
    left_join(params$reduce_factor_lookup,
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

get_benefit_table_s_2 <- function(ann_factor_table_s, 
                                salary_benefit_table_s,
                                params){
  
  cal_factor <- params$cal_factor_
  
  ben_mult_lookup <- params$ben_mult_lookup %>% select(-system)
  
  reduce_factor_lookup <- params$reduce_factor_lookup
  
  salary_benefit_small <- salary_benefit_table_s %>%
    select(entry_year, entry_age, yos, term_age, class, fas) %>%
    distinct()
  
  ann_small <- ann_factor_table_s %>%
    select(entry_year, entry_age, yos, class,
           term_year, dist_year, dist_age, tier_at_dist_age,
           ann_factor, cum_mort_dr)
  
  benefit_table_s <- ann_small %>%
    mutate(
      term_age = entry_age + yos, .before = term_year
    ) %>%
    # dist_age is distribution age, and dist_year is distribution year.
    # distribution age means the age when the member starts to accept benefits (either a refund or a pension)
    left_join(salary_benefit_small,
              by = c("entry_year", "entry_age", "yos", "term_age", "class")) %>%
    left_join(ben_mult_lookup,
              by = join_by(class, 
                           tier_at_dist_age,
                           dist_age >= dist_age_min_ge,
                           dist_age < dist_age_max_lt,
                           yos >= yos_min_ge,
                           yos < yos_max_lt,
                           dist_year >= dist_year_min_ge,
                           dist_year < dist_year_max_lt)) %>%
    left_join(reduce_factor_lookup,
              by = c("tier_at_dist_age", "dist_age", "class")) %>%
    mutate(db_benefit = yos * ben_mult * fas * reduce_factor,
           
           #cal_factor is a calibration factor added to match the normal cost from the val report
           db_benefit = db_benefit * cal_factor,
           
           #calculate the annuity factor at termination day
           ann_factor_term = ann_factor * cum_mort_dr,
           
           #calculate the actuarial present value of future DB benefits at termination day (discount the annual DB benefits back to termination day)
           pvfb_db_at_term_age = db_benefit * ann_factor_term
           
    ) 
  
  
  return(benefit_table_s)  
}

benefit_table_s <- get_benefit_table_s(ann_factor_table_s, salary_benefit_table_s, params)
benefit_table_s_2 <- get_benefit_table_s_2(ann_factor_table_s, salary_benefit_table_s, params)

identical(benefit_table_s, benefit_table_s_2)

library(microbenchmark)

microbenchmark(
  benefit_table_s   = get_benefit_table_s(ann_factor_table_s, salary_benefit_table_s, params),
  benefit_table_s_2 = get_benefit_table_s_2(ann_factor_table_s, salary_benefit_table_s, params),
  times = 2
)

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

get_dist_age_table_s_2 <- function(benefit_table_s, params) {
  
  # Build the set of tier labels that count as "normal retirement eligible"
  norm_tiers <- params$tier_table %>%
    dplyr::filter(is_norm_retire_elig) %>%
    dplyr::distinct(tier) %>%
    dplyr::pull(tier)
  
  # Build termination-point keys and attach vested-at-term flag from tier_table
  term_pts <- benefit_table_s %>%
    dplyr::distinct(class, entry_year, entry_age, yos, term_age) %>%
    dplyr::left_join(
      params$tier_table %>%
        dplyr::distinct(class, entry_year, yos, age, vested_at_term) %>%
        dplyr::rename(term_age = age),
      by = c("class", "entry_year", "yos", "term_age")
    ) %>%
    # If the tier_table join doesn’t find a match, vested_at_term is NA; treat NA as not vested (FALSE)
    dplyr::mutate(vested_at_term = dplyr::coalesce(vested_at_term, FALSE))
  
  # For vested term points only, find the earliest dist_age that is normal-retirement-eligible
  earliest_norm <- benefit_table_s %>%
    dplyr::semi_join(
      dplyr::filter(term_pts, vested_at_term) %>%
        dplyr::select(class, entry_year, entry_age, yos, term_age),
      by = c("class", "entry_year", "entry_age", "yos", "term_age")
    ) %>%
    dplyr::filter(tier_at_dist_age %in% norm_tiers) %>%
    dplyr::group_by(class, entry_year, entry_age, yos, term_age) %>%
    dplyr::summarise(earliest_norm_retire_age = min(dist_age), .groups = "drop")
  
  # Choose final dist_age: vested -> earliest eligible age; non-vested -> term_age
  term_pts %>%
    dplyr::left_join(
      earliest_norm,
      by = c("class", "entry_year", "entry_age", "yos", "term_age")
    ) %>%
    dplyr::mutate(
      dist_age = dplyr::if_else(
        vested_at_term,
        dplyr::coalesce(earliest_norm_retire_age, term_age),
        term_age
      )
    ) %>%
    dplyr::select(class, entry_year, entry_age, term_age, dist_age)
}

dist_age_table_s <- get_dist_age_table_s(benefit_table_s)
dist_age_table_s_2 <- get_dist_age_table_s_2(benefit_table_s, params)

identical(dist_age_table_s, dist_age_table_s_2)

microbenchmark(
  dist_age_table_s   = get_dist_age_table_s(benefit_table_s),
  dist_age_table_s_2 = get_dist_age_table_s_2(benefit_table_s, params),
  times = 2
)

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

get_benefit_val_table_s <- function(
    salary_benefit_table_s,
    final_benefit_table_s,
    separation_rate_table_s,
    params){
  
  benefit_val_table_s <- salary_benefit_table_s %>% 
    left_join(final_benefit_table_s, by = c("class", "entry_year", "entry_age", "term_age")) %>%
    left_join(separation_rate_table_s,
              by = c("class", "entry_year", "entry_age", "yos", "term_age")) %>%
    left_join(params$dr_lookup, by = c("tier" = "tier_at_dist_age")) %>%
    mutate(
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

indv_norm_cost_table_s <- benefit_val_table_s %>% 
  filter(yos == 0) %>% 
  select(class, entry_year, entry_age, indv_norm_cost)


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

