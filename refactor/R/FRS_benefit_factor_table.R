library(dplyr)
library(tidyr)
library(stringr)
library(tidyverse)

# Define example values
class_names <- params$class_names_no_drop_frs_
tiers <- unique(frs_data_env$tier_table$tier)
ages <- 40:80
yos <- params$yos_range_
dist_year <- 2020

# Create all combinations
ben_table <- expand.grid(class_name = class_names,
  tier_at_dist_age = tiers,
  dist_age = ages,
  yos = yos,
  dist_year = dist_year,
  stringsAsFactors = FALSE) %>%
  mutate(
    ben_mult = if_else(str_detect(tier_at_dist_age, "tier_1"),
                       if_else(class_name == "regular", 
                               case_when(
                                 (dist_age >= 65 & yos >= 6) | (yos >= 33) ~ 0.0168,
                                 (dist_age >= 64 & yos >= 6) | (yos >= 32) ~ 0.0165,
                                 (dist_age >= 63 & yos >= 6) | (yos >= 31) ~ 0.0163,
                                 (dist_age >= 62 & yos >= 6) | (yos >= 30) ~ 0.0160,
                                 str_detect(tier_at_dist_age, "early") ~ 0.0160
                               ),
                               if_else(class_name == "special", if_else(dist_year <= 1974, 0.02, 0.03),
                                       if_else(class_name == "admin", 
                                               case_when(
                                                 (dist_age >= 58 & yos >= 6) | (yos >= 28) ~ 0.0168,
                                                 (dist_age >= 57 & yos >= 6) | (yos >= 27) ~ 0.0165,
                                                 (dist_age >= 56 & yos >= 6) | (yos >= 26) ~ 0.0163,
                                                 (dist_age >= 55 & yos >= 6) | (yos >= 25) ~ 0.0160,
                                                 str_detect(tier_at_dist_age, "early") ~ 0.0160
                                               ),
                                               if_else(class_name %in% c("eco", "eso"), 0.03,
                                                       if_else(class_name == "judges", 0.0333, if_else(class_name == "senior_management", 0.02, NA)
                                                       )
                                               )
                                       )
                               )
                       ),
                       if_else(str_detect(tier_at_dist_age, "tier_2"),
                               if_else(class_name == "regular",
                                       case_when(
                                         (dist_age >= 68 & yos >= 8) | (yos >= 36) ~ 0.0168,
                                         (dist_age >= 67 & yos >= 8) | (yos >= 35) ~ 0.0165,
                                         (dist_age >= 66 & yos >= 8) | (yos >= 34) ~ 0.0163,
                                         (dist_age >= 65 & yos >= 8) | (yos >= 33) ~ 0.0160,
                                         str_detect(tier_at_dist_age, "early") ~ 0.0160
                                       ),
                                       if_else(class_name == "special", if_else(dist_year <= 1974, 0.02, 0.03),
                                               if_else(class_name == "admin",
                                                       case_when(
                                                         (dist_age >= 63 & yos >= 8) | (yos >= 33) ~ 0.0168,
                                                         (dist_age >= 62 & yos >= 8) | (yos >= 32) ~ 0.0165,
                                                         (dist_age >= 61 & yos >= 8) | (yos >= 31) ~ 0.0163,
                                                         (dist_age >= 60 & yos >= 8) | (yos >= 30) ~ 0.0160,
                                                         str_detect(tier_at_dist_age, "early") ~ 0.0160
                                                       ),
                                                       if_else(class_name %in% c("eco", "eso"), 0.03,
                                                               if_else(class_name == "judges", 0.0333, if_else(class_name == "senior_management", 0.02, NA)
                                                               )
                                                       )
                                               )
                                       )
                               ),
                               if_else(str_detect(tier_at_dist_age, "tier_3"),
                                       if_else(class_name == "regular",
                                               case_when(
                                                 (dist_age >= 68 & yos >= 8) | (yos >= 36) ~ 0.0168,
                                                 (dist_age >= 67 & yos >= 8) | (yos >= 35) ~ 0.0165,
                                                 (dist_age >= 66 & yos >= 8) | (yos >= 34) ~ 0.0163,
                                                 (dist_age >= 65 & yos >= 8) | (yos >= 33) ~ 0.0160,
                                                 str_detect(tier_at_dist_age, "early") ~ 0.0160
                                               ),
                                               if_else(class_name == "special", if_else(dist_year <= 1974, 0.02, 0.03),
                                                       if_else(class_name == "admin",
                                                               case_when(
                                                                 dist_age >= 63 & yos >= 8 ~ 0.0168,
                                                                 dist_age >= 62 & yos >= 8 ~ 0.0165,
                                                                 dist_age >= 61 & yos >= 8 ~ 0.0163,
                                                                 dist_age >= 60 & yos >= 8 ~ 0.0160,
                                                                 str_detect(tier_at_dist_age, "early") ~ 0.0160
                                                               ),
                                                               if_else(class_name %in% c("eco", "eso"), 0.03,
                                                                       if_else(class_name == "judges", 0.0333, if_else(class_name == "senior_management", 0.02, NA)
                                                                       )
                                                               )
                                                       )
                                               )
                                       ), NA)
                       )
    )
  )
    
    # View sample
ben_table %>% 
  slice_sample(n = 10)
    
    
reduce_factor_table <- expand.grid(
      class_name = class_names,
      tier_at_dist_age = tiers,
      dist_age = ages,
      stringsAsFactors = FALSE
    ) %>%
      mutate(
       reduce_factor = if_else(str_detect(tier_at_dist_age, "norm"), 1,
                              if_else(str_detect(tier_at_dist_age, "early"),
                                      if_else(class_name == "special",
                                              case_when(
                                                str_detect(tier_at_dist_age, "tier_1") ~ (1 - 0.05*(55 - dist_age)),
                                                str_detect(tier_at_dist_age, "tier_2") ~ (1 - 0.05*(60 - dist_age)),
                                                str_detect(tier_at_dist_age, "tier_3") ~ (1 - 0.05*(60 - dist_age))
                                              ),
                                              case_when(
                                                str_detect(tier_at_dist_age, "tier_1") ~ (1 - 0.05*(62 - dist_age)),
                                                str_detect(tier_at_dist_age, "tier_2") ~ (1 - 0.05*(65 - dist_age)),
                                                str_detect(tier_at_dist_age, "tier_3") ~ (1 - 0.05*(65 - dist_age))
                                              )
                                      ), NA
                              )
      ))
        
reduce_factor_table %>% 
  slice_sample(n = 10)
        