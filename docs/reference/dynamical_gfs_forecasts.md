# Archived GFS air temperature and cloud cover forecasts near Whychus Creek

Historical NOAA Global Forecast System output for the grid cell nearest
Whychus Creek (lat 44.390278, lon -121.406792), at forecast leads of one
to seven days. This is the weather archive the RM 8.5 forecast models
are trained on.

## Usage

``` r
dynamical_gfs_forecasts
```

## Format

A data frame with columns:

- `valid_date`:

  Date. The date the forecast value applies to.

- `issue_date`:

  Date. The model initialisation date the forecast was issued on.

- `lead_days`:

  Integer. Forecast lead time in days, 1 through 7.

- `variable`:

  Character. Variable name: `"temperature_2m_max"`,
  `"temperature_2m_min"`, or `"cloud_cover_mean"`.

- `value`:

  Numeric. Variable value in the unit given by `units`.

- `units`:

  Character. `"°C"` for temperature, `"%"` for cloud cover.

- `lat`:

  Numeric. Latitude (44.390278).

- `lon`:

  Numeric. Longitude (-121.406792).

## Source

dynamical.org NOAA GFS forecast archive (`s3://dynamical-noaa-gfs`,
region `us-west-2`), <https://dynamical.org>. Pulled by
`data-raw/pull_dynamical_forecasts.py`.

## Details

Unlike
[`all_historical_forecasts`](https://flowwest.github.io/udwc_temperature/reference/all_historical_forecasts.md),
which stores a single value per issue date replicated across every lead,
this dataset carries a distinct value at each lead, so a genuine
day-1-through-day-7 forecast trajectory can be reconstructed for any
issue date.

Values are calendar-day aggregates built from the model's four 6-hour
windows, taken from the 00Z initialisation. Coverage begins 2021-05-01,
the start of the dynamical.org GFS archive, and is seasonal thereafter —
the pull targets the May-October forecast season.

The column names match
[`all_historical_forecasts`](https://flowwest.github.io/udwc_temperature/reference/all_historical_forecasts.md)
(minus its `type` column) so the two archives can be compared directly.
