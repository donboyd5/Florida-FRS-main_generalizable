

# benefit_table <- bm_env$get_benefit_table(class_name, ann_factor_table, salary_benefit_table, params)

tier1 <- function(class, dist_age, dist_year, yos, term_status){
  
  regular <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 65 & yos >= 6) | (yos >= 33) ~ 0.0168,
      (dist_age >= 64 & yos >= 6) | (yos >= 32) ~ 0.0165,
      (dist_age >= 63 & yos >= 6) | (yos >= 31) ~ 0.0163,
      (dist_age >= 62 & yos >= 6) | (yos >= 30) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }
  
  special <- function(dist_year){
    case_when(dist_year <= 1974 ~ 0.02,
              .default = 0.03)
  }
  
  admin <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 58 & yos >= 6) | (yos >= 28) ~ 0.0168,
      (dist_age >= 57 & yos >= 6) | (yos >= 27) ~ 0.0165,
      (dist_age >= 56 & yos >= 6) | (yos >= 26) ~ 0.0163,
      (dist_age >= 55 & yos >= 6) | (yos >= 25) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }
  
  case_when(class=="regular" ~ regular(dist_age, yos, term_status),
            class=="special" ~ special(dist_year),
            class=="admin" ~ admin(dist_age, yos, term_status),
            class=="eco" ~.03,
            class=="eso" ~ .03,
            class=="judges" ~ 0.0333,
            class=="senior_management" ~ 0.02,
            .default = NA_real_
  )
}

tier2 <- function(class, dist_age, dist_year, yos, term_status){
  
  regular <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 68 & yos >= 8) | (yos >= 36) ~ 0.0168,
      (dist_age >= 67 & yos >= 8) | (yos >= 35) ~ 0.0165,
      (dist_age >= 66 & yos >= 8) | (yos >= 34) ~ 0.0163,
      (dist_age >= 65 & yos >= 8) | (yos >= 33) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }  
  
  special <- function(dist_year){
    case_when(dist_year <= 1974 ~ 0.02,
              .default = 0.03)
  }
  
  admin <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 63 & yos >= 8) | (yos >= 33) ~ 0.0168,
      (dist_age >= 62 & yos >= 8) | (yos >= 32) ~ 0.0165,
      (dist_age >= 61 & yos >= 8) | (yos >= 31) ~ 0.0163,
      (dist_age >= 60 & yos >= 8) | (yos >= 30) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }  
  
  case_when(class=="regular" ~ regular(dist_age, yos, term_status),
            class=="special" ~ special(dist_year),
            class=="admin" ~ admin(dist_age, yos, term_status),
            class=="eco" ~.03,
            class=="eso" ~ .03,
            class=="judges" ~ 0.0333,
            class=="senior_management" ~ 0.02,
            .default = NA_real_
  )  
}


