# Helper Functions for FRS Pension Model
# These functions support migration from legacy to better pendata structures

#' Get Constant from constants_assumptions_tbl
#'
#' Extracts a single constant value from the constants_assumptions_tbl by variable name.
#' This function replaces direct access to individual params$ scalar values.
#'
#' @param constants_tbl A data frame with columns: variable, value, description
#' @param var_name Character string naming the variable to extract
#' @param default Optional default value if variable not found (default: NULL, which throws error)
#'
#' @return The value of the constant (numeric, character, or logical depending on storage)
#'
#' @examples
#' # Legacy approach:
#' # dr_current <- params$dr_current_
#'
#' # Better structure approach:
#' # dr_current <- get_constant(params$constants_assumptions_tbl, "dr_current")
#'
get_constant <- function(constants_tbl, var_name, default = NULL) {
  # Validate inputs
  if (!is.data.frame(constants_tbl)) {
    stop("constants_tbl must be a data frame")
  }

  if (!all(c("variable", "value") %in% names(constants_tbl))) {
    stop("constants_tbl must have 'variable' and 'value' columns")
  }

  if (!is.character(var_name) || length(var_name) != 1) {
    stop("var_name must be a single character string")
  }

  # Look up the constant
  matching_rows <- constants_tbl[constants_tbl$variable == var_name, ]

  if (nrow(matching_rows) == 0) {
    if (is.null(default)) {
      stop(sprintf("Variable '%s' not found in constants_assumptions_tbl", var_name))
    } else {
      return(default)
    }
  }

  if (nrow(matching_rows) > 1) {
    warning(sprintf("Multiple rows found for '%s', using first value", var_name))
  }

  return(matching_rows$value[1])
}


#' Validate Better Structure Schema
#'
#' Checks that a better structure table has expected columns.
#' Used during migration to ensure data schemas match requirements.
#'
#' @param tbl The data frame to validate
#' @param expected_cols Character vector of required column names
#' @param tbl_name Optional name for better error messages (default: NULL)
#' @param allow_extra Whether to allow extra columns not in expected_cols (default: TRUE)
#'
#' @return Invisible TRUE if validation passes, otherwise stops with error
#'
#' @examples
#' # Validate headcount_salary has required columns
#' validate_better_structure(
#'   params$headcount_salary,
#'   expected_cols = c("class", "entry_year", "entry_age", "salary", "count"),
#'   tbl_name = "headcount_salary"
#' )
#'
validate_better_structure <- function(tbl, expected_cols, tbl_name = NULL, allow_extra = TRUE) {
  # Set default table name for messages
  if (is.null(tbl_name)) {
    tbl_name <- deparse(substitute(tbl))
  }

  # Check it's a data frame
  if (!is.data.frame(tbl)) {
    stop(sprintf("%s must be a data frame, got %s", tbl_name, class(tbl)[1]))
  }

  # Check for missing required columns
  actual_cols <- names(tbl)
  missing_cols <- setdiff(expected_cols, actual_cols)

  if (length(missing_cols) > 0) {
    stop(sprintf(
      "%s is missing required columns: %s",
      tbl_name,
      paste(missing_cols, collapse = ", ")
    ))
  }

  # Optionally check for unexpected extra columns
  if (!allow_extra) {
    extra_cols <- setdiff(actual_cols, expected_cols)
    if (length(extra_cols) > 0) {
      warning(sprintf(
        "%s has unexpected columns: %s",
        tbl_name,
        paste(extra_cols, collapse = ", ")
      ))
    }
  }

  invisible(TRUE)
}


#' Get Better Structure Table Name
#'
#' Maps legacy table names to better structure equivalents.
#' Useful for programmatic migration and backward compatibility.
#'
#' @param legacy_name Character string of legacy table name
#'
#' @return Character string of better structure name, or NULL if no mapping exists
#'
#' @examples
#' get_better_table_name("salary_headcount_table")  # Returns "headcount_salary"
#' get_better_table_name("separation_rate_table")   # Returns "withdrawal"
#'
get_better_table_name <- function(legacy_name) {
  # Mapping from legacy to better structures (Tier 1 tables)
  mapping <- c(
    "salary_headcount_table" = "headcount_salary",
    "salary_growth_table" = "salarygrowth",
    "separation_rate_table" = "withdrawal",
    "retiree_distribution" = "retirees",
    "current_amort_layers_table" = "amortization_bases"
  )

  result <- mapping[legacy_name]

  if (is.na(result)) {
    return(NULL)
  }

  return(unname(result))
}


# =============================================================================
# ADAPTER FUNCTIONS - Convert better structures to legacy format
# =============================================================================
# These adapters allow existing model functions to work unchanged while
# using better pendata structures internally. This is a Tier 1 migration
# strategy - later we can refactor functions to use better structures directly.


