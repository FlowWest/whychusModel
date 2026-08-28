---
editor_options: 
  markdown: 
    wrap: 72
---

# RM 8.5 Instream Temperature Forecasting — RF Model Workflow

**Targets:** Daily Maximum Temperature (Tmax) and 7-Day Average Daily
Maximum (7DADM)\
**Models:** Saved Random Forest objects from
`output/rm85_rf_tmax_model.rds` and `output/rm85_rf_7dadm_model.rds`\
**Model configuration:** Section C (Tmax) / Section F (7DADM) —
predictor lags + lagged target variable, Lead = 1 day

------------------------------------------------------------------------

## Overview

The pipeline has four stages:

1.  **Pull real-time hydrology** — Camp Polk flow and temperature via
    `get_owrd_hydro()`
2.  **Pull NWS weather forecast** — air temperature and cloud cover via
    `get_nws_forecast()`
3.  **Supply RM 8.5 previous-day temperature** — from a dummy value
    until a real-time sensor is installed
4.  **Assemble features → predict** — join, lag, and pass to the saved
    RF models

```         
get_owrd_hydro()       ─┐
get_nws_forecast()     ─┼─► feature table ─► RF model ─► Tmax / 7DADM forecast
dummy RM 8.5 lag temp  ─┘
```

------------------------------------------------------------------------

## 0. Setup

``` r
library(tidyverse)
library(lubridate)
library(randomForest)
library(whychusModel)   # get_owrd_hydro(), get_nws_forecast()

# Date to forecast for (tomorrow's temperature, 3-days, 7-days)
forecast_date <- Sys.Date() + 1 # 3, 7

# Paths to saved models
tmax_model_path  <- here::here("output", "rm85_rf_tmax_model.rds")
dadm_model_path  <- here::here("output", "rm85_rf_7dadm_model.rds")
```

------------------------------------------------------------------------

## 1. Pull Camp Polk Hydrology via `get_owrd_hydro()`

The models need **today's** Camp Polk mean flow, max temperature, and
7DADM, plus **yesterday's** values as lagged predictors. Pull the last 10
days to be safe and able to calculate the 7DADM. 

``` r
owrd_station <- "14076100"   # Camp Polk
pull_start   <- Sys.Date() - 10
pull_end     <- Sys.Date()

# Mean daily flow (CFS)
cp_flow_raw <- get_owrd_hydro(
  station_nbr = owrd_station,
  start_date  = pull_start,
  end_date    = pull_end,
  data_source = "MDF"
)

# Max daily water temperature (°C)
cp_tmax_raw <- get_owrd_hydro(
  station_nbr = owrd_station,
  start_date  = pull_start,
  end_date    = pull_end,
  data_source = "WTEMP_MAX"
)
```

### Expected output shape

`get_owrd_hydro()` returns a tibble with cleaned column names (via
`janitor::clean_names()`). The exact column names depend on the OWRD
response, but typically include a date column and a value column.
Inspect with `glimpse(cp_flow_raw)` and rename as needed.

``` r
cp_flow <- cp_flow_raw |>
  mutate(date = as.Date(record_date)) |>   
  select(date, cp_flow_mean = mean_daily_flow_cfs)

cp_tmax <- cp_tmax_raw |>
  mutate(date = as.Date(record_date)) |>
  select(date, cp_tmax = max_daily_water_temp_c)
```

### Compute Camp Polk 7DADM

`get_owrd_hydro()` does not return 7DADM directly. Compute it from the
max daily temperature using the last 10 days of data.

``` r
cp_7dadm <- cp_tmax |>
  arrange(date) |>
  mutate(cp_7dadm = zoo::rollmean(cp_tmax, k = 7, fill = NA, align = "right"))
```

> **Note:** If Camp Polk temperature is offline, explore the use of Whychus nr Sisters OWRD gage or the installation of another real-time sensor at Camp Polk

------------------------------------------------------------------------

## 2. Pull NWS Air Temperature & Cloud Cover via `get_nws_forecast()`

The models use **forecasted** max air temp, min air temp, and cloud
cover for the valid date (forecast_date). The NWS gridpoint for the
Whychus Creek area near Sisters, OR is approximately `"PDT/35,57"` —
verify with `https://api.weather.gov/points/44.3903,-121.4068`.

