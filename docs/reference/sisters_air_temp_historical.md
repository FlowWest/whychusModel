# Historical observed air temperature near Sisters, Oregon

Gridded daily observed air temperature for the cell containing Sisters,
Oregon (lat 44.2896, lon -121.5491), from 1979 onward. These are
observations, not forecasts — the series is used to score forecast
archives against reality and as a long-record baseline for judging how
anomalous a given summer is. It is not a model predictor.

## Usage

``` r
sisters_air_temp_historical
```

## Format

A data frame with columns:

- `date`:

  Date. Observation date.

- `tmax_C`, `tmin_C`, `tavg_C`:

  Numeric. Daily maximum, minimum and mean air temperature in degrees
  Celsius. `tavg_C` is the midpoint of the daily max and min, not an
  integrated daily mean.

- `tmax_F`, `tmin_F`, `tavg_F`:

  Numeric. The same three values converted to degrees Fahrenheit.

## Source

GridMET (~4 km gridded surface meteorology), variables `tmmx` and
`tmmn`, pulled with `climateR::getGridMET()` and converted from Kelvin.
