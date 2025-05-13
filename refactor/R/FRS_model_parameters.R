##################################################################
##                  Model Inputs & Assumptions                  ##
##################################################################

#1. Actuarial and economic assumptions:
dr_old_ <- 0.068             #previous year's discount rate
dr_current_ <- 0.067        #discount rate for current members
dr_new_ <- 0.067            #discount rate for new members
payroll_growth_ <- 0.0325   #payroll growth assumption
pop_growth_ <- 0            #plan's active population growth assumption
inflation_ <- 0.024         #inflation assumption

#2. Benefit assumptions:
db_ee_interest_rate_ <- 0

#Cost of living adjustment (COLA) assumptions:
cola_tier_1_active_constant_ <- "no" #If yes, COLA for tier 1 active members is constant instead of reduced
cola_tier_1_active_ <- 0.03 #COLA for tier 1 active members
cola_tier_2_active_ <- 0 #COLA for tier 2 active members
cola_tier_3_active_ <- 0 #COLA for tier 3 active members

cola_current_retire_ <- cola_tier_1_active_ #COLA for current retirees
cola_current_retire_one_ <- 0 #One-time COLA for current retirees
one_time_cola_ <- F   #One-time COLA or not? True means yes, False means no

#DC Employer contributions:
regular_er_dc_cont_rate_ <- 0.066            #Regular's employer DC contribution rate
special_er_dc_cont_rate_ <- 0.1654           #Special Risk's employer DC contribution rate
admin_er_dc_cont_rate_ <- 0.0843             #Special Risk Admin's employer DC contribution rate
judges_er_dc_cont_rate_ <- 0.1405            #Judges' employer DC contribution rate
eso_er_dc_cont_rate_ <- 0.1195               #Local's employer DC contribution rate
eco_er_dc_cont_rate_ <- 0.0994               #Leg-Atty-Cab's employer DC contribution rate
senior_management_er_dc_cont_rate_ <- 0.0798 #Senior Management's employer DC contribution rate

#3. Funding assumptions
# the plan simply adopts all recommendations from its actuary board, so the "statutory" policy is equivalent to the "ADC" policy. 
funding_policy_ <- "statutory"              #Plan's funding policy: "statutory" means a fixed contribution rate; "ADC" means an actuarially determined contribution rate. For FRS, this input is irrelevant since the plan's statutory policy is equivalent to its ADC policy. 
db_ee_cont_rate_ <- 0.03                    #DB employee contribution rate

#Amortization policy
amo_pay_growth_ <- payroll_growth_         #payroll growth assumption for amortization purposes
amo_period_new_ <- 20                       #amortization period for new unfunded liabilities
amo_method_ <- "level %"                    #amortization method: "level %" means level percentage of payroll amortization; "level $" means level dollar amortization

#Other policies:
funding_lag_ <- 1                            #This is the additional time (in years) that it takes for the determined contribution rate to take effect after 1 year. By the default, the contribution rate will take effect one year after it's determined (funding lag = 0).
                                             #If the funding lag is 1, then the contribution rate will take effect 2 years after it's determined. 

#4. Investment assumptions
return_scen_ <- "assumption"                 #The deterministic return scenario to be used in the funding model. 
model_return_ <- dr_new_                     #The return used under the "model" scenario. By default, this is the same as the discount rate for the new tier.
return_2023_ <- 0.067                        #The return for fiscal year 2023. This will be updated/removed when the 2023 val report comes out.

#5. Plan design assumptions
#FRS plan membership classes are: Regular, Special Risk, Special Risk Administrative, Judicial,  Legislators/Attorney/Cabinet (ECO), Local (ESO), Senior Management
class_name_ <- "regular"

#DB ratios below are the proportions of members who choose the DB plan. The remaining members choose the DC plan (Investment Plan)
special_db_legacy_before_2018_ratio_ <- 0.95      #for special-risk plan's members hired before 2018
non_special_db_legacy_before_2018_ratio_ <- 0.75  #for non-special risk plan's members hired before 2018
special_db_legacy_after_2018_ratio_ <- 0.85       #for special risk plan's members hired between 2018 and new_year
non_special_db_legacy_after_2018_ratio_ <- 0.25   #for non-special risk plan's members hired between 2018 and new_year
special_db_new_ratio_ <- 0.75                     #for special risk plan's members hired after new_year
non_special_db_new_ratio_ <- 0.25                 #for non-special risk plan's members hired after new_year


#6. Model assumptions 
model_period_ <- 30     #Projection period (typically 30 years)
min_age_ <- 18          #Age of the typical youngest member
max_age_ <- 120         #Max age from mortality assumptions
start_year_ <- 2022     #Year of the latest val report (update this when a new val report comes out)
new_year_ <- 2024       #Year for new entrants with a new tier to join (update this when a new val report comes out)
min_year_ <- 1970       #No hard rule about this. Should get back to about 40 years from now.   
max_year_ <- start_year_ + model_period_ + max_age_ - min_age_

entry_year_range_ <- min_year_:(start_year_ + model_period_)
# RetYear <- MinYear:(YearStart + ModelPeriod)
year_range_ <- min_year_:max_year_
age_range_ <- min_age_:max_age_
yos_range_ <- 0:70
# RetirementAge <- Age

