# tests/testthat/test_compare_amortization.R

# library(testthat)

cat("\n\n")
print("running amortization tests")

cat("\n")
print("amortization table tests")

test_that("Compare current_amort_layers_table_ expect_equal", {
  objname <- "current_amort_layers_table_" # the global table
  cat("Testing object: ", objname, "\n")
  old_object <- get(objname, envir = oldws)
  new_object <- get(objname, envir = newws)
  expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
  cat("\n")
})

cat("\n\n")
