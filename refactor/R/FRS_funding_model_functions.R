#
##                        Funding Model                        ####
#


# functions for funding list and amortization layers ----------------------

# these functions are NOT needed in the get_funding_data function, but are called before it is called


get_all_classes_funding_list <- function(init_funding_data,
                                         params){
  
  funding_list <- lapply(params$class_names_, get_funding_table, init_funding_data, params)
  names(funding_list) <- params$class_names_
  
  return(funding_list)
}


get_current_amort_layers_summary_table <- function(current_amort_layers_table){
  
  #Summarize current amortization layers
  current_amort_layers_table <- current_amort_layers_table %>% 
    mutate(amo_period = if_else(amo_period == "n/a", "20", amo_period),
           amo_period = as.numeric(amo_period)) %>% 
    summarise(amo_balance = sum(amo_balance),
              .by = c(class, amo_period)) %>% 
    #make sure that the amo periods are arranged in descending order
    arrange(class, desc(amo_period))
  
  return(current_amort_layers_table)
}


get_current_hire_amo_payment_table <- function(class_name,
                                               current_hire_amo_payment_table,
                                               current_hire_debt_layer_list,
                                               current_hire_amo_period_list,
                                               amo_col_num,
                                               amo_pay_growth, # this can be different than params$amo_pay_growth_
                                               params) {
  
  current_hire_amo_payment_table <- matrix(0, nrow = params$model_period_ + 1, ncol = amo_col_num)
  
  init_debt_layers <- current_hire_debt_layer_list[[class_name]][1,1:amo_col_num]
  
  amo_periods <- current_hire_amo_period_list[[class_name]][1,1:amo_col_num]
  
  current_hire_amo_payment_table[1,1:amo_col_num] <- get_pmt(pv = init_debt_layers,
                                                             r = params$dr_old_,
                                                             g = amo_pay_growth,
                                                             nper = amo_periods,
                                                             t = 0.5)
  if (params$funding_lag_ > 0) {
    current_hire_amo_payment_table[1,1:params$funding_lag_] <- 0
  }
  
  return(current_hire_amo_payment_table)
}


get_current_hire_amo_period_table <- function(class_name,
                                              current_amort_layers_table,
                                              class_amo_layers_table,
                                              amo_col_num,
                                              params) {
  
  class_amo_layers_table <- current_amort_layers_table %>% 
    filter(class == class_name)
  
  current_periods <- class_amo_layers_table$amo_period
  future_periods <- params$amo_period_new_ + params$funding_lag_
  length(current_periods) <- amo_col_num
  length(future_periods) <- amo_col_num
  
  current_hire_amo_period_table <- rbind(current_periods, 
                                         matrix(future_periods,
                                                nrow = params$model_period_,
                                                ncol = amo_col_num,
                                                byrow = TRUE))
  
  rownames(current_hire_amo_period_table) <- NULL         #Remove row names
  
  #Put the amo periods on diagonal rows
  for (i in 2:nrow(current_hire_amo_period_table)) {
    for (j in 2:ncol(current_hire_amo_period_table)) {
      current_hire_amo_period_table[i, j] <- max(current_hire_amo_period_table[i-1, j-1] - 1, 0)
    }
  }
  
  #Turn all NAs in the table to 0s
  current_hire_amo_period_table[is.na(current_hire_amo_period_table)] <- 0
  
  return(current_hire_amo_period_table)
}


get_current_hire_debt_layer_table <- function(class_name,
                                              current_amort_layers_table,
                                              amo_col_num,
                                              params
                                              ) {
  
  current_hire_debt_layer_table <- matrix(0, nrow = params$model_period_ + 1, ncol = amo_col_num + 1)
  
  current_hire_debt_layers <- current_amort_layers_table %>% 
    filter(class == class_name) %>% 
    arrange(desc(amo_period)) %>% 
    pull(amo_balance)
  
  current_hire_debt_layer_table[1,1:length(current_hire_debt_layers)] <- current_hire_debt_layers
  
  return(current_hire_debt_layer_table)
}


#### Data preparation
#Create 9 empty data frames from the init_funding_data (representing 7 classes, DROP, and FRS system), then put them in a list to store funding outputs for these entities
get_funding_table <- function(class_name, 
                              init_funding_data,
                              params) {
  funding_table <- init_funding_data %>% 
    filter(class == class_name) %>% 
    select(-class) %>%
    add_row(year = (params$start_year_ + 1):(params$start_year_ + params$model_period_))
  
  funding_table[is.na(funding_table)] <- 0
  
  return(funding_table)
}


get_future_hire_amo_payment_table <- function(class_name,
                                              amo_col_num,
                                              params) {
  # Amo payment tables for new members
  future_hire_amo_payment_table <- matrix(0, nrow = params$model_period_ + 1, ncol = amo_col_num)
  return(future_hire_amo_payment_table)
}


get_future_hire_amo_period_table <- function(class_name,
                                             amo_col_num,
                                             params) {
  
  future_periods <- params$amo_period_new_ + params$funding_lag_
  length(future_periods) <- amo_col_num
  
  future_hire_amo_period_table <- matrix(future_periods, 
                                         nrow = params$model_period_ + 1,
                                         ncol = amo_col_num,
                                         byrow = TRUE) 
  
  #Put the amo periods on diagonal rows
  for (i in 2:nrow(future_hire_amo_period_table)) {
    for (j in 2:ncol(future_hire_amo_period_table)) {
      future_hire_amo_period_table[i,j] <- max(future_hire_amo_period_table[i-1,j-1] - 1, 0)
    }
  }
  
  #Turn all NAs in the table to 0s
  future_hire_amo_period_table[is.na(future_hire_amo_period_table)] <- 0
  
  return(future_hire_amo_period_table)
}


get_future_hire_debt_layer_table <- function(class_name,
                                             amo_col_num,
                                             params) {
  # UAAL layers tables for new members
  future_hire_debt_layer_table <- matrix(0, nrow = params$model_period_ + 1, ncol = amo_col_num + 1)
  return(future_hire_debt_layer_table)
}


