# Salary & Headcount Processing -------------------------------------------

get_salary_headcount_table <- function(class_name,
                                       params)
{
  
  # djb TEMPORARY until we have stacked data: get params values for the class
  salary_table <- params[[paste0(class_name, "_salary_table_")]]
  headcount_table <- params[[paste0(class_name, "_headcount_table_")]]
  
  # salary_table <- salary_table_
  # headcount_table <- headcount_table_
  
  # if (class_name %in% c("eco", "eso", "judges")) {
  #   total_active_member <- params$eco_eso_judges_total_active_member_
  # } else {
  #   total_active_member <- params[[paste0(class_name, "_total_active_member_")]]
  # }
  
  if (class_name %in% c("eco", "eso", "judges")) {
    total_active_member <- params$eco_eso_judges_total_active_member_
  } else {
    total_active_member <- params[[paste0(class_name, "_total_active_member_")]]
  }
  
  salary_growth_table <- params$salary_growth_table_ %>% # one table for all classes
    select(yos, contains(class_name)) %>% 
    rename(cumprod_salary_increase = 2)
  
  salary_table_long <- salary_table %>% 
    pivot_longer(cols = -1, names_to = "yos", values_to = "salary")
  
  headcount_table_long <- headcount_table %>% 
    pivot_longer(cols = -1, names_to = "yos", values_to = "count") %>% 
    mutate(
      active_member_adjustment_ratio = if_else(str_detect(class_name, "eco|eso|judges"),
                                               params$eco_eso_judges_active_member_adjustment_ratio, 
                                               total_active_member / sum(count, na.rm = TRUE)),
      count = count * active_member_adjustment_ratio
    ) %>% 
    select(-active_member_adjustment_ratio)
  
  salary_headcount_table <- salary_table_long %>% 
    left_join(headcount_table_long,
              by = join_by(age, yos)) %>% 
    mutate(
      yos = as.numeric(yos),
      start_year = params$start_year_,
      entry_age = age - yos,
      entry_year = start_year - yos) %>% 
    filter(!is.na(salary), entry_age >= 18) %>% 
    left_join(salary_growth_table,
              by = join_by(yos)) %>% 
    mutate(entry_salary = salary / cumprod_salary_increase) %>% 
    select(entry_year, entry_age, age, yos, count, entry_salary)
  
  entrant_profile <- salary_headcount_table %>% 
    filter(entry_year == max(entry_year)) %>% 
    mutate(entrant_dist = count/sum(count)) %>% 
    select(entry_age, entry_salary, entrant_dist) %>% 
    rename(start_sal = entry_salary)
  
  output <- list(
    salary_headcount_table = salary_headcount_table, 
    entrant_profile = entrant_profile)
  
  return(output)
}


# Retirement & Separation Conditions --------------------------------------

#Current two tiers:
## Members joining before July 1, 2011 (tier 1)
## Members joining after July 1, 2011 (tier 2)

#tier 3: for new hires joining as of new_year_

get_tier <- function(class_name, entry_year, age, yos, new_year){
  tier = if_else(entry_year < 2011,
                 case_when(
                   class_name %in% c("special", "admin") & (yos >= 25 | (age >= 55 & yos >= 6) | (age >= 52 & yos >= 25)) ~ "tier_1_norm",
                   yos >= 30 | (age >= 62 & yos >= 6) ~ "tier_1_norm",
                   class_name %in% c("special", "admin") & (yos >= 6 & age >= 53) ~ "tier_1_early",
                   (yos >= 6 & age >= 58) ~ "tier_1_early",
                   yos >= 6 ~ "tier_1_vested",
                   .default = "tier_1_non_vested"
                 ),
                 if_else(entry_year < new_year,
                         case_when(
                           class_name %in% c("special", "admin") & (yos >= 30 | (age >= 60 & yos >= 8)) ~ "tier_2_norm",
                           yos >= 33 | (age >= 65 & yos >= 8) ~ "tier_2_norm",
                           class_name %in% c("special", "admin") & (yos >= 8 & age >= 56) ~ "tier_2_early",
                           (yos >= 8 & age >= 61) ~ "tier_2_early",
                           yos >= 8 ~ "tier_2_vested",
                           .default = "tier_2_non_vested"
                         ),
                         case_when(
                           class_name %in% c("special", "admin") & (yos >= 30 | (age >= 60 & yos >= 8)) ~ "tier_3_norm",
                           yos >= 33 | (age >= 65 & yos >= 8) ~ "tier_3_norm",
                           class_name %in% c("special", "admin") & (yos >= 8 & age >= 56) ~ "tier_3_early",
                           (yos >= 8 & age >= 61) ~ "tier_3_early",
                           yos >= 8 ~ "tier_3_vested",
                           .default = "tier_3_non_vested"
                         )))
  return(tier)
}


