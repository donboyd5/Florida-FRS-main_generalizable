
library(skimr)
ann_factor_retire_table |> skim()

benefit_table_stacked |> 
  filter(class=="admin") |> 
  skim_without_charts()

benefit_table |> 
  skim_without_charts()

summary(benefit_table_stacked |> 
          filter(class=="admin") |> 
          select(any_of(names(benefit_table))))
summary(benefit_table)


summary(dist_age_table_stacked |> 
          filter(class=="admin") |> 
          select(any_of(names(dist_age_table))))

summary(dist_age_table)

dist_age_table_stacked |> 
  filter(class=="admin") |> 
  select(any_of(names(dist_age_table))) |> 
  skim_without_charts()

dist_age_table |> 
  skim_without_charts()


final_benefit_table |> 
  skim_without_charts()

final_benefit_table_stacked |> 
  filter(class=="admin") |> 
  select(any_of(names(final_benefit_table))) |> 
  skim_without_charts()

benefit_val_table |> 
  skim_without_charts()

benefit_val_table_stacked |> 
  # filter(class=="admin") |> 
  # select(any_of(names(benefit_val_table))) |> 
  skim_without_charts()

tmp <- benefit_val_table_stacked |> 
  filter(class=="admin") |> 
  filter(is.na(pvfb_db_wealth_at_current_age) |
           pvfb_db_wealth_at_current_age != pvfb_db_wealth_at_current_age2)


tmp <- benefit_val_table_stacked |> 
  filter(is.na(pvfb_db_wealth_at_current_age))


