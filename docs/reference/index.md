# Package index

## Datasets

Observed and forecast records shipped with the package. See the “Model
Input Datasets” article for sources, coverage and exploratory plots.

- [`all_historical_forecasts`](https://flowwest.github.io/udwc_temperature/reference/all_historical_forecasts.md)
  : Historical weather forecasts and observed weather near Whychus Creek
- [`all_rm_6_dates_and_times`](https://flowwest.github.io/udwc_temperature/reference/all_rm_6_dates_and_times.md)
  : historical RM 6 instream temperature - not summarized daily
- [`all_rm_8_5_dates_and_times`](https://flowwest.github.io/udwc_temperature/reference/all_rm_8_5_dates_and_times.md)
  : Individual RM 8.5 logger readings, not summarised to daily
  statistics
- [`camp_polk_flow_historical`](https://flowwest.github.io/udwc_temperature/reference/camp_polk_flow_historical.md)
  : Historical discharge at Camp Polk
- [`camp_polk_temperature_historical`](https://flowwest.github.io/udwc_temperature/reference/camp_polk_temperature_historical.md)
  : Historical instream water temperature at Camp Polk
- [`dynamical_gfs_forecasts`](https://flowwest.github.io/udwc_temperature/reference/dynamical_gfs_forecasts.md)
  : Archived GFS air temperature and cloud cover forecasts near Whychus
  Creek
- [`rm_6_historical`](https://flowwest.github.io/udwc_temperature/reference/rm_6_historical.md)
  : historical RM 6 instream temperature
- [`rm_8_5_historical`](https://flowwest.github.io/udwc_temperature/reference/rm_8_5_historical.md)
  : Historical RM 8.5 instream temperature
- [`sisters_air_temp_historical`](https://flowwest.github.io/udwc_temperature/reference/sisters_air_temp_historical.md)
  : Historical observed air temperature near Sisters, Oregon
- [`sisters_precip_historical`](https://flowwest.github.io/udwc_temperature/reference/sisters_precip_historical.md)
  : Historical precipitation near Sisters, Oregon
- [`whychus_at_sisters_historical`](https://flowwest.github.io/udwc_temperature/reference/whychus_at_sisters_historical.md)
  : Historical instream water temperature and discharge at WHYCHUS CR AT
  SISTERS, OR
- [`whychus_nr_sisters_historical`](https://flowwest.github.io/udwc_temperature/reference/whychus_nr_sisters_historical.md)
  : Historical instream water temperature and discharge at WHYCHUS CR NR
  SISTERS, OR

## Functions

Data retrieval helpers, the RM 6 linear model, and utilities.

- [`get_historical_forecast()`](https://flowwest.github.io/udwc_temperature/reference/get_historical_forecast.md)
  : Retrieve historical forecast data at specific lead times
- [`get_historical_forecast_range()`](https://flowwest.github.io/udwc_temperature/reference/get_historical_forecast_range.md)
  : Pull historical forecasts across a long date range in annual chunks
- [`get_historical_weather()`](https://flowwest.github.io/udwc_temperature/reference/get_historical_weather.md)
  : Retrieve historical observed weather data
- [`get_nws_forecast()`](https://flowwest.github.io/udwc_temperature/reference/get_nws_forecast.md)
  : Retrieve weather forecast data from the National Weather Service API
- [`get_owrd_hydro()`](https://flowwest.github.io/udwc_temperature/reference/get_owrd_hydro.md)
  : Retrieve hydrological data from the Oregon Water Resources
  Department
- [`` `%||%` ``](https://flowwest.github.io/udwc_temperature/reference/grapes-or-or-grapes.md)
  : Null coalescing operator
- [`lm_rm6_7dadm()`](https://flowwest.github.io/udwc_temperature/reference/lm_rm6_7dadm.md)
  : Fit or apply a linear model predicting RM 6 7DADM from RM 8.5 7DADM
- [`rm_6_predict()`](https://flowwest.github.io/udwc_temperature/reference/rm_6_predict.md)
  : Predict RM 6 7DADM from an RM 8.5 temperature value
- [`to_julian()`](https://flowwest.github.io/udwc_temperature/reference/to_julian.md)
  : Convert a date to Julian day of year
