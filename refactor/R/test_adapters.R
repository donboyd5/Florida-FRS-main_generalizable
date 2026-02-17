# Test adapter functions for Tier 1 migration
source('d:/R_projects/Florida-FRS-main_generalizable/refactor/R/FRS_helper_functions.R')
load('D:/R_projects/pendata/data/frs.rda')

cat('=== TESTING ADAPTER FUNCTIONS ===\n\n')

# Test 1: salarygrowth adapter
cat('1. Testing convert_salarygrowth_to_legacy():\n')
cat('   Input (better structure - first 5 rows):\n')
print(head(frs$params_env$salarygrowth, 5))

converted_salary_growth <- convert_salarygrowth_to_legacy(frs$params_env$salarygrowth)

cat('\n   Output (legacy format - first 10 rows):\n')
print(head(converted_salary_growth, 10))

cat('\n   Original legacy (first 10 rows for comparison):\n')
print(head(frs$params_env$salary_growth_table, 10))

cat('\n   Comparison summary:\n')
cat('      Converted rows:', nrow(converted_salary_growth), '\n')
cat('      Original legacy rows:', nrow(frs$params_env$salary_growth_table), '\n')
cat('      Converted columns:', paste(names(converted_salary_growth), collapse=', '), '\n')
cat('      Legacy columns:', paste(names(frs$params_env$salary_growth_table), collapse=', '), '\n')

# Check if cumulative products match for a sample class
admin_converted <- converted_salary_growth[converted_salary_growth$class == "admin", ]
admin_legacy <- frs$params_env$salary_growth_table[frs$params_env$salary_growth_table$class == "admin", ]

cat('\n   Sample comparison (admin class, yos 0-5):\n')
comparison <- merge(
  admin_converted[admin_converted$yos <= 5, ],
  admin_legacy[admin_legacy$yos <= 5, ],
  by = c("yos", "class"),
  suffixes = c("_converted", "_legacy")
)
print(comparison)

# Test 2: amortization adapter
cat('\n\n2. Testing convert_amortization_to_legacy():\n')
cat('   Input (better structure - first 5 rows):\n')
print(head(frs$params_env$amortization_bases, 5))

converted_amort <- convert_amortization_to_legacy(frs$params_env$amortization_bases)

cat('\n   Output (legacy format - first 5 rows):\n')
print(head(converted_amort, 5))

cat('\n   Comparison summary:\n')
cat('      Converted rows:', nrow(converted_amort), '\n')
cat('      Better structure rows:', nrow(frs$params_env$amortization_bases), '\n')
cat('      Schemas match:', identical(names(converted_amort), c("class", "date", "amo_period", "amo_balance")), '\n')

cat('\n=== ADAPTER TESTS COMPLETE ===\n')