``` r
nws_gridpoint <- "PDT/35,57"  

nws_tmax  <- get_nws_forecast(nws_gridpoint, "maxTemperature")
nws_tmin  <- get_nws_forecast(nws_gridpoint, "minTemperature")
nws_cloud <- get_nws_forecast(nws_gridpoint, "skyCover")
```

### Aggregate to daily values for the forecast date

`get_nws_forecast()` returns hourly or sub-daily records. Roll them up
to one value per day.

``` r
# Helper: extract daily summary for a single date
daily_nws <- function(df, target_date, agg_fn = mean) {
  df |>
    mutate(date = as.Date(datetime)) |>
    filter(date == target_date) |>
    summarise(value = agg_fn(value, na.rm = TRUE)) |>
    pull(value)
}

air_max_fcst   <- daily_nws(nws_tmax,  forecast_date, max)
air_min_fcst   <- daily_nws(nws_tmin,  forecast_date, min)
cloud_pct_fcst <- daily_nws(nws_cloud, forecast_date, mean)
```

> For `maxTemperature` and `minTemperature` the NWS often returns one
> value per day already; the aggregation is a safety net.

### Yesterday's NWS values (lagged air predictors)

The Section C/F models include lagged air temperature predictors
(`air_max_m1`, `air_min_m1`). Pull yesterday's forecast or, if
available, pull observed values.

> TODO: Will need to think through the storing of forecasts 

``` r
yesterday <- Sys.Date()   # yesterday relative to forecast_date

air_max_m1   <- daily_nws(nws_tmax,  yesterday, max)
air_min_m1   <- daily_nws(nws_tmin,  yesterday, min)
```

------------------------------------------------------------------------

## 3. Dummy RM 8.5 Previous-Day Temperature

The most important predictor in both models is the **previous day's RM
8.5 temperature** (`Tmax_m1` for the Tmax model, `dadm_m1` for the 7DADM
model). Until a real-time sensor is installed at RM 8.5, substitute the same day of the previous year.

``` r
# --- Option A: last known historical value ---
rm85_last <- rm_8_5_historical |>
  filter(statistic == "max") |>
  arrange(desc(date)) |>
  slice(1)

Tmax_m1 <- rm85_last$temperature          # previous-day Tmax (°C)
dadm_m1 <- rm_8_5_historical |>           # previous-day 7DADM
  filter(statistic == "7DADM") |>
  arrange(desc(date)) |>
  slice(1) |>
  pull(temperature)

cat("Using RM 8.5 Tmax_m1 =", Tmax_m1, "°C from", as.character(rm85_last$date), "\n")
cat("Using RM 8.5 dadm_m1 =", dadm_m1, "°C\n")

# --- Option B: dummy fixed value (for demonstration only) ---
# Tmax_m1 <- 18.5   # °C — replace with a realistic summer value
# dadm_m1 <- 17.2   # °C
```

------------------------------------------------------------------------

## 4. Assemble the Feature Vector

Gather today's Camp Polk lagged values and combine everything into a
single named data frame that matches the column names expected by each
model.

