## define the parameters for tests
class_name = "regular"
entrant_profile_table = frs_data_env$regular_entrant_profile_table
salary_headcount_table = frs_data_env$regular_salary_headcount_table
mort_table = frs_data_env$regular_mort_table
mort_retire_table = frs_data_env$regular_mort_retire_table
separation_rate_table = frs_data_env$regular_separation_rate_table
params = params

##load the get_ann_factor_table function
source(fs::path(rdir, "FRS_benefit_model_get_benefit_data_function_GC.R")) 

class_salary_growth_table <- params$salary_growth_table %>% filter(class == class_name)

salary_benefit_table <- get_salary_benefit_table(class_name,
                                                 entrant_profile_table,
                                                 class_salary_growth_table,
                                                 salary_headcount_table,
                                                 params)

# Survival Probability and Annuity Factor for active members
  ann_factor_table <- mort_table %>% 
    #Semi join the salary_benefit_able to reduce the size of the data that needs to be calculated
    semi_join(salary_benefit_table, by = c("entry_year", "entry_age")) %>%
    mutate(
      dr = if_else(str_detect(tier_at_dist_age, "tier_3"), params$dr_new_, params$dr_current_),
      cola_2 = frs_data_env$get_cola(tier = tier_at_dist_age,
                                   yos = yos,
                                   entry_year = entry_year,
                                   params = params)
    ) 
  #%>% 
    #left_join(cola_lookup, 
    #          by = c("tier_at_dist_age", "entry_year  ", "yos")) 

head(ann_factor_table)


    
    