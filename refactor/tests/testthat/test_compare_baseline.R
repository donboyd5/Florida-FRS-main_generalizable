# tests/testthat/test_compare_baseline.R

# library(testthat)

cat("\n\n")
print("running baseline results tests")
cat("\n")

test_that("Compare baseline_funding expect_equal", {
  objname <- "baseline_funding"
  cat("Testing object: ", objname, "\n")
  if (exists(objname, envir = oldws) & exists(objname, envir = newws)) {
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = newws)
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    cat("\n")
  } else {
    cat("\nObject does not exist: ", objname, "\n")
    expect_true(FALSE, info = paste("Object does not exist:", objname))
  }
})

test_that("Compare baseline_liability expect_equal", {
  objname <- "baseline_liability"
  cat("Testing object: ", objname, "\n")
  if (exists(objname, envir = oldws) & exists(objname, envir = newws)) {
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = newws)
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    cat("\n")
  } else {
    cat("\nObject does not exist: ", objname, "\n")
    expect_true(FALSE, info = paste("Object does not exist:", objname))
  }
})

cat("\n")

# test_that("Compare baseline_funding expect_equal", {
#   objname <- "baseline_funding"
#   cat("\nTesting object: ", objname, "\n")
#   old_object <- get(objname, envir = oldws)
#   new_object <- get(objname, envir = newws)
#   expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
# })

# test_that("Compare baseline_liability expect_equal", {
#   objname <- "baseline_liability"
#   cat("\nTesting object: ", objname, "\n")
#   old_object <- get(objname, envir = oldws)
#   new_object <- get(objname, envir = newws)
#   expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
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

