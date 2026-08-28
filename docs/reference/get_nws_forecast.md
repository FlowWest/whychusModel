# Retrieve weather forecast data from the National Weather Service API

Fetches gridpoint forecast data from the NWS API and returns a tibble
for a specified weather variable.

## Usage

``` r
get_nws_forecast(
  gridpoint,
  variable = c("temperature", "maxTemperature", "minTemperature", "skyCover")
)
```

## Arguments

- gridpoint:

  Character. NWS gridpoint in the format `"office/x,y"`, e.g.
  `"PDT/35,57"`. Find your gridpoint at
  <https://api.weather.gov/points/%7Blat%7D,%7Blon%7D>.

- variable:

  Character. The forecast variable to return. One of:

  `"temperature"`

  : Hourly air temperature (°C)

  `"maxTemperature"`

  : Daily maximum air temperature (°C)

  `"minTemperature"`

  : Daily minimum air temperature (°C)

  `"skyCover"`

  : Sky cover (percent)

## Value

A tibble with columns:

- `datetime`:

  POSIXct forecast valid time (UTC)

- `value`:

  Numeric forecast value in native units

- `duration`:

  Character ISO 8601 duration string (e.g. `"PT1H"`)

- `variable`:

  Character name of the returned variable

## Examples

``` r
if (FALSE) { # \dontrun{
get_nws_forecast("PDT/35,57", "temperature")
get_nws_forecast("PDT/35,57", "skyCover")
} # }
```