tier3 <- function(class, dist_age, dist_year, yos, term_status){
  
  regular <- function(dist_age, yos, term_status){
    case_when(
      (dist_age >= 68 & yos >= 8) | (yos >= 36) ~ 0.0168,
      (dist_age >= 67 & yos >= 8) | (yos >= 35) ~ 0.0165,
      (dist_age >= 66 & yos >= 8) | (yos >= 34) ~ 0.0163,
      (dist_age >= 65 & yos >= 8) | (yos >= 33) ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }  
  
  special <- function(dist_year){
    case_when(dist_year <= 1974 ~ 0.02,
              .default = 0.03)
  }
  
  admin <- function(dist_age, yos, term_status){
    case_when(
      dist_age >= 63 & yos >= 8 ~ 0.0168,
      dist_age >= 62 & yos >= 8 ~ 0.0165,
      dist_age >= 61 & yos >= 8 ~ 0.0163,
      dist_age >= 60 & yos >= 8 ~ 0.0160,
      term_status =="early" ~ 0.0160,
      .default = NA_real_
    )
  }  
  
  case_when(class=="regular" ~ regular(dist_age, yos, term_status),
            class=="special" ~ special(dist_year),
            class=="admin" ~ admin(dist_age, yos, term_status),
            class=="eco" ~.03,
            class=="eso" ~ .03,
            class=="judges" ~ 0.0333,
            class=="senior_management" ~ 0.02,
            .default = NA_real_
  )  
}


benmult <- function(class, tier, dist_age, dist_year, yos, term_status){
  case_when(tier=="1" ~ tier1(class, dist_age, dist_year, yos, term_status),
            tier=="2" ~ tier2(class, dist_age, dist_year, yos, term_status),
            tier=="3" ~ tier3(class, dist_age, dist_year, yos, term_status),
            .default = NA_real_
  )
}

get_reduce_factor <- function(class, tier, term_status, dist_age){
  # get the reduction factor -- early retirement benefit as 
  # proportion of normal retirement benefit
  early_forumula <- function(reduction_rate, normal_age, dist_age){
    1 - reduction_rate*(normal_age - dist_age)
  }
  case_when(term_status == "norm" ~ 1,
            term_status == "early" & class == "special" ~ 
              case_when(tier=="1" ~ early_forumula(0.05, 55, dist_age),
                        tier=="2" ~ early_forumula(0.05, 60, dist_age),
                        tier=="3" ~ early_forumula(0.05, 60, dist_age),
                        .default = NA_real_),
            term_status == "early" & class != "special" ~ 
              case_when(tier=="1" ~ early_forumula(0.05, 62, dist_age),
                        tier=="2" ~ early_forumula(0.05, 65, dist_age),
                        tier=="3" ~ early_forumula(0.05, 65, dist_age),
                        .default = NA_real_),
            .default = NA_real_
  )
}

tier_lookup <- tibble(tier_at_dist_age = 
                        unique(ann_factor_table_stacked$tier_at_dist_age)) |> 
  mutate(tier = str_sub(tier_at_dist_age, 6, 6),
         term_status=str_sub(tier_at_dist_age, 8, -1),
         is_norm_retire_elig=str_ends(tier_at_dist_age, "norm"))
tier_lookup

# define names exactly as they are in reason's benefit_table (plus class) although their are a lot
keep_names <- rlang::quos(class, entry_year, entry_age, dist_year, dist_age, yos, term_age, class_name, is_norm_retire_elig, term_year, mort_final, tier_at_dist_age, dr, yos_b4_2011, cola, cum_dr, cum_mort, cum_cola, cum_mort_dr, cum_mort_dr_cola, ann_factor, tier_at_term_age, start_sal, entrant_dist, cumprod_salary_increase, entry_salary, max_entry_year, salary, fas_period, fas, db_ee_cont, db_ee_balance, ben_mult, reduce_factor, db_benefit, ann_factor_term, pvfb_db_at_term_age)
# select(!!!keep_names)

a <- proc.time()
benefit_table_stacked <- ann_factor_table_stacked |> 
  # filter(class=="regular") |>
  mutate(term_age = entry_age + yos) |> 
  left_join(tier_lookup,
            by = join_by(tier_at_dist_age)) |>
  left_join(salary_benefit_table_stacked,
            by = join_by(class, entry_year, entry_age, yos, term_age)) |> 
  mutate(ben_mult = benmult(class, tier, dist_age, dist_year, yos, term_status),
         reduce_factor = get_reduce_factor(class, tier, term_status, dist_age),
         
         db_benefit = yos * ben_mult * fas * reduce_factor,
         db_benefit = db_benefit * params$cal_factor_, # calibrate normal cost to val report
         
         ann_factor_term = ann_factor * cum_mort_dr, # annuity factor at termination day
         
         pvfb_db_at_term_age = db_benefit * ann_factor_term # discount future DB benefits back to termination day
  )
b <- proc.time()
b - a # 7.6 secs

rm(tier_lookup, keep_names, b, a)
