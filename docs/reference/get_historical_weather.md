# Retrieve historical observed weather data

Pulls actual observed weather data (ERA5 reanalysis) from the Open-Meteo
Archive API for a given location and date range. Returns data in the
same schema as `get_historical_forecast` with `issue_date = NA` and
`lead_days = NA`, since observed weather has no forecast lead time.

## Usage

``` r
get_historical_weather(
  lat = 44.390278,
  lon = -121.406792,
  start_date,
  end_date,
  variables = c("temperature_2m_max", "temperature_2m_min", "cloud_cover_mean"),
  timezone = "UTC"
)
```

## Arguments

- lat:

  Numeric. Latitude of target point.

- lon:

  Numeric. Longitude of target point.

- start_date:

  Character or Date. Start of date range.

- end_date:

  Character or Date. End of date range.

- variables:

  Character vector. Daily variables to retrieve.

- timezone:

  Character. Timezone. Defaults to "UTC".

## Value

A tibble with columns: valid_date, issue_date (NA), lead_days (NA),
variable, value, units, lat, lon

## Examples

``` r
if (FALSE) { # \dontrun{
get_historical_weather(
  lat        = 44.390278,
  lon        = -121.406792,
  start_date = "2011-01-01",
  end_date   = "2019-12-24"
)
} # }
```