inner_loop1_payroll_benefits <- function(i,
                                         funding_list,
                                         liability_list,
                                         frs_fund,
                                         params){
  
  for (class in params$class_names_no_drop_frs_) {
    # djb: it looks like no class values rely on frs values in this loop, so we could move frs entirely out of the loop
    
    #Do the assignment below to declutter the code
    class_fund <- funding_list[[class]]
    class_liab <- liability_list[[class]]
    
    #Payroll projection
    class_fund$total_payroll[i] <- class_fund$total_payroll[i-1] * (1 + params$payroll_growth_) # lagged value
    
    class_fund$payroll_db_legacy[i] <- class_fund$total_payroll[i] * class_fund$payroll_db_legacy_ratio[i]
    class_fund$payroll_db_new[i] <- class_fund$total_payroll[i] * class_fund$payroll_db_new_ratio[i]
    class_fund$payroll_dc_legacy[i] <- class_fund$total_payroll[i] * class_fund$payroll_dc_legacy_ratio[i]
    class_fund$payroll_dc_new[i] <- class_fund$total_payroll[i] * class_fund$payroll_dc_new_ratio[i]
    
    # djb update frs values with class totals no lags -- could be consolidated
    frs_fund$total_payroll[i] <- frs_fund$total_payroll[i] + class_fund$total_payroll[i]
    frs_fund$payroll_db_legacy[i] <- frs_fund$payroll_db_legacy[i] + class_fund$payroll_db_legacy[i]
    frs_fund$payroll_db_new[i] <- frs_fund$payroll_db_new[i] + class_fund$payroll_db_new[i]
    frs_fund$payroll_dc_legacy[i] <- frs_fund$payroll_dc_legacy[i] + class_fund$payroll_dc_legacy[i]
    frs_fund$payroll_dc_new[i] <- frs_fund$payroll_dc_new[i] + class_fund$payroll_dc_new[i]
    
    #Benefit payments and refunds projection
    class_fund$ben_payment_legacy[i] <- class_liab$retire_ben_db_legacy_est[i] + 
      class_liab$retire_ben_current_est[i] + 
      class_liab$retire_ben_term_est[i]
    class_fund$refund_legacy[i] <- class_liab$refund_db_legacy_est[i]
    class_fund$ben_payment_new[i] <- class_liab$retire_ben_db_new_est[i]
    class_fund$refund_new[i] <- class_liab$refund_db_new_est[i]
    
    class_fund$total_ben_payment[i] <- class_fund$ben_payment_legacy[i] + class_fund$ben_payment_new[i]
    class_fund$total_refund[i] <- class_fund$refund_legacy[i] + class_fund$refund_new[i]
    
    # djb update frs values with class totals, no lags -- could be consolidated
    frs_fund$ben_payment_legacy[i] <- frs_fund$ben_payment_legacy[i] + class_fund$ben_payment_legacy[i]
    frs_fund$refund_legacy[i] <- frs_fund$refund_legacy[i] + class_fund$refund_legacy[i]
    frs_fund$ben_payment_new[i] <- frs_fund$ben_payment_new[i] + class_fund$ben_payment_new[i]
    frs_fund$refund_new[i] <- frs_fund$refund_new[i] + class_fund$refund_new[i]
    
    frs_fund$total_ben_payment[i] <- frs_fund$total_ben_payment[i] + class_fund$total_ben_payment[i]
    frs_fund$total_refund[i] <- frs_fund$total_refund[i] + class_fund$total_refund[i]
    
    #Normal cost projection
    class_fund$nc_legacy[i] <- class_fund$nc_rate_db_legacy[i] * class_fund$payroll_db_legacy[i]
    class_fund$nc_new[i] <- class_fund$nc_rate_db_new[i] * class_fund$payroll_db_new[i]
    class_fund$total_nc_rate[i] <- (class_fund$nc_legacy[i] + class_fund$nc_new[i]) / 
      (class_fund$payroll_db_legacy[i] + class_fund$payroll_db_new[i])
    
    # djb update frs values with class totals, no lags -- could be consolidated
    frs_fund$nc_legacy[i] <- frs_fund$nc_legacy[i] + class_fund$nc_legacy[i]
    frs_fund$nc_new[i] <- frs_fund$nc_new[i] + class_fund$nc_new[i]
    frs_fund$total_nc_rate[i] <- (frs_fund$nc_legacy[i] + frs_fund$nc_new[i]) / 
      (frs_fund$payroll_db_legacy[i] + frs_fund$payroll_db_new[i])
    
    #Accrued liability projection
    class_fund$liability_gain_loss_legacy[i] <- class_liab$liability_gain_loss_legacy_est[i]
    class_fund$liability_gain_loss_new[i] <- class_liab$liability_gain_loss_new_est[i]
    class_fund$total_liability_gain_loss[i] <- class_liab$total_liability_gain_loss_est[i]
    
    # djb: lagged value here
    class_fund$aal_legacy[i] <- class_fund$aal_legacy[i-1] * (1 + params$dr_current_) +
      (class_fund$nc_legacy[i] - class_fund$ben_payment_legacy[i] - class_fund$refund_legacy[i]) *
      (1 + params$dr_current_)^0.5 + 
      class_fund$liability_gain_loss_legacy[i]
    
    # djb: lagged value here
    class_fund$aal_new[i] <- class_fund$aal_new[i-1] * (1 + params$dr_new_) + 
      (class_fund$nc_new[i] - class_fund$ben_payment_new[i] - class_fund$refund_new[i]) *
      (1 + params$dr_new_)^0.5 + 
      class_fund$liability_gain_loss_new[i]
    
    class_fund$total_aal[i] <- class_fund$aal_legacy[i] + class_fund$aal_new[i]
    
    # djb: FRS totals in the loop: update with class info no lags, could be consolidated
    frs_fund$lia_gain_loss_legacy[i] <- frs_fund$lia_gain_loss_legacy[i] + class_fund$liability_gain_loss_legacy[i]
    frs_fund$lia_gain_loss_new[i] <- frs_fund$lia_gain_loss_new[i] + class_fund$liability_gain_loss_new[i]
    frs_fund$total_lia_gain_loss[i] <- frs_fund$total_lia_gain_loss[i] + class_fund$total_liability_gain_loss[i]
    
    frs_fund$aal_legacy[i] <- frs_fund$aal_legacy[i] + class_fund$aal_legacy[i]
    frs_fund$aal_new[i] <- frs_fund$aal_new[i] + class_fund$aal_new[i]
    frs_fund$total_aal[i] <- frs_fund$total_aal[i] + class_fund$total_aal[i]
    
    #Assign the class outputs back to the funding_list
    funding_list[[class]] <- class_fund
    
  } #.. end class in class_names_no_drop_frs loop
  return(list(funding_list = funding_list,
              frs_fund = frs_fund))
}

inner_drop1_funding <- function(i,
                                funding_list,
                                frs_fund,
                                params){
  # DANGER, TEMPORARY: not passing variables. will modify them and return
  
  #### Process DROP's payroll, benefit payments, normal cost, and accrued
  #      liability (note that this is a makeshift method for now). Proper
  #      modeling of DROP will be done in the future.
  
  drop_fund <- funding_list$drop
  regular_fund <- funding_list$regular
  
  #DROP payroll projection (no DC payroll for DROP)
  # djb: lagged value here
  # djb: NOTE RELIANCE ON REGULAR
  drop_fund$total_payroll[i] <- drop_fund$total_payroll[i-1] * (1 + params$payroll_growth_)
  drop_fund$payroll_db_legacy[i] <- drop_fund$total_payroll[i] * (regular_fund$payroll_db_legacy_ratio[i] + regular_fund$payroll_dc_legacy_ratio[i])
  drop_fund$payroll_db_new[i] <- drop_fund$total_payroll[i] * (regular_fund$payroll_db_new_ratio[i] + regular_fund$payroll_dc_new_ratio[i])
  
  #DROP benefit payments and refunds projection (based on Regular class' benefit payments and refunds)
  # djb: ask Reason to explain this - why are DROP benefits and refunds based on Regular??
  # djb: RELIANCE ON REGULAR
  # djb: lagged value here
  drop_fund$total_ben_payment[i] <- drop_fund$total_ben_payment[i-1] * 
    regular_fund$total_ben_payment[i] / regular_fund$total_ben_payment[i-1]
  
  drop_fund$total_refund[i] <- drop_fund$total_refund[i-1] * 
    regular_fund$total_refund[i] / regular_fund$total_refund[i-1]
  
  drop_fund$ben_payment_legacy[i] <- drop_fund$total_ben_payment[i] * 
    regular_fund$ben_payment_legacy[i] / regular_fund$total_ben_payment[i]
  
  drop_fund$refund_legacy[i] <- drop_fund$total_refund[i] * 
    regular_fund$refund_legacy[i] / regular_fund$total_refund[i]
  
  drop_fund$ben_payment_new[i] <- drop_fund$total_ben_payment[i] * 
    regular_fund$ben_payment_new[i] / regular_fund$total_ben_payment[i]
  
  drop_fund$refund_new[i] <- drop_fund$total_refund[i] * 
    regular_fund$refund_new[i] / regular_fund$total_refund[i]
  
  #DROP normal cost projection (DROP's normal cost rate = FRS's normal cost rate)
  # djb: RELIANCE ON FRS
  drop_fund$nc_rate_db_legacy[i] <- frs_fund$nc_legacy[i] / frs_fund$payroll_db_legacy[i]
  drop_fund$nc_rate_db_new[i] <- if_else(frs_fund$payroll_db_new[i] == 0, 0, frs_fund$nc_new[i] / frs_fund$payroll_db_new[i])
  
  drop_fund$nc_legacy[i] <- drop_fund$nc_rate_db_legacy[i] * drop_fund$payroll_db_legacy[i]
  drop_fund$nc_new[i] <- drop_fund$nc_rate_db_new[i] * drop_fund$payroll_db_new[i]
  drop_fund$total_nc_rate[i] <- (drop_fund$nc_legacy[i] + drop_fund$nc_new[i]) / 
    (drop_fund$payroll_db_legacy[i] + drop_fund$payroll_db_new[i])
  
  #DROP accrued liability projection
  # djb: lagged value here
  # djb: why the square root of 1 + dr_current
  drop_fund$aal_legacy[i] <- drop_fund$aal_legacy[i-1] * (1 + params$dr_current_) +
    (drop_fund$nc_legacy[i] - drop_fund$ben_payment_legacy[i] - drop_fund$refund_legacy[i]) * 
    (1 + params$dr_current_)^0.5 + 
    drop_fund$liability_gain_loss_legacy[i]
  
  drop_fund$aal_new[i] <- drop_fund$aal_new[i-1] * (1 + params$dr_new_) + 
    (drop_fund$nc_new[i] - drop_fund$ben_payment_new[i] - drop_fund$refund_new[i]) * 
    (1 + params$dr_new_)^0.5 +
    drop_fund$liability_gain_loss_new[i]
  
  drop_fund$total_aal[i] <- drop_fund$aal_legacy[i] + drop_fund$aal_new[i]
  
  #Assign the DROP outputs back to the funding_list
  funding_list$drop <- drop_fund
  return(funding_list)
}


