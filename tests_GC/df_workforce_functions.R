initialize_df <- function(
    age_range,
    entry_age_range,
    year_range,
    term_year_range,
    retire_year_range,
    salary_headcount_table,
    mort_table,
    separation_rate_table,
    benefit_val_table,
    retire_refund_ratio
) {
  # Initial active population
  wf_active_df <- expand_grid(entry_age = entry_age_range,
                              age = age_range,
                              year = year_range) %>%
    filter(year == min(year_range), entry_age == age) %>%
    left_join(salary_headcount_table, by = c("entry_age", "age")) %>%
    mutate(count = replace_na(count, 0)) %>%
    select(entry_age, age, year, count)
  
  # Terminated and refunded structure: will be filled over time
  wf_term_df <- wf_active_df %>% mutate(term_year = year, count = 0) %>% select(entry_age, age, term_year, count)
  wf_refund_df <- wf_term_df
  
  # Retired structure
  wf_retire_df <- expand_grid(entry_age = entry_age_range,
                              age = age_range,
                              term_year = term_year_range,
                              retire_year = retire_year_range) %>%
    mutate(count = 0)
  
  # Mortality probabilities
  mort_df_term <- expand_grid(entry_age = entry_age_range,
                              age = age_range,
                              year = year_range,
                              term_year = term_year_range) %>%
    left_join(mort_table, by = c("entry_age", "age" = "dist_age", "year" = "dist_year", "term_year")) %>%
    mutate(mort_rate = replace_na(mort_final, 0)) %>%
    select(entry_age, age, year, term_year, mort_rate)
  
  # Separation probabilities
  sep_df <- expand_grid(entry_age = entry_age_range,
                        age = age_range,
                        year = year_range) %>%
    mutate(entry_year = year - (age - entry_age)) %>%
    left_join(separation_rate_table, by = c("entry_age", "age" = "term_age", "entry_year")) %>%
    mutate(sep_rate = replace_na(separation_rate, 0)) %>%
    select(entry_age, age, year, sep_rate)
  
  # Optimal retirement and refund setup
  optimal_retire <- benefit_val_table %>%
    select(entry_year, entry_age, term_age, yos, dist_age, ben_decision) %>%
    mutate(refund = case_when(ben_decision == "refund" ~ 1,
                              ben_decision == "mix" ~ 1 - retire_refund_ratio,
                              TRUE ~ 0),
           retire = case_when(ben_decision == "retire" ~ 1,
                              ben_decision == "mix" ~ 1,
                              TRUE ~ 0),
           refund_age = term_age)
  
  # Retirement probabilities
  retire_df <- expand_grid(entry_age = entry_age_range,
                           age = age_range,
                           year = year_range,
                           term_year = term_year_range) %>%
    mutate(entry_year = year - (age - entry_age),
           term_age = age - (year - term_year),
           yos = term_age - entry_age) %>%
    filter(year - term_year >= 0, yos >= 0) %>%
    left_join(optimal_retire, by = c("entry_age", "age" = "dist_age", "entry_year", "term_age", "yos")) %>%
    mutate(retire_rate = replace_na(retire, 0)) %>%
    select(entry_age, age, year, term_year, retire_rate)
  
  # Refund probabilities
  refund_df <- expand_grid(entry_age = entry_age_range,
                           age = age_range,
                           year = year_range,
                           term_year = term_year_range) %>%
    mutate(entry_year = year - (age - entry_age),
           term_age = age - (year - term_year),
           yos = term_age - entry_age) %>%
    filter(year - term_year >= 0, yos >= 0) %>%
    left_join(optimal_retire, by = c("entry_age", "age" = "refund_age", "entry_year", "term_age", "yos")) %>%
    mutate(refund_rate = replace_na(refund, 0)) %>%
    select(entry_age, age, year, term_year, refund_rate)
  
  list(
    wf_active = wf_active_df,
    wf_term = wf_term_df,
    wf_refund = wf_refund_df,
    wf_retire = wf_retire_df,
    mort_df_term = mort_df_term,
    sep_df = sep_df,
    retire_df = retire_df,
    refund_df = refund_df
  )
}

loop_through_df <- function(wf_active_df,
                            wf_term_df,
                            wf_refund_df,
                            wf_retire_df,
                            sep_df,
                            refund_df,
                            retire_df,
                            mort_retire_df,
                            age_range,
                            entry_age_range,
                            year_range,
                            entrant_profile_df,
                            pop_growth) {
  
  wf_active_df <- wf_active_df %>%
    left_join(sep_df, by = c("entry_age", "age", "year")) %>%
    arrange(entry_age, age, year) %>%
    group_by(entry_age, age) %>%
    mutate(sep_rate = replace_na(sep_rate, 0),
           term_count = lag(count) * lag(sep_rate),
           next_year = lead(year),
           age_next = age + 1,
           year = lead(year),
           count = count - replace_na(term_count, 0)) %>%
    ungroup() %>%
    filter(!is.na(year)) %>%
    select(entry_age, age = age_next, year, count)
  
  new_entrants_df <- expand_grid(year = year_range[-1], entrant_profile_df) %>%
    mutate(count = entrant_dist * pop_growth,
           age = entry_age) %>%
    select(entry_age, age, year, count)
  
  wf_active_df <- bind_rows(wf_active_df, new_entrants_df) %>%
    group_by(entry_age, age, year) %>%
    summarise(count = sum(count), .groups = "drop")
  
  wf_term_df <- wf_active_df %>%
    left_join(sep_df, by = c("entry_age", "age", "year")) %>%
    group_by(entry_age, age) %>%
    mutate(term_count = lag(count) * lag(sep_rate),
           term_year = year) %>%
    ungroup() %>%
    filter(!is.na(term_count)) %>%
    transmute(entry_age, age = age + 1, term_year, count = term_count)
  
  wf_refund_df <- wf_term_df %>%
    left_join(refund_df, by = c("entry_age", "age", "term_year" = "year")) %>%
    mutate(refund_rate = replace_na(refund_rate, 0),
           count = count * refund_rate) %>%
    select(entry_age, age, term_year, count)
  
  term_refunded <- wf_term_df %>%
    left_join(wf_refund_df, by = c("entry_age", "age", "term_year")) %>%
    mutate(count.y = replace_na(count.y, 0),
           count = count.x - count.y) %>%
    select(entry_age, age, term_year, count)
  
  wf_retire_df <- term_refunded %>%
    left_join(retire_df, by = c("entry_age", "age", "term_year" = "year")) %>%
    mutate(retire_rate = replace_na(retire_rate, 0),
           retire_year = term_year,
           count = count * retire_rate) %>%
    select(entry_age, age, term_year, retire_year, count)
  
  wf_retire_df <- wf_retire_df %>%
    left_join(mort_retire_df, by = c("entry_age", "age", "retire_year" = "year")) %>%
    mutate(mort_rate = replace_na(mort_rate, 0),
           count = count * (1 - mort_rate)) %>%
    select(entry_age, age, term_year, retire_year, count)
  
  list(
    wf_active = wf_active_df,
    wf_term = term_refunded,
    wf_refund = wf_refund_df,
    wf_retire = wf_retire_df
  )
}