# Create tier table -------------------------------------------------------
unique_classes <- c("regular", "special", "admin", "eco", "eso", "judges", "senior_management")
model_period_ <- 30     #Projection period (typically 30 years)
min_age_ <- 18          #Age of the typical youngest member
max_age_ <- 120         #Max age from mortality assumptions
start_year_ <- 2022     #Year of the latest val report (update this when a new val report comes out)
new_year_ <- 2024       #Year for new entrants with a new tier to join (update this when a new val report comes out)
min_year_ <- 1970       #No hard rule about this. Should get back to about 40 years from now.   
max_year_ <- start_year_ + model_period_ + max_age_ - min_age_
entry_year_range_ <- min_year_:(start_year_ + model_period_)
# RetYear <- MinYear:(YearStart + ModelPeriod)
year_range_ <- min_year_:max_year_
age_range_ <- min_age_:max_age_
yos_range_ <- 0:70

tier_table <- expand.grid(class = unique_classes, entry_year = entry_year_range_, yos = yos_range_, age = age_range_, new_year = new_year_) %>%
  mutate(
    tier = case_when(
      entry_year < 2011 & (
        (class %in% c("special", "admin") & (yos >= 25 | (age >= 55 & yos >= 6) | (age >= 52 & yos >= 25))) |
          (yos >= 30 | (age >= 62 & yos >= 6))
      ) ~ "tier_1_norm",
      entry_year < 2011 & (
        (class %in% c("special", "admin") & (yos >= 6 & age >= 53)) |
          (yos >= 6 & age >= 58)
      ) ~ "tier_1_early",
      entry_year < 2011 & (yos >= 6) ~ "tier_1_vested",
      entry_year < 2011 ~ "tier_1_non_vested",
      
      entry_year < new_year & (
        (class %in% c("special", "admin") & (yos >= 30 | (age >= 60 & yos >= 8))) |
          (yos >= 33 | (age >= 65 & yos >= 8))
      ) ~ "tier_2_norm",
      entry_year < new_year & (
        (class %in% c("special", "admin") & (yos >= 8 & age >= 56)) |
          (yos >= 8 & age >= 61)
      ) ~ "tier_2_early",
      entry_year < new_year & (yos >= 8) ~ "tier_2_vested",
      entry_year < new_year ~ "tier_2_non_vested",
      
      (class %in% c("special", "admin") & (yos >= 30 | (age >= 60 & yos >= 8))) |
        (yos >= 33 | (age >= 65 & yos >= 8)) ~ "tier_3_norm",
      (class %in% c("special", "admin") & (yos >= 8 & age >= 56)) |
        (yos >= 8 & age >= 61) ~ "tier_3_early",
      yos >= 8 ~ "tier_3_vested",
      TRUE ~ "tier_3_non_vested"
    )
  )

# Display the table
print(tier_table)

# test the new table is equivalent to the get_tier function
random_sample <- tier_table |>  
  slice_sample(n = 10) %>%
  rowwise() %>%
  mutate(calculated_tier = get_tier(class, entry_year, age, yos, new_year)) %>%
  ungroup()

print(random_sample)


#Separation type function
get_sep_type <- function(tier) {
  sep_type <- case_when(
    str_detect(tier, "early|norm|reduced") ~ "retire",
    str_detect(tier, "non_vested") ~ "non_vested",
    str_detect(tier, "vested") ~ "vested"
  )
}


# Mortality Assumptions ---------------------------------------------------

