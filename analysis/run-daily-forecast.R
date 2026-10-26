.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths()))
library(tidyverse)
library(lubridate)
library(randomForest)
library(zoo)
library(here)
library(whychusModel)

# Since script runs at 7 pm PST, it is 3 am UTC the next day; anchor "today"
# to Pacific time so the forecast date is correct regardless of run time.
today <- as.Date(Sys.time(), tz = "America/Los_Angeles")
cat(sprintf("Running RM 8.5 forecast for %s\n", today))

# ── Config ────────────────────────────────────────────────────────────────────
lead_days_vec       <- 1:7
owrd_station             <- "14076100"  # Camp Polk
owrd_flow_backup_station <- "14076050"  # Whychus Cr at Sisters (WAS) — flow backup
owrd_temp_backup_station <- "14075000"  # Whychus Cr nr Sisters — temperature backup
nws_gridpoint       <- "PDT/35,57" # RM 8.5 area near Sisters, OR
threshold_7dadm     <- 20          # HCP (°C)

# Must match `trend_window` in analysis/rm85-rf-delta.Rmd — the saved models
# were trained on slopes computed over this many days.
trend_window        <- 5

# Backup relationships used only when Camp Polk is unavailable. Each is flagged
# in the inputs log (cp_flow_source / cp_temp_source) so a run that used one is
# traceable.
#
# Flow: lm(cp_flow ~ was_flow) from the WAS gage (14076050),
# R² = 0.9908, n = 248.
CP_FROM_WAS_INTERCEPT <- 3.293170
CP_FROM_WAS_SLOPE     <- 1.026917

# Temperature: lm(camp_polk_daily_max ~ gage_14075000_daily_max), fit on the
# package's historical records over May-October (the model season) —
# n = 1,268 days, 2016-2026, R² = 0.9119, RMSE = 1.08 °C. Using the upstream
# gage's reading directly instead would run ~2.8 °C too cold, so the
# regression is not optional. Refit these if the historical records are
# extended substantially.
CP_FROM_14075000_INTERCEPT <- 1.658134
CP_FROM_14075000_SLOPE     <- 1.106763

output_dir             <- here("output")
temp_forecast_log_file <- file.path(output_dir, "instream-forecast-log.csv")
forecast_log           <- file.path(output_dir, "nws-forecasts-log.csv")
#feat_tmax_log_file     <- file.path(output_dir, "feat-tmax-log.csv")
#feat_7dadm_log_file    <- file.path(output_dir, "feat-7dadm-log.csv")
model_inputs_log_file  <- file.path(output_dir, "model-inputs-log.csv")  

# ── Helpers ───────────────────────────────────────────────────────────────────

abort_missing <- function(msg) {
  message("Aborting: ", msg)
  quit(status = 1)
}

#' Append `new_rows` to a CSV log, replacing any existing rows for `run_date`.
#' Consolidates the repeated read/filter/bind/write pattern used across all
#' of the script's logs.
update_log <- function(new_rows, log_file, run_date_val = today) {
  if (file.exists(log_file)) {
    existing <- read_csv(log_file, show_col_types = FALSE) |>
      mutate(across(any_of(c("run_date", "forecast_date")), as.Date)) |>
      filter(run_date != run_date_val)
    updated <- bind_rows(existing, new_rows)
  } else {
    updated <- new_rows
  }
  write_csv(updated, log_file)
  cat(sprintf("Log updated: %s (%d total rows)\n", log_file, nrow(updated)))
  invisible(updated)
}

