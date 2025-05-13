year_range <- params$start_year_:(params$start_year_ + params$model_period_) 
entry_age_range <- frs_data_env$regular_entrant_profile_table$entry_age
age_range <- min(entry_age_range):max(params$age_range_)
term_year_range <- year_range
retire_year_range <- year_range

salary_headcount_table <- frs_data_env$regular_salary_headcount_table
mort_table <- frs_data_env$regular_mort_table
separation_rate_table <- frs_data_env$regular_separation_rate_table
retire_refund_ratio <- params$retire_refund_ratio_

regular_benefit_data <- bm_env$get_benefit_data(
  "regular",
  frs_data_env$regular_entrant_profile_table,
  frs_data_env$regular_salary_headcount_table,
  frs_data_env$regular_mort_table,
  frs_data_env$regular_mort_retire_table,
  frs_data_env$regular_separation_rate_table,    
  params
)

benefit_val_table <- regular_benefit_data$benefit_val_table

pop_growth=params$pop_growth_

# initialize_arrays function ----------------------------------------------

initialize_arrays <- function(
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
){
  # Define array dimensions and names ----
  active_dim <- c(length(entry_age_range), length(age_range), length(year_range))
  active_dim_names <- list(entry_age = entry_age_range, 
                           age = age_range, 
                           year = year_range)
  
  term_dim <- c(length(entry_age_range), 
                length(age_range), 
                length(year_range), 
                length(term_year_range))
  term_dim_names <- list(entry_age = entry_age_range, 
                         age = age_range, 
                         year = year_range, 
                         term_year = term_year_range)
  
  retire_dim <- c(length(entry_age_range), 
                  length(age_range), 
                  length(year_range), 
                  length(term_year_range), 
                  length(retire_year_range))
  retire_dim_names <- list(entry_age = entry_age_range,
                           age = age_range, 
                           year = year_range, 
                           term_year = term_year_range, 
                           retire_year = retire_year_range)
  
  wf_active <- array(0, dim = active_dim, dimnames = active_dim_names)
  wf_term <- array(0, dim = term_dim, dimnames = term_dim_names)
  wf_refund <- wf_term
  wf_retire <- array(0, dim = retire_dim, dimnames = retire_dim_names)
  
  retire_array <- array(0, dim = term_dim, dimnames = term_dim_names)
  refund_array <- array(0, dim = term_dim, dimnames = term_dim_names)
  
  # Initial active population ----
  active_int_df <- expand_grid(entry_age = entry_age_range, 
                               age = age_range) %>%
    left_join(salary_headcount_table, by = c("entry_age", "age")) %>%
    replace(is.na(.), 0) %>%
    select(entry_age, age, count)
  
  active_int_matrix <- xtabs(count ~ entry_age + age, active_int_df) # should we store this as a sparse array?
  
  wf_active[,,1] <- active_int_matrix # djb: wf_active dimensions are entry_age x age x year -- so fill in first year (2022) wf_active[,,"2022"]
  
  # Create probability arrays ----
  
  #.. Mortality probability array (4 dimensions: entry_age, age, year, term_year) ----
  mort_df_term <- expand_grid(entry_age = entry_age_range,
                              age = age_range, 
                              year = year_range, 
                              term_year = term_year_range) %>% 
    left_join(mort_table, by = c("entry_age", "age" = "dist_age", "year" = "dist_year", "term_year")) %>% 
    mutate(mort = if_else(is.na(mort_final), 0, mort_final))
  
  mort_array_term <- xtabs(mort ~ entry_age + age + year + term_year, mort_df_term)
  
  #.. Separation probability array (3 dimensions: entry_age, age, year) ----
  sep_df <- expand_grid(entry_age = entry_age_range,
                        age = age_range, 
                        year = year_range) %>% 
    mutate(entry_year = year - (age - entry_age)) %>% 
    left_join(separation_rate_table, by = c("entry_age", "age" = "term_age", "entry_year")) %>% 
    select(entry_age, age, year, separation_rate) %>% 
    mutate(separation_rate = if_else(is.na(separation_rate), 0, separation_rate))
  
  sep_array <- xtabs(separation_rate ~ entry_age + age + year, sep_df)
  
  #.. Refund and retirement probability arrays ----
  
  optimal_retire <- benefit_val_table %>% 
    # rename(term_age = Age) %>% 
    select(entry_year, entry_age, term_age, yos, dist_age, ben_decision) %>% 
    mutate(refund = case_when(ben_decision == "refund" ~ 1,     # use case_when instead of ifelse to handle NA values better
                              ben_decision == "mix" ~ 1 - retire_refund_ratio,
                              .default = 0),
           retire = case_when(ben_decision == "retire" ~ 1,
                              ben_decision == "mix" ~ 1,
                              .default = 0),
           refund_age = term_age)
  
  #.... Retire probability array (4 dimensions: entry_age, age, year, term_year) ----
  retire_df <- expand_grid(entry_age = entry_age_range,
                           age = age_range, 
                           year = year_range, 
                           term_year = term_year_range) %>% 
    mutate(
      entry_year = year - (age - entry_age),
      term_age = age - (year - term_year),
      yos = term_age - entry_age) %>% 
    filter(year - term_year >= 0, yos >= 0) %>% 
    left_join(optimal_retire, by = c("entry_age",
                                     "age" = "dist_age",
                                     "entry_year",
                                     "term_age",
                                     "yos")) %>% 
    mutate(retire = if_else(is.na(retire), 0, retire))
  
  retire_array <- xtabs(retire ~ entry_age + age + year + term_year, retire_df) 
  
  #.... Refund probability array (4 dimensions: entry_age, age, year, term_year) ----
  # Note that employees get refunds in the same year they get terminated.
  refund_df <- expand_grid(entry_age = entry_age_range,
                           age = age_range, 
                           year = year_range, 
                           term_year = term_year_range) %>% 
    mutate(
      entry_year = year - (age - entry_age),
      term_age = age - (year - term_year),
      yos = term_age - entry_age
    ) %>% 
    filter(year - term_year >= 0, yos >= 0) %>% 
    left_join(optimal_retire, by = c("entry_age",
                                     "age" = "refund_age",
                                     "entry_year",
                                     "term_age",
                                     "yos")) %>% 
    mutate(refund = if_else(is.na(refund), 0, refund))
  # djb: is there any reason we shouldn't combine retire_df and refund_df? same structure and methods; wide or stacked
  
  refund_array <- xtabs(refund ~ entry_age + age + year + term_year, refund_df)
  
  return(list(wf_active=wf_active,
              wf_term=wf_term, 
              wf_refund=wf_refund, 
              wf_retire=wf_retire,
              mort_array_term=mort_array_term,
              sep_array=sep_array,
              retire_array=retire_array,
              refund_array=refund_array))
}