#Clean up mortality table
get_base_mort_table <- function(raw_mort_table){
  base_mort_table <- raw_mort_table %>% 
    #remove the first three rows and then remove empty columns
    slice(-(1:3)) %>% 
    remove_empty() %>% 
    #elevate first row to become col names, then clean col names
    row_to_names(row_number = 1) %>% 
    clean_names() %>% 
    select(-na) %>% 
    #rename columns to differentiate female and male rates
    rename_with(.fn = ~ paste0(.x, "_female"),
                .cols = !(ends_with("2") | contains("age"))) %>% 
    rename_with(.fn = ~ paste0(str_replace(.x, "2", ""), "male"),
                .cols = ends_with("2")) %>% 
    #turn data into numeric 
    mutate(across(everything(), ~ as.numeric(.x)),
           employee_female = if_else(is.na(employee_female),
                                     healthy_retiree_female, 
                                     employee_female),
           employee_male = if_else(is.na(employee_male), 
                                   healthy_retiree_male, 
                                   employee_male),
           healthy_retiree_female = if_else(is.na(healthy_retiree_female),
                                            employee_female, 
                                            healthy_retiree_female),
           healthy_retiree_male = if_else(is.na(healthy_retiree_male), 
                                          employee_male,
                                          healthy_retiree_male))
  return(base_mort_table)
}


#Clean up mortality improvement (MP) tables
clean_mp_table <- function(raw_mp_table, extend_2_yrs = FALSE){
  mp_table <- raw_mp_table %>%
    row_to_names(row_number = 1) %>% 
    rename(age = 1) %>%
    rename_with(.fn = ~ str_replace(.x, "\\+", ""),
                .col = ends_with("+")) %>% 
    mutate(age = replace(age, age == "≤ 20", 20)) %>% 
    mutate(across(everything(), ~ as.numeric(.x))) 
  
  if (extend_2_yrs == TRUE){
    mp_table <- mp_table %>% 
      add_row(age=19, .before = 1) %>% 
      add_row(age=18, .before = 1) %>% 
      fill(everything(), .direction = "up")
  }
  
  return(mp_table)
}



#Modify mortality improvement rates
#base_year is the year when the base mort rate is given. It's 2010 in this case
get_mp_final_table <- function(mp_table, gender, base_year, age_range, year_range){
  mp_table <- mp_table %>% 
    pivot_longer(-age, names_to = "year", values_to = "mp") %>% 
    mutate(year = as.numeric(year))
  
  mp_ultimate_table <- mp_table %>%       #ultimate rates = rates for the last year in the MP table
    filter(year == max(year)) %>% 
    rename(mp_ultimate = mp) %>% 
    select(-year)
  
  mp_final_table <- expand_grid(age = age_range, year = min(mp_table$year):max(year_range)) %>% 
    left_join(mp_table,
              by = join_by(age, year)) %>% 
    left_join(mp_ultimate_table,
              by = join_by(age)) %>% 
    mutate(mp_final = if_else(year > max(mp_table$year), mp_ultimate, mp)) %>% 
    group_by(age) %>% 
    
    mutate(mp_cumprod_raw = cumprod(1 - mp_final),
           #The adjusted value is the ratio of the raw value and the anchor point in base year
           mp_cumprod_adj = mp_cumprod_raw / mp_cumprod_raw[year == base_year]) %>%
    ungroup() %>% 
    rename_with(.fn = ~ paste0(gender, "_", .x),
                .col = contains("mp")) %>% 
    select(age, year, contains("adj"))
  
  return(mp_final_table)
}


##Mortality calculations
get_mort_table <- function(class_name, 
                           base_mort_table, 
                           male_mp_final_table, female_mp_final_table,
                           entrant_profile,
                           entry_year_range, age_range, yos_range,
                           new_year){
  
  final_mort_table <- expand_grid(entry_year = entry_year_range, 
                                  entry_age = entrant_profile$entry_age, 
                                  dist_age = age_range, 
                                  yos = yos_range) %>% 
    mutate(
      term_year = entry_year + yos,
      dist_year = entry_year + dist_age - entry_age
    )  %>% 
    filter(term_year <= dist_year) %>% 
    arrange(entry_year, entry_age, yos, dist_age) %>% 
    left_join(base_mort_table, by = c("dist_age" = "age")) %>% 
    left_join(male_mp_final_table, by = c("dist_age" = "age", "dist_year" = "year")) %>% 
    left_join(female_mp_final_table, by = c("dist_age" = "age", "dist_year" = "year")) %>% 
    mutate(
      tier_at_dist_age = get_tier(class_name, entry_year, dist_age, yos, new_year),
      
      male_mort = if_else(str_detect(tier_at_dist_age, "vested"), employee_male,
                          healthy_retiree_male) * male_mp_cumprod_adj,
      
      female_mort = if_else(str_detect(tier_at_dist_age, "vested"), employee_female,
                            healthy_retiree_female) * female_mp_cumprod_adj,
      
      mort_final = (male_mort + female_mort)/2
    ) %>% 
    #filter out the necessary variables
    select(entry_year, entry_age, dist_year, dist_age, yos, term_year, mort_final, tier_at_dist_age)
  
  return(final_mort_table)
}


