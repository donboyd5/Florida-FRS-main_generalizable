# Get all object names in the environment
all_objects <- ls()

# Filter the object names to include only those ending with "_"
objects_with_underscore <- grep("_$", all_objects, value = TRUE)

# Print the result
print(objects_with_underscore)

# which functions have default values ----

# Get all object names in the environment
all_objects <- ls()

# Filter to find functions
all_functions <- sapply(all_objects, function(x) is.function(get(x)))

# Get the names of functions
function_names <- names(all_functions)[all_functions]

# Function to check if a function has default arguments
has_default_args <- function(f) {
  args <- formals(f)
  any(!sapply(args, is.symbol))  # Check if any argument has a default value
}

# Find functions with default arguments
functions_with_defaults <- sapply(function_names, function(fn) has_default_args(get(fn)))

# Get the names of functions with default values
functions_with_defaults_names <- function_names[functions_with_defaults]

# Print the list of functions with default arguments
print(functions_with_defaults_names)


new_year_


# djb check this out globals ----
# DONE get_mort_table new_year_
# DONE get_funding_table needs init_funding_data
# DONE: get_wf_data has default globals instead should pass
# DONE: get_benefit_data has default globals instead should pass

# get_liability_data -- allow default parameters because otherwise
#   it is less clear which parameters are changed in a call

get_funding_data also
FIRST:: INTERNAL functions in get_funding_data use globals
A LOT OF WORK TO DO ON GET FUNDING DATA



# end ----


> function_names
[1] "clean_mp_table"                         "clean_retire_rate_table"                "get_agg_norm_cost_table"               
[4] "get_all_classes_funding_list"           "get_annuity_factor_retire_table"        "get_annuity_factor_table"              
[7] "get_base_mort_table"                    "get_benefit_data"                       "get_benefit_table"                     
[10] "get_benefit_val_table"                  "get_class_salary_growth_table"          "get_current_amort_layers_summary_table"
[13] "get_dist_age_table"                     "get_early_retire_rate_table"            "get_final_benefit_table"               
[16] "get_funding_data"                       "get_funding_table"                      "get_liability_data"                    
[19] "get_mort_retire_table"                  "get_mort_table"                         "get_mp_final_table"                    
[22] "get_normal_retire_rate_table"           "get_salary_benefit_table"               "get_salary_headcount_table"            
[25] "get_sep_type"                           "get_separation_table"                   "get_tier"                              
[28] "get_wf_data"                            "initialize_arrays"                      "loop_through_arrays"                   
[31] "run_tests"                             
