# tests/testthat/test_compare_workforce.R

# library(testthat)

cat("\n\n")
print("running workforce data tests")

classes <- c("regular", "special", "admin", "eco", "eso", "judges", "senior_management")

cat("\n")
print("wf_data table tests")

test_that(" wf_data table matches Reason",{
  walk(classes, function(class) {
    objname <- paste0(class, "_wf_data")
    cat("\nTesting object: ", objname, "\n")
    old_object <- get(objname, envir = oldws)
    new_object <- get(objname, envir = newws)
    expect_equal(new_object, old_object, info = paste("Mismatch in", objname))
    # cat("\n")
  })})

cat("\n\n")
