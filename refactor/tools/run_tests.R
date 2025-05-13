# run_tests.R

library(testthat)
options(testthat.edition = 3)

tdir <- here::here("refactor", "tests", "testthat")

run_tests <- function() {
  # Load setup once
  source(here::here(tdir, "initial_setup.R"))

  # Run tests
  # reporters: ListReporter, ProgressReporter, SummaryReporter, TapReporter, JunitReporter, CheckReporter
  test_file(here::here(tdir, "test_compare_baseline.R"), reporter = CompactProgressReporter)
  test_file(here::here(tdir, "test_compare_salary_headcount_entrants_profile.R"), reporter = CompactProgressReporter)
  test_file(here::here(tdir, "test_compare_mortality.R"), reporter = CompactProgressReporter)
  test_file(here::here(tdir, "test_compare_separation.R"), reporter = CompactProgressReporter)
  test_file(here::here(tdir, "test_compare_workforce.R"), reporter = CompactProgressReporter)
  test_file(here::here(tdir, "test_compare_amortization.R"), reporter = CompactProgressReporter)
  cat("\n")
  # Add more test files as needed
}

# Run the tests
run_tests()


# Cleanup code
cat("\n")
print("done with tests, removing objects and environments created during setup...")
# Remove objects or environments created during setup
rm(list = ls(envir = oldws), envir = oldws)
rm(oldws)

rm(list = ls(envir = newws), envir = newws)
rm(newws)




# test_file("tests/testthat/test_compare_baseline.R")
# test_file("tests/testthat/test_compare_salary_headcount.R")
# test_dir("tests/testthat")