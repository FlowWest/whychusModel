# Pull historical forecasts across a long date range in annual chunks

Pull historical forecasts across a long date range in annual chunks

## Usage

``` r
get_historical_forecast_range(
  lat,
  lon,
  start_date,
  end_date,
  lead_days = c(1, 3, 7),
  variables = c("temperature_2m_max", "temperature_2m_min", "cloud_cover_mean"),
  model = "gfs_seamless",
  save_dir = NULL,
  sleep = 1
)
```

## Arguments

- lat:

  Numeric. Latitude.

- lon:

  Numeric. Longitude.

- start_date:

  Character or Date.

- end_date:

  Character or Date.

- lead_days:

  Integer vector. Lead times in days.

- variables:

  Character vector. Variables to retrieve.

- model:

  Character. Forecast model. Default "gfs_seamless".

- save_dir:

  Character or NULL. Directory for annual CSV checkpoints.

- sleep:

  Numeric. Seconds between API calls.

## Value

A tibble of all results combined.