inner_frs_fund1 <- function(i,
                            frs_fund,
                            drop_fund){
  # DANGER, TEMPORARY: not passing variables. will modify them and return
  
  ####Update FRS's numbers after DROP
  #FRS's payroll projection
  frs_fund$total_payroll[i] <- frs_fund$total_payroll[i] + drop_fund$total_payroll[i]
  frs_fund$payroll_db_legacy[i] <- frs_fund$payroll_db_legacy[i] + drop_fund$payroll_db_legacy[i]
  frs_fund$payroll_db_new[i] <- frs_fund$payroll_db_new[i] + drop_fund$payroll_db_new[i]
  
  #FRS's benefit payments and refunds projection
  frs_fund$ben_payment_legacy[i] <- frs_fund$ben_payment_legacy[i] + drop_fund$ben_payment_legacy[i]
  frs_fund$refund_legacy[i] <- frs_fund$refund_legacy[i] + drop_fund$refund_legacy[i]
  frs_fund$ben_payment_new[i] <- frs_fund$ben_payment_new[i] + drop_fund$ben_payment_new[i]
  frs_fund$refund_new[i] <- frs_fund$refund_new[i] + drop_fund$refund_new[i]
  
  frs_fund$total_ben_payment[i] <- frs_fund$total_ben_payment[i] + drop_fund$total_ben_payment[i]
  frs_fund$total_refund[i] <- frs_fund$total_refund[i] + drop_fund$total_refund[i]
  
  #FRS's normal cost projection
  frs_fund$nc_legacy[i] <- frs_fund$nc_legacy[i] + drop_fund$nc_legacy[i]
  frs_fund$nc_new[i] <- frs_fund$nc_new[i] + drop_fund$nc_new[i]
  frs_fund$total_nc_rate[i] <- (frs_fund$nc_legacy[i] + frs_fund$nc_new[i]) / (frs_fund$payroll_db_legacy[i] + frs_fund$payroll_db_new[i])
  
  frs_fund$nc_rate_db_legacy[i] <- frs_fund$nc_legacy[i] / frs_fund$payroll_db_legacy[i]
  frs_fund$nc_rate_db_new[i] <- if_else(frs_fund$payroll_db_new[i] == 0, 0, frs_fund$nc_new[i] / frs_fund$payroll_db_new[i])
  
  #FRS's accrued liability projection
  frs_fund$aal_legacy[i] <- frs_fund$aal_legacy[i] + drop_fund$aal_legacy[i]
  frs_fund$aal_new[i] <- frs_fund$aal_new[i] + drop_fund$aal_new[i]
  frs_fund$total_aal[i] <- frs_fund$total_aal[i] + drop_fund$total_aal[i]
  return(frs_fund)
}


