year_range <- params$start_year_:(params$start_year_ + params$model_period_) 
entry_age_range <- frs_data_env$entrant_profile_table$entry_age
age_range <- min(entry_age_range):max(params$age_range_)
term_year_range <- year_range
retire_year_range <- year_range
class_name <- frs_data_env$class_names_no_drop_frs_

salary_headcount_table_s <- frs_data_env$salary_headcount_table
mort_table_s <- frs_data_env$mort_table
separation_rate_table_s <- frs_data_env$separation_rate_table
retire_refund_ratio_s <- params$retire_refund_ratio_
entrant_profile_table_s <- frs_data_env$entrant_profile_table
mort_retire_table_s <- frs_data_env$mort_retire_table

benefit_data_s <- get_benefit_data_s(
  frs_data_env$entrant_profile_table,
  frs_data_env$salary_headcount_table,
  frs_data_env$mort_table,
  frs_data_env$mort_retire_table,
  frs_data_env$separation_rate_table,    
  params
)


get_wf_data <- function(
    class_name,
    entrant_profile_table,
    salary_headcount_table,
    mort_table,
    mort_retire_table,
    separation_rate_table,
    params
) {
  cat("\n\n")
  print(paste0("..preparing wf_data for class: ", class_name))
  
  class_name = "regular"
  
  ann_factor_table <- benefit_data_s$ann_factor_table %>% filter(class == class_name) %>% select(-class)
  ann_factor_retire_table <- benefit_data_s$ann_factor_retire_table %>% filter(class == class_name) %>% select(-class)
  benefit_table <- benefit_data_s$benefit_table %>% filter(class == class_name) %>% select(-class)
  final_benefit_table <- benefit_data_s$final_benefit_table %>% filter(class == class_name) %>% select(-class)
  benefit_val_table <- benefit_data_s$benefit_val_table %>% filter(class == class_name) %>% select(-class)
  indv_norm_cost_table <- benefit_data_s$indv_norm_cost_table %>% filter(class == class_name) %>% select(-class)
  agg_norm_cost_table <- benefit_data_s$agg_norm_cost_table %>% filter(class == class_name) %>% select(-class)
  
  entrant_profile_table <- frs_data_env$entrant_profile_table %>% filter(class == class_name) %>% select(-class)
  salary_headcount_table <- salary_headcount_table_s %>% filter(class == class_name) %>% select(-class)
  mort_table <- mort_table_s %>% filter(class == class_name) %>% select(-class)
  mort_retire_table <- mort_retire_table_s %>% filter(class == class_name) %>% select(-class)
  separation_rate_table <- separation_rate_table_s %>% filter(class == class_name) %>% select(-class)
  
  
  # Get age, entry_age, year, term_year, and retire_year ranges needed for array initialization ----
  entry_age_range <- entrant_profile_table$entry_age # djb: note that there are gaps in these ages
  year_range <- params$start_year_:(params$start_year_ + params$model_period_)   #test now, fix this later
  
  # local variables using ranges calculated above
  age_range <- min(entry_age_range):max(params$age_range_)
  retire_year_range <- year_range
  term_year_range <- year_range
  
  
  # Initialize empty workforce projection arrays ----
  a <- proc.time()
  init_list <- initialize_arrays(
    age_range,
    entry_age_range,
    year_range,
    term_year_range,
    retire_year_range,
    salary_headcount_table,
    mort_table,
    separation_rate_table,
    benefit_val_table,
    retire_refund_ratio = params$retire_refund_ratio_
  )
  list2env(init_list, envir = environment()) # djb: put REFERENCES to list elements into the current environment
  b <- proc.time()
  cat("initialize_arrays user system elapsed: ", b - a)
  
  a <- proc.time()
  array_list <- loop_through_arrays(
    wf_active,
    wf_term, 
    wf_refund, 
    wf_retire,
    mort_array_term,
    sep_array,
    retire_array,
    refund_array,
    age_range,
    entry_age_range,
    year_range,
    entrant_profile_table,
    pop_growth=params$pop_growth_)
  b <- proc.time()
  cat("\nloop_through_arrays user system elapsed: ", b - a)
  
  list2env(array_list, envir = environment()) # djb: copy each element of alist into the current environment
  
  # Convert the multidimensional arrays to data frames ----
  wf_active_df <- data.frame(expand.grid(entry_age = entry_age_range, 
                                         age = age_range, 
                                         year = year_range), 
                             n_active = as.vector(wf_active)) %>% filter(age >= entry_age)
  
  wf_term_df <- data.frame(expand.grid(entry_age = entry_age_range, 
                                       age = age_range, 
                                       year = year_range, 
                                       term_year = term_year_range), 
                           n_term = as.vector(wf_term)) %>% 
    filter(age >= entry_age, year >= term_year)
  
  wf_refund_df <- data.frame(expand.grid(entry_age = entry_age_range, 
                                         age = age_range, 
                                         year = year_range, 
                                         term_year = term_year_range),
                             n_refund = as.vector(wf_refund)) %>% 
    filter(age >= entry_age, year >= term_year)
  
  
  # split large wf_retire_array into smaller parts for processing ----
  
  # Since the wf_retire array is too big to handle using the above method, we
  # need to split it into smaller parts for processing
  wf_retire_list <- list()  # empty list to save retire workforce data in the for loop
  
  for (i in seq_along(entrant_profile_table$entry_age)) {
    wf_retire_name <- paste0("wf_retire_", entrant_profile_table$entry_age[i]) # NOT DANGEROUS create a unique name for the retire matrix [age x year] for this entry_age, term_year, retire_year
    
    assign(wf_retire_name, wf_retire[i,,,,])
    
    wf_retire_i <- data.table(CJ(retire_year = retire_year_range, term_year = term_year_range, year = year_range, age = age_range), # CJ is cross join
                              n_retire = as.vector(get(wf_retire_name)))[n_retire > 0,] %>%  # djb CAUTION: get(), but it is quite local 
      mutate(entry_age = entrant_profile_table$entry_age[i])
    
    assign(wf_retire_name, wf_retire_i)   #do this to save memory space
    wf_retire_list <- append(wf_retire_list, list(get(wf_retire_name))) # djb get corresponds to assign a few lines above, don't think it gives names
  }
  
  #.. Combine all retire data frames from the retire list into one retire data frame ----
  wf_retire_df <- rbindlist(wf_retire_list) %>% # data.table function to a list of data.tables
    select(entry_age, age, year, term_year, retire_year, n_retire)
  
  
  # save wf_data list of data frames ----
  wf_data <- list(wf_active_df = wf_active_df,
                  wf_term_df = wf_term_df,
                  wf_refund_df = wf_refund_df,
                  wf_retire_df = wf_retire_df)
  
  saveRDS(wf_data, fs::path(iddir, paste0(class_name, "_wf_data.rds")))
  
}



