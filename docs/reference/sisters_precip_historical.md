# Historical precipitation near Sisters, Oregon

Gridded daily precipitation for the same point and pull as
[`sisters_air_temp_historical`](https://flowwest.github.io/udwc_temperature/reference/sisters_air_temp_historical.md),
partitioned into rain and snow. Not a model predictor — snowmelt timing
reaches summer stream temperature through discharge, which the model
already observes directly at Camp Polk.

## Usage

``` r
sisters_precip_historical
```

## Format

A data frame with columns:

- `date`:

  Date. Observation date.

- `precip_mm`:

  Numeric. Total daily precipitation in millimetres.

- `rain_mm`:

  Numeric. Precipitation falling on days with mean air temperature above
  0 degrees Celsius.

- `snow_mm`:

  Numeric. Precipitation falling on days with mean air temperature at or
  below 0 degrees Celsius.

## Source

GridMET (~4 km gridded surface meteorology), variable `pr`, pulled with
`climateR::getGridMET()`.

## Details

The rain/snow split is a simple temperature threshold, not a physical
partition: precipitation is classed as snow when the day's mean air
temperature is at or below 0 degrees Celsius and as rain otherwise, so
`rain_mm` and `snow_mm` always sum to `precip_mm`.
