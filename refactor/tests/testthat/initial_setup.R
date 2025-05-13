# tests/initial_stuff.R

print("loading the Reason results and new results environments...")

# Load the old workspace environment
oldpath <- here::here("refactor", "reason_results", "reason_workspace.RData")
load(oldpath, oldws <- new.env())

# Load the new workspace environment
newpath <- here::here("refactor", "new_results", "new_workspace.RData")
load(newpath, newws <- new.env())

cat("\n")
print("ready to begin tests...")

# Schedule cleanup of the old environment
# withr::defer({
#   rm(list = ls(envir = oldws), envir = oldws)
#   rm(oldws)
# }, envir = globalenv())
# 
# # Schedule cleanup of the new environment
# withr::defer({
#   rm(list = ls(envir = newws), envir = newws)
#   rm(newws)
# }, envir = globalenv())
