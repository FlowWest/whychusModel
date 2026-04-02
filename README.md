# whychusInputs

An R package of model inputs and data retrieval functions for stream temperature forecasting on Whychus Creek, developed for the Upper Deschutes Watershed Council (UDWC).

## Installation

```r
# install.packages("devtools")
devtools::install_github("FlowWest/whychusInputs")
```

## Data Objects

| Object | Description | Rows | Date Range |
|--------|-------------|------|------------|
| `rm_6_historical` | UDWC instream temperature at RM 6 (mean, median, max, min daily) | 8,232 | 2012-04-23 – 2025-10-17 |
| `camp_polk_historical` | OWRD daily water temperature and discharge at Camp Polk (station 14076100) | 15,578 | 2015-10-01 – present |
| `all_historical_forecasts` | Archived GFS forecasts at 1-, 3-, and 7-day lead times for max/min air temperature and cloud cover near Whychus Creek (lat 44.39, lon -121.41) | 20,529 | 2020-01-01 – 2026-03-30 |
| `rm_8_5_historical` | UDWC instream temperature at RM 8.5 (mean, median, max, min daily) | 11,424 | 2011-04-28 - 2025-10-29

## Functions

### Data Retrieval

#### `get_owrd_hydro()`
Downloads streamflow or water temperature data from the [OWRD Near Real-Time Hydrograph](https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/) for a given station and date range.

```r
# Mean daily flow
flow <- get_owrd_hydro(
  station_nbr = "14076100",
  start_date  = "2023-01-01",
  end_date    = "2023-12-31",
  data_source = "MDF"
)

# Mean daily water temperature
temp <- get_owrd_hydro(
  station_nbr = "14076100",
  start_date  = "2023-06-01",
  end_date    = "2023-09-30",
  data_source = "WTEMP_MEAN"
)
```

**`data_source` options:** `"MDF"`, `"Instantaneous_Flow"`, `"WTEMP15"`, `"WTEMP_MEAN"`, `"WTEMP_MAX"`, `"WTEMP_MIN"`

---

#### `get_nws_forecast()`
Fetches gridpoint forecast data from the [NWS API](https://api.weather.gov).

```r
get_nws_forecast("PDT/35,57", "temperature")
get_nws_forecast("PDT/35,57", "maxTemperature")
```

**`variable` options:** `"temperature"`, `"maxTemperature"`, `"minTemperature"`, `"skyCover"`

---

#### `get_historical_forecast()`
Pulls archived GFS/NWS forecast model output from the [Open-Meteo Historical Forecast API](https://open-meteo.com) at specified lead times (available from 2020 onward).

```r
get_historical_forecast(
  lat        = 44.390278,
  lon        = -121.406792,
  start_date = "2023-07-01",
  end_date   = "2023-07-31",
  lead_days  = c(1, 3, 7)
)
```

**Returns:** `valid_date`, `issue_date`, `lead_days`, `variable`, `value`, `units`, `lat`, `lon`

---

#### `get_historical_forecast_range()`
Wrapper around `get_historical_forecast()` for long date ranges — splits requests into annual chunks and optionally saves CSV checkpoints.

```r
get_historical_forecast_range(
  lat        = 44.390278,
  lon        = -121.406792,
  start_date = "2020-01-01",
  end_date   = "2023-12-31",
  lead_days  = c(1, 3, 7),
  save_dir   = "data-raw/forecasts/"
)
```

### Utilities

#### `to_julian()`
Converts a date to Julian day of year (1–366).

```r
to_julian("2023-07-15")   # returns 196
df |> mutate(julian_day = to_julian(date))
```

## Workflows

**`data-raw/pull-real-time-data.Rmd`**
Pulls current hydrological and weather data for near real-time use.

**`data-raw/pull-historical-data.Rmd`**
Pulls and assembles historical OWRD and forecast data for model training.

## Data Sources

| Source | Description |
|--------|-------------|
| [OWRD Near Real-Time Hydrograph](https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/) | Streamflow and water temperature at Camp Polk (station 14076100) |
| [NWS Gridpoint Forecast API](https://api.weather.gov) | Weather forecasts by gridpoint |
| [Open-Meteo Historical Forecast API](https://open-meteo.com) | Archived GFS model output at daily resolution (2020–present) |
| [UDWC field monitoring](https://www.upperdeschuteswatershedcouncil.org/water-quality/) | Instream temperature loggers at multiple RM sites on Whychus Creek |
