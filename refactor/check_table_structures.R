# Check structure of key better tables and potential gap tables
load('D:/R_projects/pendata/data/frs.rda')

cat('=== BETTER STRUCTURES - Verify they exist and show schemas ===\n\n')

# 1. headcount_salary
cat('1. headcount_salary:\n')
cat('   Rows:', nrow(frs$params_env$headcount_salary), '\n')
cat('   Columns:', paste(names(frs$params_env$headcount_salary), collapse=', '), '\n')
cat('   First few rows:\n')
print(head(frs$params_env$headcount_salary, 3))

# 2. benefit_rules
cat('\n2. benefit_rules:\n')
cat('   Rows:', nrow(frs$params_env$benefit_rules), '\n')
cat('   Columns:', paste(names(frs$params_env$benefit_rules), collapse=', '), '\n')
cat('   First few rows:\n')
print(head(frs$params_env$benefit_rules, 3))

# 3. constants_assumptions_tbl
cat('\n3. constants_assumptions_tbl:\n')
cat('   Rows:', nrow(frs$params_env$constants_assumptions_tbl), '\n')
cat('   Columns:', paste(names(frs$params_env$constants_assumptions_tbl), collapse=', '), '\n')
cat('   Sample constants:\n')
print(head(frs$params_env$constants_assumptions_tbl[, c('variable', 'value', 'description')], 5))

# 4. salarygrowth
cat('\n4. salarygrowth:\n')
cat('   Rows:', nrow(frs$params_env$salarygrowth), '\n')
cat('   Columns:', paste(names(frs$params_env$salarygrowth), collapse=', '), '\n')

# 5. withdrawal
cat('\n5. withdrawal:\n')
cat('   Rows:', nrow(frs$params_env$withdrawal), '\n')
cat('   Columns:', paste(names(frs$params_env$withdrawal), collapse=', '), '\n')

# 6. retirees
cat('\n6. retirees:\n')
cat('   Rows:', nrow(frs$params_env$retirees), '\n')
cat('   Columns:', paste(names(frs$params_env$retirees), collapse=', '), '\n')
cat('   First few rows:\n')
print(head(frs$params_env$retirees, 3))

# 7. amortization_bases
cat('\n7. amortization_bases:\n')
cat('   Rows:', nrow(frs$params_env$amortization_bases), '\n')
cat('   Columns:', paste(names(frs$params_env$amortization_bases), collapse=', '), '\n')

cat('\n\n=== SURPRISE FINDS - Tables I thought were gaps ===\n\n')

# 8. retirement_rates - THIS WAS LISTED AS A GAP BUT IT EXISTS!
cat('8. retirement_rates (FOUND - was listed as gap!):\n')
cat('   Rows:', nrow(frs$params_env$retirement_rates), '\n')
cat('   Columns:', paste(names(frs$params_env$retirement_rates), collapse=', '), '\n')
cat('   First few rows:\n')
print(head(frs$params_env$retirement_rates, 3))

# 9. return_scenarios
cat('\n9. return_scenarios (checking if this is better format):\n')
if (is.data.frame(frs$params_env$return_scenarios)) {
  cat('   Type: data.frame\n')
  cat('   Rows:', nrow(frs$params_env$return_scenarios), '\n')
  cat('   Columns:', paste(names(frs$params_env$return_scenarios), collapse=', '), '\n')
  print(head(frs$params_env$return_scenarios, 3))
} else {
  cat('   Type:', class(frs$params_env$return_scenarios), '\n')
  cat('   Dimensions:', dim(frs$params_env$return_scenarios), '\n')
}

# 10. Check db_dc tables
cat('\n10. db_dc_legacy_table:\n')
cat('   Rows:', nrow(frs$params_env$db_dc_legacy_table), '\n')
cat('   Columns:', paste(names(frs$params_env$db_dc_legacy_table), collapse=', '), '\n')
cat('   First few rows:\n')
print(head(frs$params_env$db_dc_legacy_table, 3))

cat('\n11. db_dc_new_table:\n')
cat('   Rows:', nrow(frs$params_env$db_dc_new_table), '\n')
cat('   Columns:', paste(names(frs$params_env$db_dc_new_table), collapse=', '), '\n')

cat('\n\n=== REMAINING GAPS - Do mortality tables have better versions? ===\n\n')

# Check if there's a consolidated mortality table
cat('12. mort_table (legacy - checking structure):\n')
cat('   Rows:', nrow(frs$params_env$mort_table), '\n')
cat('   Columns:', paste(names(frs$params_env$mort_table), collapse=', '), '\n')

cat('\n13. mort_retire_table (legacy):\n')
cat('   Rows:', nrow(frs$params_env$mort_retire_table), '\n')
cat('   Columns:', paste(names(frs$params_env$mort_retire_table), collapse=', '), '\n')

# Check for any tables with "mortality" in name
cat('\nSearching for any "mortality" tables...\n')
mortality_tables <- grep('mortality|mort', names(frs$params_env), value=TRUE, ignore.case=TRUE)
cat('Found:', paste(mortality_tables, collapse=', '), '\n')
