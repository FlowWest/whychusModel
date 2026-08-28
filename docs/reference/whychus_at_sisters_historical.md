# Historical instream water temperature and discharge at WHYCHUS CR AT SISTERS, OR

Daily discharge data collected by the Oregon Water Resources Department
(OWRD) at the WHYCHUS CR AT SISTERS, OR monitoring station (station
14076050) on the Whychus.

## Usage

``` r
whychus_at_sisters_historical
```

## Format

A data frame with 4122 rows and 10 columns:

- `station_nbr`:

  Numeric. OWRD station number (14076050).

- `date`:

  Date. Observation date, ranging from 2015-10-01 to 2026-04-14

- `value`:

  Numeric.Discharge in cfs

- `published_status`:

  Character. OWRD data publication status (e.g. `"PVL"` = provisional).

- `download_date`:

  Character. Date and time the data were downloaded from OWRD.

- `variable`:

  Character. Variable name as returned by OWRD API (e.g.
  `"water temperature (c)", discharge (cfs)`).

- `statistic`:

  Character. Summary statistic: `"max"`, `"min"`, `"mean"`.

- `location`:

  Character. Station location name (`"camp polk"`).

- `estimated`:

  Character. Flag indicating whether the value was estimated. `NA` if
  not estimated.

- `revised`:

  Logical. Flag indicating whether the value has been revised. `NA` if
  not revised.

## Source

Oregon Water Resources Department Near Real-Time Hydrograph:
<https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/display_hydro_graph.aspx?station_nbr=14076050>
