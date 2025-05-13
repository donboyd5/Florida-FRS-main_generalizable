# Stacked salary and count tables -----------------------------------------


# 1).Salary and headcount ----------------------------------------------------

salary_list <- list(
  regular = regular_salary_table_,
  special = special_salary_table_,
  admin   = admin_salary_table_,
  eco     = eco_salary_table_,
  eso     = eso_salary_table_,
  judges  = judges_salary_table_,
  senior  = senior_management_salary_table_
)

headcount_list <- list(
  regular = regular_headcount_table_,
  special = special_headcount_table_,
  admin   = admin_headcount_table_,
  eco     = eco_headcount_table_,
  eso     = eso_headcount_table_,
  judges  = judges_headcount_table_,
  senior  = senior_management_headcount_table_
)

salary_table_ <- map2_df(salary_list,
                         names(salary_list),
                         ~ .x %>%
                           mutate(class = .y)) %>%
  pivot_longer(
    cols = -c(class, age),
    names_to = "yos",
    values_to = "salary"
  ) %>%
  mutate(yos = as.numeric(yos))

headcount_table_ <- map2_df(headcount_list,
                            names(headcount_list),
                            ~ .x %>%
                              mutate(class = .y)) %>%
  pivot_longer(
    cols = -c(class, age),
    names_to = "yos",
    values_to = "count"
  ) %>%
  mutate(yos = as.numeric(yos))

salary_headcount_list <- list(
  regular            = regular_salary_headcount_table,
  special            = special_salary_headcount_table,
  admin              = admin_salary_headcount_table,
  eco                = eco_salary_headcount_table,
  eso                = eso_salary_headcount_table,
  judges             = judges_salary_headcount_table,
  senior_management  = senior_management_salary_headcount_table
)

salary_headcount_table <- map2_df(
  salary_headcount_list,
  names(salary_headcount_list),
  ~ .x %>% mutate(class = .y)
)

# 2).Separation tables ------------------------------------

male_list <- list(
  regular = regular_term_rate_male_table_,
  special = special_term_rate_male_table_,
  admin   = admin_term_rate_male_table_,
  eco     = eco_term_rate_male_table_,
  eso     = eso_term_rate_male_table_,
  judges  = judges_term_rate_male_table_,
  senior  = senior_management_term_rate_male_table_
)

female_list <- list(
  regular = regular_term_rate_female_table_,
  special = special_term_rate_female_table_,
  admin   = admin_term_rate_female_table_,
  eco     = eco_term_rate_female_table_,
  eso     = eso_term_rate_female_table_,
  judges  = judges_term_rate_female_table_,
  senior  = senior_management_term_rate_female_table_
)

term_rate_male_table_ <- map2_df(male_list,
                                 names(male_list),
                                 ~ .x %>%
                                   mutate(class = .y, gender = "male")) %>%
  pivot_longer(
    cols = -c(class, yos, gender),
    names_to = "age",
    values_to = "rate"
  )

term_rate_female_table_ <- map2_df(female_list,
                                   names(female_list),
                                   ~ .x %>%
                                     mutate(class = .y, gender = "female")) %>%
  pivot_longer(
    cols = -c(class, yos, gender),
    names_to = "age",
    values_to = "rate"
  )

term_rate_ <- bind_rows(term_rate_male_table_, term_rate_female_table_)

term_rate_age <- term_rate_ %>%
  mutate(age = case_when(
    age == "25_to_29" ~ list(25:29),
    age == "30_to_34" ~ list(30:34),
    age == "35_to_44" ~ list(35:44),
    age == "45_to_54" ~ list(45:54),
    age == "over_55" ~ list(55:100)  # Assuming 100 as an upper bound
  )) %>%
  unnest(age)  # Expand age ranges into individual rows

mort_list <- list(
  regular            = regular_mort_table,
  special            = special_mort_table,
  admin              = admin_mort_table,
  eco                = eco_mort_table,
  eso                = eso_mort_table,
  judges             = judges_mort_table,
  senior_management  = senior_management_mort_table
)

mort_table <- map2_df(mort_list, names(mort_list), ~ .x %>% mutate(class = .y))


# 3) Entrant Profile -------------------------------------------
entrant_profile_list <- list(
  regular            = regular_entrant_profile_table,
  special            = special_entrant_profile_table,
  admin              = admin_entrant_profile_table,
  eco                = eco_entrant_profile_table,
  eso                = eso_entrant_profile_table,
  judges             = judges_entrant_profile_table,
  senior_management  = senior_management_entrant_profile_table
)

entrant_profile_table <- map2_df(
  entrant_profile_list,
  names(entrant_profile_list),
  ~ .x %>% mutate(class = .y)
)