#' Pull Camp Polk daily flow/temp/7DADM, falling back to backup gages if
#' Camp Polk is unavailable: flow uses gage 14076050 (WAS) via the flow
#' regression; temperature uses gage 14075000 via the temp regression.
get_camp_polk_daily <- function(pull_start, pull_end) {
  
  cp_flow_raw <- tryCatch(
    get_owrd_hydro(owrd_station, pull_start, pull_end, "Instantaneous_Flow"),
    error = function(e) { message("Camp Polk flow pull failed: ", conditionMessage(e)); NULL }
  )
  cp_tmax_raw <- tryCatch(
    get_owrd_hydro(owrd_station, pull_start, pull_end, "WTEMP15"),
    error = function(e) { message("Camp Polk temp pull failed: ", conditionMessage(e)); NULL }
  )
  
  flow_source <- "camp_polk"
  temp_source <- "camp_polk"
  
  if (is.null(cp_flow_raw) || nrow(cp_flow_raw) == 0) {
    message("Camp Polk flow unavailable — falling back to WAS gage 14076050 (regression)")
    was_flow_raw <- tryCatch(
      get_owrd_hydro(owrd_flow_backup_station, pull_start, pull_end, "Instantaneous_Flow"),
      error = function(e) { message("WAS gage flow pull failed: ", conditionMessage(e)); NULL }
    )
    if (is.null(was_flow_raw) || nrow(was_flow_raw) == 0) {
      abort_missing("Camp Polk and WAS backup flow both unavailable.")
    }
    cp_flow_raw <- was_flow_raw |>
      mutate(instananteous_flow_cfs = CP_FROM_WAS_INTERCEPT + CP_FROM_WAS_SLOPE * instananteous_flow_cfs)
    flow_source <- "was_regression"
  }
  
  if (is.null(cp_tmax_raw) || nrow(cp_tmax_raw) == 0) {
    message("Camp Polk temp unavailable — falling back to gage 14075000 (regression)")
    backup_temp_raw <- tryCatch(
      get_owrd_hydro(owrd_temp_backup_station, pull_start, pull_end, "WTEMP15"),
      error = function(e) { message("Gage 14075000 temp pull failed: ", conditionMessage(e)); NULL }
    )
    if (is.null(backup_temp_raw) || nrow(backup_temp_raw) == 0) {
      abort_missing("Camp Polk and gage 14075000 temperature both unavailable.")
    }
    cp_tmax_raw <- backup_temp_raw |>
      mutate(instantaneous_water_temp_c = CP_FROM_14075000_INTERCEPT + CP_FROM_14075000_SLOPE * instantaneous_water_temp_c)
    temp_source <- "gage14075000_regression"
  }
  
  cp_flow <- cp_flow_raw |>
    mutate(date = as.Date(parse_date_time(record_date, orders = c("mdy", "mdy HM")))) |>
    group_by(date) |>
    summarise(cp_flow_mean = mean(instananteous_flow_cfs, na.rm = TRUE)) |>
    arrange(date)
  
  cp_tmax <- cp_tmax_raw |>
    mutate(date = as.Date(parse_date_time(record_date, orders = c("mdy", "mdy HM")))) |>
    group_by(date) |>
    summarise(cp_tmax = max(instantaneous_water_temp_c, na.rm = TRUE)) |>
    arrange(date)
  
  cp_7dadm <- cp_tmax |>
    mutate(cp_7dadm = rollmean(cp_tmax, k = 7, fill = NA, align = "right"))
  
  list(cp_flow = cp_flow, cp_tmax = cp_tmax, cp_7dadm = cp_7dadm,
       flow_source = flow_source, temp_source = temp_source)
}

#' Pull one NWS variable. If the API call fails outright, fall back to the
#' most recent previous run of that variable in the forecast log ("use the
#' previous day"). Always returns datetime/value/variable/source columns.
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

#' Aggregate a variable to a single day. If that specific date is missing
#' from `primary_data` (e.g. forecast horizon too short), check the log for
#' the most recent run that covered that date before giving up.
daily_nws <- function(variable, primary_data, target_date, agg_fn, log_df,
                      tz = "America/Los_Angeles") {
  
  val <- primary_data |>
    mutate(date = as.Date(datetime, tz = tz)) |>
    filter(date == target_date) |>
    summarise(value = agg_fn(value, na.rm = TRUE)) |>
    pull(value)
  
  bad <- length(val) == 0 || is.nan(val) || is.na(val) || is.infinite(val)
  if (!bad) return(list(value = val, source = unique(primary_data$source)[1] %||% "api"))
  
  message(sprintf("No %s value for %s — checking log for that date", variable, target_date))
  if (!is.null(log_df)) {
    log_match <- log_df |>
      filter(variable == !!variable) |>
      mutate(date = as.Date(datetime, tz = tz)) |>
      filter(date == target_date) |>
      slice_max(run_date, n = 1)
    
    if (nrow(log_match) > 0) {
      val2 <- agg_fn(log_match$value, na.rm = TRUE)
      if (!is.nan(val2) && !is.na(val2) && !is.infinite(val2)) {
        message(sprintf("  [fallback] Used logged run_date %s for %s on %s",
                        unique(log_match$run_date), variable, target_date))
        return(list(value = val2, source = paste0("fallback_run_", unique(log_match$run_date))))
      }
    }
  }
  message(sprintf("  No fallback available for %s on %s — returning NA", variable, target_date))
  list(value = NA_real_, source = "missing")
}

