# Get FRS data ------------------------------------------------------------

# Import key data tables ----
FileName <- fs::path(sddir, "Florida FRS inputs.xlsx")


# Headcount, mortality, salary --------------------------------------------

base_teacher_mort_table_ <- read_excel(fs::path(sddir, "pub-2010-headcount-mort-rates.xlsx"), sheet = "PubT.H-2010")
base_safety_mort_table_ <- read_excel(fs::path(sddir, "pub-2010-headcount-mort-rates.xlsx"), sheet = "PubS.H-2010")
base_general_mort_table_ <- read_excel(fs::path(sddir, "pub-2010-headcount-mort-rates.xlsx"), sheet = "PubG.H-2010")

male_mp_table_ <- read_excel(fs::path(sddir, "mortality-improvement-scale-mp-2018-rates.xlsx"), sheet = "Male")
female_mp_table_ <- read_excel(fs::path(sddir, "mortality-improvement-scale-mp-2018-rates.xlsx"), sheet = "Female")

salary_growth_table_original_ <- read_excel(FileName, sheet = "Salary Growth") # compares to Reason's salary_growth_table_

regular_salary_table_ <- read_excel(FileName, sheet="Salary Distribution Regular")
regular_headcount_table_ <- read_excel(FileName, sheet="HeadCount Distribution Regular") %>% 
  mutate(across(everything(), ~replace(.x, is.na(.x), 0)))

special_salary_table_ <- read_excel(FileName, sheet="Salary Distribution Special")
special_headcount_table_ <- read_excel(FileName, sheet="HeadCount Distribution Special") %>% 
  mutate(across(everything(), ~replace(.x, is.na(.x), 0)))

admin_salary_table_ <- read_excel(FileName, sheet="Salary Distribution Admin")
admin_headcount_table_ <- read_excel(FileName, sheet="HeadCount Distribution Admin") %>% 
  mutate(across(everything(), ~replace(.x, is.na(.x), 0)))

eco_salary_table_ <- read_excel(FileName, sheet="Salary Distribution Eco")
eco_headcount_table_ <- read_excel(FileName, sheet="HeadCount Distribution Eco") %>% 
  mutate(across(everything(), ~replace(.x, is.na(.x), 0)))

eso_salary_table_ <- read_excel(FileName, sheet="Salary Distribution Eso")
eso_headcount_table_ <- read_excel(FileName, sheet="HeadCount Distribution Eso") %>% 
  mutate(across(everything(), ~replace(.x, is.na(.x), 0)))

judges_salary_table_ <- read_excel(FileName, sheet="Salary Distribution Judge")
judges_headcount_table_ <- read_excel(FileName, sheet="HeadCount Distribution Judge") %>% 
  mutate(across(everything(), ~replace(.x, is.na(.x), 0)))

senior_management_salary_table_ <- read_excel(FileName, sheet="Salary Distribution Sen Man")
senior_management_headcount_table_ <- read_excel(FileName, sheet="HeadCount Distribution Sen Man") %>% 
  mutate(across(everything(), ~replace(.x, is.na(.x), 0)))

drop_entry_tier_1_table_ <- read_excel(fs::path(xidir, "drop entry tier 1.xlsx"))
drop_entry_tier_2_table_ <- read_excel(fs::path(xidir, "drop entry tier 2.xlsx"))

normal_retirement_tier_1_table_ <- read_excel(fs::path(xidir, "normal retirement tier 1.xlsx"))
normal_retirement_tier_2_table_ <- read_excel(fs::path(xidir, "normal retirement tier 2.xlsx"))

early_retirement_tier_1_table_ <- read_excel(fs::path(xidir, "early retirement tier 1.xlsx"))
early_retirement_tier_2_table_ <- read_excel(fs::path(xidir, "early retirement tier 2.xlsx"))

#Termination, Withdrawal, separation rates --------------------------------

regular_term_rate_male_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Regular Male")
regular_term_rate_female_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Regular Female")

special_term_rate_male_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Special Male")
special_term_rate_female_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Special Female")

admin_term_rate_male_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Admin Male")
admin_term_rate_female_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Admin Female")

eco_term_rate_male_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Eco")
eco_term_rate_female_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Eco")

eso_term_rate_male_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Eso")
eso_term_rate_female_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Eso")

