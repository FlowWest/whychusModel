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
lead_days_vec       <- c(1, 3, 7)
owrd_station        <- "14076100"  # Camp Polk
owrd_backup_station <- "14076050"  # WAS gage — used only if Camp Polk fails
nws_gridpoint       <- "PDT/35,57" # RM 8.5 area near Sisters, OR
threshold_tmax      <- 20.0
threshold_7dadm     <- 20          # HCP (°C)

# Known relationship for estimating Camp Polk flow from the WAS gage when
# Camp Polk is unavailable: lm(cp_flow ~ was_flow), R² = 0.9908, n = 248.
# No equivalent regression exists for temperature, so if Camp Polk temp is
# missing we fall back to the WAS gage's own reading directly (flagged via
# cp_temp_source so this is traceable in the inputs log).
CP_FROM_WAS_INTERCEPT <- 3.293170
CP_FROM_WAS_SLOPE     <- 1.026917

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
pull_start <- today - 10
pull_end   <- today

cp <- get_camp_polk_daily(pull_start, pull_end)

cp_today <- cp$cp_flow |>
  filter(date == today) |>
  left_join(cp$cp_tmax, by = "date") |>
  left_join(select(cp$cp_7dadm, date, cp_7dadm), by = "date")

cp_yest <- cp$cp_flow |>
  filter(date == today - 1) |>
  left_join(cp$cp_tmax, by = "date") |>
  left_join(select(cp$cp_7dadm, date, cp_7dadm), by = "date")

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

# ── 3. RM 8.5 lag (dummy: year == 2025 from rm_8_5_historical) ────────────────
rm85_lag_tmax <- rm_8_5_historical |>
  filter(statistic == "max", year(date) == 2025,
         month(date) == month(today), day(date) == day(today)) |>
  mutate(date = as.Date(date)) |>
  slice(1)

rm85_lag_dadm <- rm_8_5_historical |>
  filter(statistic == "7DADM", year(date) == 2025,
         month(date) == month(today), day(date) == day(today)) |>
  mutate(date = as.Date(date)) |>
  slice(1)

Tmax_m1 <- if (nrow(rm85_lag_tmax) > 0) rm85_lag_tmax$temperature else NA_real_
dadm_m1 <- if (nrow(rm85_lag_dadm) > 0) rm85_lag_dadm$temperature else NA_real_

cat(sprintf("RM 8.5 lag (2025 dummy): Tmax_m1 = %.2f °C,  dadm_m1 = %.2f °C\n", Tmax_m1, dadm_m1))

# ── 4. Build one full inputs table per lead day (single source of truth) ─────
build_inputs_row <- function(k) {
  fdate <- today + k
  
  air_max_k    <- daily_nws("maxTemperature", nws_tmax,  fdate,     max,  nws_log_fallback)
  air_min_k    <- daily_nws("minTemperature", nws_tmin,  fdate,     min,  nws_log_fallback)
  cloud_k      <- daily_nws("skyCover",       nws_cloud, fdate,     mean, nws_log_fallback)
  air_max_m1_k <- daily_nws("maxTemperature", nws_tmax,  fdate - 1, max,  nws_log_fallback)
  air_min_m1_k <- daily_nws("minTemperature", nws_tmin,  fdate - 1, min,  nws_log_fallback)
  
  tibble(
    run_date       = today,
    forecast_date  = fdate,
    lead_days      = k,
    cp_flow_mean   = cp_today$cp_flow_mean,
    cp_flow_source = cp$flow_source,
    cp_tmax        = cp_today$cp_tmax,
    cp_temp_source = cp$temp_source,
    cp_7dadm       = cp_today$cp_7dadm,
    Julian         = yday(fdate),
    air_max        = air_max_k$value,
    air_max_source = air_max_k$source,
    air_min        = air_min_k$value,
    air_min_source = air_min_k$source,
    cloud_pct      = cloud_k$value,
    cloud_source   = cloud_k$source,
    cp_flow_m1     = cp_yest$cp_flow_mean,
    cp_tmax_m1     = cp_yest$cp_tmax,
    cp_7dadm_m1    = cp_yest$cp_7dadm,
    air_max_m1     = air_max_m1_k$value,
    air_min_m1     = air_min_m1_k$value,
    Tmax_m1        = Tmax_m1,
    dadm_m1        = dadm_m1
  )
}

model_inputs <- map_dfr(lead_days_vec, build_inputs_row)

# NEW: running audit log of every input + its source, one row per lead day
update_log(model_inputs, model_inputs_log_file)

# feat_tmax / feat_7dadm are just the columns each RF model was trained on —
# derived from model_inputs so there's no duplicated feature-building logic
feat_tmax_rows <- model_inputs |>
  select(run_date, forecast_date, lead_days,
         cp_flow_mean, cp_tmax, Julian, air_max, air_min, cloud_pct,
         cp_flow_m1, cp_tmax_m1, air_max_m1, air_min_m1, Tmax_m1)

feat_7dadm_rows <- model_inputs |>
  select(run_date, forecast_date, lead_days,
         cp_flow_mean, cp_7dadm, Julian, air_max, air_min, cloud_pct,
         cp_flow_m1, cp_7dadm_m1, air_max_m1, air_min_m1, dadm_m1)

#update_log(feat_tmax_rows, feat_tmax_log_file)
#update_log(feat_7dadm_rows, feat_7dadm_log_file)

# ── 5. Predict across all lead days ───────────────────────────────────────────
results_list <- map(feat_tmax_rows$lead_days, function(k) {
  fdate <- today + k
  
  rf_tmax  <- readRDS(here("output", paste0("rm85_rf_tmax_lead",  k, ".rds")))
  rf_7dadm <- readRDS(here("output", paste0("rm85_rf_7dadm_lead", k, ".rds")))
  
  feat_tmax_x  <- feat_tmax_rows  |> filter(lead_days == k) |> select(-run_date, -forecast_date, -lead_days)
  feat_7dadm_x <- feat_7dadm_rows |> filter(lead_days == k) |> select(-run_date, -forecast_date, -lead_days)
  
  actual_tmax <- rm_8_5_historical |>
    filter(statistic == "max", year(date) == 2025,
           month(date) == month(fdate), day(date) == day(fdate)) |>
    pull(temperature)
  
  actual_dadm <- rm_8_5_historical |>
    filter(statistic == "7DADM", year(date) == 2025,
           month(date) == month(fdate), day(date) == day(fdate)) |>
    pull(temperature)
  
  tibble(
    run_date       = today,
    forecast_date  = fdate,
    lead_days      = k,
    pred_tmax_C    = round(predict(rf_tmax,  feat_tmax_x),  2),
    pred_7dadm_C   = round(predict(rf_7dadm, feat_7dadm_x), 2),
    note = "dummy data"
  )
})

results <- bind_rows(results_list)

print(results, n = Inf)

# ── 6. Append instream forecast to cumulative log ─────────────────────────────
update_log(results, temp_forecast_log_file)
