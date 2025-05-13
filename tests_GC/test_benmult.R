ben_mult_lookup %>% slice_sample(n = 20)

unique(ben_mult_lookup$tier_at_dist_age)


tier_vec <- c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
              "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
              "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm")

summary(ben_mult_lookup$ben_mult)
unique(ben_mult_lookup$tier_at_dist_age)

x <- ben_mult_lookup %>% 
  filter((tier_at_dist_age != "tier_1_non_vested") & (tier_at_dist_age != "tier_2_non_vested") & (tier_at_dist_age != "tier_3_non_vested")) %>% 
  select(ben_mult)

summary_stats <- c(
  Q1 = round(quantile(x, 0.25, na.rm = TRUE), 3),
  Median = round(quantile(x, 0.5, na.rm = TRUE), 3),
  Q3 = round(quantile(x, 0.75, na.rm = TRUE), 3),
  n = sum(!is.na(x)),
  na = sum(is.na(x))
)
summary_stats

# ### Test
# 
# 
# # Create benefit multiplier function --------------------------------------
# get_ben_mult <- function(tier, class_name, dist_age, dist_year, yos) {
#   tier_1 <- c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm")
#   tier_2 <- c("tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm")
#   tier_3 <- c("tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm")
#   tier_early <- c("tier_1_early", "tier_2_early", "tier_3_early")
#   
#   result <- case_when(
#     # Tier 1: Regular
#     (tier %in% tier_1) & (class_name == "regular") ~ case_when(
#       (dist_age >= 65 & yos >= 6) | yos >= 33 ~ 0.0168,
#       (dist_age >= 64 & yos >= 6) | yos >= 32 ~ 0.0165,
#       (dist_age >= 63 & yos >= 6) | yos >= 31 ~ 0.0163,
#       (dist_age >= 62 & yos >= 6) | yos >= 30 ~ 0.0160,
#       (tier %in% tier_early) ~ 0.0160,
#       TRUE ~ NA
#     ),
#     
#     # Tier 1, 2 and 3: Special
#     (tier %in% c(tier_1, tier_2, tier_3)) & (class_name == "special") ~ if_else(dist_year <= 1974, 0.02, 0.03),
#     
#     # Tier 1: Admin
#     (tier %in% tier_1) & (class_name == "admin") ~ case_when(
#       (dist_age >= 58 & yos >= 6) | yos >= 28 ~ 0.0168,
#       (dist_age >= 57 & yos >= 6) | yos >= 27 ~ 0.0165,
#       (dist_age >= 56 & yos >= 6) | yos >= 26 ~ 0.0163,
#       (dist_age >= 55 & yos >= 6) | yos >= 25 ~ 0.0160,
#       tier %in% tier_early ~ 0.0160,
#       TRUE ~ NA
#     ),
#     
#     # Tier 2 & 3: Regular
#     (tier %in% c(tier_2, tier_3)) & (class_name == "regular") ~ case_when(
#       (dist_age >= 68 & yos >= 8) | yos >= 36 ~ 0.0168,
#       (dist_age >= 67 & yos >= 8) | yos >= 35 ~ 0.0165,
#       (dist_age >= 66 & yos >= 8) | yos >= 34 ~ 0.0163,
#       (dist_age >= 65 & yos >= 8) | yos >= 33 ~ 0.0160,
#       tier %in% tier_early ~ 0.0160,
#       TRUE ~ NA
#     ),
#     
#     # Tier 2: Admin
#     (tier %in% tier_2) & (class_name == "admin") ~ case_when(
#       (dist_age >= 63 & yos >= 8) | yos >= 33 ~ 0.0168,
#       (dist_age >= 62 & yos >= 8) | yos >= 32 ~ 0.0165,
#       (dist_age >= 61 & yos >= 8) | yos >= 31 ~ 0.0163,
#       (dist_age >= 60 & yos >= 8) | yos >= 30 ~ 0.0160,
#       tier %in% tier_early ~ 0.0160,
#       TRUE ~ NA
#     ),
#     
#     # Tier 3: Admin
#     (tier %in% tier_3) & (class_name == "admin") ~ case_when(
#       dist_age >= 63 & yos >= 8  ~ 0.0168,
#       dist_age >= 62 & yos >= 8  ~ 0.0165,
#       dist_age >= 61 & yos >= 8  ~ 0.0163,
#       dist_age >= 60 & yos >= 8 ~ 0.0160,
#       (tier %in% tier_early) ~ 0.0160,
#       TRUE ~ NA
#     ),
#     
#     # Flat values
#     (class_name %in% c("eco", "eso")) ~ 0.03,
#     (class_name == "judges") ~ 0.0333,
#     (class_name == "senior_management") ~ 0.02,
#     
#     # Final fallback
#     TRUE ~ NA
#   )
#   
#   return(result)
# }
# 
# 
# 
# # ben_mult_lookup <- expand.grid(
# #   tier_at_dist_age = c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
# #            "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
# #            "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm"),
# #   class_name = frs_data_env$class_names_no_drop_frs_,
# #   dist_age = frs_data_env$age_range_,
# #   yos = frs_data_env$yos_range_,
# #   dist_year = frs_data_env$year_range_) %>%
# #   mutate(ben_mult = get_ben_mult(tier = tier_at_dist_age, class_name, dist_age, dist_year, yos))
# 
# 
# ## Use a loop to build the lookup table
# tier_vec <- c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
#               "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
#               "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm")
# 
# class_vec <- frs_data_env$class_names_no_drop_frs_
# 
# # Loop over combinations of class and tier
# ben_mult_lookup_list <- list()
# 
# 
# for (cl in frs_data_env$class_names_no_drop_frs_) {  
#   
#   ben_mult_lookup <- expand.grid(
#     tier_at_dist_age = c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
#                          "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
#                          "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm"),
#     class_name = cl,
#     dist_age = frs_data_env$age_range_,
#     yos = frs_data_env$yos_range_,
#     dist_year = frs_data_env$year_range_) %>%
#     mutate(ben_mult = get_ben_mult(tier = tier_at_dist_age, class_name, dist_age, dist_year, yos))
#   
#   ben_mult_lookup_list[[cl]] <- ben_mult_lookup
# }
# 
# ben_mult_lookup_2 <- dplyr::bind_rows(ben_mult_lookup_list)
# 
# ben_mult_compare <- ben_mult_lookup_2 %>% left_join(ben_mult_lookup,
#                                 by = join_by(class_name, 
#                                              tier_at_dist_age,
#                                              dist_age >= dist_age_min_ge,
#                                              dist_age < dist_age_max_lt,
#                                              yos >= yos_min_ge,
#                                              yos < yos_max_lt,
#                                              dist_year >= dist_year_min_ge,
#                                              dist_year < dist_year_max_lt)) %>%
#   mutate(
#     mismatch = (ben_mult.x != ben_mult.y) |
#       xor(is.na(ben_mult.x), is.na(ben_mult.y))
#   ) %>%
#   filter(mismatch == TRUE) %>%
#   select(ben_mult.x, ben_mult.y, class_name, tier_at_dist_age, dist_age, yos, dist_year) 
# 
# ben_mult_compare %>% slice_sample (n = 10)

# ### test_ended
