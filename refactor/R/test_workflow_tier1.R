# Test that FRS_new_workflow.R loads correctly with Tier 1 adapters
# This is a quick test before running the full model

cat('=== TESTING TIER 1 WORKFLOW INTEGRATION ===\n\n')

# Set up paths
rdir <- "d:/R_projects/Florida-FRS-main_generalizable/refactor/R"

cat('1. Loading pendata...\n')
load('D:/R_projects/pendata/data/frs.rda')

cat('2. Loading params...\n')
params <- list2env(as.list(frs$params_env))

cat('3. Loading helper functions...\n')
source(file.path(rdir, "FRS_helper_functions.R"))

cat('4. Applying Tier 1 adapters...\n')
params$salary_growth_table <- convert_salarygrowth_to_legacy(params$salarygrowth)
params$current_amort_layers_table <- convert_amortization_to_legacy(params$amortization_bases)

cat('\n5. Verifying conversions:\n')

# Check salary_growth_table
cat('   salary_growth_table:\n')
cat('      Rows:', nrow(params$salary_growth_table), '\n')
cat('      Columns:', paste(names(params$salary_growth_table), collapse=', '), '\n')
cat('      Sample (first 3 rows):\n')
print(head(params$salary_growth_table, 3))

# Check current_amort_layers_table
cat('\n   current_amort_layers_table:\n')
cat('      Rows:', nrow(params$current_amort_layers_table), '\n')
cat('      Columns:', paste(names(params$current_amort_layers_table), collapse=', '), '\n')
cat('      Sample (first 3 rows):\n')
print(head(params$current_amort_layers_table, 3))

cat('\n=== TIER 1 WORKFLOW TEST PASSED ===\n')
cat('The workflow successfully loads params and applies adapters.\n')
cat('Ready to test full model run.\n')