# 4) Mortality Tables (Retirees) --------------------------------
mort_retire_list <- list(
  regular            = regular_mort_retire_table,
  special            = special_mort_retire_table,
  admin              = admin_mort_retire_table,
  eco                = eco_mort_retire_table,
  eso                = eso_mort_retire_table,
  judges             = judges_mort_retire_table,
  senior_management  = senior_management_mort_retire_table
)

mort_retire_table <- map2_df(mort_retire_list,
                             names(mort_retire_list),
                             ~ .x %>% mutate(class = .y))


# 5) Normal Retirement Rate ----------------------------
normal_retire_rate_tier_1_list <- list(
  regular            = regular_normal_retire_rate_tier_1_table,
  special            = special_normal_retire_rate_tier_1_table,
  admin              = admin_normal_retire_rate_tier_1_table,
  eco                = eco_normal_retire_rate_tier_1_table,
  eso                = eso_normal_retire_rate_tier_1_table,
  judges             = judges_normal_retire_rate_tier_1_table,
  senior_management  = senior_management_normal_retire_rate_tier_1_table
)

normal_retire_rate_tier_1_table <- map2_df(
  normal_retire_rate_tier_1_list,
  names(normal_retire_rate_tier_1_list),
  ~ .x %>% mutate(class = .y)
)

normal_retire_rate_tier_2_list <- list(
  regular            = regular_normal_retire_rate_tier_2_table,
  special            = special_normal_retire_rate_tier_2_table,
  admin              = admin_normal_retire_rate_tier_2_table,
  eco                = eco_normal_retire_rate_tier_2_table,
  eso                = eso_normal_retire_rate_tier_2_table,
  judges             = judges_normal_retire_rate_tier_2_table,
  senior_management  = senior_management_normal_retire_rate_tier_2_table
)

normal_retire_rate_tier_2_table <- map2_df(
  normal_retire_rate_tier_2_list,
  names(normal_retire_rate_tier_2_list),
  ~ .x %>% mutate(class = .y)
)

normal_retire_rate_table <- bind_rows(
  normal_retire_rate_tier_1_table %>% mutate(tier = "tier_1"),
  normal_retire_rate_tier_2_table %>% mutate(tier = "tier_2")
)

# 6) Early Retirement Rate -----------------------------
early_retire_rate_tier_1_list <- list(
  regular            = regular_early_retire_rate_tier_1_table,
  special            = special_early_retire_rate_tier_1_table,
  admin              = admin_early_retire_rate_tier_1_table,
  eco                = eco_early_retire_rate_tier_1_table,
  eso                = eso_early_retire_rate_tier_1_table,
  judges             = judges_early_retire_rate_tier_1_table,
  senior_management  = senior_management_early_retire_rate_tier_1_table
)

early_retire_rate_tier_1_table <- map2_df(
  early_retire_rate_tier_1_list,
  names(early_retire_rate_tier_1_list),
  ~ .x %>% mutate(class = .y)
)

early_retire_rate_tier_2_list <- list(
  regular            = regular_early_retire_rate_tier_2_table,
  special            = special_early_retire_rate_tier_2_table,
  admin              = admin_early_retire_rate_tier_2_table,
  eco                = eco_early_retire_rate_tier_2_table,
  eso                = eso_early_retire_rate_tier_2_table,
  judges             = judges_early_retire_rate_tier_2_table,
  senior_management  = senior_management_early_retire_rate_tier_2_table
)

early_retire_rate_tier_2_table <- map2_df(
  early_retire_rate_tier_2_list,
  names(early_retire_rate_tier_2_list),
  ~ .x %>% mutate(class = .y)
)


early_retire_rate_table <- bind_rows(
  early_retire_rate_tier_1_table %>% mutate(tier = "tier_1"),
  early_retire_rate_tier_2_table %>% mutate(tier = "tier_2")
)

# 7) Separation Rate Tables --------------------------------------
separation_rate_list <- list(
  regular            = regular_separation_rate_table,
  special            = special_separation_rate_table,
  admin              = admin_separation_rate_table,
  eco                = eco_separation_rate_table,
  eso                = eso_separation_rate_table,
  judges             = judges_separation_rate_table,
  senior_management  = senior_management_separation_rate_table
)

separation_rate_table <- map2_df(
  separation_rate_list,
  names(separation_rate_list),
  ~ .x %>% mutate(class = .y)
)

# 8) Salary growth rate table -------------------------------------