``` r
# Today's Camp Polk values (row for Sys.Date())
today <- Sys.Date()

cp_today <- cp_flow |>
  filter(date == today) |>
  left_join(cp_tmax,  by = "date") |>
  left_join(cp_7dadm, by = "date")

# Yesterday's Camp Polk values (lagged predictors)
yesterday_row <- cp_flow |>
  filter(date == today - 1) |>
  left_join(cp_tmax,  by = "date") |>
  left_join(cp_7dadm, by = "date")

# Julian day of the forecast date
julian_day <- yday(forecast_date)

# ── Feature table for the Tmax model (Section C) ──────────────────────────
features_tmax <- tibble(
  cp_flow_mean = cp_today$cp_flow_mean,
  cp_tmax      = cp_today$cp_tmax,
  Julian       = julian_day,
  air_max      = air_max_fcst,
  air_min      = air_min_fcst,
  cloud_pct    = cloud_pct_fcst,
  # lagged predictors (t-1)
  cp_flow_m1   = yesterday_row$cp_flow_mean,
  cp_tmax_m1   = yesterday_row$cp_tmax,
  air_max_m1   = air_max_m1,
  air_min_m1   = air_min_m1,
  # lagged target (t-1)
  Tmax_m1      = Tmax_m1
)

# ── Feature table for the 7DADM model (Section F) ─────────────────────────
features_7dadm <- tibble(
  cp_flow_mean = cp_today$cp_flow_mean,
  cp_7dadm     = cp_today$cp_7dadm,
  Julian       = julian_day,
  air_max      = air_max_fcst,
  air_min      = air_min_fcst,
  cloud_pct    = cloud_pct_fcst,
  # lagged predictors (t-1)
  cp_flow_m1   = yesterday_row$cp_flow_mean,
  cp_7dadm_m1  = yesterday_row$cp_7dadm,
  air_max_m1   = air_max_m1,
  air_min_m1   = air_min_m1,
  # lagged target (t-1)
  dadm_m1      = dadm_m1
)
```

> **Column name check:** the RF models were trained with exact column
> names. Run `names(features_tmax)` and compare against
> `rf_tmax$forest$xlevels` or `names(importance(rf_tmax))` to confirm
> alignment before predicting.

------------------------------------------------------------------------

## 5. Load Models and Predict

``` r
rf_tmax  <- readRDS(tmax_model_path)
rf_7dadm <- readRDS(dadm_model_path)

pred_tmax  <- predict(rf_tmax,  newdata = as.data.frame(features_tmax))
pred_7dadm <- predict(rf_7dadm, newdata = as.data.frame(features_7dadm))

cat(sprintf(
  "\nRM 8.5 Forecast for %s\n  Tmax  : %.2f °C\n  7DADM : %.2f °C\n",
  forecast_date, pred_tmax, pred_7dadm
))
```

------------------------------------------------------------------------

## 6. Full Dummy Run — Self-Contained Example

The block below is a complete, runnable demonstration using hardcoded
dummy values so the pipeline can be tested before real-time RM 8.5 data
are available.

``` r
library(tidyverse)
library(lubridate)
library(randomForest)
library(whychusModel)

# ── Dummy inputs (replace each with live data pulls as sensors come online) ──

forecast_date <- as.Date("2026-07-15")   # target date to forecast

# Camp Polk — today's values
cp_flow_mean_today <- 42.3    # CFS
cp_tmax_today      <- 19.1    # °C
cp_7dadm_today     <- 18.4    # °C

# Camp Polk — yesterday's values (lag t-1)
cp_flow_mean_m1    <- 44.7    # CFS
cp_tmax_m1_cp      <- 18.6    # °C   (Camp Polk Tmax lag, not RM 8.5)
cp_7dadm_m1_cp     <- 17.9    # °C

# NWS forecast for forecast_date
air_max_fcst       <- 32.5    # °C
air_min_fcst       <- 9.2     # °C
cloud_pct_fcst     <- 15.0    # %

# NWS yesterday (lag t-1 air)
air_max_m1_val     <- 30.8    # °C
air_min_m1_val     <- 8.5     # °C

# RM 8.5 previous-day temperature (DUMMY — replace with sensor or last obs)
Tmax_m1_rm85  <- 21.3         # °C  — yesterday's RM 8.5 Tmax
dadm_m1_rm85  <- 20.1         # °C  — yesterday's RM 8.5 7DADM

# Julian day
julian_day <- yday(forecast_date)   # 196 for July 15

# ── Build feature tables ───────────────────────────────────────────────────

features_tmax <- data.frame(
  cp_flow_mean = cp_flow_mean_today,
  cp_tmax      = cp_tmax_today,
  Julian       = julian_day,
  air_max      = air_max_fcst,
  air_min      = air_min_fcst,
  cloud_pct    = cloud_pct_fcst,
  cp_flow_m1   = cp_flow_mean_m1,
  cp_tmax_m1   = cp_tmax_m1_cp,
  air_max_m1   = air_max_m1_val,
  air_min_m1   = air_min_m1_val,
  Tmax_m1      = Tmax_m1_rm85
)

features_7dadm <- data.frame(
  cp_flow_mean = cp_flow_mean_today,
  cp_7dadm     = cp_7dadm_today,
  Julian       = julian_day,
  air_max      = air_max_fcst,
  air_min      = air_min_fcst,
  cloud_pct    = cloud_pct_fcst,
  cp_flow_m1   = cp_flow_mean_m1,
  cp_7dadm_m1  = cp_7dadm_m1_cp,
  air_max_m1   = air_max_m1_val,
  air_min_m1   = air_min_m1_val,
  dadm_m1      = dadm_m1_rm85
)

# ── Load models and predict ────────────────────────────────────────────────

rf_tmax  <- readRDS(here::here("output", "rm85_rf_tmax_model.rds"))
rf_7dadm <- readRDS(here::here("output", "rm85_rf_7dadm_model.rds"))

pred_tmax  <- predict(rf_tmax,  newdata = features_tmax)
pred_7dadm <- predict(rf_7dadm, newdata = features_7dadm)

# ── Results ────────────────────────────────────────────────────────────────

results <- tibble(
  forecast_date = forecast_date,
  location      = "RM 8.5 (Rimrock Ranch)",
  pred_tmax_C   = round(pred_tmax,  2),
  pred_7dadm_C  = round(pred_7dadm, 2),
  rm85_lag_source = "DUMMY — last historical obs"
)

print(results)
```

