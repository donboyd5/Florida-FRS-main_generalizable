library(dplyr)
library(purrr)

# 1) Create a named list of data frames in the desired order
df_list <- list(
  regular = regular_separation_rate_table,
  special = special_separation_rate_table,
  admin   = admin_separation_rate_table,
  eco     = eco_separation_rate_table,
  eso     = eso_separation_rate_table,
  judges  = judges_separation_rate_table,
  senior  = senior_management_separation_rate_table
)

# 2) Combine them into one long data frame, adding a column "employee_class"
long_separation_rates <- map2_df(df_list, names(df_list), ~ .x %>%
                                   mutate(employee_class = .y))

# 3) Inspect the result
head(long_separation_rates)
count(long_separation_rates, employee_class)
