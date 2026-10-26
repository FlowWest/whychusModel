# Predict RM 6 7DADM from an RM 8.5 temperature value

Convenience wrapper around
[`lm_rm6_7dadm`](https://flowwest.github.io/udwc_temperature/reference/lm_rm6_7dadm.md)
that accepts a plain numeric temperature (or vector of temperatures) at
RM 8.5 and returns the predicted 7DADM at RM 6.

## Usage

``` r
rm_6_predict(temp_8_5, months = 5:9)
```

## Arguments

- temp_8_5:

  Numeric vector. Observed or forecast 7DADM temperature at RM 8.5 in
  degrees C.

- months:

  Integer vector of calendar months used to train the underlying linear
  model. Defaults to May–September (`5:9`).

## Value

A numeric vector of predicted RM 6 7DADM temperatures (°C), the same
length as `temp_8_5`.

## Examples

``` r
rm_6_predict(6)          # single value
#> [1] 5.899946
rm_6_predict(c(15, 18, 20, 22))  # vector
#> [1] 15.04509 18.09347 20.12573 22.15798
```