#' Convert salarygrowth (better) to salary_growth_table (legacy)
#'
#' Transforms range-based salary growth to point-based with cumulative products.
#'
#' @param salarygrowth_tbl Better structure with columns: class, yos_lb, yos_ub, value
#'
#' @return Legacy format with columns: yos, class, cumprod_salary_increase
#'
#' @details
#' The better structure has:
#'   - Range-based yos (yos_lb/ub)
#'   - Single-year growth rates (value)
#'
#' The legacy structure needs:
#'   - Point yos values
#'   - Cumulative product of (1 + growth_rate)
#'
#' Strategy:
#'   - Expand ranges to individual yos values
#'   - Calculate cumulative product by class
#'
convert_salarygrowth_to_legacy <- function(salarygrowth_tbl) {
  # Validate input
  required_cols <- c("class", "yos_lb", "yos_ub", "value")
  if (!all(required_cols %in% names(salarygrowth_tbl))) {
    stop(sprintf("salarygrowth_tbl missing columns: %s",
                 paste(setdiff(required_cols, names(salarygrowth_tbl)), collapse = ", ")))
  }

  # Expand ranges: for yos_lb=yos_ub (point values), just use that value
  # For yos_lb<yos_ub (actual ranges), expand to all integer values
  expanded <- lapply(seq_len(nrow(salarygrowth_tbl)), function(i) {
    row <- salarygrowth_tbl[i, ]
    yos_seq <- row$yos_lb:row$yos_ub
    data.frame(
      class = rep(row$class, length(yos_seq)),
      yos = yos_seq,
      growth_rate = rep(row$value, length(yos_seq)),
      stringsAsFactors = FALSE
    )
  })

  expanded_df <- do.call(rbind, expanded)

  # Calculate cumulative product by class
  # Sort by class and yos to ensure correct order
  expanded_df <- expanded_df[order(expanded_df$class, expanded_df$yos), ]

  # Calculate cumulative product within each class
  # Start at 1.0 for yos=0, then multiply by (1 + growth_rate) cumulatively
  # The growth rate at yos=N applies to get from yos=N to yos=N+1
  expanded_df$cumprod_salary_increase <- ave(
    expanded_df$growth_rate,
    expanded_df$class,
    FUN = function(rates) {
      # Start with 1.0, then cumulatively multiply by (1 + rate)
      # But the rate at position i applies BEFORE reaching that position
      # So we need to lag the rates
      c(1.0, cumprod(1 + rates[-length(rates)]))
    }
  )

  # Return legacy format
  result <- expanded_df[, c("yos", "class", "cumprod_salary_increase")]

  # ===========================================================================
  # TODO: REMOVE THIS BLOCK WHEN READY TO USE CORRECT DATA
  #
  # DELIBERATE DATA PATCH — backward-compatibility hack
  #
  # pendata has the CORRECT value: yos=7, regular = 0.045 (4.5%)
  # The legacy Excel "Florida FRS inputs.xlsx" has a TRANSCRIPTION ERROR:
  #   yos=7, regular = 0.044 (4.4%)
  # Authoritative source: Milliman AV2022 p.A-22 confirms 4.5% is correct
  #   (file: refactor/source_data/Reports/Florida FRS Valuation 2022.pdf)
  #
  # We override here (NOT in pendata) to preserve exact backward compatibility
  # with prior model results during the refactor. pendata must stay correct.
  #
  # To remove: delete this block, then update the test baseline
  #   (expect ~0.096% change in baseline_funding for the regular class).
  #
  # Tracked in: https://github.com/gchen3/Florida-FRS-main_generalizable/issues/6
  # ===========================================================================
  reg_mask <- result$class == "regular"
  reg      <- result[reg_mask, ]
  reg      <- reg[order(reg$yos), ]

  # Get growth rates for regular in yos order, then patch yos=7 to wrong value
  reg_rates <- expanded_df$growth_rate[expanded_df$class == "regular"]
  reg_rates <- reg_rates[order(expanded_df$yos[expanded_df$class == "regular"])]
  reg_rates[reg$yos == 7L] <- 0.044   # override correct 0.045 with legacy error

  # Recompute all cumprod values for regular from the patched rates
  reg$cumprod_salary_increase <- c(1.0, cumprod(1 + reg_rates[-length(reg_rates)]))
  result[reg_mask, ] <- reg
  # ===========================================================================

  return(result)
}


