# tests/testthat/test_compare_salary_headcount_entrants.R

# library(testthat)
library(purrr)

classes <- c("regular", "special", "admin", "eco", "eso", "judges", "senior_management")

cat("\n\n")
print("running salary headcount tests")

test_that(" salary headcount table matches Reason",{
  walk(classes, function(class) {
    objname <- paste0(class, "_salary_headcount_table")
    cat("Testing object: ", objname, "\n")
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = newws)
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    cat("\n")
  })})

cat("\n")
print("running entrant profile tests")

test_that(" entrant profile table matches Reason",{
  walk(classes, function(class) {
    objname <- paste0(class, "_entrant_profile_table")
    cat("Testing object: ", objname, "\n")
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = newws)
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    cat("\n")
  })})

cat("\n")

# run with 
#   testthat::test_dir("tests/testthat", reporter = ListReporter)
#   testthat::test_file("tests/testthat/test_compare_objects.R", reporter = ListReporter)