**Example output:**

```         
# A tibble: 1 × 5
  forecast_date location               pred_tmax_C pred_7dadm_C rm85_lag_source
  <date>        <chr>                        <dbl>        <dbl> <chr>
1 2026-07-15    RM 8.5 (Rimrock Ranch)        22.4         20.8 DUMMY — last historical obs
```

------------------------------------------------------------------------

## 7. Regulatory Thresholds (Context)

| Metric | Threshold | Significance |
|------------------|------------------------|------------------------------|
| 7DADM | 17.8 °C | Oregon DEQ temperature standard for salmon/steelhead rearing |
| 7DADM | 20.0 °C | Habitat Conservation Plan (HCP) threshold for RM 6 |

Flagging predictions against these in the output table can make the
forecast immediately actionable for operations staff.

``` r
results <- results |>
  mutate(
    flag_7dadm = pred_7dadm_C > 17.8,
    flag_tmax  = pred_tmax_C  > 20.0
  )
```

------------------------------------------------------------------------

## 8. Transition Plan: Replacing Dummy RM 8.5 Data

Once a real-time temperature sensor is operating at RM 8.5, replace the
dummy lag values in Step 3 with a live pull. Depending on the sensor
platform, options include:

``` r
# Option A — OWRD sensor installed at RM 8.5 (preferred)
rm85_rt <- get_real_time_rm_85(
  station_nbr = "<rm85_station_id>",   
  start_date  = Sys.Date() - 1,
  end_date    = Sys.Date() - 1,
  data_source = "instantaneous_temperature"
)

Tmax_m1 <- rm85_rt |> pull(<value_column>)
```

No other changes to the pipeline are needed — the feature names and
model objects stay the same.

------------------------------------------------------------------------

## Summary of Predictor Sources

| Predictor | Source | Function |
|---------------------------|--------------------|-------------------------|
| `cp_flow_mean` | OWRD station 14076100 | `get_owrd_hydro(..., "MDF")` |
| `cp_tmax` | OWRD station 14076100 | `get_owrd_hydro(..., "WTEMP_MAX")` |
| `cp_7dadm` | Computed from `cp_tmax` | 7-day rolling mean |
| `Julian` | Derived from forecast date | `lubridate::yday()` |
| `air_max` | NWS gridpoint forecast | `get_nws_forecast(..., "maxTemperature")` |
| `air_min` | NWS gridpoint forecast | `get_nws_forecast(..., "minTemperature")` |
| `cloud_pct` | NWS gridpoint forecast | `get_nws_forecast(..., "skyCover")` |
| `*_m1` lags | Same sources, previous day | Same functions, `Sys.Date() - 1` |
| `Tmax_m1` / `dadm_m1` | **RM 8.5 sensor (pending)** | Dummy / last historical obs for now |
