
# Create benefit multiplier function --------------------------------------
ben_mult_lookup <- read_excel(here::here(sddir, "FRS_rules_table.xlsx"), sheet = "benmult") %>%
  filter(!is.na(system)) %>%
  rename(ben_mult = benmult,
         tier_at_dist_age = tier_group)


ben_mult_lookup <- ben_mult_lookup %>%
  mutate(
    tier_status = if_else(
      !str_detect(tier_at_dist_age, "early"),
      list(c("norm", "vested", "non_vested")),         # expand to multiple suffixes
      list(NA_character_)                              # keep as-is if "early"
    )
  ) %>%
  unnest(tier_status, keep_empty = TRUE) %>%
  mutate(
    tier_at_dist_age = case_when(
      is.na(tier_status) ~ tier_at_dist_age,                                # if NA, keep original
      TRUE ~ paste(tier_at_dist_age, tier_status, sep = "_")                # else paste suffix
    )
  )

# Benefit reduction factor function ---------------------------------------

get_reduce_factor <- function(tier, class_name, dist_age) {
  # Define tier groups
  tier_1 <- c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm")
  tier_2 <- c("tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm")
  tier_3 <- c("tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm")
  tier_early <- c("tier_1_early", "tier_2_early", "tier_3_early")
  tier_norm  <- c("tier_1_norm", "tier_2_norm", "tier_3_norm")
  
  case_when(
    tier %in% tier_norm ~ 1,
    
    tier %in% tier_early & class_name == "special" ~ case_when(
      tier %in% tier_1 ~ (1 - 0.05 * (55 - dist_age)),
      tier %in% c(tier_2, tier_3) ~ (1 - 0.05 * (60 - dist_age)),
      TRUE ~ NA
    ),
    
    tier %in% tier_early & class_name != "special" ~ case_when(
      tier %in% tier_1 ~ (1 - 0.05 * (62 - dist_age)),
      tier %in% tier_2 ~ (1 - 0.05 * (65 - dist_age)),
      tier %in% tier_3 ~ (1 - 0.05 * (65 - dist_age)),
      TRUE ~ NA
    ),
    
    TRUE ~ NA
  )
}


reduce_factor_lookup <- expand.grid(
  tier_at_dist_age = c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
                       "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
                       "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm"),
  class = frs_data_env$class_names_no_drop_frs_,
  dist_age = frs_data_env$age_range_) %>%
  mutate(reduce_factor = frs_data_env$get_reduce_factor(tier = tier_at_dist_age,
                                                        class_name = class,
                                                        dist_age = dist_age))


# reduce_factor_lookup %>%
#   mutate(reduce_factor_reason = if_else(str_detect(tier_at_dist_age, "norm"), 1,
#                                         if_else(str_detect(tier_at_dist_age, "early"),
#                                                 if_else(class_name == "special",
#                                                         case_when(
#                                                           str_detect(tier_at_dist_age, "tier_1") ~ (1 - 0.05*(55 - dist_age)),
#                                                           str_detect(tier_at_dist_age, "tier_2") ~ (1 - 0.05*(60 - dist_age)),
#                                                           str_detect(tier_at_dist_age, "tier_3") ~ (1 - 0.05*(60 - dist_age))
#                                                         ),
#                                                         case_when(
#                                                           str_detect(tier_at_dist_age, "tier_1") ~ (1 - 0.05*(62 - dist_age)),
#                                                           str_detect(tier_at_dist_age, "tier_2") ~ (1 - 0.05*(65 - dist_age)),
#                                                           str_detect(tier_at_dist_age, "tier_3") ~ (1 - 0.05*(65 - dist_age))
#                                                         )
#                                                 ), NA))) %>%
#   
#   mutate(
#     mismatch = (reduce_factor != reduce_factor_reason) |
#       xor(is.na(reduce_factor), is.na(reduce_factor_reason))
#   ) %>%
#   filter(mismatch == TRUE)