inner_loop2_funding <- function(i,
                                funding_list,
                                frs_fund,
                                current_hire_amo_payment_list,
                                future_hire_amo_payment_list,
                                return_scenarios,
                                return_scen_index,
                                params){
  
  for (class in params$class_names_no_frs_) {
    
    #Do the assignments below to declutter the code
    class_fund <- funding_list[[class]]
    current_hire_amo_pay_table <- current_hire_amo_payment_list[[class]] # djb check the dimensions of these tables
    future_hire_amo_pay_table <- future_hire_amo_payment_list[[class]]
    
    #Normal cost and employee contribution rates
    class_fund$nc_rate_legacy[i] <- class_fund$nc_legacy[i] / class_fund$payroll_db_legacy[i]
    
    if(class_fund$payroll_db_new[i] == 0) {
      class_fund$nc_rate_new[i] <- 0
    } else {
      class_fund$nc_rate_new[i] <- class_fund$nc_new[i] / (class_fund$payroll_db_new[i])  
    } # end if else
    
    class_fund$ee_nc_rate_legacy[i] <- params$db_ee_cont_rate_
    class_fund$ee_nc_rate_new[i] <- params$db_ee_cont_rate_
    
    #Employer contribution rates (DB)
    class_fund$er_nc_rate_legacy[i] <- class_fund$nc_rate_legacy[i] - class_fund$ee_nc_rate_legacy[i]
    class_fund$er_nc_rate_new[i] <- class_fund$nc_rate_new[i] - class_fund$ee_nc_rate_new[i]
    
    class_fund$amo_rate_legacy[i] <- sum(current_hire_amo_pay_table[i-1,]) / class_fund$payroll_db_legacy[i]
    
    if (class_fund$payroll_db_new[i] == 0) {
      class_fund$amo_rate_new[i] <- 0
    } else {
      class_fund$amo_rate_new[i] <- sum(future_hire_amo_pay_table[i-1,]) / class_fund$payroll_db_new[i]
    } # end if else
    
    #Employer contribution rates (DC)
    if (class == "drop") {
      class_fund$er_dc_rate_legacy[i] <- 0
      class_fund$er_dc_rate_new[i] <- 0
    } else {
      
      # djb: temporary fix to prior code that used get to grab a global variable - now get from params
      temp_er_dc_cont_rate <- params[[str_replace(paste0(class, "_er_dc_cont_rate_"), " ", "_")]]
      class_fund$er_dc_rate_legacy[i] <- temp_er_dc_cont_rate
      class_fund$er_dc_rate_new[i] <- temp_er_dc_cont_rate
      rm(temp_er_dc_cont_rate) # clean up. too bad this is in a loop
    } # end if else
    
    #Admin rate
    class_fund$admin_exp_rate[i] <- class_fund$admin_exp_rate[i-1]
    
    #Employee contribution amounts
    class_fund$ee_nc_cont_legacy[i] <- class_fund$ee_nc_rate_legacy[i] * class_fund$payroll_db_legacy[i]
    class_fund$ee_nc_cont_new[i] <- class_fund$ee_nc_rate_new[i] * (class_fund$payroll_db_new[i])
    
    frs_fund$ee_nc_cont_legacy[i] <- frs_fund$ee_nc_cont_legacy[i] + class_fund$ee_nc_cont_legacy[i]
    frs_fund$ee_nc_cont_new[i] <- frs_fund$ee_nc_cont_new[i] + class_fund$ee_nc_cont_new[i]
    
    #Admin expense amounts
    class_fund$admin_exp_legacy[i] <- class_fund$admin_exp_rate[i] * class_fund$payroll_db_legacy[i]
    class_fund$admin_exp_new[i] <- class_fund$admin_exp_rate[i] * (class_fund$payroll_db_new[i])
    
    frs_fund$admin_exp_legacy[i] <- frs_fund$admin_exp_legacy[i] + class_fund$admin_exp_legacy[i]
    frs_fund$admin_exp_new[i] <- frs_fund$admin_exp_new[i] + class_fund$admin_exp_new[i]
    
    #Employer contribution amounts (DB)
    class_fund$er_nc_cont_legacy[i] <- class_fund$er_nc_rate_legacy[i] * class_fund$payroll_db_legacy[i] + class_fund$admin_exp_legacy[i]
    class_fund$er_nc_cont_new[i] <- class_fund$er_nc_rate_new[i] * (class_fund$payroll_db_new[i]) + class_fund$admin_exp_new[i]
    
    class_fund$er_amo_cont_legacy[i] <- class_fund$amo_rate_legacy[i] * class_fund$payroll_db_legacy[i]
    class_fund$er_amo_cont_new[i] <- class_fund$amo_rate_new[i] * (class_fund$payroll_db_new[i])
    class_fund$total_er_db_cont[i] <- class_fund$er_nc_cont_legacy[i] + class_fund$er_nc_cont_new[i] + class_fund$er_amo_cont_legacy[i] + class_fund$er_amo_cont_new[i]
    
    frs_fund$er_nc_cont_legacy[i] <- frs_fund$er_nc_cont_legacy[i] + class_fund$er_nc_cont_legacy[i]
    frs_fund$er_nc_cont_new[i] <- frs_fund$er_nc_cont_new[i] + class_fund$er_nc_cont_new[i]
    
    frs_fund$er_amo_cont_legacy[i] <- frs_fund$er_amo_cont_legacy[i] + class_fund$er_amo_cont_legacy[i]
    frs_fund$er_amo_cont_new[i] <- frs_fund$er_amo_cont_new[i] + class_fund$er_amo_cont_new[i]
    frs_fund$total_er_db_cont[i] <- frs_fund$total_er_db_cont[i] + class_fund$total_er_db_cont[i]
    
    #Employer contribution amounts (DC)
    class_fund$er_dc_cont_legacy[i] <- class_fund$er_dc_rate_legacy[i] * class_fund$payroll_dc_legacy[i]
    class_fund$er_dc_cont_new[i] <- class_fund$er_dc_rate_new[i] * class_fund$payroll_dc_new[i]
    class_fund$total_er_dc_cont[i] <- class_fund$er_dc_cont_legacy[i] + class_fund$er_dc_cont_new[i]
    
    frs_fund$er_dc_cont_legacy[i] <- frs_fund$er_dc_cont_legacy[i] + class_fund$er_dc_cont_legacy[i]
    frs_fund$er_dc_cont_new[i] <- frs_fund$er_dc_cont_new[i] + class_fund$er_dc_cont_new[i]
    frs_fund$total_er_dc_cont[i] <- frs_fund$total_er_dc_cont[i] + class_fund$total_er_dc_cont[i]
    
    #Simulated returns
    class_fund$roa[i] <- return_scenarios[which(return_scenarios$year == class_fund$year[i]), return_scen_index][[1]]
    frs_fund$roa[i] <- return_scenarios[which(return_scenarios$year == class_fund$year[i]), return_scen_index][[1]]
    
    #Solvency contribution and cash flows
    cf_legacy <- class_fund$ee_nc_cont_legacy[i] + 
      class_fund$er_nc_cont_legacy[i] + 
      class_fund$er_amo_cont_legacy[i] - 
      class_fund$ben_payment_legacy[i] - 
      class_fund$refund_legacy[i] - 
      class_fund$admin_exp_legacy[i]
    
    cf_new <- class_fund$ee_nc_cont_new[i] + 
      class_fund$er_nc_cont_new[i] + 
      class_fund$er_amo_cont_new[i] - 
      class_fund$ben_payment_new[i] - 
      class_fund$refund_new[i] - 
      class_fund$admin_exp_new[i]
    
    cf_total <- cf_legacy + cf_new
    
    class_fund$total_solv_cont[i] <- max(-(class_fund$mva[i-1] * (1 + class_fund$roa[i]) + 
                                             cf_total * (1 + class_fund$roa[i])^0.5) / (1 + class_fund$roa[i])^0.5, 0)
    
    class_fund$solv_cont_legacy[i] <- class_fund$total_solv_cont[i] * class_fund$aal_legacy[i] / class_fund$total_aal[i]
    
    class_fund$solv_cont_new[i] <- class_fund$total_solv_cont[i] * class_fund$aal_new[i] / class_fund$total_aal[i]
    
    class_fund$net_cf_legacy[i] <- cf_legacy + class_fund$solv_cont_legacy[i]
    class_fund$net_cf_new[i] <- cf_new + class_fund$solv_cont_new[i]
    
    frs_fund$net_cf_legacy[i] <- frs_fund$net_cf_legacy[i] + class_fund$net_cf_legacy[i]
    frs_fund$net_cf_new[i] <- frs_fund$net_cf_new[i] + class_fund$net_cf_new[i]
    
    #MVA projection
    class_fund$mva_legacy[i] <- class_fund$mva_legacy[i-1] * (1 + class_fund$roa[i]) + class_fund$net_cf_legacy[i] * (1 + class_fund$roa[i])^0.5
    class_fund$mva_new[i] <- class_fund$mva_new[i-1] * (1 + class_fund$roa[i]) + class_fund$net_cf_new[i] * (1 + class_fund$roa[i])^0.5
    class_fund$total_mva[i] <- class_fund$mva_legacy[i] + class_fund$mva_new[i]
    
    frs_fund$mva_legacy[i] <- frs_fund$mva_legacy[i] + class_fund$mva_legacy[i]
    frs_fund$mva_new[i] <- frs_fund$mva_new[i] + class_fund$mva_new[i]
    frs_fund$total_mva[i] <- frs_fund$total_mva[i] + class_fund$total_mva[i]
    
    #AVA development prep
    class_fund$ava_base_legacy[i] <- class_fund$ava_legacy[i-1] + class_fund$net_cf_legacy[i]/2
    class_fund$ava_base_new[i] <- class_fund$ava_new[i-1] + class_fund$net_cf_new[i]/2
    
    #Assign the class outputs back to the funding_list
    funding_list[[class]] <- class_fund
  } #.. end class in class_names_no_frs loop
  
  return(list(funding_list = funding_list,
              frs_fund = frs_fund))
}

inner_frs_fund2 <- function(i,
                            frs_fund,
                            params){
  # DANGER, TEMPORARY: not passing variables. will modify them and return  
  
  # <open code frs calculations>
  #AVA legacy development (step 1: calculate FRS's AVA)
  frs_fund$exp_inv_earnings_ava_legacy[i] <- frs_fund$ava_legacy[i-1] * params$dr_current_ + 
    frs_fund$net_cf_legacy[i] * params$dr_current_ / 2
  
  frs_fund$exp_ava_legacy[i] <- frs_fund$ava_legacy[i-1] + 
    frs_fund$net_cf_legacy[i] + 
    frs_fund$exp_inv_earnings_ava_legacy[i]
  
  # djb: Caution: hard-coded numbers here and further below ----
  frs_fund$ava_legacy[i] <- max(min(frs_fund$exp_ava_legacy[i] + (frs_fund$mva_legacy[i] - frs_fund$exp_ava_legacy[i]) * 0.2,
                                    frs_fund$mva_legacy[i] * 1.2), frs_fund$mva_legacy[i] * 0.8)
  
  frs_fund$alloc_inv_earnings_ava_legacy[i] <- frs_fund$ava_legacy[i] - 
    frs_fund$ava_legacy[i-1] - 
    frs_fund$net_cf_legacy[i]
  
  frs_fund$ava_base_legacy[i] <- frs_fund$ava_legacy[i-1] + frs_fund$net_cf_legacy[i]/2
  
  #AVA new development (step 1: calculate FRS's AVA)
  frs_fund$exp_inv_earnings_ava_new[i] <- frs_fund$ava_new[i-1] * params$dr_new_ +
    frs_fund$net_cf_new[i] * params$dr_new_ / 2
  frs_fund$exp_ava_new[i] <- frs_fund$ava_new[i-1] + frs_fund$net_cf_new[i] + frs_fund$exp_inv_earnings_ava_new[i]
  frs_fund$ava_new[i] <- max(min(frs_fund$exp_ava_new[i] + (frs_fund$mva_new[i] - frs_fund$exp_ava_new[i]) * 0.2,
                                 frs_fund$mva_new[i] * 1.2), 
                             frs_fund$mva_new[i] * 0.8)
  frs_fund$alloc_inv_earnings_ava_new[i] <- frs_fund$ava_new[i] - frs_fund$ava_new[i-1] - frs_fund$net_cf_new[i]
  frs_fund$ava_base_new[i] <- frs_fund$ava_new[i-1] + frs_fund$net_cf_new[i] / 2
  
  return(frs_fund)
}

