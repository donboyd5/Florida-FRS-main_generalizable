### Test tables ###

get_class_salary_growth_table <- function(class_name, salary_growth_table){
  
  class_salary_growth_table <- salary_growth_table %>% 
    select(yos, contains(class_name)) %>% 
    rename(cumprod_salary_increase = 2)
  
  return(class_salary_growth_table)
}

class_list <- c("admin", "regular", "special", "eco", "eso", "judges", "senior_management")

walk(class_list, function(class_name) {
  table1 <- get_class_salary_growth_table(class_name, params$salary_growth_table_)
  table2 <- params$salary_growth_table %>% filter(class == class_name)
  identical_result <- all.equal(table1$cumprod_salary_increase, table2$cumprod_salary_increase)
  message(sprintf("Class: %s - Identical: %s", class_name, identical_result))
})







