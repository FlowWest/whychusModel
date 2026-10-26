# Individual RM 8.5 logger readings, not summarised to daily statistics

The raw logger readings behind
[`rm_8_5_historical`](https://flowwest.github.io/udwc_temperature/reference/rm_8_5_historical.md),
so the daily statistics can be recomputed without re-reading the annual
UDWC Excel workbooks.

## Usage

``` r
all_rm_8_5_dates_and_times
```

## Format

A data frame with columns:

- `date`:

  POSIXct. Observation date; time of day is always midnight.

- `temperature`:

  Numeric. Instream temperature in degrees Celsius.

## Source

Upper Deschutes Watershed Council continuous temperature monitoring
program, monitoring location `WC_008-50`.

## Details

Note that time of day was not preserved during compilation: every
reading is stamped at midnight, so the several readings sharing a date
cannot be distinguished and this dataset cannot be used for sub-daily
analysis. Use
[`all_rm_6_dates_and_times`](https://flowwest.github.io/udwc_temperature/reference/all_rm_6_dates_and_times.md),
which does retain hourly timestamps, if you need a diurnal signal.
