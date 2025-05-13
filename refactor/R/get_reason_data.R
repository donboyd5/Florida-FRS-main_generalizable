

# setup -------------------------------------------

source(here::here("data-raw", "frs", "_common_frs.R"))
wspath <- path(dfreason, "reason_workspace.RData")

# load Reason workspace into its own environment ------------------------------
# load takes some time

load(wspath, rws <- new.env())


# prep to work with the environment ---------------------------------------

objnames <- ls(name=rws) # names of objects in the workspace
objnames
# get(objnames[119], envir=rws) # how to get an object from the workspace

get_object <- function(x){
  # get an object from the workspace
  get(x, envir = rws)
}

reason_classes <- frs_constants$classes |>
  str_replace("seniormanagement", "senior_management")


# unpack workforce data ---------------------------------------------------
# regular_wf_data <- readRDS("regular_wf_data.rds")
# special_wf_data <- readRDS("special_wf_data.rds")
# admin_wf_data <- readRDS("admin_wf_data.rds")
# eco_wf_data <- readRDS("eco_wf_data.rds")
# eso_wf_data <- readRDS("eso_wf_data.rds")
# judges_wf_data <- readRDS("judges_wf_data.rds")
# senior_management_wf_data <- readRDS("senior_management_wf_data.rds")

wfnames <- paste0(reason_classes, "_wf_data")
wfnames # names of wf objects to extract from Reason workspace

wfclasses <- str_remove(wfnames, "_wf_data")


# get_object(wfnames[1])

# get one big list of lists of data frames
# outer list has 7 lists, one for each class
# each inner list has 4 data frames
#   wf_active_df, term, refund, retire
# they are similar but not the same in structure, but the same structure for each class
wflist <- wfnames |>
  purrr::map(\(x) get_object(x))|>
  purrr::set_names(wfclasses)

str(wflist[[1]])
(wfdfnames <- wflist[[1]] |> names())

# get 4 data frames, with classes stacked
nested <- wflist |>
  as_tibble() |>
  mutate(dfname=wfdfnames) |>
  pivot_longer(cols = -dfname, names_to = "class") |>
  pivot_wider(names_from = dfname)

unpack_dframes <- function(colname){
  print(colname)
  df <- nested |>
    select(class, nestcol=all_of(colname)) |>
    unnest_wider(col=nestcol) |>
    unnest_longer(col=-class)
  assign(colname, df, envir = .GlobalEnv)
}

purrr::walk(wfdfnames, unpack_dframes)

count(wf_refund_df, class)
count(wf_refund_df, class)

# create a list of wf data frames and save it as an rds file
wf_dataframes <- mget(wfdfnames)
saveRDS(wf_dataframes, fs::path(dfreason, "wf_dataframes.rds"))

# list2env(wf_dataframes, envir = .GlobalEnv) # put the dataframes into the environment


# look at the wf dataframes -----------------------------------------------
# sums are the same every year, so Reason must be bringing in  new entrants
# that replace separations, retirements, and deaths

wf_dataframes <- readRDS(fs::path(dfreason, "wf_dataframes.rds"))
list2env(wf_dataframes, envir = .GlobalEnv)

wf_active_df

wfsums <- wf_active_df |>
  summarise(value=sum(n_active), .by=c(class, year))

wfsums |>
  filter(year %in% c(2022:2025, 2030, 2035)) |>
  pivot_wider(names_from = class)

wf_active_df |>
  filter(n_active>0, class=="regular") |>
  filter(year %in% c(2022:2030)) |>
  summarise(value=sum(n_active), .by=c(age, year)) |>
  arrange(year) |>
  pivot_wider(names_from = year) |>
  arrange(age)

wf_active_df |>
  filter(n_active>0, class=="regular") |>
  mutate(agegroup=cut(age, c(-Inf, 24, 34, 44, 54, 64, Inf))) |>
  filter(year %in% c(2022:2030)) |>
  summarise(value=sum(n_active), .by=c(agegroup, year)) |>
  pivot_wider(names_from = agegroup)

wf_active_df |>
  filter(n_active>0, class=="regular") |>
  mutate(agegroup=cut(age, c(-Inf, 24, 34, 44, 54, 64, Inf))) |>
  filter(year %in% c(2022:2030, 2035, 2040, 2045, 2050)) |>
  summarise(value=sum(n_active), .by=c(agegroup, year)) |>
  mutate(value=value / sum(value), .by=c(year)) |>
  pivot_wider(names_from = agegroup) |>
  gt() |>
  fmt_percent(columns=-year, decimals=1)



# unpack ... ---------------------------------------------------

baseline_funding <- readRDS(fs::path(dfreason, "baseline_funding.rds"))
