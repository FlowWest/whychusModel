#' @title historical RM 6 instream temperature
#' @name rm_6_historical
#' @description RM 6 historical instream temperature - daily statistics 
#' @format 9968 x 3 data frame
#' \itemize{
#'   \item{\code{date: }}{2012-04-23 - 2025-10-17}
#'   \item{\code{statistic: }}{mean, median, max, min, 7DADM}
#'   \item{\code{temperature: }}{instream temperature collected by UDWC, degrees C}
#' }
"rm_6_historical"

#' @title historical RM 6 instream temperature - not summarized daily
#' @name all_rm_6_dates_and_times
#' @description RM 6 historical instream temperature - hourly. Data represents the average of 1-3 loggers that are placed instream. 
#' @format 75,514 x 2 data frame
#' \itemize{
#'   \item{\code{date: }}{2012-04-23 - 2025-10-17}
#'   \item{\code{temperature: }}{hourly instream temperature collected by UDWC, degrees C}
#' }
"all_rm_6_dates_and_times"

#' Historical instream water temperature at Camp Polk
#'
#' Daily instream water temperature data collected by the Oregon Water Resources
#' Department (OWRD) at the Camp Polk monitoring station (station 14076100) on
#' the Whychus combined with UDWC logger data at the same site
#'
#' @format A data frame with 21,135 rows and 3 columns:
#' \itemize{
#'   \item{\code{date: }}{2012-05-29 - 2026-04-20}
#'   \item{\code{statistic: }}{mean, median, max, min, 7DADM}
#'   \item{\code{temperature: }}{instream temperature collected by UDWC and OWRD, degrees C}
#' }
#'
#' @source Oregon Water Resources Department Near Real-Time Hydrograph:
#'   \url{https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/}
"camp_polk_temperature_historical"

#' Historical discharge at Camp Polk
#'
#' Daily discharge data collected by the Oregon Water Resources
#' Department (OWRD) at the Camp Polk monitoring station (station 14076100) on
#' the Whychus 
#'
#' @format A data frame with 5,469 rows and 3 columns:
#' \itemize{
#'   \item{\code{date: }}{2011-05-01 - 2026-04-20}
#'   \item{\code{statistic: }}{mean}
#'   \item{\code{flow_cfs: }}{instream temperature collected by OWRD, degrees C}
#' }
#'
#' @source Oregon Water Resources Department Near Real-Time Hydrograph:
#'   \url{https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/}
"camp_polk_flow_historical"

#' Historical RM 8.5 instream temperature
#'
#' Daily instream water temperature collected by the Upper Deschutes Watershed
#' Council (UDWC) at the Rimrock Ranch downstream site (WC_008-50) on Whychus
#' Creek, river mile 8.5.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{date}}{POSIXct. Observation date, ranging from 2011 to present.}
#'   \item{\code{statistic}}{Character. Summary statistic: \code{"mean"}, \code{"median"}, \code{"max"}, \code{"min"}, \code{7DADM}}
#'   \item{\code{temperature}}{Numeric. Instream temperature in degrees Celsius.}
#' }
#'
#' @source Upper Deschutes Watershed Council continuous temperature monitoring
#'   program. Data compiled from annual UDWC data submission files (2011–2025).
"rm_8_5_historical"

#' Individual RM 8.5 logger readings, not summarised to daily statistics
#'
#' The raw logger readings behind \code{\link{rm_8_5_historical}}, so the daily
#' statistics can be recomputed without re-reading the annual UDWC Excel
#' workbooks.
#'
#' Note that time of day was not preserved during compilation: every reading is
#' stamped at midnight, so the several readings sharing a date cannot be
#' distinguished and this dataset cannot be used for sub-daily analysis. Use
#' \code{\link{all_rm_6_dates_and_times}}, which does retain hourly timestamps,
#' if you need a diurnal signal.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{date}}{POSIXct. Observation date; time of day is always midnight.}
#'   \item{\code{temperature}}{Numeric. Instream temperature in degrees Celsius.}
#' }
#'
#' @source Upper Deschutes Watershed Council continuous temperature monitoring
#'   program, monitoring location \code{WC_008-50}.
"all_rm_8_5_dates_and_times"

