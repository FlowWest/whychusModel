.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths()))
library(tidyverse)
library(lubridate)
library(randomForest)
library(zoo)
library(here)
library(whychusModel)

# Since script runs at 7 pm PST, it is 3 am UTC and therefore "today" is set to the next day. 
# Subtracting 1 makes it the actual day of the forecast. 
#today <- Sys.Date() - 1 
today <- as.Date(Sys.time(), tz = "America/Los_Angeles")
cat(sprintf("Running RM 8.5 forecast for %s\n", today))

# ── Config ────────────────────────────────────────────────────────────────────
lead_days_vec   <- c(1, 3, 7)
owrd_station    <- "14076100"   # Camp Polk
nws_gridpoint   <- "PDT/35,57" # RM 8.5 area near Sisters, OR
threshold_tmax  <- 20.0         # HCP (°C)
threshold_7dadm <- 17.8         # ODEQ (°C)
temp_forecast_log_file <- here("output", "instream-forecast-log.csv")
forecast_log    <- here("output", "nws-forecasts-log.csv")

# ── 1. Camp Polk hydrology (OWRD) ─────────────────────────────────────────────
pull_start <- today - 10
pull_end   <- today

cp_flow_raw <- tryCatch(
  get_owrd_hydro(owrd_station, pull_start, pull_end, "Instantaneous_Flow"),
  error = function(e) { message("OWRD flow pull failed: ", conditionMessage(e)); NULL }
)
cp_tmax_raw <- tryCatch(
  get_owrd_hydro(owrd_station, pull_start, pull_end, "WTEMP15"),
  error = function(e) { message("OWRD temp pull failed: ", conditionMessage(e)); NULL }
)

