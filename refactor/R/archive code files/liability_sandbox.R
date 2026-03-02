#################################################################
##                       Liability Model                       ##
#################################################################
library(dplyr)
# library to read xlsx files
library(readxl)


# get_wf_active -----------------------------------------------------------

wf_active_df_s <- wf_data_env$wf_active_df_s
benefit_val_table_s <-  bf_data_env$benefit_data_s$benefit_val_table_s
params <- as.list(pendata::frs$params_env)

params$component_meta <- readxl::read_excel(
  here::here("refactor","R","component.xlsx"),
  sheet = "component_meta"
)

params$plan_alloc <- readxl::read_excel(
  here::here("refactor","R","component.xlsx"),
  sheet = "plan_alloc"
)

get_wf_active_df_final_s_2 <- function(wf_active_df_s,
                                       benefit_val_table_s,
                                       params) {
  
  safe_divide <- function(num, den) if_else(den == 0, 0, num / den)
  
  # components relevant to ACTIVE workflow + plan types
  meta_active <- params$component_meta %>%
    filter(str_detect(applies_to, "active")) %>%
    select(component, plan_type)
  
  active_components <- meta_active %>% pull(component)
  
  # base: attach benefit values
  base <- wf_active_df_s %>%
    filter(year <= params$start_year_ + params$model_period_) %>%
    mutate(entry_year = year - (age - entry_age)) %>%
    left_join(
      benefit_val_table_s,
      by = c("class", "entry_age", "age" = "term_age", "year" = "term_year", "entry_year")
    ) %>%
    select(
      class, year, entry_age, age, entry_year,
      n_active, salary, indv_norm_cost,
      pvfb_db_wealth_at_current_age, pvfnc_db
    )
  
  # allocate +  attach plan_type
  long <- base %>%
    left_join(
      params$plan_alloc %>% filter(component %in% active_components),
      by = join_by(class, entry_year >= entry_year_ll, entry_year < entry_year_ul)
    ) %>%
    # mutate(
    #   # robust share: handle NA + character shares
    #   share = as.numeric(share),
      # share = coalesce(share, 0)
    # ) %>%
    left_join(meta_active, by = "component") %>%
    mutate(
      n_comp  = n_active * share,
      payroll = salary * n_comp,
      nc_dol  = if_else(plan_type == "db", indv_norm_cost * salary * n_comp, 0),
      pvfb    = if_else(plan_type == "db", pvfb_db_wealth_at_current_age * n_comp, 0),
      pvfnc   = if_else(plan_type == "db", pvfnc_db * n_comp, 0), 
      aal_active  = pvfb - pvfnc
    )
  
  # summarise by component and pivot wide
  out <- long %>%
    group_by(class, year, component) %>%
    summarise(
      payroll      = sum(payroll, na.rm = TRUE),
      nc_rate      = safe_divide(sum(nc_dol, na.rm = TRUE), sum(payroll, na.rm = TRUE)),
      pvfb_active  = sum(pvfb, na.rm = TRUE),
      pvfnc        = sum(pvfnc, na.rm = TRUE),
      aal_active   = sum(aal_active, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    pivot_wider(
      names_from  = component,
      values_from = c(payroll, nc_rate, pvfb_active, pvfnc, aal_active),
      names_glue  = "{.value}_{component}_est",
      values_fill = 0
    )
  
  totals <- long %>%
    group_by(class, year) %>%
    summarise(
      total_payroll_est = sum(payroll, na.rm = TRUE),
      total_n_active    = sum(n_comp,  na.rm = TRUE),
      
      payroll_db_est = sum(if_else(plan_type == "db", payroll, 0), na.rm = TRUE),
      payroll_dc_est = sum(if_else(plan_type == "dc", payroll, 0), na.rm = TRUE),
      
      total_nc_rate_est = safe_divide(
        sum(if_else(plan_type == "db", nc_dol, 0), na.rm = TRUE),
        sum(if_else(plan_type == "db", payroll, 0), na.rm = TRUE)
      ),
      .groups = "drop"
    )
  
  out <- out %>%
    left_join(totals, by = c("class", "year"))
  
  out
}


get_wf_active_df_final_s <- function(wf_active_df_s,
                                     benefit_val_table_s,
                                     params){
  #Join wf active table with FinalData table to calculate the overall payroll, normal costs, PVFB, and PVFS each year
  wf_active_df_final_s <- wf_active_df_s %>%
    filter(year <= params$start_year_ + params$model_period_) %>% 
    mutate(entry_year = year - (age - entry_age)) %>% 
    left_join(benefit_val_table_s, by = c("class", "entry_age", "age" = "term_age", "year" = "term_year", "entry_year")) %>% 
    select(class, entry_age, age, year, entry_year, n_active, indv_norm_cost, salary, 
           pvfb_db_wealth_at_current_age, pvfnc_db, pvfs_at_current_age) %>% 
    left_join(params$db_dc_legacy_table, 
              by = join_by(class,
                           entry_year >= year_ll, 
                           entry_year < year_ul)) %>%
    left_join(params$db_dc_new_table,
              by = join_by(class,
                           entry_year >= new_year_ll,
                           entry_year < new_year_ul)) %>%
    replace(is.na(.), 0) %>%
    # filter(n_active > 0) %>% 
    #allocate members to plan designs based on entry year
    mutate(n_active_db_legacy = n_active * db_legacy,
           n_active_db_new = n_active * db_new,
           n_active_dc_legacy = n_active * dc_legacy,
           n_active_dc_new = n_active * dc_new) %>%
    group_by(class, year) %>% 
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
  
  return(wf_active_df_final_s)
}


wf_active_df_final_s_2 <- get_wf_active_df_final_s_2(wf_active_df_s, benefit_val_table_s, params)
wf_active_df_final_s <- get_wf_active_df_final_s(wf_active_df_s, benefit_val_table_s, params)


n2  <- names(wf_active_df_final_s_2)
n1  <- names(wf_active_df_final_s)

common_cols   <- intersect(n2, n1)
only_in_2     <- setdiff(n2, n1)
only_in_old   <- setdiff(n1, n2)

common_cols
only_in_2 
only_in_old

a2 <- wf_active_df_final_s_2 %>% select(all_of(common_cols)) %>% arrange(class, year)
b2 <- wf_active_df_final_s   %>% select(all_of(common_cols)) %>% arrange(class, year)

all.equal(a2, b2, tolerance = 1e-10)


# get_wf_term -------------------------------------------------------------


get_wf_term_df_final_s_2 <- function(wf_term_df_s, benefit_val_table_s, benefit_table_s, params) {
  
  safe_divide <- function(num, den) if_else(den == 0, 0, num / den)
  
  # TERM components (based on metadata)
  meta_term <- params$component_meta %>%
    filter(str_detect(applies_to, "term")) %>%
    select(component, plan_type)
  
  term_components <- meta_term$component
  
  # Base term records + compute PV at termination 
  base <- wf_term_df_s %>%
    filter(year <= params$start_year_ + params$model_period_, n_term > 0) %>%
    mutate(entry_year = year - (age - entry_age)) %>%
    # brings pvfb_db_at_term_age (numerator piece)
    left_join(benefit_val_table_s, by = c("class", "entry_age", "term_year", "entry_year")) %>%
    # brings cum_mort_dr at current age via dist_age/dist_year (denominator piece)
    left_join(
      benefit_table_s %>% select(-pvfb_db_at_term_age),
      by = c("class", "entry_age", "age" = "dist_age", "year" = "dist_year", "term_year", "entry_year")
    ) %>%
    mutate(
      pvfb_db_at_term_age = coalesce(pvfb_db_at_term_age, 0),
      cum_mort_dr_current = coalesce(cum_mort_dr, 0),
      pvfb_db_term        = safe_divide(pvfb_db_at_term_age, cum_mort_dr_current)
    )
  
  # Allocate n_term to components using plan_alloc shares
  long <- base %>%
    left_join(
      params$plan_alloc %>% filter(component %in% term_components),
      by = join_by(class, entry_year >= entry_year_ll, entry_year < entry_year_ul)
    ) %>%
    mutate(share = coalesce(as.numeric(share), 0)) %>%
    left_join(meta_term, by = "component") %>%
    mutate(
      n_comp   = n_term * share,
      # Term AAL only meaningful for DB components
      aal_term = if_else(plan_type == "db", pvfb_db_term * n_comp, 0)
    )
  
  # Component-level outputs (wide)
  out <- long %>%
    group_by(class, year, component) %>%
    summarise(
      aal_term = sum(aal_term, na.rm = TRUE),
      # n_term   = sum(n_comp,   na.rm = TRUE),
      .groups = "drop"
    ) %>%
    pivot_wider(
      names_from  = component,
      values_from = c(aal_term), #, n_term),
      names_glue  = "{.value}_{component}_est",
      values_fill = 0
    )
  
  return(out)
}


get_wf_term_df_final_s <- function(
    wf_term_df_s,
    benefit_val_table_s,
    benefit_table_s,
    params
) {
  #Term table
  wf_term_df_final_s <- wf_term_df_s %>% 
    filter(year <= params$start_year_ + params$model_period_,
           n_term > 0) %>% 
    mutate(entry_year = year - (age - entry_age)) %>% 
    #join benefit_val_table to get PV_DB_Benefit (the present value of benefits at termination)
    left_join(benefit_val_table_s, by = c("class", "entry_age", "term_year", "entry_year")) %>% 
    select(class, entry_age, age, year, term_year, entry_year, dist_age, n_term, pvfb_db_at_term_age) %>% 
    #join benefit_table to get the surv_DR at current age
    left_join(benefit_table_s %>% 
                select(-pvfb_db_at_term_age), 
              by = c("class", "entry_age", "age" = "dist_age", "year" = "dist_year", "term_year", "entry_year")) %>% 
    select(class, entry_age, age, year, term_year, entry_year, dist_age, n_term, pvfb_db_at_term_age, cum_mort_dr) %>% 
    #rename to clarify variables' meanings
    rename(cum_mort_dr_current = cum_mort_dr) %>% 
    left_join(params$db_dc_legacy_table, 
              by = join_by(class,
                           entry_year >= year_ll, 
                           entry_year < year_ul)) %>%
    left_join(params$db_dc_new_table,
              by = join_by(class,
                           entry_year >= new_year_ll,
                           entry_year < new_year_ul)) %>%
    mutate(
      #pvfb_db_term = First DB benefit * annuity factor at retirement * surv_DR at retirement / surv_DR at current time
      #Note that pvfb_db_at_term_ag = First DB benefit * annuity factor at retirement * surv_DR at retirement
      pvfb_db_term = pvfb_db_at_term_age / cum_mort_dr_current,
      n_term_db_legacy = n_term * db_legacy,
      n_term_db_new = n_term * db_new
    ) %>% 
    group_by(class, year) %>% 
    summarise(aal_term_db_legacy_est = sum(pvfb_db_term * n_term_db_legacy),
              aal_term_db_new_est = sum(pvfb_db_term * n_term_db_new)
    ) %>% 
    ungroup()
  
  return(wf_term_df_final_s)
}

# Compare term results
wf_term_df_s <- wf_data_env$wf_term_df_s
benefit_table_s <- bf_data_env$benefit_data_s$benefit_table_s
wf_term_df_final_s_2 <- get_wf_term_df_final_s_2(wf_term_df_s, benefit_val_table_s, benefit_table_s, params)
wf_term_df_final_s <- get_wf_term_df_final_s(wf_term_df_s, benefit_val_table_s, benefit_table_s, params)

identical(wf_term_df_final_s_2, wf_term_df_final_s)


# get_wf_refund -----------------------------------------------------------


get_wf_refund_df_final_s_2 <- function(wf_refund_df_s, benefit_table_s, params) {
  
  # REFUND components (based on metadata)
  meta_refund <- params$component_meta %>%
    filter(str_detect(applies_to, "refund")) %>%
    select(component, plan_type)
  
  refund_components <- meta_refund$component
  
  # Base refund records + attach DB employee balance
  base <- wf_refund_df_s %>%
    filter(year <= params$start_year_ + params$model_period_, n_refund > 0) %>%
    mutate(entry_year = year - (age - entry_age)) %>%
    left_join(
      benefit_table_s,
      by = c("class", "entry_age", "age" = "dist_age", "year" = "dist_year", "term_year", "entry_year")
    ) %>%
    mutate(db_ee_balance = coalesce(db_ee_balance, 0))
  
  # Allocate to components using plan_alloc shares
  long <- base %>%
    left_join(
      params$plan_alloc %>% filter(component %in% refund_components),
      by = join_by(class, entry_year >= entry_year_ll, entry_year < entry_year_ul)
    ) %>%
    mutate(share = coalesce(as.numeric(share), 0)) %>%
    left_join(meta_refund, by = "component") %>%
    mutate(
      n_comp = n_refund * share,
      refund = if_else(plan_type == "db", db_ee_balance * n_comp, 0)
    ) 
  
  # Component-level outputs (wide)
  out <- long %>%
    group_by(class, year, component) %>%
    summarise(
      refund   = sum(refund, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    pivot_wider(
      names_from  = component,
      values_from = c(refund),
      names_glue  = "{.value}_{component}_est",
      values_fill = 0
    )
  
    return(out)
}

get_wf_refund_df_final_s <- function(wf_refund_df_s,
                                     benefit_table_s,
                                     params){
  # Join wf refund table with benefit table to calculate the overall refunds each year
  wf_refund_df_final_s <- wf_refund_df_s %>% 
    filter(year <= params$start_year_ + params$model_period_,
           n_refund > 0) %>% 
    mutate(entry_year = year - (age - entry_age)) %>% 
    left_join(benefit_table_s, 
              by = c("class", "entry_age", "age" = "dist_age", "year" = "dist_year", "term_year", "entry_year")) %>% 
    select(class, entry_age, age, year, term_year, entry_year, n_refund, db_ee_balance) %>% 
    left_join(params$db_dc_legacy_table, 
              by = join_by(class,
                           entry_year >= year_ll, 
                           entry_year < year_ul)) %>%
    left_join(params$db_dc_new_table,
              by = join_by(class,
                           entry_year >= new_year_ll,
                           entry_year < new_year_ul)) %>%
    #allocate members to plan designs based on entry year
    mutate(n_refund_db_legacy = n_refund * db_legacy,
           n_refund_db_new = n_refund * db_new
    ) %>%
    # mutate(n_refund_db_legacy = if_else(entry_year < 2018, 
    #                                     n_refund * ratios$db_legacy_before_2018_ratio,
    #                                     if_else(entry_year < params$new_year_, 
    #                                             n_refund * ratios$db_legacy_after_2018_ratio, 
    #                                             0)),
    #        n_refund_db_new = if_else(entry_year < params$new_year_, 0, n_refund * ratios$db_new_ratio)
    # ) %>%
    group_by(class, year) %>% 
    summarise(refund_db_legacy_est = sum(db_ee_balance * n_refund_db_legacy),
              refund_db_new_est = sum(db_ee_balance * n_refund_db_new)
    ) %>% 
    ungroup()
  
  return(wf_refund_df_final_s)
}

wf_refund_df_s <- wf_data_env$wf_refund_df_s

wf_refund_df_final_s <- get_wf_refund_df_final_s(wf_refund_df_s, benefit_table_s, params)
wf_refund_df_final_s_2 <- get_wf_refund_df_final_s_2(wf_refund_df_s, benefit_table_s, params)

names(wf_refund_df_final_s)
names(wf_refund_df_final_s_2)

identical(wf_refund_df_final_s, wf_refund_df_final_s_2)


# get_wf_retire -----------------------------------------------------------

get_wf_retire_df_final_s_2 <- function(wf_retire_df_s, benefit_table_s, ann_factor_table_s, params) {
  
  # RETIRE components (based on metadata)
  meta_retire <- params$component_meta %>%
    filter(str_detect(applies_to, "retire")) %>%
    select(component, plan_type)
  
  retire_components <- meta_retire$component
  
  # Base retire records + attach base DB benefit, COLA, and annuity factor
  base <- wf_retire_df_s %>%
    filter(year <= params$start_year_ + params$model_period_) %>%
    mutate(entry_year = year - (age - entry_age)) %>%
    # base benefit + cola (from benefit_table)
    left_join(
      benefit_table_s %>% select(-ann_factor),,
      by = c("class", "entry_age", "entry_year", "term_year", "retire_year" = "dist_year")
    ) %>%
    left_join(
      ann_factor_table_s %>% select(-cola),
      by = c("class", "entry_age", "entry_year", "term_year", "year" = "dist_year")
    ) %>%
    mutate(
      db_benefit = coalesce(db_benefit, 0),
      cola       = coalesce(cola, 0),
      ann_factor = coalesce(ann_factor, 0),
      # adjust benefit forward from retirement year
      db_benefit_final = db_benefit * (1 + cola)^(year - retire_year),
      # PVFB for retirees excludes first payment
      pvfb_db_retire   = db_benefit_final * (ann_factor - 1)
    )
  
  # Allocate retirees to components using plan_alloc shares
  long <- base %>%
    left_join(
      params$plan_alloc %>% filter(component %in% retire_components),
      by = join_by(class, entry_year >= entry_year_ll, entry_year < entry_year_ul)
    ) %>%
    mutate(share = coalesce(as.numeric(share), 0)) %>%
    left_join(meta_retire, by = "component") %>%
    mutate(
      n_comp = n_retire * share,
      # retire benefits + retire AAL are DB-only
      retire_ben = if_else(plan_type == "db", db_benefit_final * n_comp, 0),
      aal_retire = if_else(plan_type == "db", pvfb_db_retire   * n_comp, 0)
    )
  
  # Component-level outputs (wide)
  out <- long %>%
    group_by(class, year, component) %>%
    summarise(
      retire_ben = sum(retire_ben, na.rm = TRUE),
      aal_retire = sum(aal_retire, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    pivot_wider(
      names_from  = component,
      values_from = c(retire_ben, aal_retire),
      names_glue  = "{.value}_{component}_est",
      values_fill = 0
    )
  
  return(out)
}

get_wf_retire_df_final_s <- function(wf_retire_df_s,
                                     benefit_table_s,
                                     ann_factor_table_s,
                                     params){
  # Join wf retire table with benefit table to calculate the overall retirement benefits each year
  wf_retire_df_final_s <- wf_retire_df_s %>% 
    filter(year <= params$start_year_ + params$model_period_) %>% 
    mutate(entry_year = year - (age - entry_age)) %>%    
    left_join(benefit_table_s, by = c("class", "entry_age", "entry_year", "term_year", "retire_year" = "dist_year")) %>% 
    select(class, entry_age, age, year, term_year, retire_year, entry_year, n_retire, db_benefit, cola) %>% 
    left_join(ann_factor_table_s %>% 
                select(-cola), 
              by = c("class", "entry_age", "entry_year", "term_year", "year" = "dist_year")) %>% 
    select(class, entry_age, age, year, term_year, retire_year, entry_year, n_retire, db_benefit, cola, ann_factor) %>% 
    rename(base_db_benefit = db_benefit) %>% 
    #Adjust the benefit based on COLA and allocate members to plan designs based on entry year
    left_join(params$db_dc_legacy_table, 
              by = join_by(class,
                           entry_year >= year_ll, 
                           entry_year < year_ul)) %>%
    left_join(params$db_dc_new_table,
              by = join_by(class,
                           entry_year >= new_year_ll,
                           entry_year < new_year_ul)) %>%
    mutate(
      db_benefit_final = base_db_benefit * (1 + cola)^(year - retire_year),
      n_retire_db_legacy = n_retire * db_legacy,
      n_retire_db_new = n_retire * db_new,
      #We use "AnnuityFactor_DR - 1" below because the PVFB for retirees excludes the first payment (i.e. the first payment has already been delivered when the PVFB is calculated)
      pvfb_db_retire = db_benefit_final * (ann_factor - 1)
    ) %>% 
    group_by(class, year) %>% 
    summarise(retire_ben_db_legacy_est = sum(db_benefit_final * n_retire_db_legacy),
              retire_ben_db_new_est = sum(db_benefit_final * n_retire_db_new),
              
              aal_retire_db_legacy_est = sum(pvfb_db_retire * n_retire_db_legacy),
              aal_retire_db_new_est = sum(pvfb_db_retire * n_retire_db_new)
    ) %>% 
    ungroup()
  
  return(wf_retire_df_final_s)    
}

wf_retire_df_s <- wf_data_env$wf_retire_df_s
ann_factor_table_s <- bf_data_env$benefit_data_s$ann_factor_table
benefit_table_s <- bf_data_env$benefit_data_s$benefit_table_s
wf_retire_df_final_s <- get_wf_retire_df_final_s(wf_retire_df_s, benefit_table_s, ann_factor_table_s, params)
wf_retire_df_final_s_2 <- get_wf_retire_df_final_s_2(wf_retire_df_s, benefit_table_s, ann_factor_table_s, params)

names(wf_retire_df_final_s)
names(wf_retire_df_final_s_2)

identical(wf_retire_df_final_s, wf_retire_df_final_s_2)
all.equal(wf_retire_df_final_s, wf_retire_df_final_s_2, tolerance = 1e-10)


get_wf_retire_current_final_s <- function(ann_factor_retire_table_s,
                                          params) {
  
  # Project benefit payments for current retirees
  retire_current_int_s <- params$retiree_distribution %>% 
    select(age, n_retire_ratio, total_ben_ratio) %>% 
    crossing(params$current_year_table %>% select(class, retiree_pop_current, ben_payment_current)) %>%
    mutate(
      n_retire_current = n_retire_ratio * retiree_pop_current,
      total_ben_current = total_ben_ratio * ben_payment_current,
      avg_ben_current = total_ben_current / n_retire_current,
      year = params$start_year_
    )
  
  wf_retire_current_s <- ann_factor_retire_table_s %>% 
    filter(year <= params$start_year_ + params$model_period_) %>% 
    left_join(retire_current_int_s, by = c("class","age", "year")) %>% 
    select(base_age:ann_factor_retire, n_retire_current, avg_ben_current, total_ben_current, class) %>% 
    group_by(class, base_age) %>% 
    mutate(n_retire_current = pentools::recur_grow(n_retire_current, -mort_final),
           avg_ben_current = pentools::recur_grow2(avg_ben_current, cola),
           total_ben_current = n_retire_current * avg_ben_current,
           #W e use "AnnuityFactor_DR - 1" below because the PVFB for retirees excludes the first payment (i.e. the first payment has already been delivered when the PVFB is calculated)
           pvfb_retire_current = avg_ben_current * (ann_factor_retire - 1)
    ) %>% 
    filter(!is.na(n_retire_current)) %>% 
    ungroup()
  
  wf_retire_current_final_s <- wf_retire_current_s %>% 
    group_by(class, year) %>% 
    summarise(retire_ben_current_est = sum(total_ben_current),
              aal_retire_current_est = sum(n_retire_current * pvfb_retire_current)
    ) %>% 
    ungroup()
  # rename(year = Years)
  
  return(wf_retire_current_final_s)
}


get_wf_term_current_s <- function(
    params){
  
  # Project benefit payments for current term vested members
  # Note that we use the original "dr_current_" in calculating the benefit payments so that any discount rate adjustment can work
  # Set model years
  year <- params$start_year_:(params$start_year_ + params$model_period_)
  amo_years_term <- (params$start_year_ + 1):(params$start_year_ + params$amo_period_term_)
  
  # Build all-class version correctly
  wf_term_current_s <- params$current_year_table %>%
    select(class, pvfb_term_current) %>%
    mutate(retire_ben_term = purrr::map_dbl(
      pvfb_term_current,
      ~ get_pmt(
        r = params$dr_current_,
        nper = params$amo_period_term_,
        pv = .x,
        g = params$payroll_growth_
      )
    )) %>%
    rowwise() %>%
    mutate(retire_ben_term_vec = list({
      vec <- double(length = length(year))
      vec[year %in% amo_years_term] <- pentools::recur_grow3(
        retire_ben_term,
        g = params$payroll_growth_,
        nper = params$amo_period_term_
      )
      vec
    })
    ) %>%
    ungroup() %>%
    mutate(year = list(year)) %>%
    unnest(c(year, retire_ben_term_vec)) %>%
    rename(retire_ben_term_est = retire_ben_term_vec) %>%
    group_by(class) %>%
    arrange(year, .by_group = TRUE) %>%
    mutate(
      aal_term_current_est = pentools::roll_pv(
        rate = params$dr_current_,
        g = params$payroll_growth_,
        nper = params$amo_period_term_,
        pmt_vec = retire_ben_term_est
      )
    ) %>%
    ungroup() %>%
    select(class, year, retire_ben_term_est, aal_term_current_est)
  
  return(wf_term_current_s)
  
}

get_funding_df_s <- function(wf_active_df_final_s,
                             wf_term_df_final_s,
                             wf_refund_df_final_s,
                             wf_retire_df_final_s,
                             wf_retire_current_final_s,
                             wf_term_current_s,
                             params)
  
  ##### Funding model - liability side
{
  funding_df_s <- wf_active_df_final_s %>% 
    left_join(wf_term_df_final_s,
              by = join_by(class, year)) %>% 
    left_join(wf_refund_df_final_s,
              by = join_by(class, year)) %>% 
    left_join(wf_retire_df_final_s,
              by = join_by(class, year)) %>%
    left_join(wf_retire_current_final_s,
              by = join_by(class, year)) %>% 
    left_join(wf_term_current_s,
              by = join_by(class, year)) %>%
    replace(is.na(.), 0) %>% 
    mutate(
      aal_legacy_est = aal_active_db_legacy_est + aal_term_db_legacy_est + aal_retire_db_legacy_est + aal_retire_current_est + aal_term_current_est,
      aal_new_est = aal_active_db_new_est + aal_term_db_new_est + aal_retire_db_new_est,
      total_aal_est = aal_legacy_est + aal_new_est,
      tot_ben_refund_legacy_est = refund_db_legacy_est + retire_ben_db_legacy_est + retire_ben_current_est + retire_ben_term_est,
      tot_ben_refund_new_est = refund_db_new_est + retire_ben_db_new_est,
      tot_ben_refund_est = tot_ben_refund_legacy_est + tot_ben_refund_new_est
    )
  
  # Initialize output list
  funding_list <- list()
  
  #Calculate liability gain/loss if any and project AAL using the roll forward method
  for (class_name in unique(funding_df_s$class)) {
    funding_df <- funding_df_s %>% filter(class == class_name)
    
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
    
    funding_list[[class_name]] <- funding_df
    
  }
  
  funding_df_s <- bind_rows(funding_list)
  
  
  return(funding_df_s)
}

# main function -----------------------------------------------------------
get_liability_data_s <- function(
    bf_data_env,
    wf_data_env,
    params
) {
  
  # unpack the wf_data and benefit_data objects
  wf_active_df_s <- wf_data_env$wf_active_df_s
  wf_term_df_s <- wf_data_env$wf_term_df_s
  wf_refund_df_s <- wf_data_env$wf_refund_df_s
  wf_retire_df_s <- wf_data_env$wf_retire_df_s
  
  benefit_val_table_s <- bf_data_env$benefit_data_s$benefit_val_table 
  benefit_table_s <- bf_data_env$benefit_data_s$benefit_table 
  ann_factor_table_s <- bf_data_env$benefit_data_s$ann_factor_table 
  ann_factor_retire_table_s <- bf_data_env$benefit_data_s$ann_factor_retire_table
  
  wf_active_df_final_s <- get_wf_active_df_final_s(
    wf_active_df_s,
    benefit_val_table_s,
    params
  )
  
  wf_term_df_final_s <- get_wf_term_df_final_s(
    wf_term_df_s,
    benefit_val_table_s,
    benefit_table_s,
    params
  )  
  
  wf_refund_df_final_s <- get_wf_refund_df_final_s(
    wf_refund_df_s,
    benefit_table_s,
    params
  )    
  
  wf_retire_df_final_s <- get_wf_retire_df_final_s(
    wf_retire_df_s,
    benefit_table_s,
    ann_factor_table_s,
    params
  )
  
  wf_retire_current_final_s <- get_wf_retire_current_final_s(
    ann_factor_retire_table_s,
    params
  )
  
  wf_term_current_s <- get_wf_term_current_s(
    params
  )
  
  funding_df_s <- get_funding_df_s(wf_active_df_final_s,
                                   wf_term_df_final_s,
                                   wf_refund_df_final_s,
                                   wf_retire_df_final_s,
                                   wf_retire_current_final_s,
                                   wf_term_current_s,
                                   params)
  
  # Check liability gain/loss
  # If the liability gain/loss isn't 0 under the perfect condition (experience = assumption), something must be wrong.
  
  return(funding_df_s)
}


