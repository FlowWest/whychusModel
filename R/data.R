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