# tests/testthat/test_compare_baseline.R

# library(testthat)

cat("\n\n")
print("running mortality tests")

cat("\n")
print("mortality improvement table tests")

test_that("Compare male_mp_final_table expect_equal", {
  objname <- "male_mp_final_table"
  cat("Testing object: ", objname, "\n")
  old_object <- get(objname, envir = oldws)
  new_object <- get(objname, envir = newws)
  expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
  cat("\n")
})

test_that("Compare female_mp_final_table expect_equal", {
  objname <- "female_mp_final_table"
  cat("Testing object: ", objname, "\n")
  old_object <- get(objname, envir = oldws)
  new_object <- get(objname, envir = newws)
  expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
  cat("\n")
})

classes <- c("regular", "special", "admin", "eco", "eso", "judges", "senior_management")

cat("\n")
print("mortality table tests")

test_that(" mortality table matches Reason",{
  walk(classes, function(class) {
    objname <- paste0(class, "_mort_table")
    cat("\nTesting object: ", objname, "\n")
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = newws)
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    # cat("\n")
  })})

cat("\n\n")
print("mortality retirement table tests")

test_that(" mortality retirement table matches Reason",{
  walk(classes, function(class) {
    objname <- paste0(class, "_mort_retire_table")
    cat("Testing object: ", objname, "\n")
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = newws)
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    cat("\n")
  })})

cat("\n")

# walk(classes, function(class) {
#   test_that(sprintf("Compare mortality table for class: %s", class), {
#     objname <- paste0(class, "_mort_table")
#     cat("\nTesting object: ", objname, "\n")
#     old_object <- get(objname, envir = oldws)
#     new_object <- get(objname, envir = newws)
#     
#     expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
#   })
# })


# cat("\n\n")
# print("mortality retirement table tests")
# walk(classes, function(class) {
#   test_that(sprintf("Compare mortality retirement table for class: %s", class), {
#     objname <- paste0(class, "_mort_retire_table")
#     cat("\nTesting object: ", objname, "\n")
#     old_object <- get(objname, envir = oldws)
#     new_object <- get(objname, envir = newws)
#     
#     expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
#   })
# })


# test_that("Compare baseline_funding expect_identical", {
#   old_object <- get("baseline_funding", envir = oldws)
#   new_object <- get("baseline_funding", envir = newws)
#   print(all.equal(old_object, new_object))
#   expect_identical(old_object, new_object)
# })

# run with 
#   testthat::test_dir("tests/testthat", reporter = ListReporter)
#   testthat::test_file("tests/testthat/test_compare_objects.R", reporter = ListReporter)

