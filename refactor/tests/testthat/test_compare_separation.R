# tests/testthat/test_compare_separation.R

# library(testthat)

cat("\n\n")
print("running separation-rate table tests")

classes <- c("regular", "special", "admin", "eco", "eso", "judges", "senior_management")

cat("\n")
print("separation-rate table tests")

test_that(" separation-rate table matches Reason",{
  walk(classes, function(class) {
    objname <- paste0(class, "_separation_rate_table")
    cat("\nTesting object: ", objname, "\n")
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = newws)
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    # cat("\n")
  })})

cat("\n\n")