inner_loop3_ava_development <- function(i,
                                        funding_list,
                                        frs_fund,
                                        params){
  # DANGER, TEMPORARY: not passing variables. will modify them and return
  
  for (class in params$class_names_no_frs_) { 
    #Do the assignment below to declutter the code
    class_fund <- funding_list[[class]]
    
    # AVA legacy development (step 2: calculate class's unadjusted AVA)
    class_fund$alloc_inv_earnings_ava_legacy[i] <- frs_fund$alloc_inv_earnings_ava_legacy[i] *
      class_fund$ava_base_legacy[i] / frs_fund$ava_base_legacy[i]
    
    class_fund$unadj_ava_legacy[i] <- class_fund$ava_legacy[i-1] + 
      class_fund$net_cf_legacy[i] + 
      class_fund$alloc_inv_earnings_ava_legacy[i]
    
    # AVA new development (step 2: calculate class's unadjusted AVA)
    class_fund$alloc_inv_earnings_ava_new[i] <- if_else(frs_fund$ava_base_new[i] == 0, 0, frs_fund$alloc_inv_earnings_ava_new[i] * class_fund$ava_base_new[i]/frs_fund$ava_base_new[i])
    class_fund$unadj_ava_new[i] <- class_fund$ava_new[i-1] + 
      class_fund$net_cf_new[i] + 
      class_fund$alloc_inv_earnings_ava_new[i]
    
    # Assign the class outputs back to the funding_list
    funding_list[[class]] <- class_fund
  }
  
  return(funding_list)
} 


inner_drop2_asset_reallocation <- function(i,
                                           funding_list,
                                           frs_fund) {
  # DANGER, TEMPORARY: not passing variables. will modify them and return  
  
  #DROP asset reallocation
  drop_fund <- funding_list$drop
  
  drop_fund$net_reallocation_legacy[i] <- drop_fund$unadj_ava_legacy[i] - drop_fund$aal_legacy[i] * frs_fund$ava_legacy[i] / frs_fund$aal_legacy[i]
  drop_fund$ava_legacy[i] <- drop_fund$unadj_ava_legacy[i] - drop_fund$net_reallocation_legacy[i]
  
  drop_fund$net_reallocation_new[i] <- if_else(frs_fund$aal_new[i] == 0, 0, drop_fund$unadj_ava_new[i] - drop_fund$aal_new[i] * frs_fund$ava_new[i] / frs_fund$aal_new[i])
  drop_fund$ava_new[i] <- drop_fund$unadj_ava_new[i] - drop_fund$net_reallocation_new[i]
  
  #Assign the DROP's updated numbers back to the funding_list
  funding_list$drop <- drop_fund
  
  return(funding_list)
}


inner_loop4_ava <- function(i,
                            funding_list,
                            frs_fund,
                            params){
  # DANGER, TEMPORARY: not passing variables. will modify them and return
  
  for (class in params$class_names_no_drop_frs_) {
    #Do the assignment below to declutter the code
    class_fund <- funding_list[[class]]
    
    #AVA legacy development (step 3: calculate class's adjusted AVA)
    class_drop_prop_legacy <- class_fund$aal_legacy[i] / (frs_fund$aal_legacy[i] - funding_list$drop$aal_legacy[i])
    class_fund$net_reallocation_legacy[i] <- class_drop_prop_legacy * funding_list$drop$net_reallocation_legacy[i]
    class_fund$ava_legacy[i] <- class_fund$unadj_ava_legacy[i] + class_fund$net_reallocation_legacy[i]
    
    #AVA new development (step 3: calculate class's adjusted AVA)
    class_drop_prop_new <- if_else((frs_fund$aal_new[i] - funding_list$drop$aal_new[i]) == 0, 0, class_fund$aal_new[i] / (frs_fund$aal_new[i] - funding_list$drop$aal_new[i]))
    class_fund$net_reallocation_new[i] <- class_drop_prop_new * funding_list$drop$net_reallocation_new[i]
    class_fund$ava_new[i] <- class_fund$unadj_ava_new[i] + class_fund$net_reallocation_new[i]
    
    #Assign the class outputs back to the funding_list
    funding_list[[class]] <- class_fund
  }
  
  return(funding_list)
}


inner_loop5_all_in_cost <- function(i,
                                    funding_list,
                                    frs_fund,
                                    params
                                    ){
  # DANGER, TEMPORARY: not passing variables. will modify them and return
  
  for (class in params$class_names_no_frs_) {
    #Do the assignment below to declutter the code
    class_fund <- funding_list[[class]]
    
    class_fund$total_ava[i] <- class_fund$ava_legacy[i] + class_fund$ava_new[i]
    
    frs_fund$total_ava[i] <- frs_fund$total_ava[i] + class_fund$total_ava[i]
    
    class_fund$ual_ava_legacy[i] <- class_fund$aal_legacy[i] - class_fund$ava_legacy[i]
    class_fund$ual_ava_new[i] <- class_fund$aal_new[i] - class_fund$ava_new[i]
    class_fund$total_ual_ava[i] <- class_fund$ual_ava_legacy[i] + class_fund$ual_ava_new[i]
    
    frs_fund$ual_ava_legacy[i] <- frs_fund$ual_ava_legacy[i] + class_fund$ual_ava_legacy[i]
    frs_fund$ual_ava_new[i] <- frs_fund$ual_ava_new[i] + class_fund$ual_ava_new[i]
    frs_fund$total_ual_ava[i] <- frs_fund$total_ual_ava[i] + class_fund$total_ual_ava[i]
    
    class_fund$ual_mva_legacy[i] <- class_fund$aal_legacy[i] - class_fund$mva_legacy[i]
    class_fund$ual_mva_new[i] <- class_fund$aal_new[i] - class_fund$mva_new[i]
    class_fund$total_ual_mva[i] <- class_fund$ual_mva_legacy[i] + class_fund$ual_mva_new[i]
    
    frs_fund$ual_mva_legacy[i] <- frs_fund$ual_mva_legacy[i] + class_fund$ual_mva_legacy[i]
    frs_fund$ual_mva_new[i] <- frs_fund$ual_mva_new[i] + class_fund$ual_mva_new[i]
    frs_fund$total_ual_mva[i] <- frs_fund$total_ual_mva[i] + class_fund$total_ual_mva[i]
    
    class_fund$fr_mva[i] <- class_fund$total_mva[i] / class_fund$total_aal[i]
    class_fund$fr_ava[i] <- class_fund$total_ava[i] / class_fund$total_aal[i]
    
    frs_fund$fr_mva[i] <- frs_fund$total_mva[i] / frs_fund$total_aal[i]
    frs_fund$fr_ava[i] <- frs_fund$total_ava[i] / frs_fund$total_aal[i]
    
    #Contribution analysis
    class_fund$total_er_cont[i] <- class_fund$total_er_db_cont[i] + class_fund$total_er_dc_cont[i] + class_fund$total_solv_cont[i]
    frs_fund$total_er_cont[i] <- frs_fund$total_er_cont[i] + class_fund$total_er_cont[i]
    
    class_fund$total_er_cont_rate[i] <- class_fund$total_er_cont[i] / class_fund$total_payroll[i]
    frs_fund$total_er_cont_rate[i] <- frs_fund$total_er_cont[i] / frs_fund$total_payroll[i]
    
    #All-in-cost analysis
    class_fund$total_er_cont_real[i] <- class_fund$total_er_cont[i] / (1 + params$inflation_)^(class_fund$year[i] - params$start_year_)
    frs_fund$total_er_cont_real[i] <- frs_fund$total_er_cont_real[i] + class_fund$total_er_cont_real[i]
    
    if (i == 2) {
      class_fund$cum_er_cont_real[i] <- class_fund$total_er_cont_real[i]
    } else {
      class_fund$cum_er_cont_real[i] <- class_fund$cum_er_cont_real[i - 1] + class_fund$total_er_cont_real[i]  
    } # end if else
    
    frs_fund$cum_er_cont_real[i] <- frs_fund$cum_er_cont_real[i] + class_fund$cum_er_cont_real[i]
    
    class_fund$total_ual_mva_real[i] <- class_fund$total_ual_mva[i] / (1 + params$inflation_)^(class_fund$year[i] - params$start_year_)
    frs_fund$total_ual_mva_real[i] <- frs_fund$total_ual_mva_real[i] + class_fund$total_ual_mva_real[i]
    
    class_fund$all_in_cost_real[i] <- class_fund$cum_er_cont_real[i] + class_fund$total_ual_mva_real[i]
    frs_fund$all_in_cost_real[i] <- frs_fund$all_in_cost_real[i] + class_fund$all_in_cost_real[i]
    
    
    #Assign the class outputs back to the funding_list
    funding_list[[class]] <- class_fund
  } #.. end class in class_names_no_frs loop
  
  return(list(funding_list = funding_list,
              frs_fund = frs_fund))
}


