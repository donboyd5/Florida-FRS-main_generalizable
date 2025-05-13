#################################################################
##                       Liability Model                       ##
#################################################################

# class_name = class_name_
# dr_current = dr_current_
# dr_new = dr_new_
# cola_tier_1_active = cola_tier_1_active_
# cola_tier_2_active = cola_tier_2_active_
# cola_tier_3_active = cola_tier_3_active_
# cola_current_retire = cola_current_retire_
# cola_current_retire_one = cola_current_retire_one_
# one_time_cola = one_time_cola_
# retire_refund_ratio = retire_refund_ratio_
# cal_factor = cal_factor_
# #inputs below are for the liability model
# non_special_db_new_ratio = non_special_db_new_ratio_
# special_db_new_ratio = special_db_new_ratio_


# djb: CAUTIONS ----
# Still assumed to be in the global environment:

#   salary_growth_table

# end CAUTIONS ----


get_funding_df <- function(wf_active_df_final,
                           wf_term_df_final,
                           wf_refund_df_final,
                           wf_retire_df_final,
                           wf_retire_current_final,
                           wf_term_current,
                           params)
  
  ##### Funding model - liability side
  {
  funding_df <- wf_active_df_final %>% 
    left_join(wf_term_df_final,
              by = join_by(year)) %>% 
    left_join(wf_refund_df_final,
              by = join_by(year)) %>% 
    left_join(wf_retire_df_final,
              by = join_by(year)) %>%
    left_join(wf_retire_current_final,
              by = join_by(year)) %>% 
    left_join(wf_term_current,
              by = join_by(year)) %>%
    replace(is.na(.), 0) %>% 
    mutate(
      aal_legacy_est = aal_active_db_legacy_est + aal_term_db_legacy_est + aal_retire_db_legacy_est + aal_retire_current_est + aal_term_current_est,
      aal_new_est = aal_active_db_new_est + aal_term_db_new_est + aal_retire_db_new_est,
      total_aal_est = aal_legacy_est + aal_new_est,
      tot_ben_refund_legacy_est = refund_db_legacy_est + retire_ben_db_legacy_est + retire_ben_current_est + retire_ben_term_est,
      tot_ben_refund_new_est = refund_db_new_est + retire_ben_db_new_est,
      tot_ben_refund_est = tot_ben_refund_legacy_est + tot_ben_refund_new_est
    )
  
  #Calculate liability gain/loss if any and project AAL using the roll forward method
  funding_df$liability_gain_loss_legacy_est <- 0
  funding_df$liability_gain_loss_new_est <- 0
  funding_df$total_liability_gain_loss_est <- 0
  
  funding_df$aal_legacy_roll <- 0
  funding_df$aal_new_roll <- 0
  funding_df$total_aal_roll <- 0
  
  for (i in 1:nrow(funding_df)) {
    if (i == 1) {
      funding_df$liability_gain_loss_legacy_est[i] <- 0
      funding_df$liability_gain_loss_new_est[i] <- 0
      
      funding_df$aal_legacy_roll[i] <- funding_df$aal_legacy_est[i]
      funding_df$aal_new_roll[i] <- funding_df$aal_new_est[i]
      
    } else {
      
      funding_df$liability_gain_loss_legacy_est[i] <- round(funding_df$aal_legacy_est[i] -
                                                              (funding_df$aal_legacy_est[i-1] * (1 + params$dr_current_) +
                                                                 funding_df$payroll_db_legacy_est[i-1] * funding_df$nc_rate_db_legacy_est[i-1] -
                                                                 funding_df$tot_ben_refund_legacy_est[i]),
                                                            digits = 1)
      
      funding_df$liability_gain_loss_new_est[i] <- round(funding_df$aal_new_est[i] -
                                                           (funding_df$aal_new_est[i-1] * (1 + params$dr_new_) + 
                                                              funding_df$payroll_db_new_est[i-1] * funding_df$nc_rate_db_new_est[i-1] -
                                                              funding_df$tot_ben_refund_new_est[i]), 
                                                         digits = 1)
      
      funding_df$aal_legacy_roll[i] <- funding_df$aal_legacy_roll[i-1] * (1 + params$dr_current_) +
        funding_df$payroll_db_legacy_est[i-1] * funding_df$nc_rate_db_legacy_est[i-1] -
        funding_df$tot_ben_refund_legacy_est[i] +
        funding_df$liability_gain_loss_legacy_est[i]
      
      funding_df$aal_new_roll[i] <- funding_df$aal_new_roll[i-1] * (1 + params$dr_new_) +
        funding_df$payroll_db_new_est[i-1] * funding_df$nc_rate_db_new_est[i-1] -
        funding_df$tot_ben_refund_new_est[i] + 
        funding_df$liability_gain_loss_new_est[i]
    }
  }
  
  funding_df$total_liability_gain_loss_est <- funding_df$liability_gain_loss_legacy_est + funding_df$liability_gain_loss_new_est
  funding_df$total_aal_roll <- funding_df$aal_legacy_roll + funding_df$aal_new_roll
  
  return(funding_df)
}


