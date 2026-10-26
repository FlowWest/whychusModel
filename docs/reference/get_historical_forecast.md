# Retrieve historical forecast data at specific lead times

Pulls archived GFS/NWS forecast model output from the Open-Meteo
Historical Forecast API for a given location, date range, and set of
forecast lead times. Returns the forecast that would have been issued
`lead_days` before the valid date — i.e. what a model would have
received as input on that day.

## Usage

``` r
get_historical_forecast(
  lat = 44.390278,
  lon = -121.406792,
  start_date,
  end_date,
  lead_days = c(1, 3, 7),
  variables = c("temperature_2m_max", "temperature_2m_min", "cloud_cover_mean"),
  model = "gfs_seamless",
  timezone = "UTC"
)
```

## Arguments

- lat:

  Numeric. Latitude of target point.

- lon:

  Numeric. Longitude of target point.

- start_date:

  Character or Date. Start of valid date range.

- end_date:

  Character or Date. End of valid date range.

- lead_days:

  Integer vector. Forecast lead times in days. e.g. c(1, 3, 7) returns
  the day-1, day-3, and day-7 forecasts.

- variables:

  Character vector. Daily forecast variables to retrieve.

- model:

  Character. Forecast model to use. "gfs_seamless" is the closest to NWS
  operational output. Other options: "ecmwf_ifs04", "gfs025",
  "icon_seamless".

- timezone:

  Character. Timezone. Defaults to "UTC".

## Value

A tibble with columns: valid_date, issue_date, lead_days, variable,
value, units, lat, lon

## Details

The Open-Meteo Historical Forecast API archives GFS model runs from 2020
onwards at daily resolution. The `forecast_days` parameter controls how
many days ahead each archived run extends. By requesting the same valid
date from runs issued at different lead times, you can reconstruct what
the forecast said at each lead time.

## Examples

``` r
if (FALSE) { # \dontrun{
get_historical_forecast(
  lat        = 44.390278,
  lon        = -121.406792,
  start_date = "2023-07-01",
  end_date   = "2023-07-31",
  lead_days  = c(1, 3, 7)
)
} # }
```