`%||%` <- function(a, b) if (length(a) == 0 || is.na(a)) b else a

# ── 1. Camp Polk hydrology (OWRD, with WAS backup) ────────────────────────────
# The 5-day trend features reach back to run date - trend_window, and a 7DADM
# needs 7 days of daily maxima behind it, so pull far enough to cover both.
pull_start <- today - (trend_window + 9)
pull_end   <- today

cp <- get_camp_polk_daily(pull_start, pull_end)

cp_at <- function(d) {
  cp$cp_flow |>
    filter(date == d) |>
    left_join(cp$cp_tmax, by = "date") |>
    left_join(select(cp$cp_7dadm, date, cp_7dadm), by = "date")
}

cp_today <- cp_at(today)
cp_yest  <- cp_at(today - 1)
cp_mw    <- cp_at(today - trend_window)

# Slope over the trend window, run date - 1 back to run date - trend_window.
# Matches how the delta models were trained (cp_flow_trend / cp_7dadm_trend).
cp_flow_trend  <- (cp_yest$cp_flow_mean - cp_mw$cp_flow_mean) / (trend_window - 1)
cp_7dadm_trend <- (cp_yest$cp_7dadm     - cp_mw$cp_7dadm)     / (trend_window - 1)

# ── 2. NWS air temperature & cloud cover (with previous-day fallback) ────────
nws_log_fallback <- if (file.exists(forecast_log)) {
  read_csv(forecast_log, show_col_types = FALSE) |>
    mutate(
      forecast_date = as.Date(forecast_date),
      run_date      = as.Date(run_date),
      datetime      = as.POSIXct(forecast_date, tz = "America/Los_Angeles")
    )
} else NULL

nws_tmax  <- get_nws_variable("maxTemperature", nws_gridpoint, nws_log_fallback)
nws_tmin  <- get_nws_variable("minTemperature", nws_gridpoint, nws_log_fallback)
nws_cloud <- get_nws_variable("skyCover",       nws_gridpoint, nws_log_fallback)

# ── Print statements: NWS data ────────────────────────────────────────────────
cat("---- NWS maxTemperature ----\n")
print(nws_tmax, n = Inf)
cat("---- NWS minTemperature ----\n")
print(nws_tmin, n = Inf)
cat("---- NWS skyCover ----\n")
print(nws_cloud, n = Inf)

all_forecasts <- bind_rows(nws_tmax, nws_tmin, nws_cloud) |>
  mutate(
    run_date      = today,
    forecast_date = as.Date(datetime, tz = "America/Los_Angeles"),
    lead_days     = as.integer(forecast_date - today)
  ) |>
  select(run_date, forecast_date, lead_days, variable, value, source)

update_log(all_forecasts, forecast_log)


# ── 3. RM 8.5 current state (placeholder — no live source wired in yet) ──────
# The delta models are anchored on RM 8.5's own observed 7DADM and daily max
# on the run date (`dadm_m0`, `tmax_m0`) plus their slopes over the last
# `trend_window` days. This is the one input that has no live feed yet, so
# until one is connected it is stood in for by the 2025 value on the same
# calendar day, exactly as the previous version of this script did.
#
# Every prediction made from these values is therefore NOT a real forecast, and
# is labelled "dummy data" in the output log. To go live, replace the body of
# `get_rm85_observed()` and set `rm85_source` — nothing downstream changes.
rm85_source <- "dummy_2025"

get_rm85_observed <- function(run_date) {
  lookup_2025 <- function(stat, d) {
    d25 <- as.Date(sprintf("2025-%02d-%02d", month(d), day(d)))
    rm_8_5_historical |>
      filter(statistic == stat, as.Date(date) == d25) |>
      slice(1) |>
      pull(temperature) |>
      (\(x) if (length(x) == 0) NA_real_ else x)()
  }
  list(
    dadm_m0 = lookup_2025("7DADM", run_date),
    tmax_m0 = lookup_2025("max",   run_date),
    dadm_mw = lookup_2025("7DADM", run_date - trend_window),
    tmax_mw = lookup_2025("max",   run_date - trend_window)
  )
}

