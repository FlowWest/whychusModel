# Historical weather forecasts and observed weather near Whychus Creek

Combined dataset of archived GFS forecast model output (2019-12-25
onward) and ERA5 reanalysis observed weather (2011-01-01 to 2019-12-24)
for the location near Whychus Creek (lat 44.39, lon -121.41). A `type`
column distinguishes the two sources.

## Usage

``` r
all_historical_forecasts
```

## Format

A data frame with columns:

- `valid_date`:

  Date. The date the weather value applies to.

- `issue_date`:

  Date. The model run issue date (NA for historical weather rows).

- `lead_days`:

  Integer. Forecast lead time in days (NA for historical weather rows).

- `variable`:

  Character. Variable name: `"temperature_2m_max"`,
  `"temperature_2m_min"`, or `"cloud_cover_mean"`.

- `value`:

  Numeric. Variable value in the unit given by `units`.

- `units`:

  Character. Units string (e.g. `"°C"`, `"%"`).

- `lat`:

  Numeric. Latitude (44.390278).

- `lon`:

  Numeric. Longitude (-121.406792).

- `type`:

  Character. Data source: `"historical forecast"` (GFS, 2019-12-25
  onward) or `"historical weather"` (ERA5, 2011-01-01 to 2019-12-24).

## Source

Open-Meteo Historical Forecast API (GFS seamless) and Open-Meteo Archive
API (ERA5 reanalysis).
