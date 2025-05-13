extend_params <- function(params){
  # extend the params environment with additional objects ----
  
  # update return scenarios
  # this is done much later in the Reason model but we have all the info we need to do it now
  params$return_scenarios <- params$return_scenarios_original_ |> 
    mutate(across(-year, \(x) ifelse(year==2023, params$return_2023_, x)),
           model=ifelse(year > 2023, params$model_return_, model),
           assumption=ifelse(year > 2023, params$dr_current_, assumption))  
  
  params$return_scen_index <- which(colnames(params$return_scenarios) == params$return_scen_)
  
  # class groupings
  params$class_names_ <- params$init_funding_data$class
  params$class_names_no_frs_ <- params$class_names_[!params$class_names_ %in% c("frs")]
  params$class_names_no_drop_frs_ <- params$class_names_[!params$class_names_ %in% c("drop", "frs")]
 
  
  # create a tibble that has nc_cal_ values for each class
  var_names <- ls(pattern = "_nc_cal_$", envir=params)
  classes <- gsub("_nc_cal_$", "", var_names) # Extract the class prefix
  values <- mget(var_names, envir = params)
  params$nc_cal_ <- tibble(class = classes, nc_cal_ = unlist(values))
  
  params$salary_growth_table_ <- params$salary_growth_table_original_ %>% 
    # add rows to the tibble for additional yos
    bind_rows(tibble(yos = (max(params$salary_growth_table_original_$yos) + 1):max(params$yos_range_))) %>% 
    fill(everything(), .direction = "down") %>% 
    mutate(across(contains("salary"), ~ cumprod(1 + lag(.x, default = 0)), .names = "cumprod_{.col}"), .keep = "unused")
  
  params$term_rate_male_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_term_rate_male_table_"), envir = params)
  params$term_rate_female_table_list <- mget(paste0(params$class_names_no_drop_frs_, "_term_rate_female_table_"), envir = params)
  
  return(params)
}


get_params <- function(frs_data_env, modparm_data_env){
  
  # decide what variables to keep in the params environment ----
  
  #.. first, look at frs_data_env ----
  frs_names <- ls(envir = frs_data_env) |> sort()
  frs_underscore <- frs_names[grepl("_$", frs_names)] # we'll keep all the underscore-ending names
  
  # what other variables do we want to keep?
  # setdiff(frs_names, frs_underscore)
  frs_extras <- c("eco_eso_judges_active_member_adjustment_ratio", "retiree_distribution", "init_funding_data")
  frs_GC_add <- c("salary_growth_table")
  frs_keep <- c(frs_underscore, frs_extras, frs_GC_add)
  frs_objects <- mget(frs_keep, envir = frs_data_env)
  
  #.. now, look at modparm_data_env ----
  modparm_names <- ls(envir = modparm_data_env) |> sort()
  modparm_underscore <- modparm_names[grepl("_$", modparm_names)] # keep all of the underscore-ending names
  # setdiff(modparm_names, modparm_underscore) # they're all underscored - no names that don't end in non-underscore
  
  modparm_keep <- modparm_underscore
  modparm_objects <- mget(modparm_keep, envir = modparm_data_env)
  
  params <- new.env()
  params_objects <- c(frs_objects, modparm_objects)
  list2env(params_objects, envir = params) 
  
  params <- extend_params(params)
  
  # it is possible to make the names in params sorted, but work, and it won't
  # be maintained if we modify params, so I don't do it
  
  # but here's how, just to show the method
  # create a temporary environment from which we will copy objects, sorted by name
  # temp_env <- new.env()
  # list2env(c(frs_objects, modparm_objects), envir = temp_env) 
  # sorted_names <- ls(envir=temp_env)
  # 
  # params <- new.env()
  # for (name in sorted_names) {
  #   # use assign rather than list2env so we can control sort order
  #   assign(name, temp_env[[name]], envir = params)
  # }
  return(params)
}