#Create a second mortality table for current retirees
# age_range_, year_range_, start_year_
get_mort_retire_table <- function(base_mort_table,
                                  male_mp_final_table, female_mp_final_table,
                                  age_range, year_range, start_year){
  
  mort_retire_table <- expand_grid(age = age_range[age_range >= 40], year = year_range[year_range >= start_year]) %>% 
    left_join(base_mort_table, by = "age") %>% 
    left_join(male_mp_final_table, by = c("age", "year")) %>% 
    left_join(female_mp_final_table, by = c("age", "year")) %>% 
    mutate(base_age = age - (year - start_year),
           male_mort = healthy_retiree_male * male_mp_cumprod_adj,
           female_mort = healthy_retiree_female * female_mp_cumprod_adj,
           mort_final = (male_mort + female_mort)/2) %>% 
    select(base_age, age, year, mort_final) %>% 
    filter(base_age >= 40) %>%
    arrange(base_age)
  
  return(mort_retire_table)
}



# Separation Assumptions --------------------------------------------------


# .. retirement rate tables -----------------------------------------------

clean_retire_rate_table <- function(df, col_names){
  
  index_of_na_row_from_bottom <- tail(which(rowSums(is.na(df)) == ncol(df)),1)
  index_of_row_before_body <- which(df[,1] == "Age")
  
  df <- df %>% 
    slice(-(index_of_na_row_from_bottom:n())) %>% 
    slice(-(1:index_of_row_before_body)) %>% 
    select_if(~any(!is.na(.)))
  
  index_of_70_79_row <- which(df[,1] == "70-79")
  
  names(df) <- col_names
  
  df <- df %>% 
    add_row(age=as.character(71:79), .after=index_of_70_79_row) %>% 
    mutate(
      age = replace(age, age == "70-79", "70"),
      across(everything(), ~as.numeric(.x))
    ) %>% 
    fill(everything(), .direction = "down")
  
  return(df)
}


get_normal_retire_rate_table <- function(class_name, drop_entry_table, normal_retire_rate_table){
  
  if (class_name %in% c("eco", "eso", "judge")) {
    search_text_in_drop_entry_table = "other"
    search_text_in_normal_retire_table = "eco_eso_jud"
  } else if (class_name == "senior_management") {
    search_text_in_drop_entry_table = "other"
    search_text_in_normal_retire_table = "senior_management"
  } else if (class_name == "admin"){
    search_text_in_drop_entry_table = search_text_in_normal_retire_table = "special"
  } else {
    search_text_in_drop_entry_table = search_text_in_normal_retire_table = class_name
  }
  
  normal_retire_rate_table <- (drop_entry_table %>% select(contains(search_text_in_drop_entry_table)) + 
                                 normal_retire_rate_table %>% select(contains(search_text_in_normal_retire_table))) %>% 
    add_column(age = drop_entry_table$age, .before = 1) %>% 
    rowwise() %>% 
    mutate(normal_retire_rate = mean(c_across(-age)), .keep = "unused") %>% 
    ungroup()
  
  return(normal_retire_rate_table)
}


# ..early retirement rate tables ------------------------------------------

get_early_retire_rate_table <- function(class_name, init_early_retire_rate_table){
  if (class_name %in% c("eco", "eso", "judge")) {
    search_text = "eco_eso_jud"
  } else if (class_name == "senior_management") {
    search_text = "senior_management"
  } else if (class_name == "admin"){
    search_text = "special"
  } else {
    search_text = class_name
  }
  
  final_early_retire_rate_table <- init_early_retire_rate_table %>% 
    select(age, contains(search_text)) %>% 
    rowwise() %>% 
    mutate(early_retire_rate = mean(c_across(-age)), .keep = "unused") %>% 
    ungroup()
  
  return(final_early_retire_rate_table)
}


#.. separation tables ---------------------------------------------------------