judges_term_rate_male_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Judges")
judges_term_rate_female_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Judges")

senior_management_term_rate_male_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Sen Man Male")
senior_management_term_rate_female_table_ <- read_excel(FileName, sheet = "Withdrawal Rate Sen Man Female")



# Retirement, funding, returns, amortization -----------------------------------------------------

retiree_distribution <- read_excel(FileName, sheet = "Retiree Distribution") 

init_funding_data <- read_excel(FileName, sheet = "Funding Input")
# count(init_funding_data, class)
init_funding_data <- init_funding_data |> 
  mutate(class = str_replace(class, " ", "_"))

# djb: I put the suffix on this
return_scenarios_original_ <- read_excel(FileName, sheet = "Return Scenarios")

current_amort_layers_table_ <- read_excel(FileName, sheet = "Amort Input")
# count(current_amort_layers_table_, class)
current_amort_layers_table_ <- current_amort_layers_table_ |> 
  mutate(class = str_replace(class, " ", "_"))


# FRS constants -----------------------------------------------------------

#.. FRS Retirement benefit assumptions
pension_payment_ <- 11944986866         #Pension Payments in Reconciliation of Market Value of Assets Used for Valuation table
contribution_refunds_ <- 28343757       #Contribution Refunds in Reconciliation of Market Value of Assets Used for Valuation table
disbursement_to_ip_ <- 768106850        #Disbursements to Investment Plan in Reconciliation of Market Value of Assets Used for Valuation table
admin_expense_ <- 22494571              #Administrative Expenses in Reconciliation of Market Value of Assets Used for Valuation table

ben_payment_ratio_ <- pension_payment_ / 
  (pension_payment_ + contribution_refunds_ + disbursement_to_ip_ + admin_expense_)

#Below are the cash outflows for each membership class. These numbers are Benefit Payments and other Disbursements in the Development of Actuarial Value of Assets table
regular_outflow_ <- 8967096000
special_outflow_ <- 2423470000
admin_outflow_ <- 8090000
judges_outflow_ <- 105844000
eso_outflow_ <- 53526000
eco_outflow_ <- 9442000
senior_management_outflow_ <- 338664000

#Below are the estimated benefit payments for each membership class
regular_ben_payment_current_ <- regular_outflow_ * ben_payment_ratio_
special_ben_payment_current_ <- special_outflow_ * ben_payment_ratio_
admin_ben_payment_current_ <- admin_outflow_ * ben_payment_ratio_
judges_ben_payment_current_ <- judges_outflow_ * ben_payment_ratio_
eso_ben_payment_current_ <- eso_outflow_ * ben_payment_ratio_
eco_ben_payment_current_ <- eco_outflow_ * ben_payment_ratio_
senior_management_ben_payment_current_ <- senior_management_outflow_ * ben_payment_ratio_

#Below are the numbers of annuitants for each membership class, representing the retiree populations
regular_retiree_pop_current_ <- 393308
special_retiree_pop_current_ <- 41696
admin_retiree_pop_current_ <- 160
judges_retiree_pop_current_ <- 989
eso_retiree_pop_current_ <- 1446
eco_retiree_pop_current_ <- 227
senior_management_retiree_pop_current_ <- 5828

#retire_refund_ratio is the ratio of vested members who choose to retire instead of getting a refund (i.e. a ratio of 0.8 means 80% of vested members choose to retire)
retire_refund_ratio_ <- 1

#Model Calibration
cal_factor_ <- 0.9                   #Calibration factor for the benefit model. This is to adjust the normal cost to match the normal cost from the val report.
#Adjust this calibration factor after getting preliminary results from the benefit model.

regular_val_norm_cost_ <- 0.0896               #Normal cost for Regular members from the val report  
special_val_norm_cost_ <- 0.2013               #Normal cost for Special Risk members from the val report
admin_val_norm_cost_ <- 0.1457                 #Normal cost for Special Risk Admin members from the val report
judges_val_norm_cost_ <- 0.1777                #Normal cost for Judicial members from the val report
eso_val_norm_cost_ <- 0.1463                   #Normal cost for Local members from the val report
eco_val_norm_cost_ <- 0.1254                   #Normal cost for Leg-Atty-Cab members from the val report
senior_management_val_norm_cost_ <- 0.1086     #Normal cost for Senior Management members from the val report

