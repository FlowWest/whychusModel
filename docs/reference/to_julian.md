# Convert a date to Julian day of year

Returns the day of year (1–366) for a given date.

## Usage

``` r
to_julian(date)
```

## Arguments

- date:

  A `Date`, `POSIXct`, or character vector coercible to `Date` via
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html).

## Value

An integer vector of day-of-year values between 1 and 366.

## Examples

``` r
to_julian("2023-07-15")   # returns 196
#> [1] 196
to_julian(Sys.Date())
#> [1] 259

# use in a dplyr pipeline
df |> mutate(julian_day = to_julian(date))
#> Error in mutate(df, julian_day = to_julian(date)): could not find function "mutate"
```
