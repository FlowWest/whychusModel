# scripts/common.R
# Shared by scripts/fetch_nws.R, scripts/fetch_camp_polk.R and
# scripts/run-daily-forecast.R (sourced; fetch_hydrovu.R has its own config in
# hydrovu_config.R and follows the same data-directory convention).
#
# Data lives in the separate whychusData repo:
#   input/   one CSV per data source, written by the fetch_*.R scripts
#   output/  model_outputs.csv, written by run-daily-forecast.R
#
# WHYCHUS_DATA_DIR points at whychusData's input/ folder (the same variable
# hydrovu_config.R reads); output/ is its sibling. Defaults to a whychusData
# clone sitting next to this repo.

DATA_INPUT_DIR <- Sys.getenv("WHYCHUS_DATA_DIR",
                             file.path(dirname(here::here()), "whychusData", "input"))
DATA_OUTPUT_DIR <- file.path(dirname(DATA_INPUT_DIR), "output")

if (!dir.exists(dirname(DATA_INPUT_DIR))) {
  stop("whychusData repo not found at ",
       normalizePath(dirname(DATA_INPUT_DIR), mustWork = FALSE),
       "; clone it next to whychusModel or set WHYCHUS_DATA_DIR.", call. = FALSE)
}
dir.create(DATA_INPUT_DIR,  showWarnings = FALSE, recursive = TRUE)
dir.create(DATA_OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# Script runs at 8 pm Pacific, which is the next day in UTC; anchor "today" to
# Pacific time so the run date is correct regardless of the runner's clock.
TZ_PACIFIC <- "America/Los_Angeles"
today <- as.Date(Sys.time(), tz = TZ_PACIFIC)

# Exit non-zero so a failed source shows up on the GitHub Action step.
abort_missing <- function(msg) {
  message("Aborting: ", msg)
  quit(status = 1)
}

#' A CSV column with no values at all (e.g. `note` when no lead was skipped) is
#' read back by readr as logical, and a logical column cannot be combined with
#' text. Give such a column in `x` the type of the same-named column in `other`.
#' Without this, the first run after a file holds only blank notes crashes.
align_blank_columns <- function(x, other) {
  for (nm in intersect(names(x), names(other))) {
    if (is.logical(x[[nm]]) && all(is.na(x[[nm]])) && !is.logical(other[[nm]])) {
      x[[nm]] <- other[[nm]][rep(NA_integer_, nrow(x))]
    }
  }
  x
}

#' Append `new_rows` to a CSV log, replacing any existing rows for `run_date`.
update_log <- function(new_rows, log_file, run_date_val = today) {
  if (file.exists(log_file)) {
    existing <- readr::read_csv(log_file, show_col_types = FALSE) |>
      dplyr::mutate(dplyr::across(dplyr::any_of(c("run_date", "forecast_date")), as.Date)) |>
      dplyr::filter(run_date != run_date_val)
    updated <- dplyr::bind_rows(align_blank_columns(existing, new_rows),
                                align_blank_columns(new_rows, existing))
  } else {
    updated <- new_rows
  }
  readr::write_csv(updated, log_file)
  cat(sprintf("Log updated: %s (%d total rows)\n", log_file, nrow(updated)))
  invisible(updated)
}

#' Merge `new_rows` into a date-keyed CSV: rows for any date present in
#' `new_rows` are replaced, all other dates are kept.
upsert_by_date <- function(new_rows, file) {
  if (file.exists(file)) {
    existing <- readr::read_csv(file, show_col_types = FALSE) |>
      dplyr::mutate(date = as.Date(date)) |>
      dplyr::filter(!date %in% new_rows$date)
    updated <- dplyr::bind_rows(align_blank_columns(existing, new_rows),
                                align_blank_columns(new_rows, existing))
  } else {
    updated <- new_rows
  }
  updated <- dplyr::arrange(updated, date)
  readr::write_csv(updated, file)
  cat(sprintf("Updated: %s (%d total rows)\n", file, nrow(updated)))
  invisible(updated)
}
