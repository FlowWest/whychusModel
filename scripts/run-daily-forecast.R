# scripts/run-daily-forecast.R
# Forecasts RM 8.5 7DADM at leads 1-7 days with the delta random forests
# (output/rm85_rf_7dadm_delta_lead*.rds) and writes two logs in the whychusData
# repo:
#   input/model_inputs.csv   the full feature row fed to the model, per lead
#   output/model_outputs.csv  the forecast, per lead
#
# Apart from those two logs this script only READS data. The input CSVs in
# whychusData's input/ folder are refreshed beforehand by
# scripts/fetch_hydrovu.R, scripts/fetch_nws.R and scripts/fetch_camp_polk.R,
# in that order, by .github/workflows/daily-forecast.yml. To run locally, run
# those first (or `git pull` whychusData) and then:
#   Rscript scripts/run-daily-forecast.R
#
# Both logs began life as the old model-inputs-log.csv and
# instream-forecast-log.csv, and those rows are kept as they were. The delta
# model's inputs cannot be expressed in the old fixed-column layout (it uses
# 17-41 lead-dependent predictors), so new rows ADD columns to the right of the
# old ones instead of replacing them. Columns the two generations share
# (run_date, forecast_date, lead_days, cp_flow_mean, cp_tmax, cp_7dadm, the
# *_source columns, pred_7dadm_C, note) mean the same thing in both; columns
# only one generation has are blank in the other's rows (e.g. pred_tmax_C,
# which the delta models do not produce).
.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths()))
library(tidyverse)
library(lubridate)
library(randomForest)
library(zoo)
library(here)

source(here("scripts", "common.R"))

cat(sprintf("Running RM 8.5 forecast for %s\n", today))

# ── Config ────────────────────────────────────────────────────────────────────
lead_days_vec <- 1:7

# Must match `trend_window` in analysis/rm85-rf-delta.Rmd — the saved models
# were trained on slopes computed over this many days.
trend_window <- 5

# RM 8.5 logger readings in hydro_vu.csv: parameter 1 is water temperature (°C).
hv_temp_parameter_id <- "1"
# A day's max is only trusted if it has at least this many readings. The logger
# reports hourly, and the run happens in the evening, so a complete past day
# has 24 and today has ~19-20; a thin day (logger outage, or the partial first
# day of a fresh pull) would otherwise understate the max.
hv_min_readings <- 18

input_files <- list(
  camp_polk = file.path(DATA_INPUT_DIR, "camp_polk.csv"),
  nws       = file.path(DATA_INPUT_DIR, "nws.csv"),
  hydrovu   = file.path(DATA_INPUT_DIR, "hydro_vu.csv")
)
model_inputs_file <- file.path(DATA_INPUT_DIR,  "model_inputs.csv")
model_output_file <- file.path(DATA_OUTPUT_DIR, "model_outputs.csv")

missing_inputs <- names(input_files)[!file.exists(unlist(input_files))]
if (length(missing_inputs) > 0) {
  abort_missing(sprintf("input file(s) not found in %s: %s",
                        DATA_INPUT_DIR, paste(missing_inputs, collapse = ", ")))
}

# ── 1. Camp Polk (input/camp_polk.csv) ────────────────────────────────────────
camp_polk <- read_csv(input_files$camp_polk, show_col_types = FALSE) |>
  mutate(date = as.Date(date))

#' One Camp Polk value on a date; NA if that date is absent.
cp_val <- function(col, d) {
  v <- camp_polk[[col]][camp_polk$date == d]
  if (length(v) == 0) NA_real_ else v[[1]]
}

# Slope over the trend window, run date - 1 back to run date - trend_window.
# Matches how the delta models were trained (cp_flow_trend / cp_7dadm_trend).
cp_flow_trend  <- (cp_val("cp_flow_mean", today - 1) - cp_val("cp_flow_mean", today - trend_window)) / (trend_window - 1)
cp_7dadm_trend <- (cp_val("cp_7dadm",     today - 1) - cp_val("cp_7dadm",     today - trend_window)) / (trend_window - 1)

cp_today_row <- camp_polk |> filter(date == today)
cp_flow_source <- if (nrow(cp_today_row)) cp_today_row$flow_source[[1]] else "missing"
cp_temp_source <- if (nrow(cp_today_row)) cp_today_row$temp_source[[1]] else "missing"

