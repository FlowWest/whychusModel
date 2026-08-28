# Null coalescing operator

Returns `x` if it is neither `NULL` nor length zero, otherwise returns
`y`. Equivalent to the null coalescing operator in other languages.

## Usage

``` r
x %||% y
```

## Arguments

- x:

  The primary value to test.

- y:

  The fallback value returned when `x` is `NULL` or has length zero.

## Value

`x` if `!is.null(x) && length(x) > 0`, otherwise `y`.

## Examples

``` r
NULL %||% "default"   # returns "default"
#> [1] "default"
"value" %||% "default" # returns "value"
#> [1] "value"
character(0) %||% "default" # returns "default"
#> [1] "default"
```