get_ratios <- function(class_name,
                       params){
  #Plan design choice ratios:
  if (class_name == "special") {
    db_legacy_before_2018_ratio <- params$special_db_legacy_before_2018_ratio_
    db_legacy_after_2018_ratio <- params$special_db_legacy_after_2018_ratio_
    db_new_ratio <- params$special_db_new_ratio_
  } else {
    db_legacy_before_2018_ratio <- params$non_special_db_legacy_before_2018_ratio_
    db_legacy_after_2018_ratio <- params$non_special_db_legacy_after_2018_ratio_
    db_new_ratio <- params$non_special_db_new_ratio_
  }
  
  # local variables
  dc_legacy_before_2018_ratio <- 1 - db_legacy_before_2018_ratio
  dc_legacy_after_2018_ratio <- 1 - db_legacy_after_2018_ratio
  dc_new_ratio <- 1 - db_new_ratio
  
  return(list(
    db_legacy_before_2018_ratio = db_legacy_before_2018_ratio,
    db_legacy_after_2018_ratio = db_legacy_after_2018_ratio,
    db_new_ratio = db_new_ratio,
    
    dc_legacy_before_2018_ratio = dc_legacy_before_2018_ratio,
    dc_legacy_after_2018_ratio = dc_legacy_after_2018_ratio,
    dc_new_ratio = dc_new_ratio
  ))
}


get_wf_active_df_final <- function(wf_active_df,
                             benefit_val_table,
                             ratios,
                             params){
  #Join wf active table with FinalData table to calculate the overall payroll, normal costs, PVFB, and PVFS each year
  wf_active_df_final <- wf_active_df %>% 
    filter(year <= params$start_year_ + params$model_period_) %>% 
    mutate(entry_year = year - (age - entry_age)) %>% 
    left_join(benefit_val_table, by = c("entry_age", "age" = "term_age", "year" = "term_year", "entry_year")) %>% 
    select(entry_age, age, year, entry_year, n_active, indv_norm_cost, salary, 
           pvfb_db_wealth_at_current_age, pvfnc_db, pvfs_at_current_age) %>% 
    replace(is.na(.), 0) %>% 
    # filter(n_active > 0) %>% 
    #allocate members to plan designs based on entry year
    mutate(
      n_active_db_legacy = if_else(entry_year < 2018, 
                                   n_active * ratios$db_legacy_before_2018_ratio,
                                   if_else(entry_year < params$new_year_,
                                           n_active * ratios$db_legacy_after_2018_ratio, 
                                           0)),
      n_active_db_new = if_else(entry_year < params$new_year_,
                                0, 
                                n_active * ratios$db_new_ratio),
      n_active_dc_legacy = if_else(entry_year < 2018, 
                                   n_active * ratios$dc_legacy_before_2018_ratio,
                                   if_else(entry_year < params$new_year_,
                                           n_active * ratios$dc_legacy_after_2018_ratio, 
                                           0)),
      n_active_dc_new = if_else(entry_year < params$new_year_, 
                                0, 
                                n_active * ratios$dc_new_ratio)
    ) %>% 
    group_by(year) %>% 
    summarise(
      #Payroll
      payroll_db_legacy_est = sum(salary * n_active_db_legacy),
      payroll_db_new_est = sum(salary * n_active_db_new),
      payroll_dc_legacy_est = sum(salary * n_active_dc_legacy),
      payroll_dc_new_est = sum(salary * n_active_dc_new),
      total_payroll_est = sum(salary * n_active),
      #Normal cost rates
      nc_rate_db_legacy_est = if_else(payroll_db_legacy_est == 0, 
                                      0, 
                                      sum(indv_norm_cost * salary * n_active_db_legacy) / sum(salary * n_active_db_legacy)),
      nc_rate_db_new_est = if_else(payroll_db_new_est == 0, 
                                   0, 
                                   sum(indv_norm_cost * salary * n_active_db_new) / sum(salary * n_active_db_new)),
      #Present value of future benefits
      pvfb_active_db_legacy_est = sum(pvfb_db_wealth_at_current_age * n_active_db_legacy),
      pvfb_active_db_new_est = sum(pvfb_db_wealth_at_current_age * n_active_db_new),
      #Present value of future normal costs
      pvfnc_db_legacy_est = sum(pvfnc_db * n_active_db_legacy),
      pvfnc_db_new_est = sum(pvfnc_db * n_active_db_new),
      #Count of active members
      total_n_active = sum(n_active)
    ) %>% 
    ungroup() %>% 
    mutate(payroll_db_est = payroll_db_legacy_est + payroll_db_new_est,
           payroll_dc_est = payroll_dc_legacy_est + payroll_dc_new_est,
           total_nc_rate_est = if_else(payroll_db_est == 0, 0, (nc_rate_db_legacy_est * payroll_db_legacy_est + nc_rate_db_new_est * payroll_db_new_est) / payroll_db_est),
           aal_active_db_legacy_est = pvfb_active_db_legacy_est - pvfnc_db_legacy_est,
           aal_active_db_new_est = pvfb_active_db_new_est - pvfnc_db_new_est) %>% 
    replace(is.na(.), 0)
  
  return(wf_active_df_final)
}


