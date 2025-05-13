

# benefit_val_table_stacked ----

tierterm_lookup <- salary_benefit_table_stacked |> 
  select(tier_at_term_age) |> 
  distinct() |> 
  as_tibble() |> 
  mutate(tier = str_sub(tier_at_term_age, 6, 6),
         term_status=str_sub(tier_at_term_age, 8, -1),
         sep_type = case_when(
           str_detect(tier_at_term_age, "early|norm|reduced") ~ "retire",
           str_detect(tier_at_term_age, "non_vested") ~ "non_vested",
           str_detect(tier_at_term_age, "vested") ~ "vested",
           .default = NULL # Reason did not give an explicit default, which means it is NULL; perhaps NA_character_ would be better
         ))
tierterm_lookup


npv <- function(cashflows, rate, immediate=FALSE) {
  # faster npv
  n <- length(cashflows)
  if (immediate) { # cash flows at beginning of period
    powers <- 0:(n-1)
  } else {  # cash flows at end of period
    powers <- 1:n
  }
  sum(cashflows / (1 + rate)^powers)
}

get_pvfb <- function(sep_rate_vec, interest_vec, value_vec){ 
  # faster get_pvfb
  pv <- function(i){
    sep_prob <- cumprod(1 - data.table::shift(sep_rate_vec[i:end], n = 2, fill = 0)) * 
      data.table::shift(sep_rate_vec[i:end], n = 1, fill = 0)
    cashflow <- sep_prob * value_vec[i:end]
    npv(cashflow, interest_vec[i], immediate = TRUE)
  }
  end <- length(sep_rate_vec)
  # loop below has proven to be faster than purrr::map()
  pvfb <- double(length = end)
  for (i in 1:end) {
    pvfb[i] <- pv(i)
  }
  # CAUTION: temporary treatment to replace zeros with NAs to match FRS model results
  pvfb[pvfb == 0] <- NA
  pvfb
}

get_pvfs <- function(remaining_prob_vec, interest_vec, sal_vec){ 
  # faster get_pvfs
  pv <- function(i){
    saladj <- sal_vec[i:end] * remaining_prob_vec[i:end] /  remaining_prob_vec[i]
    npv(saladj, interest_vec[i], immediate = FALSE)
  }
  end <- length(sal_vec)
  pvfs <- double(length = end)
  for (i in 1:end) {
    pvfs[i] <- pv(i)
  }
  pvfs
}

get_benefit_val_table_stacked <- function(
    salary_benefit_table_stacked,
    final_benefit_table_stacked,
    separation_rate_table_stacked,
    params){
  
  benefit_val_table_stacked <- salary_benefit_table_stacked |> 
    left_join(final_benefit_table_stacked,
              by = join_by(class, entry_age, entry_year, term_age)) |> 
    left_join(separation_rate_table_stacked,
              by = join_by(class, entry_year, entry_age, yos, term_age))  |> 
    left_join(tierterm_lookup |> 
                select(tier_at_term_age, tier, sep_type),
              by = join_by(tier_at_term_age)) |>
    mutate(
      # note that the tier below applies at termination age only
      dr = if_else(tier=="3", params$dr_new_, params$dr_current_),
      ben_decision = case_when(
        yos == 0 ~ NA_character_,
        sep_type == "retire" ~ "retire",
        sep_type == "vested" ~ "mix",
        sep_type == "non_vested" ~ "refund",
        .default = NA_character_
      ),
      pvfb_db_wealth_at_term_age = case_when(
        sep_type == "retire" ~ pvfb_db_at_term_age,
        sep_type == "vested" ~ (params$retire_refund_ratio_ * pvfb_db_at_term_age + 
                                  (1 - params$retire_refund_ratio_) * db_ee_balance),
        sep_type == "non_vested" ~ db_ee_balance
      ))|> 
    mutate(
      # instead of pentools::get_pvfb
      pvfb_db_wealth_at_current_age = get_pvfb(sep_rate_vec = separation_rate,
                                               interest_vec = dr,
                                               value_vec = pvfb_db_wealth_at_term_age),
      
      # calculate the present value of future salary at current age (discount the annual salary back to current age)
      # instead of pentools::get_pvfs
      pvfs_at_current_age = get_pvfs(remaining_prob_vec = remaining_prob,
                                     interest_vec = dr,
                                     sal_vec = salary),
      
      # calculate the individual normal cost rate at current age
      indv_norm_cost = pvfb_db_wealth_at_current_age[yos == 0] / pvfs_at_current_age[yos == 0],
      
      # calculate the present value of future normal cost at current age (discount the annual normal cost back to current age)
      pvfnc_db = indv_norm_cost * pvfs_at_current_age,
      .by = c(class, entry_year, entry_age)
    )
  
  return(benefit_val_table_stacked)
}

a <- proc.time()
benefit_val_table_stacked <- get_benefit_val_table_stacked(
  salary_benefit_table_stacked,
  final_benefit_table_stacked,
  inputs_stacked_env$separation_rate_table_stacked,
  params)
b <- proc.time()
b - a

rm(a, b)
