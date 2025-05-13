# tests/testthat/test_compare_salary_headcount_entrants.R

# library(testthat)
library(purrr)
library(stringr)
library(tidyverse)

cat("\n\n")
print("running test on ALL Reason objects, except functions and selected other objects")

# reason_object_names <- ls(envir = oldws)
# newws_object_names <- ls(envir = newws)


# Pre-process old data ----------------------------------------------------

cat("\n")
print("Preprocessing Reason results to change 'senior management' to 'senior_management'")
print("..changing class column of init_funding_data in Reason results")
oldws$init_funding_data <- oldws$init_funding_data |>
  mutate(class = ifelse(class == "senior management",
                        "senior_management",
                        class))

print("..changing element name of baseline_funding in Reason results")
names(oldws$baseline_funding)[names(oldws$baseline_funding) == "senior management"] <- "senior_management"

print("..changing class column of current_amort_layers_table in Reason results")
oldws$current_amort_layers_table <- oldws$current_amort_layers_table |>
  mutate(class = ifelse(class == "senior management",
                        "senior_management",
                        class))

print("..changing class column of current_amort_layers_table_ in Reason results")
oldws$current_amort_layers_table_ <- oldws$current_amort_layers_table_ |>
  mutate(class = ifelse(class == "senior management",
                        "senior_management",
                        class))

print("..changing element name of funding_list in Reason results")
names(oldws$funding_list)[names(oldws$funding_list) == "senior management"] <- "senior_management"


cat("\n")
print("Preprocessing new results: pull selected objects from params into new workspace...")
newws$funding_list <- newws$params$funding_list
newws$current_amort_layers_table <- newws$params$current_amort_layers_table
print("TODO: salary_growth_table")


# prepare new environment -------------------------------------------------

print("dumping new results sub-environments into the main new results environment")
list2env(as.list(newws$params), envir = newws)
# overwrite an item that Reason changed from its initial value so we compare apples
newws$return_scenarios <- newws$params$return_scenarios_original_

# overwrite an item that I changed from initial
newws$salary_growth_table_ <- newws$params$salary_growth_table_original_

list2env(as.list(newws$modparm_data_env), envir = newws)
list2env(as.list(newws$wf_data_env), envir = newws)

get_baseline_funding_list <- function(baseline_funding_stacked_tibble, old_baseline_funding_list) {
  baseline_funding_list <- split(baseline_funding_stacked_tibble, 
                                 factor(baseline_funding_stacked_tibble$class, 
                                        levels = names(old_baseline_funding_list))) # keep the original order of names
  
  # Reason's baseline_funding list doesn't have a class column
  baseline_funding_list <- lapply(baseline_funding_list, function(x) select(x, -class)) 
  
  # the drop and frs tibbles don't have all variables in the other tibbles
  lose_names <- setdiff(names(old_baseline_funding_list$regular), names(old_baseline_funding_list$drop))
  baseline_funding_list$drop <- baseline_funding_list$drop |> select(-all_of(lose_names))
  baseline_funding_list$frs <- baseline_funding_list$frs |> select(-all_of(lose_names))
  
  return(baseline_funding_list)
}

# if baseline_funding is a (stacked) tibble, convert it to a list in form equivalent to Reason
if (is_tibble(newws$baseline_funding)) {
  print("baseline_funding in new results is a stacked tibble. Creating a list of tibbles for comparison with Reason...")
  newws$baseline_funding_stacked <- newws$baseline_funding # keep a copy
  newws$baseline_funding <- get_baseline_funding_list(newws$baseline_funding, oldws$baseline_funding)
}

# GC: temp to set the salary growth table to the old one (unstacked)

newws$salary_growth_table <- oldws$salary_growth_table ##Temp to set the salary growth table to the old one (unstacked)


# select names ----
reason_object_names <- ls(envir = oldws)
newws_object_names <- ls(envir = newws)

# Filter out functions
reason_functions <- sapply(reason_object_names, function(x) is.function(get(x, envir = oldws)))
non_function_reason_names <- setdiff(reason_object_names, names(which(reason_functions)))

reason_names_in_newws <- intersect(non_function_reason_names, newws_object_names)

# look at globals to see if there are any we want to exclude
# reason_globals <- stringr::str_subset(reason_names_in_newws, "_$")


# done modifying Reason results

excludes <- c("FileName")

names_to_compare <- setdiff(reason_names_in_newws, excludes)


cat("\n")
print("Reason non-function objects that are not in new workspace and thus not compared (if any)")
print(setdiff(non_function_reason_names, newws_object_names))

cat("\n")
print("Reason non-function objects that are in new workspace but excluded from comparisons (if any)")
print(setdiff(reason_names_in_newws, names_to_compare))

cat("\n")
print("New-results objects that are not in Reason workspace and thus not compared (if any)")
print(setdiff(newws_object_names, reason_object_names))

cat("\n")
print("New results being compared to Reason counterparts")
print(names_to_compare)

cat("\n\n")


walk(names_to_compare, function(objname) {
  #cat("Testing object: ", objname, "\n")
  old_object <- get(objname, envir = oldws)
  new_object <- get(objname, envir = newws)  
  test_that(" new result-object matches Reason counterpart",{
      expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    })
})


# test_that(" new result-object matches Reason counterpart",{
#   walk(names_to_compare, function(objname) {
#     cat("Testing object: ", objname, "\n")
#     old_object <- get(objname, envir = oldws)
#     new_object <- get(objname, envir = newws)
#     expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
#     cat("\n")
#   })
# })