get_wf_term_df_final <- function(
    wf_term_df,
    benefit_val_table,
    benefit_table,
    ratios,
    params
) {
  #Term table
  wf_term_df_final <- wf_term_df %>% 
    filter(year <= params$start_year_ + params$model_period_,
           n_term > 0) %>% 
    mutate(entry_year = year - (age - entry_age)) %>% 
    #join benefit_val_table to get PV_DB_Benefit (the present value of benefits at termination)
    left_join(benefit_val_table, by = c("entry_age", "term_year", "entry_year")) %>% 
    select(entry_age, age, year, term_year, entry_year, dist_age, n_term, pvfb_db_at_term_age) %>% 
    #join benefit_table to get the surv_DR at current age
    left_join(benefit_table %>% 
                select(-pvfb_db_at_term_age), 
              by = c("entry_age", "age" = "dist_age", "year" = "dist_year", "term_year", "entry_year")) %>% 
    select(entry_age, age, year, term_year, entry_year, dist_age, n_term, pvfb_db_at_term_age, cum_mort_dr) %>% 
    #rename to clarify variables' meanings
    rename(cum_mort_dr_current = cum_mort_dr) %>% 
    mutate(
      #pvfb_db_term = First DB benefit * annuity factor at retirement * surv_DR at retirement / surv_DR at current time
      #Note that pvfb_db_at_term_ag = First DB benefit * annuity factor at retirement * surv_DR at retirement
      pvfb_db_term = pvfb_db_at_term_age / cum_mort_dr_current,
      
      n_term_db_legacy = if_else(entry_year < 2018, 
                                 n_term * ratios$db_legacy_before_2018_ratio,
                                 if_else(entry_year < params$new_year_,
                                         n_term * ratios$db_legacy_after_2018_ratio, 
                                         0)),
      n_term_db_new = if_else(entry_year < params$new_year_, 
                              0, 
                              n_term * ratios$db_new_ratio)
    ) %>% 
    group_by(year) %>% 
    summarise(aal_term_db_legacy_est = sum(pvfb_db_term * n_term_db_legacy),
              aal_term_db_new_est = sum(pvfb_db_term * n_term_db_new)
    ) %>% 
    ungroup()
  
  return(wf_term_df_final)
}