#' Historical observed air temperature near Sisters, Oregon
#'
#' Gridded daily observed air temperature for the cell containing Sisters,
#' Oregon (lat 44.2896, lon -121.5491), from 1979 onward. These are
#' observations, not forecasts — the series is used to score forecast archives
#' against reality and as a long-record baseline for judging how anomalous a
#' given summer is. It is not a model predictor.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{date}}{Date. Observation date.}
#'   \item{\code{tmax_C}, \code{tmin_C}, \code{tavg_C}}{Numeric. Daily maximum,
#'     minimum and mean air temperature in degrees Celsius. \code{tavg_C} is the
#'     midpoint of the daily max and min, not an integrated daily mean.}
#'   \item{\code{tmax_F}, \code{tmin_F}, \code{tavg_F}}{Numeric. The same three
#'     values converted to degrees Fahrenheit.}
#' }
#'
#' @source GridMET (~4 km gridded surface meteorology), variables \code{tmmx}
#'   and \code{tmmn}, pulled with \code{climateR::getGridMET()} and converted
#'   from Kelvin.
"sisters_air_temp_historical"

#' Historical precipitation near Sisters, Oregon
#'
#' Gridded daily precipitation for the same point and pull as
#' \code{\link{sisters_air_temp_historical}}, partitioned into rain and snow.
#' Not a model predictor — snowmelt timing reaches summer stream temperature
#' through discharge, which the model already observes directly at Camp Polk.
#'
#' The rain/snow split is a simple temperature threshold, not a physical
#' partition: precipitation is classed as snow when the day's mean air
#' temperature is at or below 0 degrees Celsius and as rain otherwise, so
#' \code{rain_mm} and \code{snow_mm} always sum to \code{precip_mm}.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{date}}{Date. Observation date.}
#'   \item{\code{precip_mm}}{Numeric. Total daily precipitation in millimetres.}
#'   \item{\code{rain_mm}}{Numeric. Precipitation falling on days with mean air
#'     temperature above 0 degrees Celsius.}
#'   \item{\code{snow_mm}}{Numeric. Precipitation falling on days with mean air
#'     temperature at or below 0 degrees Celsius.}
#' }
#'
#' @source GridMET (~4 km gridded surface meteorology), variable \code{pr},
#'   pulled with \code{climateR::getGridMET()}.
"sisters_precip_historical"

#' Historical instream water temperature and discharge at WHYCHUS CR AT SISTERS, OR
#'
#' Daily discharge data collected by the Oregon Water Resources
#' Department (OWRD) at the WHYCHUS CR AT SISTERS, OR monitoring station (station 14076050) on
#' the Whychus.
#'
#' @format A data frame with 4122 rows and 10 columns:
#' \describe{
#'   \item{\code{station_nbr}}{Numeric. OWRD station number (14076050).}
#'   \item{\code{date}}{Date. Observation date, ranging from 2015-10-01 to 2026-04-14}
#'   \item{\code{value}}{Numeric.Discharge in cfs}
#'   \item{\code{published_status}}{Character. OWRD data publication status (e.g. \code{"PVL"} = provisional).}
#'   \item{\code{download_date}}{Character. Date and time the data were downloaded from OWRD.}
#'   \item{\code{variable}}{Character. Variable name as returned by OWRD API (e.g. \code{"water temperature (c)", discharge (cfs)}).}
#'   \item{\code{statistic}}{Character. Summary statistic: \code{"max"}, \code{"min"}, \code{"mean"}.}
#'   \item{\code{location}}{Character. Station location name (\code{"camp polk"}).}
#'   \item{\code{estimated}}{Character. Flag indicating whether the value was estimated. \code{NA} if not estimated.}
#'   \item{\code{revised}}{Logical. Flag indicating whether the value has been revised. \code{NA} if not revised.}
#' }
#'
#' @source Oregon Water Resources Department Near Real-Time Hydrograph:
#'   \url{https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/display_hydro_graph.aspx?station_nbr=14076050}
"whychus_at_sisters_historical"