# ── 2. RM 8.5 current state (input/hydro_vu.csv, HydroVu logger) ──────────────
# The delta models are anchored on RM 8.5's own observed 7DADM and daily max
# on the run date (`dadm_m0`, `tmax_m0`) plus their slopes over the last
# `trend_window` days. Timestamps are true UTC (fetch_hydrovu.R corrects the
# device clock), so convert to Pacific before taking calendar-day maxima.
hv <- read_csv(input_files$hydrovu, show_col_types = FALSE,
               col_types = cols(.default = col_character())) |>
  mutate(timestamp = ymd_hms(timestamp, tz = "UTC"),
         value     = as.numeric(value)) |>
  filter(parameter_id == hv_temp_parameter_id)

if (n_distinct(hv$location_id) > 1) {
  abort_missing("hydro_vu.csv holds more than one HydroVu location; filter to the RM 8.5 location_id before computing daily statistics.")
}

rm85_daily <- hv |>
  mutate(date = as.Date(timestamp, tz = TZ_PACIFIC)) |>
  group_by(date) |>
  summarise(n_readings = n(), tmax = max(value, na.rm = TRUE), .groups = "drop") |>
  mutate(tmax = if_else(n_readings >= hv_min_readings, tmax, NA_real_)) |>
  # Insert absent days so a gap breaks the rolling mean instead of being skipped.
  complete(date = seq(min(date), max(date), by = "day")) |>
  arrange(date) |>
  # mean() without na.rm: any missing day in the window makes the 7DADM NA.
  mutate(dadm = rollapply(tmax, width = 7, FUN = mean, fill = NA, align = "right"))

rm85_val <- function(col, d) {
  v <- rm85_daily[[col]][rm85_daily$date == d]
  if (length(v) == 0) NA_real_ else v[[1]]
}

rm85 <- list(
  dadm_m0 = rm85_val("dadm", today),
  tmax_m0 = rm85_val("tmax", today),
  dadm_mw = rm85_val("dadm", today - trend_window),
  tmax_mw = rm85_val("tmax", today - trend_window)
)

dadm_trend <- (rm85$dadm_m0 - rm85$dadm_mw) / trend_window
tmax_trend <- (rm85$tmax_m0 - rm85$tmax_mw) / trend_window

# Provenance for the RM 8.5 inputs, logged on every row of model_inputs.csv. A
# NA dadm_m0 is usually explained by a low reading count on the run date (a
# stalled HydroVu feed), which is invisible in the numbers themselves.
rm85_readings_today <- {
  n <- rm85_val("n_readings", today)
  if (is.na(n)) 0L else as.integer(n)
}
rm85_source <- if (nrow(hv) > 0) "hydro_vu" else "missing"

cat(sprintf("RM 8.5 state: dadm_m0 = %.2f, tmax_m0 = %.2f, dadm_trend = %+.3f, tmax_trend = %+.3f\n",
            rm85$dadm_m0, rm85$tmax_m0, dadm_trend, tmax_trend))

# ── 3. NWS forecast (input/nws.csv) ──────────────────────────────────────────
nws <- read_csv(input_files$nws, show_col_types = FALSE) |>
  mutate(across(c(run_date, forecast_date), as.Date)) |>
  filter(run_date <= today)

#' One variable on one forecast date, taken from the most recent run that
#' covers that date. Normally that is today's run; if today's fetch failed or
#' its horizon is too short, it is the latest earlier run, and the source says
#' so ("fallback_run_<date>").
daily_nws <- function(variable, target_date, agg_fn) {
  rows <- nws |> filter(variable == !!variable, forecast_date == target_date)
  if (nrow(rows) == 0) return(list(value = NA_real_, source = "missing"))

  latest <- rows |> filter(run_date == max(run_date))
  val    <- agg_fn(latest$value, na.rm = TRUE)
  if (!is.finite(val)) return(list(value = NA_real_, source = "missing"))

  src <- if (unique(latest$run_date) == today) unique(latest$source)[[1]]
         else paste0("fallback_run_", unique(latest$run_date))
  list(value = val, source = src)
}

# One NWS value per day for days 1..max lead, built once and sliced per lead.
max_lead <- max(lead_days_vec)

trajectory <- map_dfr(seq_len(max_lead), function(j) {
  fdate <- today + j
  mx <- daily_nws("maxTemperature", fdate, max)
  mn <- daily_nws("minTemperature", fdate, min)
  cl <- daily_nws("skyCover",       fdate, mean)
  tibble(
    day = j, forecast_date = fdate, julian = yday(fdate),
    air_max = mx$value, air_max_source = mx$source,
    air_min = mn$value, air_min_source = mn$source,
    cloud   = cl$value, cloud_source   = cl$source
  )
})