salary_growth_table <- frs_data_env$salary_growth_table_original_ %>%
  bind_rows(tibble(yos = (max(frs_data_env$salary_growth_table_original_$yos) + 1):max(frs_data_env$yos_range_))) %>%
  fill(everything(), .direction = "down") %>%
  mutate(
    across(contains("salary"), ~ cumprod(1 + lag(.x, default = 0)), .names = "cumprod_{.col}"),
    .keep = "unused"
  ) %>%
  pivot_longer(
    cols = contains("cumprod"),
    names_to = "class",
    names_prefix = "cumprod_salary_increase_",
    values_to = "cumprod_salary_increase"
  ) %>%
  mutate(
    class = case_when(
      class == "special_risk" ~ "special",
      TRUE ~ class
    )
  )

class_salary_growth_table <- salary_growth_table   #temporary for now

# 9) list all the tables
# List of all tables to analyze
tables_list <- list(
  salary_headcount_table = salary_headcount_table,
  entrant_profile_table = entrant_profile_table,
  mort_table = mort_table,
  mort_retire_table = mort_retire_table,
  normal_retire_rate_table = normal_retire_rate_table,
  early_retire_rate_table = early_retire_rate_table,
  separation_rate_table = separation_rate_table,
  salary_growth_table = salary_growth_table
)

# Function to get table dimensions and numeric variable ranges
summarize_table <- function(df, table_name) {
  num_rows <- nrow(df)
  num_cols <- ncol(df)
  numeric_cols <- df %>% select(where(is.numeric)) 
  num_ranges <- map_df(numeric_cols, ~ data.frame(
    min = min(.x, na.rm = TRUE),
    max = max(.x, na.rm = TRUE)
  ), .id = "variable")
  summary_df <- tibble(
    table = table_name,
    num_rows = num_rows,
    num_cols = num_cols
  ) %>%
    bind_cols(num_ranges)
  return(summary_df)
}

# Apply function to all tables and combine results
table_summaries <- map2_df(tables_list, names(tables_list), summarize_table)

# Print the results
table_summaries %>%
  gt() %>%
  fmt_number(
    columns = c(min, max),
    decimals = 0,  # Default to two decimal places
    use_seps = FALSE
  ) %>%
  fmt_number(
    columns = c(num_rows),
    decimals = 0,  # Default to two decimal places
    use_seps = TRUE
  ) 


# summarize dimensions ----------------------------------------------------
summarize_dimensions <- function(df, table_name) {
  df %>%
    summarize(
      table = table_name,
      unique_class = if ("class" %in% colnames(df)) n_distinct(class, na.rm = TRUE) else NA,
      unique_age = if ("age" %in% colnames(df)) n_distinct(age, na.rm = TRUE) else NA,
      unique_yos = if ("yos" %in% colnames(df)) n_distinct(yos, na.rm = TRUE) else NA,
      unique_entry_year = if ("entry_year" %in% colnames(df)) n_distinct(entry_year, na.rm = TRUE) else NA,
      unique_entry_age = if ("entry_age" %in% colnames(df)) n_distinct(entry_age, na.rm = TRUE) else NA,
      unique_dist_year = if ("dist_year" %in% colnames(df)) n_distinct(dist_year, na.rm = TRUE) else NA,
      unique_dist_age = if ("dist_age" %in% colnames(df)) n_distinct(dist_age, na.rm = TRUE) else NA,
      unique_term_year = if ("term_year" %in% colnames(df)) n_distinct(term_year, na.rm = TRUE) else NA,
      unique_base_age = if ("base_age" %in% colnames(df)) n_distinct(base_age, na.rm = TRUE) else NA,
      unique_year = if ("year" %in% colnames(df)) n_distinct(year, na.rm = TRUE) else NA,
      unique_term_age = if ("term_age" %in% colnames(df)) n_distinct(term_age, na.rm = TRUE) else NA,
      num_rows = n()
    )
}

# Apply function to all tables and combine results
dimensions_summary <- map2_df(tables_list, names(tables_list), summarize_dimensions)

# Display results using gt()
dimensions_table <- dimensions_summary %>%
  mutate(
    product_all_dims = apply(select(., starts_with("unique_")), 1, function(x) prod(x, na.rm = TRUE))) %>%
  gt() %>%
  cols_label(
    table = "Table Name",
    unique_class = "Employee Classes",
    unique_age = "Age Values",
    unique_yos = "YOS Values",
    unique_entry_year = "Entry Years",
    unique_entry_age = "Entry Ages",
    unique_dist_year = "Distribution Years",
    unique_dist_age = "Distribution Ages",
    unique_term_year = "Termination Years",
    unique_base_age = "Base Ages",
    unique_year = "Years",
    unique_term_age = "Termination Ages",
    num_rows = "Total Rows"
  ) %>%
  sub_missing(columns = everything(), missing_text = "") %>%
  fmt_number(
    columns = c(product_all_dims),
    decimals = 0,  # Default to two decimal places
    use_seps = TRUE
  ) 

dimensions_table