#Below are calibration factors to further adjust the normal costs to match the numbers from the val report.These are calculated by dividing the normal costs from the val report by the normal costs from the benefit model.
regular_nc_cal_ <- regular_val_norm_cost_ / 0.09096784
special_nc_cal_ <- special_val_norm_cost_ / 0.2044051
admin_nc_cal_ <- admin_val_norm_cost_ / 0.10436284
judges_nc_cal_ <- judges_val_norm_cost_ / 0.1937982
eso_nc_cal_ <- eso_val_norm_cost_ / 0.1557111
eco_nc_cal_ <- eco_val_norm_cost_ / 0.1513904
senior_management_nc_cal_ <- senior_management_val_norm_cost_ / 0.11295223


#Assumptions about the "remaining" accrued liability (which is not accounted for by the PVFB calculations). 
#This is lumped together with the accrued liability for current term vested members.
#The value is calculated by subtracting the preliminary actuarial accrued liability produced by the liability model from the accrued liability from the val report.
#The preliminary accrued liability is the liability calculated by the liability model when these values below are set to 0.
regular_pvfb_term_current_ <- 145585523000 - 138993598036
special_pvfb_term_current_ <- 45070773000 - 41833009006
admin_pvfb_term_current_ <- 90337000 - 92432291
eco_pvfb_term_current_ <- 138008000 - 110403603
eso_pvfb_term_current_ <- 751363000 - 720397602
judges_pvfb_term_current_ <- 1545348000 - 1444240024
senior_management_pvfb_term_current_ <- 6039701000 - 5404229360

amo_period_term_ <- 50        #Amortization period for the remaining accrued liability
amo_term_growth_ <- 0.03      #Growth rate of the annual amortization payments for the remaining accrued liability
#Note: we've switched to a new amortization method for the remaining accrued liability that produces amo payments fitting a bell curve instead of growing at a constant rate. This new method has not yet been implemented for Florida FRS but will be in the next update.

#Membership assumptions
#Below are the total membership numbers for each membership class. These numbers are from the ACFR and include both DB and DC membership. 
regular_total_active_member_ <- 537128
special_total_active_member_ <- 72925
admin_total_active_member_ <- 104
eco_eso_judges_total_active_member_ <- 2075
senior_management_total_active_member_ <- 7610

###We account for the Investment Plan (DC plan) head count by inflating the DB head count by the ratio of total system head count to DB head count
#ECO, ESO, and Judges head counts are processed separately as the ACFR does not provide detailed head counts for these classes 
eco_eso_judges_active_member_adjustment_ratio <- eco_eso_judges_total_active_member_ / sum(eco_headcount_table_[-1] + eso_headcount_table_[-1] +judges_headcount_table_[-1])

#.. call get_salary_headcount_table -----------------------------------------
# GC: Temporarily create cumulative salary growth table from original
frs_data_env$salary_growth_table_ <- frs_data_env$salary_growth_table_original_ %>%
  bind_rows(tibble(yos = (max(frs_data_env$salary_growth_table_original_$yos) + 1):max(frs_data_env$yos_range_))) %>%
  fill(everything(), .direction = "down") %>%
  mutate(
    across(contains("salary"), ~ cumprod(1 + lag(.x, default = 0)), .names = "cumprod_{.col}"),
    .keep = "unused"
  )
# End: Temporary fix to salary growth table

print("get salary_headcount and entrant_profile tables")
temp <- frs_data_env$get_salary_headcount_table("regular", frs_data_env)
regular_salary_headcount_table <- temp$salary_headcount_table
regular_entrant_profile_table <- temp$entrant_profile

temp <- frs_data_env$get_salary_headcount_table("special", frs_data_env)
special_salary_headcount_table <- temp$salary_headcount_table
special_entrant_profile_table <- temp$entrant_profile

temp <- frs_data_env$get_salary_headcount_table("admin", frs_data_env)
admin_salary_headcount_table <- temp$salary_headcount_table
admin_entrant_profile_table <- temp$entrant_profile

temp <- frs_data_env$get_salary_headcount_table("eco", frs_data_env)
eco_salary_headcount_table <- temp$salary_headcount_table
eco_entrant_profile_table <- temp$entrant_profile

