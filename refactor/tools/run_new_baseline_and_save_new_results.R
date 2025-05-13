cat("\014") # clear console in Windows
rm(list = ls())


# run the following in a CLEAN environment with the branch of interest checked out --------------------------------

# pkdir <- "E:/R_projects/packages"
# detach("package:pentools", unload = TRUE)
# remove.packages("pentools")
# pkg <- fs::path(pkdir, "pentools_0.2.0.tar.gz")
# pkg <- fs::path(pkdir, "pentools_0.3.0.tar.gz")
# install.packages(pkg, repos = NULL, type = "source")
# library(pentools)
# ??pentools-package
# MANUALLY RESET AND CLEAR ENVIRONMENT WITH Ctrl-Shift-F10 !!!!!
# Then source this file (or run line by line)

system.time(source(here::here("refactor", "R", "FRS_master_GC.R"))) # 3 mins load and build the full FRS Florida model

# generate baseline results
system.time(baseline_funding <- fm_env$get_funding_data(
  params = params,
  return = "stacked"
)) # about 60 secs tot, ~ 10 seconds for a single class

system.time(save.image(here::here("refactor", "new_results", "new_workspace.RData"))) # save the entire workspace, ~ 15-20 secs

# run one or the other of the following tests

# system.time(source(fs::path(tooldir, "run_tests.R"))) # run selected tests
# tooldir <- here::here("refactor", "tools") # run if needed
system.time(source(fs::path(tooldir, "run_allobjects_tests.R"))) # run tests on all objects appropriate to compare ~ 15 secs


# NOTE:
#   regex for finding global variables:   \w+_(?=\s|$|\)|,|\;)  -- use in RStudio search box
