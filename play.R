pentools::get_pvfb
pentools::npv
pentools::get_pvfs

# pvfs_at_current_age = pentools::get_pvfs(remaining_prob_vec = remaining_prob,
#                                          interest_vec = dr,
#                                          sal_vec = salary),

remaining_prob_vec <- play$remaining_prob
interest_vec <- play$dr
sal_vec <- play$salary
calc <-pentools::get_pvfs(remaining_prob_vec, interest_vec, sal_vec) 
truth <- play$pvfs_at_current_age
test <- get_pvfs(remaining_prob_vec, interest_vec, sal_vec)
get_pvfs2(remaining_prob_vec, interest_vec, sal_vec) 

i <- 1
end <- length(remaining_prob_vec)
rp2 <- remaining_prob_vec[i:end] /  remaining_prob_vec[i]
saladj <- sal_vec[i:end] * rp2
npv(saladj, interest_vec[i], immediate = FALSE)

get_pvfs <- function(remaining_prob_vec, interest_vec, sal_vec){ 
  # this isn't any faster than the built-in function
  pv <- function(i){
    saladj <- sal_vec[i:end] * remaining_prob_vec[i:end] /  remaining_prob_vec[i]
    npv(saladj, interest_vec[i], immediate = FALSE)
  }
  end <- length(sal_vec)
  pvfs<- purrr::map_dbl(1:end, pv)
  pvfs
}

get_pvfs2 <- function(remaining_prob_vec, interest_vec, sal_vec){ 
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




ptpvfs <- function(remaining_prob_vec, interest_vec, sal_vec) 
{
  PVFS <- double(length = length(sal_vec))
  for (i in 1:length(sal_vec)) {
    remaining_prob_og <- remaining_prob_vec[i:length(remaining_prob_vec)]
    remaining_prob <- remaining_prob_og/remaining_prob_og[1]
    interest <- interest_vec[i]
    sal <- sal_vec[i:length(sal_vec)]
    sal_adjusted <- sal * remaining_prob
    PVFS[i] <- npv(interest, sal_adjusted)
  }
  return(PVFS)
}

play <- 
  benefit_val_table_stacked |> 
  filter(class=="admin",
         entry_age==20,
         entry_year==1990) |> 
  select(class, entry_year, entry_age,
         remaining_prob,
         dr, 
         salary,
         pvfs_at_current_age)

sep_rate_vec <- play$separation_rate
interest_vec <- play$dr
value_vec <- play$pvfb_db_wealth_at_term_age
calc <- get_pvfb(sep_rate_vec, interest_vec, value_vec) 
truth <- play$pvfb_db_wealth_at_current_age


library(microbenchmark)

get_pvfb2(sep_rate_vec, interest_vec, value_vec)
pentools::get_pvfb(sep_rate_vec, interest_vec, value_vec)

pentools::get_pvfs(remaining_prob_vec, interest_vec, sal_vec) 

res <- microbenchmark(
  pentools::get_pvfs(remaining_prob_vec, interest_vec, sal_vec),
  get_pvfs(remaining_prob_vec, interest_vec, sal_vec),
  get_pvfs2(remaining_prob_vec, interest_vec, sal_vec),
  times = 10000
)
print(res)
str(res)

# where are the nas? ----
findnas <- benefit_val_table_stacked |> 
  filter(is.na(pvfb_db_wealth_at_current_age)) |> 
  select(class, entry_year, entry_age, separation_rate, dr, pvfb_db_wealth_at_term_age, pvfb_db_wealth_at_current_age)

basenas <- findnas |>
  filter(row_number() == 1) |> 
  select(class, entry_year, entry_age) |> 
  left_join(benefit_val_table_stacked, by=join_by(class, entry_year, entry_age)) |> 
  select(class, entry_year, entry_age, separation_rate, dr, pvfb_db_wealth_at_term_age, pvfb_db_wealth_at_current_age)


pentools::get_pvfb(sep_rate_vec=c(.2, .1, .05, 1),
                   interest_vec=c(.1, .1, .1, .1),
                   value_vec=c(0, 100, 200, 300))

