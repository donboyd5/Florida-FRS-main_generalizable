# Explore pendata frs object
load('D:/R_projects/pendata/data/frs.rda')

cat('Total objects in params_env:', length(names(frs$params_env)), '\n\n')

cat('=== ALL OBJECTS (sorted) ===\n')
all_names <- names(frs$params_env) |> sort()
cat(all_names, sep='\n')

cat('\n\n=== OBJECTS CONTAINING "better" PATTERNS ===\n')
# Look for better structure names
better_patterns <- c('headcount_salary', 'benefit_rules', 'constants_assumptions',
                     'salarygrowth', 'withdrawal', 'retirees', 'amortization')

for (pattern in better_patterns) {
  matches <- grep(pattern, all_names, value = TRUE, ignore.case = TRUE)
  if (length(matches) > 0) {
    cat('\n', pattern, ':\n', sep='')
    cat('  ', matches, sep='\n  ')
  }
}

cat('\n\n=== CHECK FOR GAP TABLES ===\n')
gap_patterns <- c('mortality', 'mort_', 'retire_rate', 'retirement_rate',
                  'return_scenario', 'db_dc_')

for (pattern in gap_patterns) {
  matches <- grep(pattern, all_names, value = TRUE, ignore.case = TRUE)
  if (length(matches) > 0) {
    cat('\n', pattern, ':\n', sep='')
    cat('  ', matches, sep='\n  ')
  }
}
