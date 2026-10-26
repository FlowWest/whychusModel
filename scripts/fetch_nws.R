# scripts/fetch_nws.R
# Appends today's NWS forecast (max temp, min temp, sky cover) to nws.csv in
# the whychusData repo's input/ folder (see DATA_INPUT_DIR in common.R).
#
# One row per run x variable x forecast period. Cumulative: re-running a day
# replaces that day's rows. If the NWS API fails for a variable, the most
# recent previous run of that variable is re-logged under today's run date
# with a `fallback_run_<date>` source, so downstream code always finds a
# complete run.
#
# Run daily by .github/workflows/daily-forecast.yml. To run locally:
#   Rscript scripts/fetch_nws.R
library(tidyverse)
library(here)
library(whychusModel)

source(here("scripts", "common.R"))

nws_gridpoint <- "PDT/35,57" # RM 8.5 area near Sisters, OR
nws_file      <- file.path(DATA_INPUT_DIR, "nws.csv")

cat(sprintf("Fetching NWS forecast for %s\n", today))

#' Pull one NWS variable. If the API call fails outright, fall back to the
#' most recent previous run of that variable in the log ("use the previous
#' day"). Always returns datetime/value/variable/source columns.
get_nws_variable <- function(variable, gridpoint, log_df) {
  result <- tryCatch(get_nws_forecast(gridpoint, variable), error = function(e) NULL)

  if (!is.null(result) && nrow(result) > 0) {
    return(result |> mutate(variable = variable, source = "api"))
  }

  message(sprintf("NWS API failed for %s — falling back to previous day's forecast run", variable))
  if (is.null(log_df)) abort_missing(sprintf("%s unavailable from API and no forecast log exists.", variable))

  fallback <- log_df |>
    filter(variable == !!variable) |>
    slice_max(run_date, n = 1)

  if (nrow(fallback) == 0) {
    abort_missing(sprintf("%s unavailable from API and no logged runs exist.", variable))
  }

  message(sprintf("  [fallback] Using run_date %s for %s", unique(fallback$run_date), variable))
  fallback |>
    select(datetime, value) |>
    mutate(variable = variable, source = paste0("fallback_run_", unique(fallback$run_date)))
}

nws_log_fallback <- if (file.exists(nws_file)) {
  read_csv(nws_file, show_col_types = FALSE) |>
    mutate(
      forecast_date = as.Date(forecast_date),
      run_date      = as.Date(run_date),
      datetime      = as.POSIXct(forecast_date, tz = TZ_PACIFIC)
    )
} else NULL

nws_tmax  <- get_nws_variable("maxTemperature", nws_gridpoint, nws_log_fallback)
nws_tmin  <- get_nws_variable("minTemperature", nws_gridpoint, nws_log_fallback)
nws_cloud <- get_nws_variable("skyCover",       nws_gridpoint, nws_log_fallback)

cat("---- NWS maxTemperature ----\n"); print(nws_tmax, n = Inf)
cat("---- NWS minTemperature ----\n"); print(nws_tmin, n = Inf)
cat("---- NWS skyCover ----\n");       print(nws_cloud, n = Inf)

all_forecasts <- bind_rows(nws_tmax, nws_tmin, nws_cloud) |>
  mutate(
    run_date      = today,
    forecast_date = as.Date(datetime, tz = TZ_PACIFIC),
    lead_days     = as.integer(forecast_date - today)
  ) |>
  select(run_date, forecast_date, lead_days, variable, value, source)

update_log(all_forecasts, nws_file)
