# Fit or apply a linear model predicting RM 6 7DADM from RM 8.5 7DADM

Trains a simple linear regression of seven-day average daily maximum
temperature (7DADM) at RM 6 on observed 7DADM at RM 8.5 using the
package's built-in historical data. If `newdata` is supplied, the
function returns a tibble of RM 6 predictions; otherwise it returns the
fitted `lm` object for further inspection or prediction elsewhere.

## Usage

``` r
lm_rm6_7dadm(newdata = NULL, months = 5:9)
```

## Arguments

- newdata:

  A data frame or tibble with a column named `rm85_7dadm` (numeric,
  degrees C). A `date` column, if present, is carried through to the
  output unchanged. If `NULL` (default), the fitted `lm` object is
  returned instead of predictions.

- months:

  Integer vector of calendar months to include in model training.
  Defaults to May–September (`5:9`).

## Value

If `newdata` is `NULL`: a fitted [`lm`](https://rdrr.io/r/stats/lm.html)
object with formula `rm6_7dadm ~ rm85_7dadm`, trained on historical data
from the specified months.

If `newdata` is supplied: a tibble containing all columns from `newdata`
plus `rm6_7dadm_pred` (predicted RM 6 7DADM in degrees C).

## Examples

``` r
# Inspect the fitted model
m <- lm_rm6_7dadm()
summary(m)
#> 
#> Call:
#> lm(formula = rm6_7dadm ~ rm85_7dadm, data = train)
#> 
#> Residuals:
#>     Min      1Q  Median      3Q     Max 
#> -4.4177 -0.1599  0.0089  0.1694  1.1019 
#> 
#> Coefficients:
#>              Estimate Std. Error t value Pr(>|t|)    
#> (Intercept) -0.196817   0.041598  -4.731  2.4e-06 ***
#> rm85_7dadm   1.016127   0.002315 438.926  < 2e-16 ***
#> ---
#> Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
#> 
#> Residual standard error: 0.3364 on 1846 degrees of freedom
#> Multiple R-squared:  0.9905, Adjusted R-squared:  0.9905 
#> F-statistic: 1.927e+05 on 1 and 1846 DF,  p-value: < 2.2e-16
#> 

# Predict from new RM 8.5 values
library(tibble)
new <- tibble(date = Sys.Date() + 0:6, rm85_7dadm = c(15, 16, 17, 18, 19, 20, 21))
lm_rm6_7dadm(newdata = new)
#> # A tibble: 7 × 3
#>   date       rm85_7dadm rm6_7dadm_pred
#>   <date>          <dbl>          <dbl>
#> 1 2026-09-16         15           15.0
#> 2 2026-09-17         16           16.1
#> 3 2026-09-18         17           17.1
#> 4 2026-09-19         18           18.1
#> 5 2026-09-20         19           19.1
#> 6 2026-09-21         20           20.1
#> 7 2026-09-22         21           21.1
```