#' Historical instream water temperature and discharge at WHYCHUS CR NR SISTERS, OR
#'
#' Daily instream water temperature and discharge data collected by the Oregon Water Resources
#' Department (OWRD) at the WHYCHUS CR NR SISTERS, OR monitoring station (station 14075000) on
#' the Whychus.
#'
#' @format A data frame with 15,390 rows and 10 columns:
#' \describe{
#'   \item{\code{station_nbr}}{Numeric. OWRD station number (14075000).}
#'   \item{\code{date}}{Date. Observation date, ranging from 2015-10-01 to 2026-04-14}
#'   \item{\code{value}}{Numeric. Water temperature in degrees Celsius. Discharge in cfs}
#'   \item{\code{published_status}}{Character. OWRD data publication status (e.g. \code{"PVL"} = provisional).}
#'   \item{\code{download_date}}{Character. Date and time the data were downloaded from OWRD.}
#'   \item{\code{variable}}{Character. Variable name as returned by OWRD API (e.g. \code{"water temperature (c)", discharge (cfs)}).}
#'   \item{\code{statistic}}{Character. Summary statistic: \code{"max"}, \code{"min"}, \code{"mean"}.}
#'   \item{\code{location}}{Character. Station location name (\code{"camp polk"}).}
#'   \item{\code{estimated}}{Character. Flag indicating whether the value was estimated. \code{NA} if not estimated.}
#'   \item{\code{revised}}{Logical. Flag indicating whether the value has been revised. \code{NA} if not revised.}
#' }
#'
#' @source Oregon Water Resources Department Near Real-Time Hydrograph:
#'   \url{https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/display_hydro_graph.aspx?station_nbr=14075000}
"whychus_nr_sisters_historical"

#' Historical weather forecasts and observed weather near Whychus Creek
#'
#' Combined dataset of archived GFS forecast model output (2019-12-25 onward)
#' and ERA5 reanalysis observed weather (2011-01-01 to 2019-12-24) for the
#' location near Whychus Creek (lat 44.39, lon -121.41). A \code{type} column
#' distinguishes the two sources.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{valid_date}}{Date. The date the weather value applies to.}
#'   \item{\code{issue_date}}{Date. The model run issue date (NA for historical weather rows).}
#'   \item{\code{lead_days}}{Integer. Forecast lead time in days (NA for historical weather rows).}
#'   \item{\code{variable}}{Character. Variable name: \code{"temperature_2m_max"},
#'     \code{"temperature_2m_min"}, or \code{"cloud_cover_mean"}.}
#'   \item{\code{value}}{Numeric. Variable value in the unit given by \code{units}.}
#'   \item{\code{units}}{Character. Units string (e.g. \code{"°C"}, \code{"\%"}).}
#'   \item{\code{lat}}{Numeric. Latitude (44.390278).}
#'   \item{\code{lon}}{Numeric. Longitude (-121.406792).}
#'   \item{\code{type}}{Character. Data source: \code{"historical forecast"} (GFS, 2019-12-25 onward)
#'     or \code{"historical weather"} (ERA5, 2011-01-01 to 2019-12-24).}
#' }
#'
#' @source Open-Meteo Historical Forecast API (GFS seamless) and
#'   Open-Meteo Archive API (ERA5 reanalysis).
"all_historical_forecasts"