if (is.null(cp_flow_raw) || is.null(cp_tmax_raw)) {
  message("Aborting: OWRD data unavailable.")
  quit(status = 1)
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

cp_today <- cp_flow |>
  filter(date == today) |>
  left_join(cp_tmax, by = "date") |>
  left_join(select(cp_7dadm, date, cp_7dadm), by = "date")

cp_yest <- cp_flow |>
  filter(date == today - 1) |>
  left_join(cp_tmax, by = "date") |>
  left_join(select(cp_7dadm, date, cp_7dadm), by = "date")

# ── 2. NWS air temperature & cloud cover ──────────────────────────────────────
nws_tmax  <- tryCatch(get_nws_forecast(nws_gridpoint, "maxTemperature"), error = function(e) NULL)
nws_tmin  <- tryCatch(get_nws_forecast(nws_gridpoint, "minTemperature"), error = function(e) NULL)
nws_cloud <- tryCatch(get_nws_forecast(nws_gridpoint, "skyCover"),       error = function(e) NULL)

if (is.null(nws_tmax) || is.null(nws_tmin) || is.null(nws_cloud)) {
  message("NWS API unavailable — falling back to nws-forecasts-log.csv")
  
  nws_log_file <- here("output", "nws-forecasts-log.csv")
  
  if (!file.exists(nws_log_file)) {
    message("Aborting: NWS data unavailable and no forecast log found.")
    quit(status = 1)
  }
  
  nws_log <- read_csv(nws_log_file, show_col_types = FALSE) |>
    mutate(
      forecast_date = as.Date(forecast_date),
      datetime      = as.POSIXct(forecast_date, tz = "America/Los_Angeles")
    )
  
  # pull the most recent logged forecast for each variable/date combination
  latest_run <- nws_log |>
    filter(forecast_date >= today) |>
    group_by(variable, forecast_date) |>
    slice_max(run_date, n = 1) |>
    ungroup()
  
  if (is.null(nws_tmax))
    nws_tmax  <- latest_run |> filter(variable == "maxTemperature") |> select(datetime, value)
  if (is.null(nws_tmin))
    nws_tmin  <- latest_run |> filter(variable == "minTemperature") |> select(datetime, value)
  if (is.null(nws_cloud))
    nws_cloud <- latest_run |> filter(variable == "skyCover")       |> select(datetime, value)
  
  # final check — if any variable still has no rows, abort
  if (nrow(nws_tmax) == 0 || nrow(nws_tmin) == 0 || nrow(nws_cloud) == 0) {
    message("Aborting: fallback log missing one or more required variables.")
    quit(status = 1)
  }
  
  message("Fallback successful — using most recent logged NWS forecasts.")
}

all_forecasts <- bind_rows(
  nws_tmax, 
  nws_tmin, 
  nws_cloud
) |> 
  mutate(
    run_date     = today,
    forecast_date = as.Date(datetime, tz = "America/Los_Angeles"),
    lead_days    = as.integer(forecast_date - today)
  ) |>
  select(run_date, forecast_date, lead_days, variable, value) 

daily_nws <- function(df, target_date, agg_fn = mean) {
  result <- df |>
    mutate(date = as.Date(datetime)) |>
    filter(date == target_date) |>
    summarise(value = agg_fn(value, na.rm = TRUE)) |>
    pull(value)
  
  if (length(result) == 0 || is.nan(result)) NA_real_ else result
}

# ── 3. RM 8.5 dummy lag (year == 2025 from rm_8_5_historical) ─────────────────
rm85_lag_tmax <- rm_8_5_historical |>
  filter(statistic == "max",
         year(date)  == 2025,
         month(date) == month(today),
         day(date)   == day(today)) |>
  mutate(date = as.Date(date)) |>
  slice(1)

rm85_lag_dadm <- rm_8_5_historical |>
  filter(statistic == "7DADM",
         year(date)  == 2025,
         month(date) == month(today),
         day(date)   == day(today)) |>
  mutate(date = as.Date(date)) |>
  slice(1)

Tmax_m1 <- if (nrow(rm85_lag_tmax) > 0) rm85_lag_tmax$temperature else NA_real_
dadm_m1  <- if (nrow(rm85_lag_dadm) > 0) rm85_lag_dadm$temperature else NA_real_

cat(sprintf("RM 8.5 lag (2025 dummy): Tmax_m1 = %.2f °C,  dadm_m1 = %.2f °C\n",
            Tmax_m1, dadm_m1))

print(nws_tmax)

# ── 4. Predict across all lead days ───────────────────────────────────────────
results_list <- map(lead_days_vec, function(k) {
  fdate <- today + k

  air_max_k    <- daily_nws(nws_tmax,  fdate,     max)
  air_min_k    <- daily_nws(nws_tmin,  fdate,     min)
  cloud_k      <- daily_nws(nws_cloud, fdate,     mean)
  air_max_m1_k <- daily_nws(nws_tmax,  fdate - 1, max)
  air_min_m1_k <- daily_nws(nws_tmin,  fdate - 1, min)

  feat_tmax <- data.frame(
    cp_flow_mean = cp_today$cp_flow_mean,
    cp_tmax      = cp_today$cp_tmax,
    Julian       = yday(fdate),
    air_max      = air_max_k,
    air_min      = air_min_k,
    cloud_pct    = cloud_k,
    cp_flow_m1   = cp_yest$cp_flow_mean,
    cp_tmax_m1   = cp_yest$cp_tmax,
    air_max_m1   = air_max_m1_k,
    air_min_m1   = air_min_m1_k,
    Tmax_m1      = Tmax_m1
  )

  feat_7dadm <- data.frame(
    cp_flow_mean = cp_today$cp_flow_mean,
    cp_7dadm     = cp_today$cp_7dadm,
    Julian       = yday(fdate),
    air_max      = air_max_k,
    air_min      = air_min_k,
    cloud_pct    = cloud_k,
    cp_flow_m1   = cp_yest$cp_flow_mean,
    cp_7dadm_m1  = cp_yest$cp_7dadm,
    air_max_m1   = air_max_m1_k,
    air_min_m1   = air_min_m1_k,
    dadm_m1      = dadm_m1
  )

  rf_tmax  <- readRDS(here("output", paste0("rm85_rf_tmax_lead",  k, ".rds")))
  rf_7dadm <- readRDS(here("output", paste0("rm85_rf_7dadm_lead", k, ".rds")))

  # 2025 "actuals" for the same calendar day as the forecast date
  actual_tmax <- rm_8_5_historical |>
    filter(statistic == "max",
           year(date)  == 2025,
           month(date) == month(fdate),
           day(date)   == day(fdate)) |>
    pull(temperature)

  actual_dadm <- rm_8_5_historical |>
    filter(statistic == "7DADM",
           year(date)  == 2025,
           month(date) == month(fdate),
           day(date)   == day(fdate)) |>
    pull(temperature)

  tibble(
    run_date       = today,
    forecast_date  = fdate,
    lead_days      = k,
    pred_tmax_C    = round(predict(rf_tmax,  feat_tmax),  2),
    pred_7dadm_C   = round(predict(rf_7dadm, feat_7dadm), 2),
    actual_tmax_C  = if (length(actual_tmax) > 0) actual_tmax[[1]] else NA_real_,
    actual_7dadm_C = if (length(actual_dadm) > 0) actual_dadm[[1]] else NA_real_,
    note = "dummy data"
  )
})

results <- bind_rows(results_list) |>
  mutate(
    tmax_error   = round(pred_tmax_C  - actual_tmax_C,  2),
    dadm_error   = round(pred_7dadm_C - actual_7dadm_C, 2),
    exceed_tmax  = pred_tmax_C  > threshold_tmax,
    exceed_7dadm = pred_7dadm_C > threshold_7dadm
  )

print(results, n = Inf)

# ── 5. Append to cumulative log ────────────────────────────────────────────────
if (file.exists(temp_forecast_log_file)) {
  existing <- read_csv(temp_forecast_log_file, show_col_types = FALSE) |>
    filter(as.Date(run_date) != today)  # drop any prior run from today before re-appending
  updated <- bind_rows(existing, results)
} else {
  updated <- results
}

write_csv(updated, temp_forecast_log_file)
cat(sprintf("Instream Temp Forecast log updated: %s (%d total rows)\n", temp_forecast_log_file, nrow(updated)))

# NWS: 
if (file.exists(forecast_log)) {
  existing_nws <- read_csv(forecast_log, show_col_types = FALSE) |>
    filter(as.Date(run_date) != today)  # drop any prior run from today before re-appending
  updated_nws <- bind_rows(existing_nws, all_forecasts)
} else {
  updated_nws <- all_forecasts
}

write_csv(updated_nws, forecast_log)
cat(sprintf("NWS Forecast log updated: %s (%d total rows)\n", forecast_log, nrow(updated_nws)))
