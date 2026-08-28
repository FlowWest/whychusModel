# Retrieve hydrological data from the Oregon Water Resources Department

Downloads streamflow or water temperature data from the OWRD Near
Real-Time Hydrograph web service for a given station and date range.
Handles session cookies and form-based POST requests automatically.

## Usage

``` r
get_owrd_hydro(
  station_nbr = "14076100",
  start_date,
  end_date,
  data_source = c("MDF", "Instantaneous_Flow", "WTEMP15", "WTEMP_MEAN", "WTEMP_MAX",
    "WTEMP_MIN"),
  max_retries = 3,
  timeout_sec = 30
)
```

## Arguments

- station_nbr:

  Character. OWRD station number. Defaults to `"14076100"`.

- start_date:

  Character or Date. Start date for the data request. Will be coerced to
  `Date` — any format accepted by
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) works.

- end_date:

  Character or Date. End date for the data request. Will be coerced to
  `Date` — any format accepted by
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) works.

- data_source:

  Character. The type of hydrological data to retrieve. One of:

  `"MDF"`

  : Mean daily flow

  `"Instantaneous_Flow"`

  : Instantaneous flow

  `"WTEMP15"`

  : Instantaneous water temperature (15-min)

  `"WTEMP_MEAN"`

  : Mean daily water temperature

  `"WTEMP_MAX"`

  : Maximum daily water temperature

  `"WTEMP_MIN"`

  : Minimum daily water temperature

  Defaults to `"MDF"`. Partial matching is supported via
  [`match.arg()`](https://rdrr.io/r/base/match.arg.html).

- max_retries:

  Integer. Number of times to retry the GET/POST sequence on failure
  before giving up. Defaults to 3.

- timeout_sec:

  Numeric. Per-request timeout in seconds. Defaults to 30.

## Value

A tibble with cleaned column names (via
[`janitor::clean_names()`](https://sfirke.github.io/janitor/reference/clean_names.html))
containing the requested hydrological data for the specified station and
date range. Column names and units vary by `data_source`.

## Details

This function scrapes the OWRD Near Real-Time Hydrograph web application
(<https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/>). It
performs an initial GET request to retrieve the ASP.NET form state
(`__VIEWSTATE` etc.) before submitting a POST request to download data
in TSV format. A persistent session handle is used to preserve cookies
across requests.

The form containing `__VIEWSTATE` is located explicitly (by ID first,
then by field content) rather than assumed to be the first form on the
page, since OWRD may add unrelated forms (banners, widgets) ahead of the
real one. A browser-like User-Agent is sent on both requests, and the
GET/POST sequence is retried with backoff on transient failures.