#' Convert retirees (better) to retiree_distribution (legacy)
#'
#' Transforms range-based retiree counts/benefits to age-point ratios.
#'
#' @param retirees_tbl Better structure with columns: type, age_lb, age_ub, count, benefits
#'
#' @return Legacy format with columns: age, n_retire, total_ben, avg_ben,
#'   n_retire_ratio, total_ben_ratio
#'
#' @details
#' The better structure has:
#'   - Two types (disability, normearly) combined here into totals
#'   - Range-based age bands (age_lb/age_ub)
#'   - Raw counts and benefits (benefits in thousands of dollars)
#'
#' The legacy structure needs:
#'   - One row per age (45-120)
#'   - n_retire and total_ben for each age (repeated within each band)
#'   - Ratio columns: n_retire_ratio and total_ben_ratio (each sum to 1)
#'
#' Hard-coded assumptions required (not derivable from better structure alone):
#'   1. Minimum retiree age = 45 (the "Under 50" band maps to ages 45-49)
#'   2. The "80 & Up" band is split into 5 legacy sub-bands using fixed weights:
#'      80-84: 50%, 85-89: 25%, 90-94: 12.5%, 95-99: 2.5%, 100-120: 10%
#'      These weights reproduce the original retiree_distribution exactly.
#'
convert_retirees_to_legacy <- function(retirees_tbl) {
  # Validate input
  required_cols <- c("type", "age_lb", "age_ub", "count", "benefits")
  if (!all(required_cols %in% names(retirees_tbl))) {
    stop(sprintf("retirees_tbl missing columns: %s",
                 paste(setdiff(required_cols, names(retirees_tbl)), collapse = ", ")))
  }

  # Step 1: Sum disability + normearly by age band; convert benefits thousands -> dollars
  combined <- aggregate(
    cbind(n_retire_band = count, total_ben_band = benefits) ~ age_lb + age_ub,
    data = retirees_tbl,
    FUN = sum
  )
  combined$total_ben_band <- combined$total_ben_band * 1000  # thousands -> dollars
  combined <- combined[order(combined$age_lb), ]

  # Step 2: Expand each age band to individual age rows
  # "Under 50" (age_lb=18, age_ub=49) -> ages 45-49 only (matches legacy minimum age of 45)
  # 50-79 bands -> expand evenly across all ages in band
  # "80 & Up" (age_lb=80, age_ub=120) -> split into 5 legacy sub-bands with fixed weights:
  #   These weights (50/25/12.5/2.5/10%) are intrinsic to the legacy model and cannot
  #   be derived from the better structure's single "80 & Up" bucket.
  sub_band_80plus <- list(
    list(ages = 80:84,   weight = 0.500),
    list(ages = 85:89,   weight = 0.250),
    list(ages = 90:94,   weight = 0.125),
    list(ages = 95:99,   weight = 0.025),
    list(ages = 100:120, weight = 0.100)
  )

  expanded <- lapply(seq_len(nrow(combined)), function(i) {
    lb            <- combined$age_lb[i]
    ub            <- combined$age_ub[i]
    n_total       <- combined$n_retire_band[i]
    ben_total     <- combined$total_ben_band[i]

    if (lb >= 80) {
      # "80 & Up" band: apply legacy sub-band weights
      rows <- lapply(sub_band_80plus, function(sb) {
        n <- length(sb$ages)
        data.frame(
          age      = sb$ages,
          n_retire = rep(n_total * sb$weight / n, n),
          total_ben = rep(ben_total * sb$weight / n, n),
          stringsAsFactors = FALSE
        )
      })
      do.call(rbind, rows)
    } else {
      # All other bands: distribute evenly across ages
      # "Under 50" (lb=18) -> use 45:ub to match legacy minimum age of 45
      age_start <- max(lb, 45L)
      ages      <- age_start:ub
      n         <- length(ages)
      data.frame(
        age       = ages,
        n_retire  = rep(n_total / n, n),
        total_ben = rep(ben_total / n, n),
        stringsAsFactors = FALSE
      )
    }
  })

  expanded_df <- do.call(rbind, expanded)
  expanded_df <- expanded_df[order(expanded_df$age), ]

  # Step 3: Derived columns
  expanded_df$avg_ben         <- expanded_df$total_ben / expanded_df$n_retire
  expanded_df$n_retire_ratio  <- expanded_df$n_retire  / sum(expanded_df$n_retire)
  expanded_df$total_ben_ratio <- expanded_df$total_ben / sum(expanded_df$total_ben)

  result <- expanded_df[, c("age", "n_retire", "total_ben", "avg_ben",
                             "n_retire_ratio", "total_ben_ratio")]
  rownames(result) <- NULL
  return(tibble::as_tibble(result))
}


#' Convert amortization_bases (better) to current_amort_layers_table (legacy)
#'
#' The schemas are nearly identical, so this is mostly a direct pass-through.
#'
#' @param amortization_bases_tbl Better structure
#'
#' @return Legacy format with same columns: class, date, amo_period, amo_balance
#'
#' @details
#' The only difference is that the better structure date is already proper date format
#' (e.g. "1999-06-30") while legacy might have been text (e.g. "June 30, 1999").
#' This adapter ensures compatibility.
#'
convert_amortization_to_legacy <- function(amortization_bases_tbl) {
  # Validate input
  required_cols <- c("class", "date", "amo_period", "amo_balance")
  if (!all(required_cols %in% names(amortization_bases_tbl))) {
    stop(sprintf("amortization_bases_tbl missing columns: %s",
                 paste(setdiff(required_cols, names(amortization_bases_tbl)), collapse = ", ")))
  }

  # Select required columns
  result <- amortization_bases_tbl[, required_cols]

  # Normalize class names: "senior management" (space) -> "senior_management" (underscore)
  # This is a data quality issue in amortization_bases - all other better structures use underscore
  result$class <- gsub(" ", "_", result$class, fixed = TRUE)

  # Convert amo_period from integer to character and NA to "n/a"
  # Better structure: amo_period is integer with NA values
  # Legacy structure: amo_period is character with "n/a" strings
  result$amo_period <- as.character(result$amo_period)
  result$amo_period[is.na(result$amo_period)] <- "n/a"

  return(result)
}
