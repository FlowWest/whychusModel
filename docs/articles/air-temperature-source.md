# Choosing an Air Temperature Forecast Source

Every RM 8.5 water-temperature model in this project is driven by a
forecast of air temperature over the next one to seven days. Which
archive supplies that forecast turns out to matter less than most people
expect — but *how* that archive is structured matters a great deal, and
one of the options has a defect that silently removes the entire
forecast signal.

This vignette records what we checked, what we found, and what to use.
The first section runs live against the package’s own data so you can
confirm the central claim yourself; the later sections report
measurements made against external archives and cite the scripts that
produced them.

[`library`](https://rdrr.io/r/base/library.html)`(`[`whychusModel`](https://flowwest.github.io/udwc_temperature/)`)`` `[`library`](https://rdrr.io/r/base/library.html)`(`[`dplyr`](https://dplyr.tidyverse.org)`)`` `[`library`](https://rdrr.io/r/base/library.html)`(`[`tidyr`](https://tidyr.tidyverse.org)`)`` `[`library`](https://rdrr.io/r/base/library.html)`(`[`ggplot2`](https://ggplot2.tidyverse.org)`)`

## 1. The shipped archive carries no lead-specific information

`all_historical_forecasts` looks like a proper forecast archive. It has
a `valid_date` (the day being forecast), an `issue_date` (the day the
forecast was made), and `lead_days` running 1 through 7. Naively you
would build a seven-day trajectory from it and expect seven different
numbers.

Start by looking at how it is laid out:

`all_historical_forecasts`` ``|>`` `` `[`mutate`](https://dplyr.tidyverse.org/reference/mutate.html)`(``valid_date ``=`` `[`as.Date`](https://rdrr.io/r/base/as.Date.html)`(``valid_date``)``)`` ``|>`` `` `[`group_by`](https://dplyr.tidyverse.org/reference/group_by.html)`(``lead_days``, ``type``)`` ``|>`` `` `[`summarise`](https://dplyr.tidyverse.org/reference/summarise.html)`(``n ``=`` `[`n`](https://dplyr.tidyverse.org/reference/context.html)`(``)``, first ``=`` `[`min`](https://rdrr.io/r/base/Extremes.html)`(``valid_date``)``, last ``=`` `[`max`](https://rdrr.io/r/base/Extremes.html)`(``valid_date``)``,`` `` .groups ``=`` ``"drop"``)`` ``#> ``# A tibble: 8 × 5`` ``#> lead_days type n first last `` ``#> ``<dbl>`` ``<chr>`` ``<int>`` ``<date>`` ``<date>`` `` ``#> ``1`` 0 historical weather ``8``766 2011-01-01 2018-12-31`` ``#> ``2`` 1 historical forecast ``8``319 2019-01-01 2026-08-04`` ``#> ``3`` 2 historical forecast ``8``319 2019-01-01 2026-08-04`` ``#> ``4`` 3 historical forecast ``8``319 2019-01-01 2026-08-04`` ``#> ``5`` 4 historical forecast ``8``319 2019-01-01 2026-08-04`` ``#> ``6`` 5 historical forecast ``8``319 2019-01-01 2026-08-04`` ``#> ``7`` 6 historical forecast ``8``319 2019-01-01 2026-08-04`` ``#> ``8`` 7 historical forecast ``8``319 2019-01-01 2026-08-04`

Two things are already visible. `lead_days == 0` is ERA5 reanalysis
(“historical weather”) covering 2011–2018, and leads 1–7 are the
“historical forecast” covering 2019 onward. **They do not overlap** —
this is not an observed series running alongside a forecast series, it
is two different products spliced end to end. Any analysis that treats
lead 0 as “the truth” against which leads 1–7 can be scored will
silently join zero rows.

Now the important part. Group by `issue_date` and count how many
distinct values that issue date carries across its seven leads:

`by_issue`` ``<-`` ``all_historical_forecasts`` ``|>`` `` `[`filter`](https://dplyr.tidyverse.org/reference/filter.html)`(``variable`` ``==`` ``"temperature_2m_max"``, ``!`[`is.na`](https://rdrr.io/r/base/NA.html)`(``issue_date``)``, ``lead_days`` `[`%in%`](https://rdrr.io/r/base/match.html)` ``1``:``7``)`` ``|>`` `` `[`group_by`](https://dplyr.tidyverse.org/reference/group_by.html)`(``issue_date``)`` ``|>`` `` `[`summarise`](https://dplyr.tidyverse.org/reference/summarise.html)`(``n_leads ``=`` `[`n`](https://dplyr.tidyverse.org/reference/context.html)`(``)``, n_distinct_values ``=`` `[`n_distinct`](https://dplyr.tidyverse.org/reference/n_distinct.html)`(``value``)``, .groups ``=`` ``"drop"``)`` `` `[`table`](https://rdrr.io/r/base/table.html)`(``by_issue``$``n_distinct_values``)`` ``#> `` ``#> 1 `` ``#> 2779`

Every issue date carries exactly **one** distinct value across all seven
leads. Laid out for a single issue date it is unmistakable:

`all_historical_forecasts`` ``|>`` `` `[`filter`](https://dplyr.tidyverse.org/reference/filter.html)`(``variable`` ``==`` ``"temperature_2m_max"``,`` `` ``issue_date`` ``==`` `[`as.Date`](https://rdrr.io/r/base/as.Date.html)`(``"2024-07-10"``)``, ``lead_days`` `[`%in%`](https://rdrr.io/r/base/match.html)` ``1``:``7``)`` ``|>`` `` `[`transmute`](https://dplyr.tidyverse.org/reference/transmute.html)`(``issue_date``, ``lead_days``, valid_date ``=`` `[`as.Date`](https://rdrr.io/r/base/as.Date.html)`(``valid_date``)``, ``value``)`` ``|>`` `` `[`arrange`](https://dplyr.tidyverse.org/reference/arrange.html)`(``lead_days``)`` ``#> ``# A tibble: 7 × 4`` ``#> issue_date lead_days valid_date value`` ``#> ``<date>`` ``<dbl>`` ``<date>`` ``<dbl>`` ``#> ``1`` 2024-07-10 1 2024-07-11 40.7`` ``#> ``2`` 2024-07-10 2 2024-07-12 40.7`` ``#> ``3`` 2024-07-10 3 2024-07-13 40.7`` ``#> ``4`` 2024-07-10 4 2024-07-14 40.7`` ``#> ``5`` 2024-07-10 5 2024-07-15 40.7`` ``#> ``6`` 2024-07-10 6 2024-07-16 40.7`` ``#> ``7`` 2024-07-10 7 2024-07-17 40.7`

One number, stamped onto the next seven days.

### Why this is easy to miss

Slice the data the other way — fix the *valid* date and vary the lead —
and the values differ, which looks reassuringly like real forecast
behaviour:

`all_historical_forecasts`` ``|>`` `` `[`filter`](https://dplyr.tidyverse.org/reference/filter.html)`(``variable`` ``==`` ``"temperature_2m_max"``,`` `` ``valid_date`` ``==`` `[`as.Date`](https://rdrr.io/r/base/as.Date.html)`(``"2024-07-16"``)``, ``lead_days`` `[`%in%`](https://rdrr.io/r/base/match.html)` ``1``:``7``)`` ``|>`` `` `[`transmute`](https://dplyr.tidyverse.org/reference/transmute.html)`(``lead_days``, ``issue_date``, valid_date ``=`` `[`as.Date`](https://rdrr.io/r/base/as.Date.html)`(``valid_date``)``, ``value``)`` ``|>`` `` `[`arrange`](https://dplyr.tidyverse.org/reference/arrange.html)`(``lead_days``)`` ``#> ``# A tibble: 7 × 4`` ``#> lead_days issue_date valid_date value`` ``#> ``<dbl>`` ``<date>`` ``<date>`` ``<dbl>`` ``#> ``1`` 1 2024-07-15 2024-07-16 33.4`` ``#> ``2`` 2 2024-07-14 2024-07-16 36.3`` ``#> ``3`` 3 2024-07-13 2024-07-16 37.5`` ``#> ``4`` 4 2024-07-12 2024-07-16 35.8`` ``#> ``5`` 5 2024-07-11 2024-07-16 35.2`` ``#> ``6`` 6 2024-07-10 2024-07-16 40.7`` ``#> ``7`` 7 2024-07-09 2024-07-16 40.3`

They differ only because you are reading seven *different issue dates*
down that column. The variation is between issue dates, not across
leads. It is worth being precise about this, because “the values differ
by lead” is true for this slice and false in the way that matters.

### The consequence for feature building

Feature code in this project builds a trajectory for a run date `R` by
taking `air_max_dk` from the row with `lead_days == k` and
`valid_date == R + k`. That row’s issue date is `R + k - k = R` — so
*every* column in the trajectory comes from the same issue date, and
therefore carries the same value:

`get_lead`` ``<-`` ``function``(``k``)`` ``{`` `` ``all_historical_forecasts`` ``|>`` `` `[`filter`](https://dplyr.tidyverse.org/reference/filter.html)`(``lead_days`` ``==`` ``k``, ``variable`` ``==`` ``"temperature_2m_max"``)`` ``|>`` `` `[`transmute`](https://dplyr.tidyverse.org/reference/transmute.html)`(``run_date ``=`` `[`as.Date`](https://rdrr.io/r/base/as.Date.html)`(``valid_date``)`` ``-`` ``k``, ``"d{k}"`` ``:=`` ``value``)`` ``}`` `` ``traj`` ``<-`` `[`Reduce`](https://rdrr.io/r/base/funprog.html)`(``function``(``a``, ``b``)`` `[`full_join`](https://dplyr.tidyverse.org/reference/mutate-joins.html)`(``a``, ``b``, by ``=`` ``"run_date"``)``,`` `` `[`lapply`](https://rdrr.io/r/base/lapply.html)`(``1``:``7``, ``get_lead``)``)`` ``|>`` `` ``tidyr``::`[`drop_na`](https://tidyr.tidyverse.org/reference/drop_na.html)`(``)`` `` ``spread`` ``<-`` `[`apply`](https://rdrr.io/r/base/apply.html)`(`[`as.matrix`](https://rdrr.io/r/base/matrix.html)`(``traj``[``, `[`paste0`](https://rdrr.io/r/base/paste.html)`(``"d"``, ``1``:``7``)``]``)``, ``1``, ``function``(``r``)`` `[`max`](https://rdrr.io/r/base/Extremes.html)`(``r``)`` ``-`` `[`min`](https://rdrr.io/r/base/Extremes.html)`(``r``)``)`` `` `[`c`](https://rdrr.io/r/base/c.html)`(``run_dates ``=`` `[`nrow`](https://rdrr.io/r/base/nrow.html)`(``traj``)``,`` `` pct_all_seven_identical ``=`` `[`round`](https://rdrr.io/r/base/Round.html)`(`[`mean`](https://rdrr.io/r/base/mean.html)`(``spread`` ``==`` ``0``)`` ``*`` ``100``, ``1``)``,`` `` mean_spread_C ``=`` `[`round`](https://rdrr.io/r/base/Round.html)`(`[`mean`](https://rdrr.io/r/base/mean.html)`(``spread``)``, ``4``)``)`` ``#> run_dates pct_all_seven_identical mean_spread_C `` ``#> 2767 100 0`

[`head`](https://rdrr.io/r/utils/head.html)`(``traj``, ``4``)`` ``#> ``# A tibble: 4 × 8`` ``#> run_date d1 d2 d3 d4 d5 d6 d7`` ``#> ``<date>`` ``<dbl>`` ``<dbl>`` ``<dbl>`` ``<dbl>`` ``<dbl>`` ``<dbl>`` ``<dbl>`` ``#> ``1`` 2018-12-31 1 1 1 1 1 1 1 `` ``#> ``2`` 2019-01-01 1.4 1.4 1.4 1.4 1.4 1.4 1.4`` ``#> ``3`` 2019-01-02 2.4 2.4 2.4 2.4 2.4 2.4 2.4`` ``#> ``4`` 2019-01-03 9.7 9.7 9.7 9.7 9.7 9.7 9.7`

**The entire seven-day air-temperature trajectory collapses to a single
repeated number, on 100% of run dates.** A model built on this does not
see a forecast at all — it sees today’s conditions replicated forward,
and whatever skill it shows at long leads comes from persistence and
seasonal timing rather than from any knowledge of the coming week.

This is the defect that motivated moving to an external source. It does
not make `all_historical_forecasts` useless — it is a long, consistent
record and remains the only source here reaching back to 2011 — but it
should be understood as a **best-estimate weather series indexed by
issue date**, not as a per-lead forecast archive.

## 2. dynamical.org GFS: genuine leads, one aggregation trap

[dynamical.org](https://dynamical.org) publishes NOAA GFS output as
Icechunk/Zarr on S3. Its forecasts genuinely vary by lead, and
`data-raw/pull_dynamical_forecasts.py` retrieves them.

One trap is worth knowing about, because getting it wrong produces
plausible-looking numbers. Per the dataset’s own variable metadata,
`maximum_temperature_2m` and `minimum_temperature_2m` are each *“Maximum
/ Minimum over the previous 1–6 hours, reset every 6-hour forecast
step”* — they are **not calendar-day aggregates**. Selecting the single
step that lands on a target day’s 00Z captures only the last six hours
before midnight, which misses the afternoon peak and the pre-dawn low
entirely:

| Aggregation                          | Daily max bias | Daily min bias |
|--------------------------------------|----------------|----------------|
| Naive single-step                    | **−2.7 °C**    | **+8.0 °C**    |
| Four 6-hour steps, reduced correctly | −2.1 °C        | −0.2 °C        |

The pull script reconstructs each calendar day from the four
non-overlapping six-hour windows that tile it (max of the maxima, min of
the minima, mean of the cloud means). Two smaller gotchas it also
handles: GFS initialises every six hours, so an unfiltered pull returns
four runs per day (it keeps 00Z by default); and
`.sel(method = "nearest")` has no bounds checking, so a request
predating coverage silently snaps onto the earliest available date
rather than being dropped.

Coverage begins 2021-05-01.

## 3. Match the product you actually serve

The operational forecast is driven by the **NWS** gridded product from
`weather.gov`, logged daily to `output/nws-forecasts-log.csv`. Training
on GFS while serving NWS is a train/serve mismatch, and it is
measurable. Comparing each candidate archive against the NWS forecasts
actually issued for the same run date and lead in 2026 (n = 588):

| Max air temperature      | Bias         | MAE         | r         |
|--------------------------|--------------|-------------|-----------|
| Open-Meteo Previous Runs | **+0.03 °C** | **1.58 °C** | **0.949** |
| dynamical.org GFS        | −0.47 °C     | 2.03 °C     | 0.913     |

MAE against NWS grows with lead for both — from about 1.1 °C at lead 1
to 2.3 °C at lead 7 for Open-Meteo, and 1.7 to 2.8 °C for dynamical.org.

Cloud cover is poorly matched in **every** source tested (+13 to +15
percentage points versus NWS, r 0.76–0.80), so it is not a discriminator
between them.

The ideal training set would be an archive of NDFD, the exact product
`weather.gov` serves. It is not practically obtainable: the AWS
open-data bucket (`noaa-ndfd-pds`) is a rolling live mirror whose files
are overwritten in place with no date partitioning, and NCEI’s deep
archive is served through a request system limited to one day of data
per request.

## 4. Open-Meteo Previous Runs: better inputs, no better forecasts

Open-Meteo’s Previous Runs API (`previous-runs-api.open-meteo.com`,
retrieved by `data-raw/pull_openmeteo_previous_runs.py`) is a genuine
per-lead archive — only ~2% of days show identical lead-1 and lead-7
values, and error decays the way real forecast skill does (MAE 0.91 °C
at lead 1 to 2.64 °C at lead 7).

Given it also matches NWS better, it ought to produce better water
temperature forecasts. It does not. Retraining the identical model on
each source and scoring both on the real 2026 hindcast (paired t-test on
squared error, n = 357):

| Contrast (only the source differs) | ΔRMSE | p |
|----|----|----|
| Absolute target: Open-Meteo vs dynamical | +0.072 | \< 0.001 (dynamical better) |
| Delta target: Open-Meteo vs dynamical | −0.038 | 0.015 (Open-Meteo better) |
| **Best configuration: Open-Meteo vs dynamical** | **−0.010** | **0.46 — not significant** |

The source even changes sign depending on model framing, and at the
configuration actually in use the two are statistically
indistinguishable. For comparison, changing the model’s *target* from
absolute temperature to change-from-today is worth −0.29 to −0.40 RMSE
(p \< 0.001) — six to ten times larger than anything the source choice
buys.

A 0.45 °C improvement in input quality buys nothing because the model is
anchored on RM 8.5’s own observed temperature, not on the
air-temperature forecast. That anchor dominates.

One practical caveat: this archive’s `cloud_cover_previous_dayN` only
begins **2024-04-15**, while temperature reaches back to 2021. A
cloud-using model is therefore limited to about two and a half seasons
from this source — though cloud measured as irrelevant under the
change-from-today framing (p = 0.88), so that is rarely binding.

## 5. Verdict

**Use dynamical.org GFS**
(`data-raw/dynamical_gfs_air_temp_historical.csv`). Not because it is
the best match to NWS — it isn’t — but because the source choice does
not measurably affect forecast skill, and it is already integrated with
cloud cover back to 2021.

- **Do not** build lead-varying features from
  `all_historical_forecasts`. Use it for its long record, its seasonal
  climatology, or as a best-estimate weather series — not as a forecast
  trajectory.
- **Open-Meteo Previous Runs is a fine alternative** and a reasonable
  swap if pipeline simplicity matters: it pulls in seconds against
  dynamical’s twenty-plus minutes of Zarr point extraction, and needs
  only `requests` rather than `icechunk`/`xarray`/`zarr`/`s3fs`.
- **Spend effort elsewhere.** Target framing, and eventually training on
  the accumulating `output/nws-forecasts-log.csv` once it spans two or
  three seasons, both matter far more. That log is unreproducible if
  lost and worth protecting.

### Pulling each source

`# dynamical.org GFS (default: leads 1-7, RM 8.5, writes to data-raw/)`` ``# python data-raw/pull_dynamical_forecasts.py`` ``#`` ``# Open-Meteo Previous Runs`` ``# python data-raw/pull_openmeteo_previous_runs.py --start-year 2021 --end-year 2026`

Both write a long-format CSV with the same schema —
`init_date, valid_date, lead_days, variable, value`, with `variable` in
`temperature_2m_max`, `temperature_2m_min`, `cloud_cover_mean` — so they
are drop-in comparable.

Measurements in sections 2–4 come from
`data-raw/dynamical-vs-openmeteo-comparison.Rmd` and the source
comparison in `analysis/rm85-rf-delta.Rmd`; they are reported here
rather than recomputed because they depend on files under `data-raw/`
and `output/`, which are not installed with the package.
