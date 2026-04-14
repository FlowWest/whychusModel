#' @title historical RM 6 instream temperature
#' @name rm_6_historical
#' @description RM 6 historical instream temperature 
#' @format 8232 x 3 data frame
#' \itemize{
#'   \item{\code{date: }}{2012-04-23 - 2025-10-17}
#'   \item{\code{statistic: }}{mean, median, max, min}
#'   \item{\code{temperature: }}{instream temperature collected by UDWC, degrees C}
#' }
"rm_6_historical"

#' Historical instream water temperature and discharge at Camp Polk
#'
#' Daily instream water temperature and discharge data collected by the Oregon Water Resources
#' Department (OWRD) at the Camp Polk monitoring station (station 14076100) on
#' the Whychus.
#'
#' @format A data frame with 15,578 rows and 10 columns:
#' \describe{
#'   \item{\code{station_nbr}}{Numeric. OWRD station number (14076100).}
#'   \item{\code{date}}{Date. Observation date, ranging from 2015-10-01 to 2026-03-29}
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
#'   \url{https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/}
"camp_polk_historical"

#' Historical RM 8.5 instream temperature
#'
#' Daily instream water temperature collected by the Upper Deschutes Watershed
#' Council (UDWC) at the Rimrock Ranch downstream site (WC_008-50) on Whychus
#' Creek, river mile 8.5.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{\code{date}}{POSIXct. Observation date, ranging from 2011 to present.}
#'   \item{\code{statistic}}{Character. Summary statistic: \code{"mean"}, \code{"median"}, \code{"max"}, \code{"min"}.}
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