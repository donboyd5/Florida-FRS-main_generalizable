
# Get FRS data ------------------------------------------------------------

#.. Import key data tables ----
FileName <- fs::path(sddir, "Florida FRS inputs.xlsx")

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



# Stacked salary and count tables -----------------------------------------

salary_list <- list(
  regular = regular_salary_table_,
  special = special_salary_table_,
  admin   = admin_salary_table_,
  eco     = eco_salary_table_,
  eso     = eso_salary_table_,
  judges  = judges_salary_table_,
  senior  = senior_management_salary_table_
)

headcount_list <- list(
  regular = regular_headcount_table_,
  special = special_headcount_table_,
  admin   = admin_headcount_table_,
  eco     = eco_headcount_table_,
  eso     = eso_headcount_table_,
  judges  = judges_headcount_table_,
  senior  = senior_management_headcount_table_
)

salary_table_ <- map2_df(salary_list,
                         names(salary_list),
                         ~ .x %>%
                           mutate(employee_class = .y)) %>%
  pivot_longer(
    cols = -c(employee_class, age),
    names_to = "yos",
    values_to = "salary"
  ) %>%
  mutate(yos = as.numeric(yos))

headcount_table_ <- map2_df(headcount_list,
                            names(headcount_list),
                            ~ .x %>%
                              mutate(employee_class = .y)) %>%
  pivot_longer(
    cols = -c(employee_class, age),
    names_to = "yos",
    values_to = "count"
  ) %>%
  mutate(yos = as.numeric(yos))

count(salary_table_, employee_class)
count(salary_table_, employee_class, age)
count(headcount_table_ , employee_class)

unique(salary_table_$age)
unique(salary_table_$yos)
unique(headcount_table_$yos)
unique(headcount_table_$age)

unique_classes <- unique(salary_table_$employee_class)
full_ages <- 20:67
full_yos <- 2:52

expanded_table <- expand.grid(employee_class = unique_classes, age = full_ages, yos = full_yos)

#   To be imputed
#   salary_table_fill <- expanded_table %>%
#   left_join(salary_table_, by = c("employee_class", "age", "yos")) %>%
#   group_by(employee_class, age) %>%
#   mutate(salary = approx)
#   ungroup()


####
# Retirement rate tables

drop_entry_tier_1_table_ <- read_excel(fs::path(xidir, "drop entry tier 1.xlsx"))
drop_entry_tier_2_table_ <- read_excel(fs::path(xidir, "drop entry tier 2.xlsx"))

normal_retirement_tier_1_table_ <- read_excel(fs::path(xidir, "normal retirement tier 1.xlsx"))
normal_retirement_tier_2_table_ <- read_excel(fs::path(xidir, "normal retirement tier 2.xlsx"))

early_retirement_tier_1_table_ <- read_excel(fs::path(xidir, "early retirement tier 1.xlsx"))
early_retirement_tier_2_table_ <- read_excel(fs::path(xidir, "early retirement tier 2.xlsx"))

#Termination rate tables

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


# stacked termination rates -----------------------------------------------

male_list <- list(
  regular = regular_term_rate_male_table_,
  special = special_term_rate_male_table_,
  admin   = admin_term_rate_male_table_,
  eco     = eco_term_rate_male_table_,
  eso     = eso_term_rate_male_table_,
  judges  = judges_term_rate_male_table_,
  senior  = senior_management_term_rate_male_table_
)

female_list <- list(
  regular = regular_term_rate_female_table_,
  special = special_term_rate_female_table_,
  admin   = admin_term_rate_female_table_,
  eco     = eco_term_rate_female_table_,
  eso     = eso_term_rate_female_table_,
  judges  = judges_term_rate_female_table_,
  senior  = senior_management_term_rate_female_table_
)

term_rate_male_table_ <- map2_df(male_list,
                                 names(male_list),
                                 ~ .x %>%
                                   mutate(employee_class = .y, gender = "male")) %>%
  pivot_longer(
    cols = -c(employee_class, yos, gender),
    names_to = "age",
    values_to = "rate"
  )

term_rate_female_table_ <- map2_df(female_list,
                     names(female_list),
                     ~ .x %>%
                       mutate(employee_class = .y, gender = "female")) %>%
  pivot_longer(
    cols = -c(employee_class, yos, gender),
    names_to = "age",
    values_to = "rate"
  )

term_rate_ <- bind_rows(term_rate_male_table_, term_rate_female_table_)

term_rate_age <- term_rate_ %>%
  mutate(age = case_when(
    age == "25_to_29" ~ list(25:29),
    age == "30_to_34" ~ list(30:34),
    age == "35_to_44" ~ list(35:44),
    age == "45_to_54" ~ list(45:54),
    age == "over_55" ~ list(55:100)  # Assuming 100 as an upper bound
  )) %>%
  unnest(age)  # Expand age ranges into individual rows

count(term_rate_age, employee_class, gender, age)
count(term_rate_age, employee_class, gender, yos)
unique(term_rate_age$age)
unique(term_rate_age$yos)
## Note that age under 25 with 30 yos still have positive withdraw rates from the input tables, which is likely not correct

######

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

#.. FRS Retirement benefit assumptions ----
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

#We account for the Investment Plan (DC plan) head count by inflating the DB head count by the ratio of total system head count to DB head count
#ECO, ESO, and Judges head counts are processed separately as the ACFR does not provide detailed head counts for these classes 
eco_eso_judges_active_member_adjustment_ratio <- eco_eso_judges_total_active_member_ / sum(eco_headcount_table_[-1] + eso_headcount_table_[-1] + judges_headcount_table_[-1])