temp <- frs_data_env$get_salary_headcount_table("eso", frs_data_env)
eso_salary_headcount_table <- temp$salary_headcount_table
eso_entrant_profile_table <- temp$entrant_profile

temp <- frs_data_env$get_salary_headcount_table("judges", frs_data_env)
judges_salary_headcount_table <- temp$salary_headcount_table
judges_entrant_profile_table <- temp$entrant_profile

temp <- frs_data_env$get_salary_headcount_table("senior_management", frs_data_env)
senior_management_salary_headcount_table <- temp$salary_headcount_table
senior_management_entrant_profile_table <- temp$entrant_profile

rm(temp)

#.. create a list with the entrant profile tables ----
frs_data_env$class_names_ <- frs_data_env$init_funding_data$class
frs_data_env$class_names_no_frs_ <- frs_data_env$class_names_[!frs_data_env$class_names_ %in% c("frs")]
frs_data_env$class_names_no_drop_frs_ <- frs_data_env$class_names_[!frs_data_env$class_names_ %in% c("drop", "frs")]
entrant_profile_table_list <- mget(paste0(frs_data_env$class_names_no_drop_frs_, "_entrant_profile_table"))


# Retirement & Separation Conditions --------------------------------------

# no actions related to this?


# Mortality Assumptions ---------------------------------------------------

print("get mortality tables")

#.. base mortality table -----------------------------------------------
print(".. base mortality")

base_general_mort_table <- frs_data_env$get_base_mort_table(frs_data_env$base_general_mort_table_)
base_teacher_mort_table <- frs_data_env$get_base_mort_table(frs_data_env$base_teacher_mort_table_)
base_safety_mort_table <- frs_data_env$get_base_mort_table(frs_data_env$base_safety_mort_table_)

#Create this mort table for regular employees who are either teachers or general employees
base_regular_mort_table <- (base_general_mort_table + base_teacher_mort_table)/2


# .. mortality improvement ------------------------------------------------
print(".. mortality improvement")

male_mp_table <- frs_data_env$clean_mp_table(frs_data_env$male_mp_table_, extend_2_yrs = TRUE)
female_mp_table <- frs_data_env$clean_mp_table(frs_data_env$female_mp_table_, extend_2_yrs = TRUE)

male_mp_final_table <- frs_data_env$get_mp_final_table(male_mp_table, "male", 2010, frs_data_env$age_range_, frs_data_env$year_range_)
female_mp_final_table <- frs_data_env$get_mp_final_table(female_mp_table, "female", 2010, frs_data_env$age_range_, frs_data_env$year_range_)

#.. mortality tables by class -----------------------------------------------
print(".. improved mortality tables by class")

regular_mort_table <- frs_data_env$get_mort_table("regular", base_regular_mort_table, male_mp_final_table, female_mp_final_table, regular_entrant_profile_table,
                                            frs_data_env$entry_year_range_, frs_data_env$age_range_, frs_data_env$yos_range_, frs_data_env$new_year_)

special_mort_table <- frs_data_env$get_mort_table("special", base_safety_mort_table, male_mp_final_table, female_mp_final_table, special_entrant_profile_table,
                                            frs_data_env$entry_year_range_, frs_data_env$age_range_, frs_data_env$yos_range_, frs_data_env$new_year_)

admin_mort_table <- frs_data_env$get_mort_table("admin", base_safety_mort_table, male_mp_final_table, female_mp_final_table, admin_entrant_profile_table,
                                          frs_data_env$entry_year_range_, frs_data_env$age_range_, frs_data_env$yos_range_, frs_data_env$new_year_)

eco_mort_table <- frs_data_env$get_mort_table("eco", base_general_mort_table, male_mp_final_table, female_mp_final_table, eco_entrant_profile_table,
                                        frs_data_env$entry_year_range_, frs_data_env$age_range_, frs_data_env$yos_range_, frs_data_env$new_year_)

eso_mort_table <- frs_data_env$get_mort_table("eso", base_general_mort_table, male_mp_final_table, female_mp_final_table, eso_entrant_profile_table,
                                        frs_data_env$entry_year_range_, frs_data_env$age_range_, frs_data_env$yos_range_, frs_data_env$new_year_)