# ── 4. Build one full inputs row per lead ────────────────────────────────────
# Column names and order are exactly those the saved models were fit on
# (see get_model_features() in analysis/rm85-rf-delta.Rmd).
#' Distinct, sorted sources in a vector, joined by ";" ("api", or
#' "api;fallback_run_2026-10-25" when days 1..k came from different runs).
src_string <- function(x) paste(sort(unique(unlist(strsplit(x, ";")))), collapse = ";")

build_inputs_row <- function(k) {
  tr <- trajectory |> filter(day <= k)

  base <- tibble(
    run_date       = today,
    forecast_date  = today + k,
    lead_days      = k,
    cp_flow_mean   = cp_val("cp_flow_mean", today),
    cp_7dadm       = cp_val("cp_7dadm",     today),
    cp_tmax        = cp_val("cp_tmax",      today),
    cp_flow_trend  = cp_flow_trend,
    cp_7dadm_trend = cp_7dadm_trend
  )

  daily <- bind_cols(
    set_names(as.list(tr$air_max), paste0("air_max_d", tr$day)),
    set_names(as.list(tr$air_min), paste0("air_min_d", tr$day)),
    set_names(as.list(tr$cloud),   paste0("cloud_d",   tr$day)),
    set_names(as.list(tr$julian),  paste0("julian_d",  tr$day))
  )

  bind_cols(
    base, daily,
    tibble(
      dadm_m0    = rm85$dadm_m0,
      tmax_m0    = rm85$tmax_m0,
      dadm_trend = dadm_trend,
      tmax_trend = tmax_trend,
      # Shape-of-the-week summaries over days 1..k.
      traj_air_max_max  = max(tr$air_max),
      traj_air_max_mean = mean(tr$air_max),
      traj_air_min_mean = mean(tr$air_min),
      traj_warming      = tr$air_max[k] - tr$air_max[1],
      # Provenance, so a bad forecast can be traced to its input. Air sources
      # are per variable (a fallback can hit one NWS variable and not the
      # others) and list every distinct source used across days 1..k.
      cp_flow_source      = cp_flow_source,
      cp_temp_source      = cp_temp_source,
      air_max_source      = src_string(tr$air_max_source),
      air_min_source      = src_string(tr$air_min_source),
      cloud_source        = src_string(tr$cloud_source),
      rm85_source         = rm85_source,
      rm85_readings_today = rm85_readings_today
    )
  )
}

model_inputs <- map_dfr(lead_days_vec, build_inputs_row)

# Audit log of every input and its source, one row per lead per run.
update_log(model_inputs, model_inputs_file)

# ── 5. Predict: model returns the CHANGE from today; add dadm_m0 back ────────
predict_lead <- function(k) {
  row   <- model_inputs |> filter(lead_days == k)
  model <- readRDS(here("output", paste0("rm85_rf_7dadm_delta_lead", k, ".rds")))

  # model_outputs.csv carries one compact air_source; the per-variable detail is
  # in model_inputs.csv.
  prov <- row |>
    mutate(air_source = src_string(c(air_max_source, air_min_source, cloud_source))) |>
    select(cp_flow_source, cp_temp_source, air_source)

  # randomForest rejects NA predictors outright. A missing input (e.g. NWS
  # horizon too short for the last lead) should cost one lead, not the run.
  feats <- names(model$forest$xlevels)
  x     <- row[, feats, drop = FALSE]
  miss  <- feats[map_lgl(x, ~ anyNA(.x))]

  if (length(miss) > 0) {
    message(sprintf("Lead %d skipped — missing inputs: %s", k, paste(miss, collapse = ", ")))
    return(bind_cols(
      tibble(run_date = today, forecast_date = today + k, lead_days = k,
             dadm_m0 = row$dadm_m0, pred_change_C = NA_real_, pred_7dadm_C = NA_real_,
             note = paste("skipped, missing:", paste(miss, collapse = ", "))),
      prov))
  }

  change <- predict(model, x)

  bind_cols(
    tibble(run_date      = today,
           forecast_date = today + k,
           lead_days     = k,
           dadm_m0       = round(row$dadm_m0, 2),
           pred_change_C = round(as.numeric(change), 2),
           pred_7dadm_C  = round(row$dadm_m0 + as.numeric(change), 2),
           note          = NA_character_),
    prov)
}

results <- map_dfr(lead_days_vec, predict_lead)

print(results, n = Inf)

# ── 6. Append to the cumulative output log ───────────────────────────────────
update_log(results, model_output_file)
