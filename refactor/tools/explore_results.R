


# INFORMATAIONAL ONLY ------
# prepare comparisons of new vs. Reason -----------------------------------

# load each result into its own environment
# oldpath <- here::here("refactor", "reason_results", "reason_workspace.RData")
# newpath <- here::here("refactor", "new_results", "new_workspace.RData")

# load(oldpath, oldws <- new.env())
# load(newpath, newws <- new.env())

# get names of objects in each workspace
# oldnames <- ls(name=oldws) # names of objects in the workspace
# oldnames # almost 300 objects!; already sorted by name

# newnames <- ls(name=newws) # names of objects in the workspace
# newnames # almost 300 objects!; already sorted by name

# get(objnames[119], envir=rws) # how to get an object from the workspace

old1 <- oldws$baseline_funding
new1 <- newws$baseline_funding

oval <- old1$regular$payroll_db_legacy
nval <- new1$regular$payroll_db_legacy

class(old1$regular)

mean(abs(nval - oval)) / mean(abs(oval))

mean(abs(oval - nval)) / mean(abs(nval))

mean(abs(oval - nval) / nval)
mean(abs(oval - nval) / oval)


# ── Failure (test_compare_all_reason_objects.R:51:7):  new result-object matches Reason counterpart ──
# `new_object` not equal to `old_object`.
# Component “regular”: Component “payroll_db_legacy”: Mean relative difference: 1.001224
# Component “regular”: Component “payroll_db_new”: Mean relative difference: 0.2384179
# Component “regular”: Component “payroll_dc_legacy”: Mean relative difference: 0.6263772
# Component “regular”: Component “payroll_dc_new”: Mean relative difference: 0.2384179
# Component “regular”: Component “liability_gain_loss_legacy”: Mean relative difference: 1
# Component “regular”: Component “liability_gain_loss_new”: Mean relative difference: 1
# Component “regular”: Component “total_liability_gain_loss”: Mean relative difference: 1
# Component “regular”: Component “total_aal”: Mean relative difference: 1.19901
# Component “regular”: Component “aal_legacy”: Mean relative difference: 1.282213
# ...
# Mismatch in baseline_funding
# 
# ── Failure (test_compare_all_reason_objects.R:51:7):  new result-object matches Reason counterpart ──
# `new_object` not equal to `old_object`.
# Component “payroll_db_legacy_est”: Mean relative difference: 71.19649
# Component “payroll_db_new_est”: Mean relative difference: 24.8645
# Component “payroll_dc_legacy_est”: Mean relative difference: 54.43311
# Component “payroll_dc_new_est”: Mean relative difference: 24.8645
# Component “total_payroll_est”: Mean relative difference: 33.4379
# Component “nc_rate_db_legacy_est”: Mean relative difference: 2.297114
# Component “nc_rate_db_new_est”: Mean relative difference: 1.313122
# Component “pvfb_active_db_legacy_est”: Mean relative difference: 346.4105
# Component “pvfb_active_db_new_est”: Mean relative difference: 93.41514
# ...
# Mismatch in baseline_liability


# get baseline_funding list old and new --------------------------------

# blfunding_old <- get("baseline_funding", envir=oldws)
# blfunding_new <- get("baseline_funding", envir=newws)

# names(blfunding_old)
# names(blfunding_new)

# stack the two sets of data frames so they can be compared ----
#. first, fix the names to remove spaces ----
# fixnames <- function(list){
#   names(list)[names(list) == "senior management"] <- "senior_management"
#   return(list)
# }

# blfunding_old <- fixnames(blfunding_old)
# blfunding_new <- fixnames(blfunding_new)

# names(blfunding_old)
# names(blfunding_new)

#. stack the data frames ----

# str(blfunding_old)

# olddf <- bind_rows(blfunding_old, .id = "class") |> 
#   pivot_longer(-c(class, year),
#                values_to = "value")

# newdf <- bind_rows(blfunding_old, .id = "class") |> 
#   pivot_longer(-c(class, year),
#                values_to = "value")

# all.equal(olddf, newdf)

# comp <- left_join(olddf, newdf,
#                   by = join_by(class, year, name))