# test initial arrays -----------------------------------------------------

identical(wf_active_s["regular",,,], wf_active)
identical(wf_term_s["regular",,,,], wf_term)
identical(wf_refund_s["regular",,,,], wf_refund)
identical(wf_retire_s["regular",,,,,], wf_retire)

identical(active_int_df_s %>% filter(class == "regular") %>% select(-class), active_int_df)
identical(wf_active_s["regular",,,1], wf_active[,,1])

identical(mort_table_s %>% filter(class == "regular") %>% select(-class), mort_table)
identical(mort_df_term_s %>% filter(class == "regular") %>% select(-class), mort_df_term)

identical(sep_df_s %>% filter(class == "regular") %>% select(-class), sep_df)
identical(sep_array_s["regular",,,], sep_array) ### TRUE
all.equal(as.vector(sep_array_s["regular",,,]), as.vector(sep_array)) ### TRUE
sum(sep_array_s["regular",,,] - sep_array) # 0


identical(benefit_val_table_s %>% filter(class == "regular") %>% select(-class), benefit_val_table %>% select(-class.x, -class.y))
identical(optimal_retire_s %>% filter(class == "regular") %>% select(-class), optimal_retire)
identical(retire_df_s %>% filter(class == "regular") %>% select(-class), retire_df)
identical(retire_array_s["regular",,,,], retire_array) ### FALSE
sum(retire_array_s["regular",,,,] - retire_array) # 0
all.equal(as.vector(retire_array_s["regular",,,,]), as.vector(retire_array)) ### TRUE

identical(refund_df_s %>% filter(class == "regular") %>% select(-class), refund_df)
identical(refund_array_s["regular",,,,], refund_array) ### FALSE
sum(refund_array_s["regular",,,,] - refund_array) # 0
all.equal(as.vector(refund_array_s["regular",,,,]), as.vector(refund_array)) ### TRUE

# loop_through_arrays -----------------------------------------------------

