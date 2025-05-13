named_list <- function(...) {
  vars <- enquos(...)
  set_names(list(...), nm = sapply(vars, quo_name))
  # Usage:
  # tbl_list <- named_list(tbl1, tbl2, tbln)
}

separate_class <- function(data, col, into, sep = "_") {
  data  |> 
    mutate(
      temp_split = str_split_fixed(!!sym(col), sep, n = 3),
      !!into[1] := if_else(temp_split[, 1] == "senior" & temp_split[, 2] == "management",
                           paste(temp_split[, 1], temp_split[, 2], sep = "_"),
                           temp_split[, 1]),
      !!into[2] := if_else(temp_split[, 1] == "senior" & temp_split[, 2] == "management",
                           temp_split[, 3],
                           paste(temp_split[, 2], temp_split[, 3], sep = "_"))
    )  |> 
    select(-temp_split)
}


ups_wfdata <- function(wf_data_list){
  # Usage example:
  # Assuming wf_data_list is already defined, you can call:
  # wf_data_stacked_list <- ups_wfdata(wf_data_list)
  
  # Define the names of the categories and the data frames
  categories <- names(wf_data_list)
  dfnames <- c("wf_active_df", "wf_term_df", "wf_refund_df", "wf_retire_df")
  
  # Function to combine data from all categories and add a "class" column
  f <- function(dfname){
    purrr::map(categories, function(category) {
      wf_data_list[[category]][[dfname]] |> 
        mutate(class = stringr::str_remove(category, "_wf_data"))
    }) |> 
      list_rbind() |> 
      relocate(class) |> 
      as_tibble()
  }
  
  # Create a named list with stacked tibbles
  wf_stacked_list <- 
    purrr::set_names(dfnames, str_remove(dfnames, "_df") |> 
                       paste0("_stacked")) |>
    purrr::map(f)
  
  return(wf_stacked_list)
}

stack_list <- function(thelist, suffix) {
  bind_rows(thelist, .id = "name") |> 
    mutate(class = str_remove(name, suffix)) |>
    select(-name) |> 
    select(class, everything())
}


