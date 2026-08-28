# Development of the RM 8.5 Instream Temperature Forecast Model

## Abstract

This document records the development of a statistical model forecasting
seven-day average daily maximum (7DADM) water temperature at Whychus
Creek RM 8.5 at lead times of one to seven days, for use in Habitat
Conservation Plan (HCP) threshold management. Development proceeded from
an inherited artificial neural network (ANN) approach, through a random
forest (RF) model class selection, to the current formulation, in which
the RF predicts the *change* in 7DADM from the value observed on the
forecast issue date rather than the absolute temperature. The rationale
for that formulation, and the evidence supporting it, are the primary
subject of this document. The current model is treated as a working
formulation rather than a final result; open questions are stated in
Section 9.

## 1. Background and origin

The modelling approach was adapted from prior work by Spencer Sawaske
(2023) on the Middle Fork John Day, retained in
`data-raw/scripts_from_spencer/`. That work used an `sklearn`
`MLPRegressor` over a compact predictor set:

    X_M1 = [Q, Julian, Air_Max, Air_Min, Q_m1, Air_Max_m1, Air_Min_m1]

comprising discharge, day-of-year, daily air temperature extremes, and
the previous day’s value of each; an optional variant appended the
previous day’s water temperature. The accompanying `Readme.txt`
specifies a three-stage procedure — parameter iteration, evaluation of
the resulting parameter set, and reconstruction of the selected model —
which this project retained.

Two design elements from this source persist in the current model:
day-of-year as an explicit seasonal predictor, and the antecedent water
temperature at the site as a feature. `mfjd-ann-in-R.R` reproduces the
original workflow in R (`neuralnet`, `caret`) against the same inputs,
to confirm transfer of the method prior to changing basins.

## 2. Model class selection

The method was applied to RM 8.5 in `rm85-ann.Rmd`, substituting Camp
Polk discharge and temperature, NWS air temperature and cloud cover, and
RM 8.5 daily maximum temperature as the response. A random forest was
fitted to the identical feature matrix for comparison.

The two model classes performed comparably, with the ANN marginally
ahead. Numeric results from that comparison are not reported here: the
evaluation design was subsequently found to be invalid (Section 3), and
the figures it produced are not interpretable as forecast skill. The
comparison is recorded as a qualitative finding only — the classes were
close enough that the choice between them was not determined by
accuracy.

Random forests were adopted on that basis. The considerations were
practical: the RF requires no predictor scaling, no architecture search
and no convergence management; it yields permutation-based variable
importances that support interpretation of model behaviour, which
matters for a model informing regulatory decisions; and it is simpler to
retrain and deploy operationally. The ANN was not developed further.

This decision has not been revisited under the current design (Section
9). It rests on a comparison whose numbers are no longer trusted, and
should be regarded as provisional.

## 3. Feature construction and validation design

### 3.1 Exploratory grid and its exclusion

`rm85-rf.Rmd` evaluated two response variables (daily Tmax; 7DADM)
against three lag structures and three lead times. **No performance
figures from this grid, or from the ANN comparison in Section 2, are
reported in this document.** Three independent defects in the evaluation
design mean the reported metrics do not measure forecast skill. They are
set out below because each one determined a corresponding element of the
current design, which is the durable output of that phase.

One substantive finding survives and was retained: 7DADM was adopted as
the response variable, being the quantity to which the HCP threshold
applies.

### 3.2 Lag predictors postdating forecast issuance

In `build_df()`, all inputs are joined on the *target* date; the lagged
specifications then select the preceding row, yielding a predictor
evaluated at `target_date − 1`. For a forecast issued on run date *R* at
lead *k*, the target date is *R + k*, so the lag resolves to:

``` math
\text{lag date} = R + k - 1
```

This coincides with the issue date only at *k* = 1. At *k* = 3 the
predictor postdates forecast issuance by two days, and at *k* = 7 by six
days. The affected predictors include the antecedent water temperature
at the response site — that is, an observation of the response variable
itself, one day prior to the date being predicted.

*Consequence for the design:* all predictors are now constructed
relative to the issue date (Section 3.5).

### 3.3 Two further sources of optimistic bias

