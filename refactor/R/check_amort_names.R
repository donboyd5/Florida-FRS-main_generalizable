load('D:/R_projects/pendata/data/frs.rda')
cat('current_amort_layers_table_ exists:', 'current_amort_layers_table_' %in% names(frs$params_env), '\n')
cat('amortization_bases exists:', 'amortization_bases' %in% names(frs$params_env), '\n')
cat('current_amort_layers_table exists:', 'current_amort_layers_table' %in% names(frs$params_env), '\n')