judges_mort_table <- frs_data_env$get_mort_table("judges", base_general_mort_table, male_mp_final_table, female_mp_final_table, judges_entrant_profile_table,
                                           frs_data_env$entry_year_range_, frs_data_env$age_range_, frs_data_env$yos_range_, frs_data_env$new_year_)

senior_management_mort_table <- frs_data_env$get_mort_table("senior_management", base_general_mort_table, male_mp_final_table, female_mp_final_table, senior_management_entrant_profile_table,
                                                      frs_data_env$entry_year_range_, frs_data_env$age_range_, frs_data_env$yos_range_, frs_data_env$new_year_)

print(".. mortality retirement tables by class")

regular_mort_retire_table <- frs_data_env$get_mort_retire_table(base_regular_mort_table, male_mp_final_table, female_mp_final_table,
                                                          frs_data_env$age_range_, frs_data_env$year_range_, frs_data_env$start_year_)

special_mort_retire_table <- frs_data_env$get_mort_retire_table(base_safety_mort_table, male_mp_final_table, female_mp_final_table,
                                                          frs_data_env$age_range_, frs_data_env$year_range_, frs_data_env$start_year_)

admin_mort_retire_table <- frs_data_env$get_mort_retire_table(base_safety_mort_table, male_mp_final_table, female_mp_final_table,
                                                        frs_data_env$age_range_, frs_data_env$year_range_, frs_data_env$start_year_)

eco_mort_retire_table <- frs_data_env$get_mort_retire_table(base_general_mort_table, male_mp_final_table, female_mp_final_table,
                                                      frs_data_env$age_range_, frs_data_env$year_range_, frs_data_env$start_year_)

eso_mort_retire_table <- frs_data_env$get_mort_retire_table(base_general_mort_table, male_mp_final_table, female_mp_final_table,
                                                      frs_data_env$age_range_, frs_data_env$year_range_, frs_data_env$start_year_)

judges_mort_retire_table <- frs_data_env$get_mort_retire_table(base_general_mort_table, male_mp_final_table, female_mp_final_table,
                                                         frs_data_env$age_range_, frs_data_env$year_range_, frs_data_env$start_year_)

senior_management_mort_retire_table <- frs_data_env$get_mort_retire_table(base_general_mort_table, male_mp_final_table, female_mp_final_table,
                                                                    frs_data_env$age_range_, frs_data_env$year_range_, frs_data_env$start_year_)


# Separation Assumptions --------------------------------------------------

print("get separation tables")

#.. Clean retirement and drop ----

print(".. drop, normal, and early retire entry")

drop_entry_table_col_names <- c("age", "regular_inst_female", "regular_inst_male",
                                "regular_non_inst_female", "regular_non_inst_male",
                                "special_risk_non_leo_female", "special_risk_non_leo_male",
                                "special_risk_leo_female", "special_risk_leo_male",
                                "other_female", "other_male")

normal_retire_table_col_names <- c("age", "regular_inst_female", "regular_inst_male",
                                   "regular_non_inst_female", "regular_non_inst_male",
                                   "special_risk_female", "special_risk_male",
                                   "eco_eso_jud_female", "eco_eso_jud_male",
                                   "senior_management_female", "senior_management_male")

early_retire_table_col_names <- c("age", "regular_non_inst_female", "regular_non_inst_male",
                                  "special_risk_female", "special_risk_male",
                                  "eco_eso_jud_female", "eco_eso_jud_male",
                                  "senior_management_female", "senior_management_male")


drop_entry_tier_1_table <- frs_data_env$clean_retire_rate_table(frs_data_env$drop_entry_tier_1_table_, drop_entry_table_col_names)
drop_entry_tier_2_table <- frs_data_env$clean_retire_rate_table(frs_data_env$drop_entry_tier_2_table_, drop_entry_table_col_names)

normal_retire_rate_tier_1_table <- frs_data_env$clean_retire_rate_table(frs_data_env$normal_retirement_tier_1_table_, normal_retire_table_col_names)
normal_retire_rate_tier_2_table <- frs_data_env$clean_retire_rate_table(frs_data_env$normal_retirement_tier_2_table_, normal_retire_table_col_names)

early_retire_rate_tier_1_table <- frs_data_env$clean_retire_rate_table(frs_data_env$early_retirement_tier_1_table_, early_retire_table_col_names)
early_retire_rate_tier_2_table <- frs_data_env$clean_retire_rate_table(frs_data_env$early_retirement_tier_2_table_, early_retire_table_col_names)


