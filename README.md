# whychusModel

An R package of model inputs and data retrieval functions for stream temperature forecasting on Whychus Creek, developed for the Upper Deschutes Watershed Council (UDWC).

## Installation

```r
# install.packages("devtools")
devtools::install_github("FlowWest/whychusModel")
```

## Data Objects

Coverage, sources and exploratory plots for every dataset are in the
[Model Input Datasets](https://flowwest.github.io/udwc_temperature/articles/model-inputs.html)
article.

**Used by the RM 8.5 forecast model**

- `rm_8_5_historical` — UDWC instream temperature at RM 8.5; daily mean, median, max, min and 7DADM. The forecast target, and the model's persistence anchor.
- `camp_polk_temperature_historical` — daily water temperature at Camp Polk, merging OWRD station 14076100 with the UDWC logger at `WC_019-50`. The upstream boundary condition.
- `camp_polk_flow_historical` — OWRD daily mean discharge at Camp Polk (station 14076100).
- `dynamical_gfs_forecasts` — archived NOAA GFS max/min air temperature and cloud cover near Whychus Creek at forecast leads 1–7 days, from 2021-05-01 onward. The weather input the model is trained on.

**Reference series**

- `sisters_air_temp_historical` — GridMET observed daily air temperature near Sisters, OR, 1979 onward. Used to score forecast archives against reality and to judge how anomalous a given summer is.
- `sisters_precip_historical` — GridMET daily precipitation from the same pull, split into rain and snow at a 0 °C threshold.
- `all_historical_forecasts` — **superseded.** Archived GFS forecasts (2019 onward) plus ERA5 reanalysis weather (2011–2018). Do not use the forecast rows: they store one value per issue date replicated across all seven leads, so the forecast trajectory collapses to a single number. See [Choosing an Air Temperature Forecast Source](https://flowwest.github.io/udwc_temperature/articles/air-temperature-source.html). The ERA5 observation rows are sound.

**Other monitoring sites**

- `rm_6_historical` — UDWC instream temperature at RM 6; same daily statistics as RM 8.5. Downstream of RM 8.5, so not a predictor of it; `lm_rm6_7dadm()` fits a linear model to it.
- `whychus_nr_sisters_historical` — OWRD daily water temperature and discharge at Whychus Cr nr Sisters (station 14075000).
- `whychus_at_sisters_historical` — OWRD daily discharge at Whychus Cr at Sisters (station 14076050); the longest flow record here, back to 2001.
- `all_rm_6_dates_and_times`, `all_rm_8_5_dates_and_times` — the individual logger readings behind the two daily-statistic objects. Only the RM 6 version retains time of day.

## Data Sources

| Source | Description |
|--------|-------------|
| [OWRD Near Real-Time Hydrograph](https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/) | Streamflow and water temperature at Camp Polk (14076100), Whychus Cr nr Sisters (14075000) and Whychus Cr at Sisters (14076050) |
| [UDWC field monitoring](https://www.upperdeschuteswatershedcouncil.org/water-quality/) | Instream temperature loggers at RM 8.5, RM 6 and Camp Polk |
| [dynamical.org NOAA GFS archive](https://dynamical.org) | Archived GFS forecast output as Icechunk/Zarr on public S3; max/min air temperature and cloud cover at leads 1–7. Pulled by `data-raw/pull_dynamical_forecasts.py` |
| [NWS Gridpoint Forecast API](https://api.weather.gov) | Operational weather forecasts by gridpoint; the source used at forecast run time |
| [GridMET](https://www.climatologylab.org/gridmet.html) | ~4 km gridded observed daily air temperature and precipitation near Sisters, via `climateR::getGridMET()` |
| [Open-Meteo Historical Forecast API](https://open-meteo.com) | Archived GFS output behind `all_historical_forecasts`; superseded by dynamical.org as a forecast source |
