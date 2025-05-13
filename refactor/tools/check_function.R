source(here::here("tools", "libraries.R")) # load all tools
source(here::here("tools", "functions.R"))

fun <- get_salary_headcount_table
fun <- get_tier

fun <- get_base_mort_table
fun <- clean_mp_table
fun <- get_mp_final_table
fun <- get_mort_table
fun <- get_mort_retire_table

fun <- clean_retire_rate_table
fun <- get_normal_retire_rate_table
fun <- get_early_retire_rate_table

fun <- get_separation_table

fun <- get_annuity_factor_retire_table
fun <- loop_through_arrays

codetools::checkUsage(fun)

codetools::findGlobals(fun, merge = FALSE)
