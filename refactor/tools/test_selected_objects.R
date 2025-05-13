


source("E:/R_projects/projects/Florida-FRS-main_generalizable/refactor/tools/libraries.R")
source("E:/R_projects/projects/Florida-FRS-main_generalizable/refactor/tests/testthat/initial_setup.R")

ns(oldws)
ns(newws)

digest(oldws$funding_list)
digest(newws$funding_list)
digest(funding_list)

oname <- "current_amort_layers_table"
digest(oldws[[oname]])
digest(newws[[oname]])

digest(newws$funding_list)
digest(funding_list)

oldws$init_funding_data
newws$init_funding_data



ns(params)