normal_retire_rate_tier_2_table <- normal_retire_rate_tier_2_table %>% 
  add_row(age=45:49, .before=1) %>% 
  mutate(across(everything(), ~replace(.x, is.na(.x), 0)))
# mutate_all(~replace(., is.na(.), 0))

special_risk_drop_entry_tier_1_table <- drop_entry_tier_1_table %>% 
  select(age, contains("special_risk")) %>% 
  mutate(
    special_risk_female = (special_risk_non_leo_female + special_risk_leo_female)/2,
    special_risk_male = (special_risk_non_leo_male + special_risk_leo_male)/2,
    .keep = "unused"
  )

special_risk_drop_entry_tier_2_table <- drop_entry_tier_2_table %>% 
  select(age, contains("special_risk")) %>% 
  mutate(
    special_risk_female = (special_risk_non_leo_female + special_risk_leo_female)/2,
    special_risk_male = (special_risk_non_leo_male + special_risk_leo_male)/2,
    .keep = "unused"
  )


#.. get retirement-rate tables ----------------------------------------------

print(".. retirement rate tables")

regular_normal_retire_rate_tier_1_table <- frs_data_env$get_normal_retire_rate_table(class_name = "regular",
                                                                               drop_entry_table = drop_entry_tier_1_table,
                                                                               normal_retire_rate_table = normal_retire_rate_tier_1_table)

regular_normal_retire_rate_tier_2_table <- frs_data_env$get_normal_retire_rate_table(class_name = "regular",
                                                                               drop_entry_table = drop_entry_tier_2_table,
                                                                               normal_retire_rate_table = normal_retire_rate_tier_2_table)

special_normal_retire_rate_tier_1_table <- frs_data_env$get_normal_retire_rate_table(class_name = "special",
                                                                               drop_entry_table = special_risk_drop_entry_tier_1_table,
                                                                               normal_retire_rate_table = normal_retire_rate_tier_1_table)

special_normal_retire_rate_tier_2_table <- frs_data_env$get_normal_retire_rate_table(class_name = "special",
                                                                               drop_entry_table = special_risk_drop_entry_tier_2_table,
                                                                               normal_retire_rate_table = normal_retire_rate_tier_2_table)

admin_normal_retire_rate_tier_1_table <- frs_data_env$get_normal_retire_rate_table(class_name = "admin",
                                                                             drop_entry_table = special_risk_drop_entry_tier_1_table,
                                                                             normal_retire_rate_table = normal_retire_rate_tier_1_table)

admin_normal_retire_rate_tier_2_table <- frs_data_env$get_normal_retire_rate_table(class_name = "admin",
                                                                             drop_entry_table = special_risk_drop_entry_tier_2_table,
                                                                             normal_retire_rate_table = normal_retire_rate_tier_2_table)

eco_normal_retire_rate_tier_1_table <- frs_data_env$get_normal_retire_rate_table(class_name = "eco",
                                                                           drop_entry_table = drop_entry_tier_1_table,
                                                                           normal_retire_rate_table = normal_retire_rate_tier_1_table)

eco_normal_retire_rate_tier_2_table <- frs_data_env$get_normal_retire_rate_table(class_name = "eco",
                                                                           drop_entry_table = drop_entry_tier_2_table,
                                                                           normal_retire_rate_table = normal_retire_rate_tier_2_table)

eso_normal_retire_rate_tier_1_table <- frs_data_env$get_normal_retire_rate_table(class_name = "eso",
                                                                           drop_entry_table = drop_entry_tier_1_table,
                                                                           normal_retire_rate_table = normal_retire_rate_tier_1_table)

eso_normal_retire_rate_tier_2_table <- frs_data_env$get_normal_retire_rate_table(class_name = "eso",
                                                                           drop_entry_table = drop_entry_tier_2_table,
                                                                           normal_retire_rate_table = normal_retire_rate_tier_2_table)

judges_normal_retire_rate_tier_1_table <- frs_data_env$get_normal_retire_rate_table(class_name = "judge",
                                                                              drop_entry_table = drop_entry_tier_1_table,
                                                                              normal_retire_rate_table = normal_retire_rate_tier_1_table)

