library(tidyverse)
library(lubridate)
library(randomForest)
library(zoo)
library(here)
library(whychusModel)

#today <- as.Date("2025-06-22")
today <- as.Date("2025-08-01")
cat(sprintf("Running RM 8.5 forecast for %s\n", today))

# ── Config ────────────────────────────────────────────────────────────────────
lead_days_vec   <- c(1, 3, 7)
owrd_station    <- "14076100"   # Camp Polk
nws_gridpoint   <- "PDT/35,57" # RM 8.5 area near Sisters, OR
threshold_tmax  <- 20.0         # HCP (°C)
threshold_7dadm <- 17.8         # ODEQ (°C)

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
nws_tmax <- whychusModel::all_historical_forecasts |> 
  filter(variable == "temperature_2m_max") |> 
  mutate(variable = "maxTemperature") |> 
  rename(date = valid_date) |> 
  glimpse()

nws_tmin <- whychusModel::all_historical_forecasts |> 
  filter(variable == "temperature_2m_min") |> 
  mutate(variable = "minTemperature") |> 
  rename(date = valid_date) |> 
  glimpse()

nws_cloud <- whychusModel::all_historical_forecasts |> 
  filter(variable == "cloud_cover_mean") |> 
  mutate(variable = "skyCover") |> 
  rename(date = valid_date) |> 
  glimpse()
  
daily_nws <- function(df, lead_day, date, agg_fn = mean) {
  df |>
    filter(date == date) |> 
    filter(lead_day == lead_day) |> 
    summarise(value = agg_fn(value, na.rm = TRUE)) |>
    pull(value)
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

cat(sprintf("RM 8.5 lag (2025 data): Tmax_m1 = %.2f °C,  dadm_m1 = %.2f °C\n",
            Tmax_m1, dadm_m1))

# ── 4. Predict across all lead days ───────────────────────────────────────────
results_list <- map(lead_days_vec, function(k) {
  fdate <- today + k
  
  air_max_k    <- daily_nws(nws_tmax,  k, today,     max)
  air_min_k    <- daily_nws(nws_tmin,  k, today,     min)
  cloud_k      <- daily_nws(nws_cloud, k, today,     mean)
  air_max_m1_k <- daily_nws(nws_tmax, k,  fdate - 1, max)
  air_min_m1_k <- daily_nws(nws_tmin, k, fdate - 1, min)
  
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
  actual_tmax <- whychusModel::rm_8_5_historical |>
    filter(statistic == "max",
           year(date)  == 2025,
           month(date) == month(fdate),
           day(date)   == day(fdate)) |>
    pull(temperature)
  
  actual_dadm <- whychusModel::rm_8_5_historical |>
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
    actual_7dadm_C = if (length(actual_dadm) > 0) actual_dadm[[1]] else NA_real_
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