rm85 <- get_rm85_observed(today)

dadm_trend <- (rm85$dadm_m0 - rm85$dadm_mw) / trend_window
tmax_trend <- (rm85$tmax_m0 - rm85$tmax_mw) / trend_window

cat(sprintf("RM 8.5 state (%s): dadm_m0 = %.2f, tmax_m0 = %.2f, dadm_trend = %+.3f, tmax_trend = %+.3f\n",
            rm85_source, rm85$dadm_m0, rm85$tmax_m0, dadm_trend, tmax_trend))

# ── 4. Forecast trajectory: one NWS value per day for days 1..max lead ───────
# Built once and sliced per lead below. At lead k the model sees days 1..k.
max_lead <- max(lead_days_vec)

trajectory <- map_dfr(seq_len(max_lead), function(j) {
  fdate <- today + j
  mx <- daily_nws("maxTemperature", nws_tmax,  fdate, max,  nws_log_fallback)
  mn <- daily_nws("minTemperature", nws_tmin,  fdate, min,  nws_log_fallback)
  cl <- daily_nws("skyCover",       nws_cloud, fdate, mean, nws_log_fallback)
  tibble(
    day = j, forecast_date = fdate, julian = yday(fdate),
    air_max = mx$value, air_max_source = mx$source,
    air_min = mn$value, air_min_source = mn$source,
    cloud   = cl$value, cloud_source   = cl$source
  )
})

# ── 5. Build one full inputs row per lead (single source of truth) ───────────
# Column names and order are exactly those the saved models were fit on
# (see get_model_features() in analysis/rm85-rf-delta.Rmd).
build_inputs_row <- function(k) {
  tr <- trajectory |> filter(day <= k)

  base <- tibble(
    run_date       = today,
    forecast_date  = today + k,
    lead_days      = k,
    cp_flow_mean   = cp_today$cp_flow_mean,
    cp_7dadm       = cp_today$cp_7dadm,
    cp_tmax        = cp_today$cp_tmax,
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
      # Provenance, so a bad forecast can be traced to its input.
      cp_flow_source  = cp$flow_source,
      cp_temp_source  = cp$temp_source,
      air_source      = paste(unique(c(tr$air_max_source, tr$air_min_source,
                                       tr$cloud_source)), collapse = ";"),
      rm85_source     = rm85_source
    )
  )
}

model_inputs <- map_dfr(lead_days_vec, build_inputs_row)

# Running audit log of every input + its source, one row per lead day
update_log(model_inputs, model_inputs_log_file)

# ── 6. Predict: model returns the CHANGE from today; add dadm_m0 back ────────
predict_lead <- function(k) {
  row   <- model_inputs |> filter(lead_days == k)
  model <- readRDS(here("output", paste0("rm85_rf_7dadm_delta_lead", k, ".rds")))

  # randomForest rejects NA predictors outright. A missing input (e.g. NWS
  # horizon too short for the last lead) should cost one lead, not the run.
  feats <- names(model$forest$xlevels)
  x     <- row[, feats, drop = FALSE]
  miss  <- feats[map_lgl(x, ~ anyNA(.x))]

  if (length(miss) > 0) {
    message(sprintf("Lead %d skipped — missing inputs: %s", k, paste(miss, collapse = ", ")))
    return(tibble(run_date = today, forecast_date = today + k, lead_days = k,
                  dadm_m0 = row$dadm_m0, pred_change_C = NA_real_,
                  pred_7dadm_C = NA_real_,
                  note = paste("skipped, missing:", paste(miss, collapse = ", "))))
  }

  change <- predict(model, x)

  tibble(
    run_date      = today,
    forecast_date = today + k,
    lead_days     = k,
    dadm_m0       = round(row$dadm_m0, 2),
    pred_change_C = round(as.numeric(change), 2),
    pred_7dadm_C  = round(row$dadm_m0 + as.numeric(change), 2),
    note          = if (rm85_source == "dummy_2025") "dummy data" else NA_character_
  )
}

results <- map_dfr(lead_days_vec, predict_lead)

print(results, n = Inf)

# ── 7. Append instream forecast to cumulative log ─────────────────────────────
update_log(results, temp_forecast_log_file)