judges_normal_retire_rate_tier_2_table <- frs_data_env$get_normal_retire_rate_table(class_name = "judge",
                                                                              drop_entry_table = drop_entry_tier_2_table,
                                                                              normal_retire_rate_table = normal_retire_rate_tier_2_table)


senior_management_normal_retire_rate_tier_1_table <- frs_data_env$get_normal_retire_rate_table(class_name = "senior_management",
                                                                                         drop_entry_table = drop_entry_tier_1_table,
                                                                                         normal_retire_rate_table = normal_retire_rate_tier_1_table)

senior_management_normal_retire_rate_tier_2_table <- frs_data_env$get_normal_retire_rate_table(class_name = "senior_management",
                                                                                         drop_entry_table = drop_entry_tier_2_table,
                                                                                         normal_retire_rate_table = normal_retire_rate_tier_2_table)

#.. get early retirement rate tables ----------------------------------------

print(".. early retirement rate tables")

regular_early_retire_rate_tier_1_table <- frs_data_env$get_early_retire_rate_table(class_name = "regular",
                                                                             init_early_retire_rate_table = early_retire_rate_tier_1_table)

regular_early_retire_rate_tier_2_table <- frs_data_env$get_early_retire_rate_table(class_name = "regular",
                                                                             init_early_retire_rate_table = early_retire_rate_tier_2_table)


special_early_retire_rate_tier_1_table <- frs_data_env$get_early_retire_rate_table(class_name = "special",
                                                                             init_early_retire_rate_table = early_retire_rate_tier_1_table)

special_early_retire_rate_tier_2_table <- frs_data_env$get_early_retire_rate_table(class_name = "special",
                                                                             init_early_retire_rate_table = early_retire_rate_tier_2_table)


admin_early_retire_rate_tier_1_table <- frs_data_env$get_early_retire_rate_table(class_name = "admin",
                                                                           init_early_retire_rate_table = early_retire_rate_tier_1_table)

admin_early_retire_rate_tier_2_table <- frs_data_env$get_early_retire_rate_table(class_name = "admin",
                                                                           init_early_retire_rate_table = early_retire_rate_tier_2_table)

eco_early_retire_rate_tier_1_table <- frs_data_env$get_early_retire_rate_table(class_name = "eco",
                                                                         init_early_retire_rate_table = early_retire_rate_tier_1_table)

eco_early_retire_rate_tier_2_table <- frs_data_env$get_early_retire_rate_table(class_name = "eco",
                                                                         init_early_retire_rate_table = early_retire_rate_tier_2_table)

eso_early_retire_rate_tier_1_table <- frs_data_env$get_early_retire_rate_table(class_name = "eso",
                                                                         init_early_retire_rate_table = early_retire_rate_tier_1_table)

eso_early_retire_rate_tier_2_table <- frs_data_env$get_early_retire_rate_table(class_name = "eso",
                                                                         init_early_retire_rate_table = early_retire_rate_tier_2_table)

judges_early_retire_rate_tier_1_table <- frs_data_env$get_early_retire_rate_table(class_name = "judge",
                                                                            init_early_retire_rate_table = early_retire_rate_tier_1_table)

judges_early_retire_rate_tier_2_table <- frs_data_env$get_early_retire_rate_table(class_name = "judge",
                                                                            init_early_retire_rate_table = early_retire_rate_tier_2_table)


senior_management_early_retire_rate_tier_1_table <- frs_data_env$get_early_retire_rate_table(class_name = "senior_management",
                                                                                       init_early_retire_rate_table = early_retire_rate_tier_1_table)

senior_management_early_retire_rate_tier_2_table <- frs_data_env$get_early_retire_rate_table(class_name = "senior_management",
                                                                                       init_early_retire_rate_table = early_retire_rate_tier_2_table)


# ..get separation rate tables --------------------------------------------

print(".. separation rate tables by class")

frs_data_env$term_rate_male_table_list <- mget(paste0(frs_data_env$class_names_no_drop_frs_, "_term_rate_male_table_"), envir = frs_data_env)
frs_data_env$term_rate_female_table_list <- mget(paste0(frs_data_env$class_names_no_drop_frs_, "_term_rate_female_table_"), envir = frs_data_env)