inner_loop6_amortization <- function(i,
                                     funding_list,
                                     current_hire_debt_layer_list,
                                     future_hire_debt_layer_list,
                                     current_hire_amo_period_list,
                                     future_hire_amo_period_list,
                                     current_hire_amo_payment_list,
                                     future_hire_amo_payment_list,
                                     amo_pay_growth,
                                     params){
  # DANGER, TEMPORARY: not passing variables. will modify them and return
    
  ####Amortization calculations
  for (class in params$class_names_no_frs_) {
    #Do the assignment below to declutter the code
    class_fund <- funding_list[[class]] # djb: here, class_fund is not modified
    
    current_hire_debt_layer_table <- current_hire_debt_layer_list[[class]]
    future_hire_debt_layer_table <- future_hire_debt_layer_list[[class]]
    
    current_hire_amo_period_table <- current_hire_amo_period_list[[class]]
    future_hire_amo_period_table <- future_hire_amo_period_list[[class]]
    
    current_hire_amo_pay_table <- current_hire_amo_payment_list[[class]]
    future_hire_amo_pay_table <- future_hire_amo_payment_list[[class]]
    
    #Amortization for legacy hires
    current_hire_debt_layer_table[i, 2:ncol(current_hire_debt_layer_table)] <- 
      current_hire_debt_layer_table[i-1, 1:(ncol(current_hire_debt_layer_table)-1)] * (1 + params$dr_current_) - 
      current_hire_amo_pay_table[i-1, 1:ncol(current_hire_amo_pay_table)] * (1 + params$dr_current_)^0.5
    
    current_hire_debt_layer_table[i, 1] <- class_fund$ual_ava_legacy[i] - sum(current_hire_debt_layer_table[i, 2:ncol(current_hire_debt_layer_table)])
    
    current_hire_amo_pay_table[i, 1:ncol(current_hire_amo_pay_table)] <- get_pmt(r = params$dr_current_,
                                                                                 g = amo_pay_growth,
                                                                                 nper = current_hire_amo_period_table[i, 1:ncol(current_hire_amo_period_table)],
                                                                                 pv = current_hire_debt_layer_table[i, 1:(ncol(current_hire_debt_layer_table)-1)],
                                                                                 t = 0.5)
    
    #Amortization for future hires
    future_hire_debt_layer_table[i, 2:ncol(future_hire_debt_layer_table)] <- 
      future_hire_debt_layer_table[i-1, 1:(ncol(future_hire_debt_layer_table)-1)] * (1 + params$dr_new_) -
      future_hire_amo_pay_table[i-1, 1:ncol(future_hire_amo_pay_table)] * (1 + params$dr_new_)^0.5
    
    future_hire_debt_layer_table[i, 1] <- class_fund$ual_ava_new[i] - sum(future_hire_debt_layer_table[i, 2:ncol(future_hire_debt_layer_table)])
    
    future_hire_amo_pay_table[i, 1:ncol(future_hire_amo_pay_table)] <- get_pmt(r = params$dr_new_,
                                                                               g = amo_pay_growth,
                                                                               nper = future_hire_amo_period_table[i, 1:ncol(future_hire_amo_period_table)],
                                                                               pv = future_hire_debt_layer_table[i, 1:(ncol(future_hire_debt_layer_table)-1)],
                                                                               t = 0.5)
    
    #Assign the amortization outputs back to respective tables
    current_hire_debt_layer_list[[class]] <- current_hire_debt_layer_table
    future_hire_debt_layer_list[[class]] <- future_hire_debt_layer_table
    
    current_hire_amo_payment_list[[class]] <- current_hire_amo_pay_table
    future_hire_amo_payment_list[[class]] <- future_hire_amo_pay_table
  }
  
  return(list(
    current_hire_debt_layer_list = current_hire_debt_layer_list,
    future_hire_debt_layer_list = future_hire_debt_layer_list,
    current_hire_amo_payment_list = current_hire_amo_payment_list,
    future_hire_amo_payment_list = future_hire_amo_payment_list
  ))
}



