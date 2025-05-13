


source("E:/R_projects/projects/Florida-FRS-main_generalizable/refactor/tools/libraries.R")

# source("E:/R_projects/projects/Florida-FRS-main_generalizable/refactor/tests/testthat/initial_setup.R")

oldpath <- here::here("refactor", "reason_results", "reason_workspace.RData")
load(oldpath, oldws <- new.env())

newpath <- here::here("refactor", "new_results", "new_workspace.RData")
load(newpath, newws <- new.env())

objname <- "regular_wf_data"
objname <- "funding_list"
objname <- "current_amort_layers_table"
objname <- "return_scenarios"


f <- function(objname){
  test_that(paste0("Compare ", objname), {
    # objname <- "male_mp_final_table"
    cat("Testing object: ", objname, "\n")
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = .GlobalEnv)
    print(paste0("old: ", old_object))
    print(paste0("new: ", new_object))
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    cat("\n")
  })
}
f(objname)


prefixes <- str_replace(params$class_names_no_drop_frs_, " ", "_")
(objnames <- paste0(prefixes, "_wf_data"))

purrr::walk(objnames, f)


objname <- "admin_separation_rate_table"

old_object <- get(objname, envir = oldws)
new_object <- get(objname, envir = .GlobalEnv)
new_object2 <- get(objname, envir = newws)


old_object
new_object
new_object2

new_object - old_object
new_object2 - old_object

params$return_scenarios