term_rate_male_table_list <- frs_data_env$term_rate_male_table_list
term_rate_female_table_list <- frs_data_env$term_rate_female_table_list

normal_retire_rate_tier_1_table_list <- mget(paste0(frs_data_env$class_names_no_drop_frs_, "_normal_retire_rate_tier_1_table")) # defined in benefit model actions
normal_retire_rate_tier_2_table_list <- mget(paste0(frs_data_env$class_names_no_drop_frs_, "_normal_retire_rate_tier_2_table")) # defined in benefit model actions

early_retire_rate_tier_1_table_list <- mget(paste0(frs_data_env$class_names_no_drop_frs_, "_early_retire_rate_tier_1_table")) # defined in benefit model actions
early_retire_rate_tier_2_table_list <- mget(paste0(frs_data_env$class_names_no_drop_frs_, "_early_retire_rate_tier_2_table")) # defined in benefit model actions

regular_separation_rate_table <- frs_data_env$get_separation_table("regular", 
                                                             entrant_profile_table_list,
                                                             frs_data_env$term_rate_male_table_list , # we don't have this and next in the global environment next
                                                             frs_data_env$term_rate_female_table_list,
                                                             normal_retire_rate_tier_1_table_list,
                                                             normal_retire_rate_tier_2_table_list,
                                                             early_retire_rate_tier_1_table_list,
                                                             early_retire_rate_tier_2_table_list,
                                                             frs_data_env)

special_separation_rate_table <- frs_data_env$get_separation_table("special", 
                                                             entrant_profile_table_list, 
                                                             term_rate_male_table_list,
                                                             term_rate_female_table_list,
                                                             normal_retire_rate_tier_1_table_list,
                                                             normal_retire_rate_tier_2_table_list,
                                                             early_retire_rate_tier_1_table_list,
                                                             early_retire_rate_tier_2_table_list,
                                                             frs_data_env)

admin_separation_rate_table <- frs_data_env$get_separation_table("admin", 
                                                           entrant_profile_table_list, 
                                                           term_rate_male_table_list,
                                                           term_rate_female_table_list,
                                                           normal_retire_rate_tier_1_table_list,
                                                           normal_retire_rate_tier_2_table_list,
                                                           early_retire_rate_tier_1_table_list,
                                                           early_retire_rate_tier_2_table_list,
                                                           frs_data_env)

eco_separation_rate_table <- frs_data_env$get_separation_table("eco", 
                                                         entrant_profile_table_list, 
                                                         term_rate_male_table_list,
                                                         term_rate_female_table_list,
                                                         normal_retire_rate_tier_1_table_list,
                                                         normal_retire_rate_tier_2_table_list,
                                                         early_retire_rate_tier_1_table_list,
                                                         early_retire_rate_tier_2_table_list,
                                                         frs_data_env)

eso_separation_rate_table <- frs_data_env$get_separation_table("regular", # djb caution should this really be regular?? yes, it was this way in the file we got from Reason!! ----
                                                         entrant_profile_table_list, 
                                                         term_rate_male_table_list,
                                                         term_rate_female_table_list,
                                                         normal_retire_rate_tier_1_table_list,
                                                         normal_retire_rate_tier_2_table_list,
                                                         early_retire_rate_tier_1_table_list,
                                                         early_retire_rate_tier_2_table_list,
                                                         frs_data_env)

judges_separation_rate_table <- frs_data_env$get_separation_table("judges", 
                                                            entrant_profile_table_list, 
                                                            term_rate_male_table_list,
                                                            term_rate_female_table_list,
                                                            normal_retire_rate_tier_1_table_list,
                                                            normal_retire_rate_tier_2_table_list,
                                                            early_retire_rate_tier_1_table_list,
                                                            early_retire_rate_tier_2_table_list,
                                                            frs_data_env)

senior_management_separation_rate_table <- frs_data_env$get_separation_table("senior_management", 
                                                                       entrant_profile_table_list, 
                                                                       term_rate_male_table_list,
                                                                       term_rate_female_table_list,
                                                                       normal_retire_rate_tier_1_table_list,
                                                                       normal_retire_rate_tier_2_table_list,
                                                                       early_retire_rate_tier_1_table_list,
                                                                       early_retire_rate_tier_2_table_list,
                                                                       frs_data_env)

print("All done with separation tables")