main_loop <- function(funding_list,
                      liability_list,
                      current_hire_amo_payment_list,
                      future_hire_amo_payment_list,
                      current_hire_amo_period_list,
                      future_hire_amo_period_list,
                      current_hire_debt_layer_list,
                      future_hire_debt_layer_list,
                      amo_pay_growth,
                      params){
  
  # return funding_list
  
  # djb - why can't we do one loop without frs?? (or is it updated within) and adjust for drop?
  # could we, for example?:
  #   - stack the classes
  #   - loop through the years to calc class values (because we need lags)
  #   - collapse to get frs non-drop totals
  #   - loop through the years to calc drop values, relying as needed on regular and on frs-nondrop values
  #   - combine to get frs+drop totals
  
  # djb: to help figure out how to reorganize this:
  # djb: when if ever do the class values rely on the frs values?
  # djb: when does drop rely on frs or on a class value?
  
  # djb: steps seem to be:
  #   - calc non-drop class values
  #   - calc FRS working totals because we need some FRS values for drop
  #   - calc drop values - here, e.g., we need FRS NC rate for drop NC rate
  
  # where does payroll_db_legacy_ratio come from?  
  
  # Key strategy: Loop through each year, then each class. The class loop should
  # exclude FRS, and may exclude DROP depending on the calculations
  
  for (i in 2:nrow(funding_list[[1]])) { # loop 2nd year to last year
    frs_fund <- funding_list$frs
    
    # CAUTION: I modify calling-environment variables in the functions below
    
    result <- inner_loop1_payroll_benefits(i,
                                           funding_list,
                                           liability_list,
                                           frs_fund,
                                           params) #.. no_drop_frs loop: payroll, benefits, refunds, normal cost, AAL
    # list2env(result, envir = parent.frame())  # works but not as easy to understand
    funding_list <- result$funding_list
    frs_fund <- result$frs_fund
    
    funding_list <- inner_drop1_funding(i,
                                        funding_list,
                                        frs_fund,
                                        params) #.. open code: DROP payroll, benefits, NC, AL -- "makeshift"
    
    frs_fund <- inner_frs_fund1(i,
                                frs_fund,
                                funding_list$drop) # FRS totals: update with DROP -- payroll, benefits, refunds, NC, AL
    
    result <- inner_loop2_funding(i,
                                  funding_list,
                                  frs_fund,
                                  current_hire_amo_payment_list,
                                  future_hire_amo_payment_list,
                                  params$return_scenarios,
                                  params$return_scen_index,
                                  params) # NC, EEC, ERC-DB, admin expense
    funding_list <- result$funding_list
    frs_fund <- result$frs_fund    
    
    frs_fund <- inner_frs_fund2(i,
                                frs_fund,
                                params) 
    
    funding_list <- inner_loop3_ava_development(i,
                                                funding_list,
                                                frs_fund,
                                                params)
    
    funding_list <- inner_drop2_asset_reallocation(i,
                                                   funding_list,
                                                   frs_fund) #.. open code: DROP assets reallocation

    funding_list <- inner_loop4_ava(i,
                                    funding_list,
                                    frs_fund,
                                    params)

    result <- inner_loop5_all_in_cost(i,
                                      funding_list,
                                      frs_fund,
                                      params) # AVA UAL FR projections all-in cost
    funding_list <- result$funding_list
    frs_fund <- result$frs_fund    
    
    result <- inner_loop6_amortization(i,
                                       funding_list,
                                       current_hire_debt_layer_list,
                                       future_hire_debt_layer_list,
                                       current_hire_amo_period_list,
                                       future_hire_amo_period_list,
                                       current_hire_amo_payment_list,
                                       future_hire_amo_payment_list,
                                       amo_pay_growth,
                                       params)

    # djb maybe these next 4 lists need to be returned as a second list??
    current_hire_debt_layer_list <- result$current_hire_debt_layer_list
    future_hire_debt_layer_list <- result$future_hire_debt_layer_list
    current_hire_amo_payment_list <- result$current_hire_amo_payment_list
    future_hire_amo_payment_list <- result$future_hire_amo_payment_list    
    
    #Assign the FRS's updated numbers back to the funding_list
    funding_list$frs <- frs_fund
    
  } #.. end year loop
  return(funding_list)
} # end function main_loop ----



################### Model function starts here ####################

