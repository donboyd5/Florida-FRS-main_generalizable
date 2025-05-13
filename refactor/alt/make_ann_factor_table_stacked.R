
# stacked ann_factor_table ----
# stack_env$mort_table_stacked
# salary_benefit_table_stacked

# semi_join() return all rows from x with a match in y.
# here all rows from mort_table_stacked (16m recs) with a match in salary_benefit_table (158k rows)

a <- proc.time()

# create tier lookup tables
dr_lookup <- tibble(
  tier_at_dist_age = unique(inputs_stacked_env$mort_table_stacked$tier_at_dist_age)
) |> 
  mutate(dr = if_else(str_detect(tier_at_dist_age, "tier_3"), params$dr_new_, params$dr_current_))
# dr_lookup

cola_lookup <- tibble(
  tier_at_dist_age = unique(inputs_stacked_env$mort_table_stacked$tier_at_dist_age)
) |> 
  mutate(tier = str_sub(tier_at_dist_age, 6, 6),
         basecola=case_when(
           tier == "1" ~ params$cola_tier_1_active_,
           tier == "2" ~ params$cola_tier_2_active_,
           tier == "3" ~ params$cola_tier_3_active_,
           .default = 0
         ),
         tier1mult = if_else(tier == "1" & params$cola_tier_1_active_constant_ == "no",
                             TRUE, FALSE))
cola_lookup


# Convert to data.table if not already
mort_table_stacked <- inputs_stacked_env$mort_table_stacked
# salary_benefit_table_stacked -- in the global environment as it was called right before this file is loaded

setDT(mort_table_stacked) 
setDT(salary_benefit_table_stacked) # global environment
setDT(dr_lookup)
setDT(cola_lookup)

# Extract distinct keys from salary_benefit_table_stacked
salary_benefit_keys <- unique(
  salary_benefit_table_stacked[, .(class, entry_year, entry_age)]
)

# Now set keys on all tables
setkey(mort_table_stacked, class, entry_year, entry_age)
setkey(salary_benefit_keys, class, entry_year, entry_age) 
setkey(dr_lookup, tier_at_dist_age)
setkey(cola_lookup, tier_at_dist_age)

# Set index if you often filter/join on these columns
setindex(mort_table_stacked, dist_year, dist_age)

# semi_join equivalent: keep only rows in mort_table_stacked that match the keys
ann_factor_table_stacked <- mort_table_stacked[
  salary_benefit_keys, 
  on = .(class, entry_year, entry_age), 
  nomatch=0L
]

# Left joins
ann_factor_table_stacked <- ann_factor_table_stacked[
  dr_lookup,
  on = .(tier_at_dist_age), 
  nomatch = NA
]

ann_factor_table_stacked <- ann_factor_table_stacked[
  cola_lookup,
  on = .(tier_at_dist_age), 
  nomatch = NA
]

# Compute yos_b4_2011 and cola
ann_factor_table_stacked[, yos_b4_2011 := pmin(pmax(2011 - entry_year, 0), yos)]
ann_factor_table_stacked[, cola := fifelse(
  tier1mult & yos > 0, 
  basecola * (yos_b4_2011 / yos), 
  0
)]

# Order data for cumulative operations
setorder(ann_factor_table_stacked, class, entry_year, entry_age, yos, dist_year, dist_age)

# Perform grouped calculations by (class, entry_year, entry_age, yos)
ann_factor_table_stacked[, cum_dr := cumprod(1 + shift(dr, fill=0)), 
                         by = .(class, entry_year, entry_age, yos)]
ann_factor_table_stacked[, cum_mort := cumprod(1 - shift(mort_final, fill=0)), 
                         by = .(class, entry_year, entry_age, yos)]
ann_factor_table_stacked[, cum_cola := cumprod(1 + shift(cola, fill=0)), 
                         by = .(class, entry_year, entry_age, yos)]

# Derived columns
ann_factor_table_stacked[, cum_mort_dr := cum_mort / cum_dr]
ann_factor_table_stacked[, cum_mort_dr_cola := cum_mort_dr * cum_cola]

# ann_factor calculation
ann_factor_table_stacked[, ann_factor := {
  x <- cum_mort_dr_cola
  rev(cumsum(rev(x))) / x
}, by = .(class, entry_year, entry_age, yos)]

# Final select
ann_factor_table_stacked <- ann_factor_table_stacked[, .(
  class, entry_year, entry_age, dist_year, dist_age, yos, term_year,
  mort_final, tier_at_dist_age, dr, yos_b4_2011, cola,
  cum_dr, cum_mort, cum_cola, cum_mort_dr, cum_mort_dr_cola, ann_factor
)]

ann_factor_table_stacked <- as_tibble(ann_factor_table_stacked)

b <- proc.time()
print(b - a)

rm(dr_lookup, cola_lookup, mort_table_stacked, salary_benefit_keys, a, b)
