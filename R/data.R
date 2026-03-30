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
#'   \item{\code{date}}{Date. Observation date, ranging from 2015-10-01 to present.}
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