Two additional issues affect the exploratory results, including the
specifications carrying no lag predictors at all.

*Lead-invariant weather inputs.* The archive supplying the forecast
predictors (`all_historical_forecasts`) stores a single value per issue
date, replicated across all seven lead times, and therefore carries no
lead-specific information. In specifications without lag predictors this
is the only lead-dependent input, so those specifications were in effect
fitting the same information at every lead — which is consistent with
the near-constant error across lead times observed throughout the grid.
This property is demonstrated in
[`vignette("air-temperature-source")`](https://flowwest.github.io/udwc_temperature/articles/air-temperature-source.md).

*Consequence for the design:* the weather source was replaced (Section
5).

*Random partitioning of an autocorrelated series.* Both exploratory
documents partitioned observations at random
([`caret::createDataPartition`](https://rdrr.io/pkg/caret/man/createDataPartition.html);
[`sample()`](https://rdrr.io/r/base/sample.html)). Daily water
temperature at this site is strongly autocorrelated:

`d7`` ``<-`` ``rm_8_5_historical`` ``|>`` `` `[`filter`](https://dplyr.tidyverse.org/reference/filter.html)`(``statistic`` ``==`` ``"7DADM"``, ``!`[`is.na`](https://rdrr.io/r/base/NA.html)`(``temperature``)``)`` ``|>`` `` `[`mutate`](https://dplyr.tidyverse.org/reference/mutate.html)`(``date ``=`` `[`as.Date`](https://rdrr.io/r/base/as.Date.html)`(``date``)``)`` ``|>`` `` `[`arrange`](https://dplyr.tidyverse.org/reference/arrange.html)`(``date``)`` `` ``consecutive`` ``<-`` ``d7`` ``|>`` `` `[`mutate`](https://dplyr.tidyverse.org/reference/mutate.html)`(``prev ``=`` `[`lag`](https://dplyr.tidyverse.org/reference/lead-lag.html)`(``temperature``)``, gap ``=`` `[`as.numeric`](https://rdrr.io/r/base/numeric.html)`(``date`` ``-`` `[`lag`](https://dplyr.tidyverse.org/reference/lead-lag.html)`(``date``)``)``)`` ``|>`` `` `[`filter`](https://dplyr.tidyverse.org/reference/filter.html)`(``gap`` ``==`` ``1``, ``!`[`is.na`](https://rdrr.io/r/base/NA.html)`(``prev``)``)`` `` `[`c`](https://rdrr.io/r/base/c.html)`(``n_pairs ``=`` `[`nrow`](https://rdrr.io/r/base/nrow.html)`(``consecutive``)``,`` `` lag1_correlation ``=`` `[`round`](https://rdrr.io/r/base/Round.html)`(`[`cor`](https://rdrr.io/r/stats/cor.html)`(``consecutive``$``temperature``, ``consecutive``$``prev``)``, ``4``)``,`` `` mean_abs_daily_change_C ``=`` `[`round`](https://rdrr.io/r/base/Round.html)`(`[`mean`](https://rdrr.io/r/base/mean.html)`(`[`abs`](https://rdrr.io/r/base/MathFun.html)`(``consecutive``$``temperature`` ``-`` ``consecutive``$``prev``)``)``, ``3``)``)`` ``#> n_pairs lag1_correlation mean_abs_daily_change_C `` ``#> 2835.0000 0.9958 0.3150`

At a lag-1 correlation of 0.996 and a mean absolute daily change of 0.31
°C against a seasonal range of approximately 15 °C, random partitioning
places the immediate temporal neighbours of most held-out observations
in the training set. The effect is amplified for 7DADM, a seven-day
rolling mean, for which consecutive values share six of seven
constituent observations by construction.

*Consequence for the design:* subsequent work partitions
chronologically, holding out the most recent 20% of observations.

### 3.4 Effect of the three defects

The three defects are not alternative explanations for the same
optimism; they act independently and at different points. Lag predictors
postdating issuance (3.2) affect only the lagged specifications, and
only at leads greater than one. Lead-invariant weather inputs (3.3)
affect every specification, and are the sole cause of flat performance
across leads where no lag predictors are present. Random partitioning
(3.3) affects every specification at every lead. No combination of these
can be corrected after the fact from the reported figures, which is why
none are reproduced here.

### 3.5 Run-date-relative construction

All predictors in the current model are constructed by explicit
date-shifted joins evaluated as of the forecast issue date, rather than
by row-position lags applied after a target-date join. Forecast
trajectory predictors `air_max_d1 … air_max_dk` are truncated at each
model’s own lead time, since day *k* coincides with the target date and
later days describe conditions after it.

## 4. Evaluation framework

Model selection is based on a hindcast over the 2026 season
(`analysis/summer_2026_8_5_performance.Rmd`), in which saved models are
re-run against observations from a real RM 8.5 logger using the NWS
forecasts logged operationally each day
(`output/nws-forecasts-log.csv`). This evaluation is used in preference
to historical hold-out performance because it is the only one in which
the weather predictors take the form encountered in operation.

The distinction is material. The models are trained on an archived
weather series but served real NWS forecasts, and the two disagree by
1.7 °C MAE at lead 1, increasing to 2.8 °C at lead 7 (cloud cover: +15
percentage points, correlation declining to 0.58). Historical hold-out
evaluation uses the archived series on both sides of the comparison and
cannot detect the resulting degradation.

Two reporting practices were adopted following this work. Bias is
reported alongside RMSE, a systematic error of 0.6–0.8 °C having
previously been present in historical test results but not reported.
Skill is reported against persistence — carrying the issue-date
observation forward — as a minimum standard for a forecast to be
considered useful.

## 5. Formulations evaluated

**Table 1.** Formulations and modifications evaluated. Effect sizes are
ΔRMSE on the 2026 hindcast relative to the reference specification;
negative values indicate improvement. Paired *t*-tests on squared error.

| Modification | Effect | Disposition |
|----|----|----|
| Change-from-today response (Section 6) | −0.29 to −0.40, *p* \< 0.001 | **Adopted** |
| Site trend and trajectory summary predictors | −0.14 to −0.17, *p* \< 0.001 | **Adopted** |
| Same-day rather than lagged site observation | −0.10 mean RMSE | **Adopted** |
| dynamical.org GFS in place of archived series | improves bias −1.61 → −1.28 | **Adopted** |
| Quantile regression forest (intervals, exceedance probability) | n/a | **Adopted alongside** |
| Gradient boosting (XGBoost) | superior under the absolute response; inferior once retrained on GFS inputs | Not adopted |
| Open-Meteo Previous Runs weather source | −0.010, *p* = 0.46 | Not adopted |
| Seasonal anomaly predictors | +0.126, *p* \< 0.001 | Rejected |
| Recency-weighted training (row duplication) | improves leads 1–3, degrades leads 5–7 | Rejected |
| Linear recalibration of model output | ≤ 0.03 °C | No effect |
| Year-trend bias correction | not significant | No effect |
| Camp Polk offset, diurnal range, flow anomaly predictors | +0.01 to +0.03, *p* \< 0.05 | Rejected |
| Removal of cloud cover predictors | +0.003, *p* = 0.60 | Neutral |
| Two-model persistence/weather blend | no improvement | Rejected |
| Pooled cross-lead model with lead as predictor | degrades, particularly at lead 1 | Rejected |

## 6. Rationale for the change-from-today formulation

### 6.1 Problem

Under the absolute-temperature response, hindcast performance exhibited
a negative bias increasing with lead time and concentrated above the
regulatory threshold: −0.90 °C at lead 1 to −1.91 °C at lead 7, and
−1.03 °C mean bias on days observed at or above 20 °C. At lead 7 the
model did not meaningfully improve on persistence (RMSE 2.01 versus
2.05).

### 6.2 Candidate explanations tested

Extrapolation beyond the training range was evaluated and rejected as
the mechanism. Training data contained 31% of observations at or above
20 °C, with a maximum (24.06 °C) exceeding the 2026 maximum (23.12 °C),
and the gap between maximum predicted and maximum observed values did
not exceed 0.9 °C.

Two structural explanations were supported. First, the train/serve
mismatch in the weather predictors described in Section 4. Second, a
shift in the relationship between Camp Polk and RM 8.5 temperature
occurring around 2022: a relationship estimated on 2011–2015
underpredicts 2022, 2024 and 2025 by approximately 1.9–2.1 °C, and the
residual is level rather than trending, indicating a persistent regime
change rather than gradual drift.

### 6.3 Formulation

The model is fitted to the difference between the response and the site
observation available at forecast issue:

``` math
\Delta_k = \text{7DADM}(R + k) - \text{7DADM}(R)
```

with the prediction reconstructed as
$`\widehat{\text{7DADM}}(R+k) = \text{7DADM}(R) + \widehat{\Delta}_k`$.
The issue-date observation is retained in the predictor set, allowing
the magnitude of the predicted change to be conditioned on current
state.

### 6.4 Rationale

The formulation is motivated by the location of the model’s exposure to
the error sources identified in Section 6.2.

Under an absolute response, the model must reconstruct the temperature
level from its predictors, and the weather predictors — the ones subject
to train/serve mismatch — participate directly in that reconstruction.
Error in those predictors therefore propagates into the level, and does
so increasingly with lead time as forecast quality declines.

Under the change formulation, the level is supplied by
$`\text{7DADM}(R)`$, a direct observation of the response variable at
the site. This quantity is identical in training and in operation; it is
not a modelled or archived proxy and is not subject to the mismatch. The
predictors are required only to estimate a departure from it. Weather
predictor error can therefore corrupt the estimated change, but cannot
corrupt the level to which that change is applied.

The same argument accounts for robustness to distributional shift. The
2026 season was the warmest in the 15-year record (mean 7DADM +2.96 °C
above the 2011–2025 mean; 47% of days at or above threshold against a
historical median of 24%), and 20% of observations exceeded the training
maximum. A random forest cannot predict beyond the range of values held
in its terminal nodes. Under the change formulation this constraint
applies only to $`\Delta_k`$, whose distribution is approximately
stationary across years, while the level enters additively and is
unconstrained by the training range.

This reasoning is supported by the failure of the seasonal anomaly
predictors (Table 3). Anomaly features were introduced on the
expectation that they would improve performance in an anomalous year,
and instead degraded it significantly. In 2026, 61% of anomaly values
exceeded the training 95th percentile and 13% exceeded the training
maximum, so the predictor was saturated for much of the season while
continuing to occupy candidate-split positions. Supplying the anomaly as
a *predictor* reintroduces the range constraint that the change
formulation removes by handling the level outside the model.

### 6.5 Verification against persistence

Because the formulation is anchored on persistence, it was verified that
it does not reduce to persistence. On the 2026 hindcast the model
outperforms persistence at every lead time, with the margin increasing
from 0.18 °C at lead 1 to 0.76 °C at lead 7 — the opposite of the
pattern expected if the anchor were doing the work. The effect size of
the formulation change (Table 3) is six to ten times that of the weather
source substitution, which was not significant.

## 7. Current model specification

Separate random forests (500 trees, `mtry = ⌊p/3⌋`) for lead times 1–7,
fitted to $`\Delta_k`$ on the May–October season, 2021–2025, with a
chronological 80/20 partition. Predictors: Camp Polk discharge, 7DADM
and daily maximum with five-day trends; dynamical.org GFS forecast
trajectory (daily maximum and minimum air temperature, cloud cover,
day-of-year for each day `d1 … dk`); trajectory summaries; and RM 8.5
issue-date 7DADM, daily maximum, and five-day trends. Implemented in
`analysis/rm85-rf-delta.Rmd`; saved as
`output/rm85_rf_7dadm_delta_lead{1..7}.rds`.

Site observations are taken from the issue date rather than the
preceding day. The operational job runs at 19:00 PST and the site’s
daily maximum occurs by 17:00–18:00 on effectively all observed days (0%
after 19:00; 4.1% after 18:00), so the issue-date value is complete at
run time.

A quantile regression forest is fitted alongside on the same response
and predictors (`analysis/rm85-rf-delta-quantiles.Rmd`), supplying
prediction intervals and exceedance probability. Nominal intervals were
found to over-cover; calibrated levels are stored in
`output/rm85_qrf_interval_calibration.csv`.

## 8. Performance

**Table 2.** 2026 hindcast performance, current formulation (*n* = 83
per lead).

| Lead (days) | Bias (°C) | MAE (°C) | RMSE (°C) | Persistence RMSE (°C) |
|-------------|-----------|----------|-----------|-----------------------|
| 1           | −0.05     | 0.21     | 0.27      | 0.45                  |
| 2           | −0.01     | 0.32     | 0.41      | 0.81                  |
| 3           | −0.01     | 0.44     | 0.54      | 1.09                  |
| 4           | −0.02     | 0.58     | 0.74      | 1.33                  |
| 5           | −0.07     | 0.70     | 0.88      | 1.53                  |
| 6           | −0.07     | 0.79     | 1.01      | 1.68                  |
| 7           | −0.19     | 0.81     | 1.01      | 1.77                  |

Bias on days observed at or above the threshold ranges from −0.05 °C at
lead 1 to −0.45 °C at lead 7, against −0.63 to −1.76 °C under the
previous formulation.

Threshold-exceedance sensitivity ranges from 0.91 to 0.96 across lead
times. Missed exceedances occur on six dates, clustered around the three
occasions in the season on which the observed series first crossed the
threshold from below; the remaining dates are trailing days of the same
events. Missed cases are marginal rather than large errors: 85% were
observed below 20.5 °C, with a median forecast 0.6 °C below threshold
and a median required rise of 1.8 °C against a median of approximately 0
°C across all forecast dates.

## 9. Status, limitations and open questions

The current formulation is a working specification, not a settled
result. The following are unresolved.

*Validation is limited to a single, anomalous season.* The 2026 hindcast
covers 83 forecast dates in the warmest year of the record. Performance
in a season of typical warmth has not been observed, and the interval
calibration in particular should be re-derived once it has been.

*The model has not been retrained on 2026 observations.* Twenty percent
of 2026 observations exceeded the training maximum. Incorporating the
season would extend the covered range and is expected to be the single
largest available improvement.

*Uncertainty in the weather predictors is not represented.* The quantile
model characterises the conditional distribution of water temperature
given the supplied forecast; it does not represent error in that
forecast, which is the dominant error source at lead 7. Propagation
through a GEFS ensemble would address this.

*Interval coverage is calibrated empirically rather than guaranteed.*
Conformalized quantile regression would provide finite-sample coverage
guarantees while retaining lead-dependent adaptivity.

*The operational forecast log is the preferred long-term training
source.* Once `output/nws-forecasts-log.csv` spans two to three seasons,
the distribution of realised forecast errors will incorporate model
error, weather-input error and regime drift jointly, and is expected to
supersede archive-based uncertainty estimation.

*Model class selection rests on a discarded evaluation.* The ANN/RF
comparison in Section 2 was made under the design later found invalid,
and its figures are not reported for that reason. The choice of random
forest therefore rests on the practical considerations set out in
Section 2 — interpretability, absence of tuning, operational simplicity
— rather than on a measured accuracy comparison. It also predates the
change-from-today formulation, run-date-relative feature construction,
and the current weather source. Gradient boosting was superior under the
absolute response and inferior after the weather source changed; neither
result has been re-tested under the current specification. Re-running
the class comparison under the current design and a chronological
partition is the cleanest way to put this on a measured footing.

*Regime stability is assumed and not monitored.* The Camp Polk to RM 8.5
relationship shifted once within the record. No automated check on
trailing forecast bias is currently in place.

## References

Sawaske, S. (2023). Middle Fork John Day ANN water temperature model.
Retained in `data-raw/scripts_from_spencer/`.

Supporting analyses: `analysis/model-type-exploration/` (exploratory ANN
and RF work); `analysis/rm85-rf-delta.Rmd` (current model);
`analysis/rm85-rf-delta-quantiles.Rmd` (uncertainty);
`analysis/summer_2026_8_5_performance.Rmd` (operational evaluation);
`data-raw/dynamical-vs-openmeteo-comparison.Rmd` (weather source
comparison);
[`vignette("air-temperature-source")`](https://flowwest.github.io/udwc_temperature/articles/air-temperature-source.md).