#' Archived GFS air temperature and cloud cover forecasts near Whychus Creek
#'
#' Historical NOAA Global Forecast System output for the grid cell nearest
#' Whychus Creek (lat 44.390278, lon -121.406792), at forecast leads of one to
#' seven days. This is the weather archive the RM 8.5 forecast models are
#' trained on.
#'
#' Unlike \code{\link{all_historical_forecasts}}, which stores a single value
#' per issue date replicated across every lead, this dataset carries a distinct
#' value at each lead, so a genuine day-1-through-day-7 forecast trajectory can
#' be reconstructed for any issue date.
#'
#' Values are calendar-day aggregates built from the model's four 6-hour
#' windows, taken from the 00Z initialisation. Coverage begins 2021-05-01, the
#' start of the dynamical.org GFS archive, and is seasonal thereafter — the
#' pull targets the May-October forecast season.
#'
#' The column names match \code{\link{all_historical_forecasts}} (minus its
#' \code{type} column) so the two archives can be compared directly.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{valid_date}}{Date. The date the forecast value applies to.}
#'   \item{\code{issue_date}}{Date. The model initialisation date the forecast
#'     was issued on.}
#'   \item{\code{lead_days}}{Integer. Forecast lead time in days, 1 through 7.}
#'   \item{\code{variable}}{Character. Variable name: \code{"temperature_2m_max"},
#'     \code{"temperature_2m_min"}, or \code{"cloud_cover_mean"}.}
#'   \item{\code{value}}{Numeric. Variable value in the unit given by \code{units}.}
#'   \item{\code{units}}{Character. \code{"°C"} for temperature,
#'     \code{"\%"} for cloud cover.}
#'   \item{\code{lat}}{Numeric. Latitude (44.390278).}
#'   \item{\code{lon}}{Numeric. Longitude (-121.406792).}
#' }
#'
#' @source dynamical.org NOAA GFS forecast archive
#'   (\code{s3://dynamical-noaa-gfs}, region \code{us-west-2}),
#'   \url{https://dynamical.org}. Pulled by
#'   \code{data-raw/pull_dynamical_forecasts.py}.
"dynamical_gfs_forecasts"

#' HydroVu locations lookup
#'
#' Locations visible to the HydroVu account, for resolving \code{location_id}
#' in the HydroVu readings stored at \code{data-live/hv_data.Rds} on the
#' \code{data} branch.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{location_id}}{Character. HydroVu location ID.}
#'   \item{\code{name}}{Character. Location name.}
#'   \item{\code{description}}{Character. Location description.}
#'   \item{\code{gps_latitude}}{Numeric. Latitude.}
#'   \item{\code{gps_longitude}}{Numeric. Longitude.}
#' }
#'
#' @source HydroVu public API via \code{rhydrovu::hv_locations()}. Built by
#'   \code{data-raw/hydrovu_lookups.R}.
"hydrovu_locations"

#' HydroVu parameters lookup
#'
#' All HydroVu parameter friendly-names, for resolving \code{parameter_id} in
#' the HydroVu readings stored at \code{data-live/hv_data.Rds} on the
#' \code{data} branch.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{parameter_id}}{Character. HydroVu parameter ID.}
#'   \item{\code{parameter_name}}{Character. Parameter name, e.g. \code{"Temperature"}.}
#' }
#'
#' @source HydroVu public API via \code{rhydrovu::hv_parameters()}. Built by
#'   \code{data-raw/hydrovu_lookups.R}.
"hydrovu_parameters"

#' HydroVu units lookup
#'
#' All HydroVu unit friendly-names, for resolving \code{unit_id} in the HydroVu
#' readings stored at \code{data-live/hv_data.Rds} on the \code{data} branch.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{unit_id}}{Character. HydroVu unit ID.}
#'   \item{\code{unit_name}}{Character. Unit abbreviation, e.g. \code{"psi"}.}
#' }
#'
#' @source HydroVu public API via \code{rhydrovu::hv_units()}. Built by
#'   \code{data-raw/hydrovu_lookups.R}.
"hydrovu_units"
