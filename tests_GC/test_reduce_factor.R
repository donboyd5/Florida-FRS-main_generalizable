reduce_factor_lookup_2 <- read_excel(here::here(sddir, "FRS_rules_table.xlsx"), sheet = "reducefactor") %>%
  rename (tier_at_dist_age = tier_group,
          class_name = class)

reduce_factor_lookup <- expand.grid(
  tier_at_dist_age = c("tier_1_non_vested", "tier_1_vested", "tier_1_early", "tier_1_norm",
                       "tier_2_non_vested", "tier_2_vested", "tier_2_early", "tier_2_norm",
                       "tier_3_non_vested", "tier_3_vested", "tier_3_early", "tier_3_norm"),
  class_name = frs_data_env$class_names_no_drop_frs_,
  dist_age = frs_data_env$age_range_) %>%
  mutate(reduce_factor = frs_data_env$get_reduce_factor(tier = tier_at_dist_age,
                                                        class_name = class_name,
                                                        dist_age = dist_age))


reduce_factor_lookup %>%
  mutate(reduce_factor_reason = if_else(str_detect(tier_at_dist_age, "norm"), 1,
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
                                                ), NA))) %>%
  left_join(reduce_factor_lookup_2, by = c("tier_at_dist_age", "class_name")) %>%
  mutate(
    reduce_factor = eval(parse(text = reduce_factor_rule))
  ) %>%
  mutate(
    mismatch = (reduce_factor != reduce_factor_reason) |
      xor(is.na(reduce_factor), is.na(reduce_factor_reason))
  ) %>%
  filter(mismatch == TRUE)