get_separation_table <- function(class_name,
                                 entrant_profile_table_list,
                                 term_rate_male_table_list,
                                 term_rate_female_table_list,
                                 normal_retire_rate_tier_1_table_list,
                                 normal_retire_rate_tier_2_table_list,
                                 early_retire_rate_tier_1_table_list,
                                 early_retire_rate_tier_2_table_list,
                                 params){
  
  element_name <- paste0(class_name, "_entrant_profile_table")
  entrant_profile_table <- entrant_profile_table_list[[element_name]]
  
  element_name <- paste0(class_name, "_term_rate_male_table_")
  term_rate_male_table <- term_rate_male_table_list[[element_name]]  
  
  element_name <- paste0(class_name, "_term_rate_female_table_")
  term_rate_female_table <- term_rate_female_table_list[[element_name]]  
  
  normal_retire_rate_tier_1_table <- normal_retire_rate_tier_1_table_list[[paste0(class_name, "_normal_retire_rate_tier_1_table")]]
  normal_retire_rate_tier_2_table <- normal_retire_rate_tier_2_table_list[[paste0(class_name, "_normal_retire_rate_tier_2_table")]]
  
  early_retire_rate_tier_1_table <- early_retire_rate_tier_1_table_list[[paste0(class_name, "_early_retire_rate_tier_1_table")]]
  early_retire_rate_tier_2_table <- early_retire_rate_tier_2_table_list[[paste0(class_name, "_early_retire_rate_tier_2_table")]]
  
  # end of initialization ---
  
  term_rate_table <- ((term_rate_male_table + term_rate_female_table) / 2) %>% 
    add_row(yos = (max(term_rate_male_table$yos) + 1):max(params$yos_range_)) %>% 
    fill(everything(), .direction="down")
  
  breaks <- c(-Inf, 24, 29, 34, 44, 54, Inf)
  labels <- names(term_rate_table)[-1]
  
  long_term_rate_table <- pivot_longer(term_rate_table, cols = -yos, names_to = "age_group", values_to = "term_rate")
  
  separation_rate_table <- expand_grid(entry_year = params$entry_year_range_,
                                       term_age = params$age_range_, 
                                       yos = params$yos_range_) %>% 
    mutate(
      entry_age = term_age  - yos,
      term_year = entry_year + yos,
      age_group = cut(term_age, breaks, labels)
    ) %>% 
    filter(entry_age %in% entrant_profile_table$entry_age) %>% 
    arrange(entry_year, entry_age, term_age) %>% 
    left_join(long_term_rate_table,
              by = join_by(yos, age_group)) %>% 
    left_join(normal_retire_rate_tier_1_table %>% rename(normal_retire_rate_tier_1 = normal_retire_rate), by = c("term_age" = "age")) %>% 
    left_join(normal_retire_rate_tier_2_table %>% rename(normal_retire_rate_tier_2 = normal_retire_rate), by = c("term_age" = "age")) %>% 
    left_join(early_retire_rate_tier_1_table %>% rename(early_retire_rate_tier_1 = early_retire_rate), by = c("term_age" = "age")) %>% 
    left_join(early_retire_rate_tier_2_table %>% rename(early_retire_rate_tier_2 = early_retire_rate), by = c("term_age" = "age")) %>% 
    group_by(entry_year, entry_age) %>% 
    fill(contains("retire_rate"), .direction="downup") %>% 
    ungroup() %>% 
    mutate(
      tier_at_term_age = get_tier(class_name, entry_year, term_age, yos, params$new_year_),
      separation_rate = case_when(
        tier_at_term_age %in% c("tier_3_norm", "tier_2_norm") ~ normal_retire_rate_tier_2,
        tier_at_term_age %in% c("tier_3_early", "tier_2_early") ~ early_retire_rate_tier_2,
        tier_at_term_age == "tier_1_norm" ~ normal_retire_rate_tier_1,
        tier_at_term_age == "tier_1_early" ~ early_retire_rate_tier_1,
        str_detect(tier_at_term_age, "vested") ~ term_rate
      )
    ) %>% 
    group_by(entry_year, entry_age) %>% 
    mutate(
      remaining_prob = cumprod(1 - lag(separation_rate, default=0)),
      separation_prob = lag(remaining_prob, default = 1) - remaining_prob
    ) %>% 
    ungroup() %>% 
    select(entry_year, entry_age, term_age, yos, term_year, separation_rate, remaining_prob, separation_prob)
  
  return(separation_rate_table)
}

