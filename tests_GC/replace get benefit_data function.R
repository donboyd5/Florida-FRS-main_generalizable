


benefit_data_s <- get_benefit_data_s(
  frs_data_env$entrant_profile_table,
  frs_data_env$salary_headcount_table,
  frs_data_env$mort_table,
  frs_data_env$mort_retire_table,
  frs_data_env$separation_rate_table,    
  params
)

benefit_data <- list()

benefit_data$ann_factor_table <- benefit_data_s$ann_factor_table_s %>% filter(employee_class == "regular")
benefit_data$ann_factor_retire_table <- benefit_data_s$ann_factor_table_s %>% filter(employee_class == "regular")
benefit_data$benefit_table <- benefit_data_s$benefit_table_s %>% filter(employee_class == "regular")
benefit_data$final_benefit_table <- benefit_data_s$final_benefit_table_s %>% filter(employee_class == "regular")
benefit_data$benefit_val_table <- benefit_data_s$benefit_val_table_s %>% filter(class == "regular")
benefit_data$indv_norm_cost_table <- benefit_data_s$indv_norm_cost_table_s %>% filter(class == "regular")
benefit_data$agg_norm_cost_table <- benefit_data_s$agg_norm_cost_table_s %>% filter(class == "regular")

benefit_data_regular <- get_benefit_data(
  "regular",
  frs_data_env$regular_entrant_profile_table,
  frs_data_env$regular_salary_headcount_table,
  frs_data_env$regular_mort_table,
  frs_data_env$regular_mort_retire_table,
  frs_data_env$regular_separation_rate_table,
  params
)

benefit_data_regular
benefit_data
