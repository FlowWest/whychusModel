# Historical RM 8.5 instream temperature

Daily instream water temperature collected by the Upper Deschutes
Watershed Council (UDWC) at the Rimrock Ranch downstream site
(WC_008-50) on Whychus Creek, river mile 8.5.

## Usage

``` r
rm_8_5_historical
```

## Format

A data frame with columns:

- `date`:

  POSIXct. Observation date, ranging from 2011 to present.

- `statistic`:

  Character. Summary statistic: `"mean"`, `"median"`, `"max"`, `"min"`,
  `7DADM`

- `temperature`:

  Numeric. Instream temperature in degrees Celsius.

## Source

Upper Deschutes Watershed Council continuous temperature monitoring
program. Data compiled from annual UDWC data submission files
(2011–2025).