# Cost-of-living adjustment factor ----------------------------------------
get_cola <- function(tier, yos, entry_year, params) {
  yos_b4_2011 <- pmin(pmax(2011 - entry_year, 0), yos)
  
  is_tier_1 <- tier %in% c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm")
  is_tier_2 <- tier %in% c("tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm")
  is_tier_3 <- tier %in% c("tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm")
  
  case_when(
    is_tier_1 & params$cola_tier_1_active_constant_ == "no" ~ if_else(yos > 0, params$cola_tier_1_active_ * yos_b4_2011 / yos, 0),
    is_tier_1 & params$cola_tier_1_active_constant_ == "yes" ~ params$cola_tier_1_active_,
    is_tier_2 ~ params$cola_tier_2_active_,
    is_tier_3 ~ params$cola_tier_3_active_,
    TRUE ~ NA
  )
}

# Test
cola_lookup <- expand.grid(
  tier_at_dist_age = c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
                       "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
                       "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm"),
  yos = frs_data_env$yos_range_,
  entry_year = frs_data_env$year_range_) %>%
  mutate(cola = get_cola(tier = tier_at_dist_age,
                         yos = yos,
                         entry_year = entry_year,
                         params = modparm_data_env)
         #  ,
         # cola_2 = case_when(
         #    str_detect(tier_at_dist_age, "tier_1") & params$cola_tier_1_active_constant_ == "no" ~
         #      if_else(yos > 0, params$cola_tier_1_active_ * yos_b4_2011 / yos, 0),
         #    str_detect(tier_at_dist_age, "tier_1") & params$cola_tier_1_active_constant_ == "yes" ~
         #      params$cola_tier_1_active_,
         #    str_detect(tier_at_dist_age, "tier_2") ~
         #      params$cola_tier_2_active_,
         #    str_detect(tier_at_dist_age, "tier_3") ~
         #      params$cola_tier_3_active_)
  )

# ## Compare
# cola_lookup %>%
#   mutate(yos_b4_2011 = pmin(pmax(2011 - entry_year, 0), yos),
#          cola_2 = case_when(
#            str_detect(tier_at_dist_age, "tier_1") & modparm_data_env$cola_tier_1_active_constant_ == "no" ~
#              if_else(yos > 0, modparm_data_env$cola_tier_1_active_ * yos_b4_2011 / yos, 0),
#            str_detect(tier_at_dist_age, "tier_1") & modparm_data_env$cola_tier_1_active_constant_ == "yes" ~
#              modparm_data_env$cola_tier_1_active_,
#            str_detect(tier_at_dist_age, "tier_2") ~
#              modparm_data_env$cola_tier_2_active_,
#            str_detect(tier_at_dist_age, "tier_3") ~
#              modparm_data_env$cola_tier_3_active_))%>%
#   mutate(
#     mismatch = (cola != cola_2) |
#       xor(is.na(cola), is.na(cola_2))
#   ) %>%
#   filter(mismatch == TRUE)





# Discount rate -----------------------------------------------------------

get_discount_rate <- function(tier, params) {
  if_else(
    str_detect(tier, "tier_3"),
    params$dr_new_,
    params$dr_current_
  )
}

dr_lookup <- expand.grid(
  tier_at_dist_age = c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
                       "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
                       "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm")) %>%
  mutate(dr = get_discount_rate(tier = tier_at_dist_age, params = modparm_data_env))

# dr_lookup %>%
#   mutate(dr_2 = if_else(str_detect(tier_at_dist_age, "tier_3"),
#                         modparm_data_env$dr_new_,
#                         modparm_data_env$dr_current_)) %>%
#   mutate(
#     mismatch = (dr != dr_2) |
#       xor(is.na(dr), is.na(dr_2))
#   ) %>%
#   filter(mismatch == TRUE)


# final average salary period ---------------------------------------------
get_fas_period <- function(tier) {
  if_else(str_detect(tier, "tier_1"), 5L, 8L)
}

fas_period_lookup <- expand.grid(
  tier_at_term_age = c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
                       "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
                       "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm")) %>%
  mutate(fas_period = get_fas_period(tier_at_term_age))

# fas_period_lookup %>%
#   mutate(fas_period_2 = if_else(str_detect(tier_at_term_age, "tier_1"), 5, 8)) %>%
#   mutate(
#     mismatch = (fas_period != fas_period_2) |
#       xor(is.na(fas_period), is.na(fas_period_2))
#   ) %>%
#   filter(mismatch == TRUE)