get_wf_refund_df_final <- function(wf_refund_df,
                                   benefit_table,
                                   ratios,
                                   params){
  # Join wf refund table with benefit table to calculate the overall refunds each year
  wf_refund_df_final <- wf_refund_df %>% 
    filter(year <= params$start_year_ + params$model_period_,
           n_refund > 0) %>% 
    mutate(entry_year = year - (age - entry_age)) %>% 
    left_join(benefit_table, 
              by = c("entry_age", "age" = "dist_age", "year" = "dist_year", "term_year", "entry_year")) %>% 
    select(entry_age, age, year, term_year, entry_year, n_refund, db_ee_balance) %>% 
    #allocate members to plan designs based on entry year
    mutate(n_refund_db_legacy = if_else(entry_year < 2018, 
                                        n_refund * ratios$db_legacy_before_2018_ratio,
                                        if_else(entry_year < params$new_year_, 
                                                n_refund * ratios$db_legacy_after_2018_ratio, 
                                                0)),
           n_refund_db_new = if_else(entry_year < params$new_year_, 0, n_refund * ratios$db_new_ratio)
    ) %>%
    group_by(year) %>% 
    summarise(refund_db_legacy_est = sum(db_ee_balance * n_refund_db_legacy),
              refund_db_new_est = sum(db_ee_balance * n_refund_db_new)
    ) %>% 
    ungroup()
  
  return(wf_refund_df_final)
}


get_wf_retire_df_final <- function(wf_retire_df,
                                   benefit_table,
                                   ann_factor_table,
                                   ratios,
                                   params){
  # Join wf retire table with benefit table to calculate the overall retirement benefits each year
  wf_retire_df_final <- wf_retire_df %>% 
    filter(year <= params$start_year_ + params$model_period_) %>% 
    mutate(entry_year = year - (age - entry_age)) %>%    
    left_join(benefit_table, by = c("entry_age", "entry_year", "term_year", "retire_year" = "dist_year")) %>% 
    select(entry_age, age, year, term_year, retire_year, entry_year, n_retire, db_benefit, cola) %>% 
    left_join(ann_factor_table %>% 
                select(-cola), 
              by = c("entry_age", "entry_year", "term_year", "year" = "dist_year")) %>% 
    select(entry_age, age, year, term_year, retire_year, entry_year, n_retire, db_benefit, cola, ann_factor) %>% 
    rename(base_db_benefit = db_benefit) %>% 
    #Adjust the benefit based on COLA and allocate members to plan designs based on entry year
    mutate(
      db_benefit_final = base_db_benefit * (1 + cola)^(year - retire_year),
      
      n_retire_db_legacy = if_else(entry_year < 2018, 
                                   n_retire * ratios$db_legacy_before_2018_ratio,
                                   if_else(entry_year < params$new_year_, 
                                           n_retire * ratios$db_legacy_after_2018_ratio, 
                                           0)),
      n_retire_db_new = if_else(entry_year < params$new_year_, 
                                0,
                                n_retire * ratios$db_new_ratio),
      #We use "AnnuityFactor_DR - 1" below because the PVFB for retirees excludes the first payment (i.e. the first payment has already been delivered when the PVFB is calculated)
      pvfb_db_retire = db_benefit_final * (ann_factor - 1)
    ) %>% 
    group_by(year) %>% 
    summarise(retire_ben_db_legacy_est = sum(db_benefit_final * n_retire_db_legacy),
              retire_ben_db_new_est = sum(db_benefit_final * n_retire_db_new),
              
              aal_retire_db_legacy_est = sum(pvfb_db_retire * n_retire_db_legacy),
              aal_retire_db_new_est = sum(pvfb_db_retire * n_retire_db_new)
    ) %>% 
    ungroup()
  
  return(wf_retire_df_final)    
}


get_wf_retire_current_final <- function(
    retiree_pop_current,
    ben_payment_current,
    ann_factor_retire_table,
    params) {
  
  # Project benefit payments for current retirees
  retire_current_int <- params$retiree_distribution %>% 
    select(age, n_retire_ratio:total_ben_ratio) %>% 
    mutate(
      n_retire_current = n_retire_ratio * retiree_pop_current,
      total_ben_current = total_ben_ratio * ben_payment_current,
      avg_ben_current = total_ben_current / n_retire_current,
      year = params$start_year_
    )
  
  wf_retire_current <- ann_factor_retire_table %>% 
    filter(year <= params$start_year_ + params$model_period_) %>% 
    left_join(retire_current_int, by = c("age", "year")) %>% 
    select(base_age:ann_factor_retire, n_retire_current, avg_ben_current, total_ben_current) %>% 
    group_by(base_age) %>% 
    mutate(n_retire_current = pentools::recur_grow(n_retire_current, -mort_final),
           avg_ben_current = pentools::recur_grow2(avg_ben_current, cola),
           total_ben_current = n_retire_current * avg_ben_current,
           #W e use "AnnuityFactor_DR - 1" below because the PVFB for retirees excludes the first payment (i.e. the first payment has already been delivered when the PVFB is calculated)
           pvfb_retire_current = avg_ben_current * (ann_factor_retire - 1)
    ) %>% 
    filter(!is.na(n_retire_current)) %>% 
    ungroup()
  
  wf_retire_current_final <- wf_retire_current %>% 
    group_by(year) %>% 
    summarise(retire_ben_current_est = sum(total_ben_current),
              aal_retire_current_est = sum(n_retire_current * pvfb_retire_current)
    ) %>% 
    ungroup()
  # rename(year = Years)
  
  return(wf_retire_current_final)
}


