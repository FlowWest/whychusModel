# whychusModel

An R package of model inputs and data retrieval functions for stream temperature forecasting on Whychus Creek, developed for the Upper Deschutes Watershed Council (UDWC).

## Installation

```r
# install.packages("devtools")
devtools::install_github("FlowWest/whychusModel")
```

## Data Objects

| Object | Description | Rows | Date Range |
|--------|-------------|------|------------|
| `rm_6_historical` | UDWC instream temperature at RM 6 — daily statistics (mean, median, max, min, 7DADM) | 9,968 | 2012-04-23 – 2025-10-17 |
| `all_rm_6_dates_and_times` | UDWC instream temperature at RM 6 — hourly average across 1–3 loggers | 75,514 | 2012-04-23 – 2025-10-17 |
| `rm_8_5_historical` | UDWC instream temperature at RM 8.5 — daily statistics (mean, median, max, min, 7DADM) | — | 2011 – present |
| `camp_polk_temperature_historical` | Combined OWRD + UDWC daily instream water temperature at Camp Polk (station 14076100) — statistics (mean, median, max, min, 7DADM) | 21,135 | 2012-05-29 – present |
| `camp_polk_flow_historical` | OWRD daily mean discharge at Camp Polk (station 14076100) | 5,469 | 2011-05-01 – present |
| `whychus_at_sisters_historical` | OWRD daily discharge at Whychus Cr at Sisters (station 14076050) | 4,122 | 2015-10-01 – present |
| `whychus_nr_sisters_historical` | OWRD daily water temperature and discharge at Whychus Cr nr Sisters (station 14075000) | 15,390 | 2015-10-01 – present |
| `all_historical_forecasts` | Combined GFS archived forecasts (2019-12-25 onward) and ERA5 reanalysis weather (2011-01-01 – 2019-12-24) for max/min air temperature and cloud cover near Whychus Creek (lat 44.39, lon -121.41) | — | 2011-01-01 – present |

## Workflows

**`data-raw/pull-real-time-data.Rmd`**
Pulls current hydrological and weather data for near real-time use.

**`data-raw/pull-historical-data.Rmd`**
Pulls and assembles historical OWRD and forecast data for model training.

## Data Sources

| Source | Description |
|--------|-------------|
| [OWRD Near Real-Time Hydrograph](https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/) | Streamflow and water temperature at Camp Polk (station 14076100) |
| [NWS Gridpoint Forecast API](https://api.weather.gov) | Weather forecasts by gridpoint |
| [Open-Meteo Historical Forecast API](https://open-meteo.com) | Archived GFS model output at daily resolution (2020–present) |
| [UDWC field monitoring](https://www.upperdeschuteswatershedcouncil.org/water-quality/) | Instream temperature loggers at multiple RM sites on Whychus Creek |
