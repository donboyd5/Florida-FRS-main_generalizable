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

  return(result)
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

  # Return as-is (schemas are compatible)
  # Select only required columns in case better structure has extras
  result <- amortization_bases_tbl[, required_cols]

  return(result)
}