get_wf_term_current <- function(
    pvfb_term_current,
    params){
  
  # Project benefit payments for current term vested members
  # Note that we use the original "dr_current_" in calculating the benefit payments so that any discount rate adjustment can work
  
  retire_ben_term <- get_pmt(r = params$dr_current_, nper = params$amo_period_term_, pv = pvfb_term_current, g = params$payroll_growth_)
  
  year <- params$start_year_:(params$start_year_ + params$model_period_)
  
  amo_years_term <- (params$start_year_ + 1):(params$start_year_ + params$amo_period_term_)
  
  retire_ben_term_est <- double(length = length(year))
  retire_ben_term_est[which(year %in% amo_years_term)] <- pentools::recur_grow3(retire_ben_term, params$payroll_growth_, params$amo_period_term_)
  
  wf_term_current <- data.frame(year, retire_ben_term_est) %>% 
    mutate(aal_term_current_est = pentools::roll_pv(rate = params$dr_current_,
                                          g = params$payroll_growth_, 
                                          nper = params$amo_period_term_, 
                                          pmt_vec = retire_ben_term_est))
  
  return(wf_term_current)
}


# main function -----------------------------------------------------------

get_liability_data <- function(
    class_name,
    wf_data,
    ben_payment_current,
    retiree_pop_current,
    pvfb_term_current,
    entrant_profile_table,
    salary_headcount_table,
    mort_table,
    mort_retire_table,
    separation_rate_table,        
    params
    ) {
  
  print(paste0("processing get_benefit_data in liability model for: ", class_name))
  benefit_data <- bm_env$get_benefit_data(    
    class_name,
    entrant_profile_table,
    salary_headcount_table,
    mort_table,
    mort_retire_table,
    separation_rate_table,    
    params)
  
  # unpack the wf_data and benefit_data objects
  # performant, because r is copy on modify
  wf_active_df <- wf_data$wf_active_df
  wf_term_df <- wf_data$wf_term_df
  wf_refund_df <- wf_data$wf_refund_df
  wf_retire_df <- wf_data$wf_retire_df
  
  benefit_val_table <- benefit_data$benefit_val_table
  benefit_table <- benefit_data$benefit_table
  ann_factor_table <- benefit_data$ann_factor_table
  ann_factor_retire_table <- benefit_data$ann_factor_retire_table
  
  ratios <- get_ratios(class_name,
                       params)
  
  wf_active_df_final <- get_wf_active_df_final(
    wf_active_df,
    benefit_val_table,
    ratios,
    params
  )
  
  wf_term_df_final <- get_wf_term_df_final(
    wf_term_df,
    benefit_val_table,
    benefit_table,
    ratios,
    params
  )  
  
  wf_refund_df_final <- get_wf_refund_df_final(
    wf_refund_df,
    benefit_table,
    ratios,
    params
  )    

  wf_retire_df_final <- get_wf_retire_df_final(
    wf_retire_df,
    benefit_table,
    ann_factor_table,
    ratios,
    params
  )
  
  wf_retire_current_final <- get_wf_retire_current_final(
    retiree_pop_current,
    ben_payment_current,
    ann_factor_retire_table,
    params
  )
  
  wf_term_current <- get_wf_term_current(
    pvfb_term_current,
    params
  )
  
  funding_df <- get_funding_df(wf_active_df_final,
                               wf_term_df_final,
                               wf_refund_df_final,
                               wf_retire_df_final,
                               wf_retire_current_final,
                               wf_term_current,
                               params)
  
  # Check liability gain/loss
  # If the liability gain/loss isn't 0 under the perfect condition (experience = assumption), something must be wrong.
  
  return(funding_df)
}