get_funding_data <- function(
    params,
    return = "unstacked" # or "stacked"
) {
  
  # unpack parameters
  funding_list <- params$funding_list
  current_amort_layers_table <- params$current_amort_layers_table
  wf_data_list <- params$wf_data_list
  entrant_profile_table_list <- params$entrant_profile_table_list
  salary_headcount_table_list <- params$salary_headcount_table_list
  mort_table_list <- params$mort_table_list
  mort_retire_table_list <- params$mort_retire_table_list
  separation_rate_table_list <- params$separation_rate_table_list  
  
  funding_lag <- params$funding_lag_
  model_period <- params$model_period_
  
  cola_tier_1_active_constant <- params$cola_tier_1_active_constant_
  cola_tier_1_active <- params$cola_tier_1_active_
  cola_tier_2_active <- params$cola_tier_2_active_
  cola_tier_3_active <- params$cola_tier_3_active_
  cola_current_retire <- params$cola_current_retire_
  cola_current_retire_one <- params$cola_current_retire_one_
  one_time_cola <- params$one_time_cola_
  
  #inputs below are for the liability model
  non_special_db_new_ratio <- params$non_special_db_new_ratio_
  special_db_new_ratio <- params$special_db_new_ratio_
  
  #inputs below are for the funding model
  amo_period_new <- params$amo_period_new_
  
  
  # returns updated funding_list
  

  # unpack funding_list into a stacked tibble
  funding_list_stacked <- bind_rows(funding_list, .id = "class")
  # djb save it to see if I can reproduce using stacked input data
  saveRDS(funding_list_stacked, fs::path(stackdir, "funding_list_stacked.rds"))
  
  #### Produce liability outputs for each class (except DROP and FRS system) ----
  
  # Use mclapply to run the liability model in parallel. May not work properly
  # with Windows OS or API. Switch back to lapply if needed. When working,
  # mclapply will be about twice as fast as lapply.
  a <- proc.time()
  
  # get values of arguments to get_liability_data for this class and then call it
  call_get_liability_data <- function(class_name) {
    # create lists of data frames so that get_liablity_data does not have to (dangerously) pull data from the global environment with assign
    
    element_name <- paste0(class_name, "_wf_data")
    wf_data <- wf_data_list[[element_name]]
    
    ben_payment_current <- params[[paste0(class_name, "_ben_payment_current_")]]
    retiree_pop_current <- params[[paste0(class_name, "_retiree_pop_current_")]]
    pvfb_term_current <- params[[paste0(class_name, "_pvfb_term_current_")]]
    
    element_name <- paste0(class_name, "_entrant_profile_table")
    entrant_profile_table <- entrant_profile_table_list[[element_name]]
    
    element_name <- paste0(class_name, "_salary_headcount_table")
    salary_headcount_table <- salary_headcount_table_list[[element_name]]    
    
    element_name <- paste0(class_name, "_mort_table")
    mort_table <- mort_table_list[[element_name]]     
    
    element_name <- paste0(class_name, "_separation_rate_table")
    separation_rate_table <- separation_rate_table_list[[element_name]]         
    
    element_name <- paste0(class_name, "_mort_retire_table")
    mort_retire_table <- mort_retire_table_list[[element_name]]         
    
    lm_env$get_liability_data(class_name, 
                       wf_data, 
                       ben_payment_current, 
                       retiree_pop_current,
                       pvfb_term_current,
                       entrant_profile_table,
                       salary_headcount_table,
                       mort_table,
                       mort_retire_table,
                       separation_rate_table,
                       params)
  }
  
  liability_list <- mclapply(
                      X = params$class_names_no_drop_frs_, 
                      FUN = call_get_liability_data,
                      # Set mc.cores to 1 for compatibility with Windows
                      mc.cores = 1
                    )
  names(liability_list) <- params$class_names_no_drop_frs_
  b <- proc.time()
  print("liability_list time")
  print(b - a)
  
  # FOR LATER USE (djb): unpack liability_list into a stacked tibble
  liability_list_stacked <- bind_rows(liability_list, .id = "class")
  # save it to see if I can reproduce using stacked input data
  saveRDS(liability_list_stacked, fs::path(stackdir, "liability_list_stacked.rds"))
  
  # FOR LATER USE (djb) classes_stacked
  classes_stacked <- funding_list_stacked |> 
    filter(class %in% params$class_names_no_drop_frs_) |>
    left_join(liability_list_stacked,
              by = join_by(class, year)) |> 
    left_join(params$nc_cal_ |> 
                mutate(class = str_replace(class, "_", "")) |> # make senior management uniform SOON!!
                rename(nc_cal = nc_cal_), # djb this is correct - refers to a column name not the global variable
              by = join_by(class)) |> 
    arrange(class, year) |> # make sure we get the lags right
    # new variables,  use lag to align with the funding mechanism
    mutate(# payroll calibration
           payroll_db_legacy_ratio = lag(payroll_db_legacy_est / total_payroll_est),
           payroll_db_new_ratio = lag(payroll_db_new_est / total_payroll_est),
           payroll_dc_legacy_ratio = lag(payroll_dc_legacy_est / total_payroll_est),
           payroll_dc_new_ratio = lag(payroll_dc_new_est / total_payroll_est),
           
           # normal cost calibration/projection
           nc_rate_db_legacy = lag(nc_rate_db_legacy_est * nc_cal),
           nc_rate_db_new = lag(nc_rate_db_new_est * nc_cal),
           
           # aal calibration - no great way to do this in a chain so use 4 ifelse statements
           aal_legacy = if_else(year == first(year), aal_legacy_est, aal_legacy),
           total_aal = if_else(year == first(year), total_aal_est, total_aal),
           
           ual_ava_legacy = ifelse(year == first(year),
                                   aal_legacy - ava_legacy,
                                   ual_ava_legacy),
           
           total_ual_ava = ifelse(year == first(year),
                                  total_aal - total_ava,
                                  total_ual_ava),
           .by=class)
  
  # names(flstacked) |> sort()
  
  # djb: examine the drop comments immediately below
  #Create a "liability" data for the DROP plan
  #This is a makeshift solution for now. Proper modeling of the DROP plan will be done in the future.
  # drop_liability_output <- funding_list[["drop"]]

  #### Model calibration ----
  # does the same thing as classes_stacked above does
  a <- proc.time()
  for (class in params$class_names_no_drop_frs_) {
    
    fund_data <- funding_list[[class]]
    liab_data <- liability_list[[class]]
    
    #payroll calibration
    fund_data$payroll_db_legacy_ratio <- lag(liab_data$payroll_db_legacy_est / liab_data$total_payroll_est) #use lag to align with the funding mechanism
    fund_data$payroll_db_new_ratio <- lag(liab_data$payroll_db_new_est / liab_data$total_payroll_est)
    fund_data$payroll_dc_legacy_ratio <- lag(liab_data$payroll_dc_legacy_est / liab_data$total_payroll_est)
    fund_data$payroll_dc_new_ratio <- lag(liab_data$payroll_dc_new_est / liab_data$total_payroll_est)
    
    #normal cost calibration/projection
    nc_cal <- params[[paste0(class, "_nc_cal_")]]
    fund_data$nc_rate_db_legacy <- lag(liab_data$nc_rate_db_legacy_est * nc_cal)
    fund_data$nc_rate_db_new <- lag(liab_data$nc_rate_db_new_est * nc_cal)
    
    #accrued liability calibration
    fund_data$aal_legacy[1] <- liab_data$aal_legacy_est[1]
    fund_data$total_aal[1] <- liab_data$total_aal_est[1]
    fund_data$ual_ava_legacy[1] <- fund_data$aal_legacy[1] - fund_data$ava_legacy[1]
    fund_data$total_ual_ava[1] <- fund_data$total_aal[1] - fund_data$total_ava[1]
    
    funding_list[[class]] <- fund_data
  } # end model calibration loop
  
  ####Set up amo period sequences
  #Create two lists, one for the current hire amo periods, and one for new hire amo periods
  # Each has 8 elements (1 per class excl. frs), each element is a matrix 31 years x 21 columns
  # current_hire_amo_period_list$regular
  
  # djb Determine amo payment parameters BEFORE calling routines related to amo_payment ----
  
  #Determine the number of columns for the amo period tables
  amo_col_num <- max(current_amort_layers_table$amo_period, amo_period_new + params$funding_lag_)  
  
  #Level % or level $ for debt amortization 
  # create LOCAL variable amo_pay_growth - I moved this up from below
  amo_pay_growth <- ifelse(params$amo_method_ == "level $", 0, params$amo_pay_growth_)
  
  
  current_hire_amo_period_list <- purrr::set_names(params$class_names_no_frs_) |> 
                                  # returns a list of 8 matrices, 31 x 21 (nyears x amo_col_num)
                                  purrr::map(
                                             get_current_hire_amo_period_table,
                                             current_amort_layers_table,
                                             class_amo_layers_table,
                                             amo_col_num,
                                             params)  
  
  future_hire_amo_period_list <- purrr::set_names(params$class_names_no_frs_) |> 
                                 # returns a list of 8 matrices, 31 x 21 (nyears x amo_col_num)
                                 purrr::map(
                                            get_future_hire_amo_period_table,
                                            amo_col_num,
                                            params)
  

  
  ####Set up the UAAL layer and amo payment tables for current members and initialize the first UAAL layer and amo payments
  #UAAL layers tables for current members
  current_hire_debt_layer_list <- purrr::set_names(params$class_names_no_frs_) |> 
                                  # returns a list of 8 matrices, 31 x 22 (nyears x amo_col_num+1)
                                  purrr::map(
                                             get_current_hire_debt_layer_table,
                                             current_amort_layers_table,
                                             amo_col_num,
                                             params)

  current_hire_amo_payment_list <- purrr::set_names(params$class_names_no_frs_) |> 
                                   # returns a list of 8 matrices, 31 x 21 (nyears x amo_col_num)
                                   purrr::map(
                                              get_current_hire_amo_payment_table,
                                              current_hire_amo_payment_table,
                                              current_hire_debt_layer_list,
                                              current_hire_amo_period_list,
                                              amo_col_num,
                                              amo_pay_growth, # DO NOT CHANGE TO params$amo_pay_growth, this can be different
                                              params)
    
  ####Set up the UAL layer and amo payment tables for new members
  future_hire_debt_layer_list <- purrr::set_names(params$class_names_no_frs_) |> 
                                 # returns a list of 8 matrices, 31 x 22 (nyears x amo_col_num+1)
                                 purrr::map( 
                                            get_future_hire_debt_layer_table,
                                            amo_col_num,
                                            params)
  
  #Amo payment tables for new members
  future_hire_amo_payment_list <- purrr::set_names(params$class_names_no_frs_) |> 
                                  # returns a list of 8 matrices, 31 x 21 (nyears x amo_col_num)
                                  purrr::map(
                                             get_future_hire_amo_payment_table,
                                             amo_col_num,
                                             params)
  
  # djb: create nested tibble with these matrices
  # verify that all names are the same and in the same order
  amo_table <- tibble(
    class = names(current_hire_amo_period_list),
    
    current_hire_amo_period = purrr::map(current_hire_amo_period_list, \(x) x),
    current_hire_amo_payment = purrr::map(current_hire_amo_payment_list, \(x) x),
    current_hire_debt_layer = purrr::map(current_hire_debt_layer_list, \(x) x),
    
    future_hire_amo_period = purrr::map(future_hire_amo_period_list, \(x) x),
    future_hire_amo_payment = purrr::map(future_hire_amo_payment_list, \(x) x),
    future_hire_debt_layer = purrr::map(future_hire_debt_layer_list, \(x) x)
  )

  # here's how to verify that the names are all properly aligned
  # amo_table |> 
  #   mutate(across(-class, \(x) names(x)))

  # djb: this next block seems DANGEROUS - they modify a GLOBAL variable,
  # return_scenarios, and further, use hard-coded values
  
  #Set return values for "model" and "assumption" scenarios
  #Set 2023 returns and update "model" and "assumption" scenarios
  # djb CAUTION does this need to be in funding model?? ----
  # return_scenarios <- params$return_scenarios |> 
  #   mutate(across(-year, \(x) ifelse(year==2023, params$return_2023_, x)),
  #          model=ifelse(year > 2023, params$model_return_, model),
  #          assumption=ifelse(year > 2023, params$dr_current_, assumption))    
  
  #Return scenario
  # return_scen <- "recur_recession"
  # return_scen_index <- which(colnames(params$return_scenarios) == params$return_scen_)
  

  funding_list <- main_loop(funding_list = funding_list,
                            liability_list = liability_list,
                            current_hire_amo_payment_list = current_hire_amo_payment_list,
                            future_hire_amo_payment_list = future_hire_amo_payment_list,
                            current_hire_amo_period_list = current_hire_amo_period_list,
                            future_hire_amo_period_list = future_hire_amo_period_list,
                            current_hire_debt_layer_list = current_hire_debt_layer_list,
                            future_hire_debt_layer_list = future_hire_debt_layer_list,
                            amo_pay_growth,
                            params)
  
  if (return == "stacked") {
    output <- bind_rows(funding_list, .id = "class")
  } else {
    output <- funding_list
  }

  return(output)
  
}