loop_through_arrays <- function(wf_active,
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
                                pop_growth){
  
  # calculate dims - one less thing to pass to the function
  term_dim <- dim(wf_term)
  retire_dim <- dim(wf_retire)
  
  # Position matrix to add new hires
  position_matrix <- expand_grid(entry_age = entry_age_range, age = age_range) %>% 
    mutate(new = if_else(entry_age == age, 1, 0)) # djb: only 11 cells of 1,133 have 1
  
  position_matrix <- xtabs(new ~ entry_age + age, position_matrix) # djb: has 0 or 1; note xtab can create sparse matrices
  
  # transition matrix to shift the population to the right by 1 age after 1 year
  TM <-  diag(length(age_range) + 1)[-1, -(length(age_range) + 1)] 
  
  # possible array dimensions: entry_age, age, year, term_year, retire_year
  # Workforce projection loop ----
  for (i in 2:length(year_range)) {
    
    # calculate the # of newly terminated actives. 2-dimensional array
    active2term <- wf_active[,,i-1] * sep_array[,,i-1]   
    
    # deduct terminated members from the active workforce and shift the wf_active matrix to the right by one year
    wf_active[,,i] <- (wf_active[,,i-1] - active2term) %*% TM  
    
    # new entrants matrix to be added to the active workforce
    new_entrants <- pentools::add_new_entrants(g = pop_growth, # GLOBAL
                                               ne_dist = entrant_profile_table$entrant_dist, 
                                               wf1 = wf_active[,,i-1],
                                               wf2 = wf_active[,,i], 
                                               ea = entry_age_range, 
                                               age = age_range,
                                               position_matrix = position_matrix)
    
    wf_active[,,i] = wf_active[,,i] + new_entrants  # add new entrants
    
    term2death <- wf_term[,,i-1,] * mort_array_term[,,i-1,] # 3-dimensional array entry_age, age, year
    
    wf_term[,,i,] <- apply(wf_term[,,i-1,] - term2death, 3, function(x) x %*% TM) %>% array(term_dim[-3]) 
    
    wf_term[,,i,i] <- active2term %*% TM   # add newly terminated members to the term population
    
    # calculate the # of newly refunded members. 2-dimensional array: entry_age, age
    term2refund <- wf_term[,,i,i] * refund_array[,,i,i]  
    
    wf_term[,,i,i] <- wf_term[,,i,i] - term2refund # update wf_term
    wf_refund[,,i,i] <- term2refund # update wf_refund
    
    # calculate the # of newly retired members. 3-dimensional array: entry_age, age, ., term_year
    term2retire <- wf_term[,,i,] * retire_array[,,i,]  
    
    wf_term[,,i,] <- wf_term[,,i,] - term2retire # update wf_term
    
    # 4-dimensional array: entry_age, age, year, term_year # apply over each term_year??
    retire2death <- apply(wf_retire[,,i-1,,],
                          4, # djb: looks like term_year, should be able to use "term_year" -- check
                          function(x) x * mort_array_term[,,i-1,]) %>% array(retire_dim[-3])
    
    # update wf_retire for this year 5 dimensional: entry_age, age, year, term_year, retire_year
    wf_retire[,,i,,] <- apply(wf_retire[,,i-1,,] - retire2death, c(3,4), function(x) x %*% TM) %>% array(retire_dim[-3])
    wf_retire[,,i,,i] <- term2retire
  } # end loop
  
  return(list(wf_active=wf_active,
              wf_term=wf_term, 
              wf_refund=wf_refund, 
              wf_retire=wf_retire))
}




# main workforce model function -------------------------------------------

################################################################## #
##                       Workforce Model                       ##
################################################################## #

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
  
  benefit_data_s <- bm_env$get_benefit_data_s(
    entrant_profile_table,
    salary_headcount_table,
    mort_table,
    mort_retire_table,
    separation_rate_table,    
    params
  )
  
  benefit_data <- list()
  
  benefit_data$ann_factor_table <- benefit_data_s$ann_factor_table_s %>% filter(class == class_name) %>% select(-class)
  benefit_data$ann_factor_retire_table <- benefit_data_s$ann_factor_retire_table_s %>% filter(class == class_name) %>% select(-class)
  benefit_data$benefit_table <- benefit_data_s$benefit_table_s %>% filter(class == class_name) %>% select(-class)
  benefit_data$final_benefit_table <- benefit_data_s$final_benefit_table_s %>% filter(class == class_name) %>% select(-class)
  benefit_data$benefit_val_table <- benefit_data_s$benefit_val_table_s %>% filter(class == class_name) %>% select(-class)
  benefit_data$indv_norm_cost_table <- benefit_data_s$indv_norm_cost_table_s %>% filter(class == !!class_name)
  benefit_data$agg_norm_cost_table <- benefit_data_s$agg_norm_cost_table_s %>% filter(class == !!class_name)
  
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
    benefit_val_table = benefit_data$benefit_val_table,
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

