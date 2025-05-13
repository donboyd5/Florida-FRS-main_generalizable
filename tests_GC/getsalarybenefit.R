
class_name = "regular"

salary_benefit_table <- expand_grid(entry_year = params$entry_year_range_, 
                                    entry_age = frs_data_env$special_entrant_profile_table$entry_age, 
                                    yos = params$yos_range_) %>%
  mutate(
    term_age = entry_age + yos,
    # term_year = entry_year + yos,
    tier_at_term_age = frs_data_env$get_tier(class_name, entry_year, term_age, yos, params$new_year_)) %>%
  left_join(frs_data_env$tier_table %>% filter(class == class_name) , by = c("entry_year", "yos", "term_age"= "age"))
  
  
compare_salary_benefit_table <- salary_benefit_table %>%
  mutate(mismatch = if_else(tier_at_term_age != tier, "mismatch", "match")) %>%
  filter(mismatch == "mismatch")
  
