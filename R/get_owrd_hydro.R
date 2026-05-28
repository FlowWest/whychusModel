#' Retrieve hydrological data from the Oregon Water Resources Department
#'
#' Downloads streamflow or water temperature data from the OWRD Near Real-Time
#' Hydrograph web service for a given station and date range. Handles session
#' cookies and form-based POST requests automatically.
#'
#' @param station_nbr Character. OWRD station number. Defaults to \code{"14076100"}.
#' @param start_date Character or Date. Start date for the data request.
#'   Will be coerced to \code{Date} — any format accepted by \code{as.Date()} works.
#' @param end_date Character or Date. End date for the data request.
#'   Will be coerced to \code{Date} — any format accepted by \code{as.Date()} works.
#' @param data_source Character. The type of hydrological data to retrieve.
#'   One of:
#'   \describe{
#'     \item{\code{"MDF"}}{Mean daily flow}
#'     \item{\code{"Instantaneous_Flow"}}{Instantaneous flow}
#'     \item{\code{"WTEMP15"}}{Instantaneous water temperature (15-min)}
#'     \item{\code{"WTEMP_MEAN"}}{Mean daily water temperature}
#'     \item{\code{"WTEMP_MAX"}}{Maximum daily water temperature}
#'     \item{\code{"WTEMP_MIN"}}{Minimum daily water temperature}
#'   }
#'   Defaults to \code{"MDF"}. Partial matching is supported via \code{match.arg()}.
#'
#' @return A tibble with cleaned column names (via \code{janitor::clean_names()})
#'   containing the requested hydrological data for the specified station and
#'   date range. Column names and units vary by \code{data_source}.
#'
#' @details
#' This function scrapes the OWRD Near Real-Time Hydrograph web application
#' (\url{https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/}). It
#' performs an initial GET request to retrieve the ASP.NET form state
#' (\code{__VIEWSTATE} etc.) before submitting a POST request to download
#' data in TSV format. A persistent session handle is used to preserve cookies
#' across requests.
#'
#' @examples
#' \dontrun{
#' # Mean daily flow for a station in 2023
#' flow <- get_owrd_hydro(
#'   station_nbr = "14076100",
#'   start_date  = "2023-01-01",
#'   end_date    = "2023-12-31",
#'   data_source = "MDF"
#' )
#'
#' # Mean daily water temperature
#' temp <- get_owrd_hydro(
#'   station_nbr = "14076100",
#'   start_date  = "2023-06-01",
#'   end_date    = "2023-09-30",
#'   data_source = "WTEMP_MEAN"
#' )
#' }
#'
#' @importFrom httr GET POST handle stop_for_status content add_headers headers
#' @importFrom rvest read_html html_form
#' @importFrom readr read_tsv
#' @importFrom janitor clean_names
#' @importFrom stringr str_detect
#' @export
get_owrd_hydro <- function(
    station_nbr = "14076100",
    start_date,
    end_date,
    data_source = c(
      "MDF",                # Mean Daily Flow
      "Instantaneous_Flow", # Instantaneous Flow
      "WTEMP15",            # Instantaneous Water Temperature
      "WTEMP_MEAN",         # Mean Daily Water Temperature
      "WTEMP_MAX",          # Maximum Daily Water Temperature
      "WTEMP_MIN"           # Minimum Daily Water Temperature
    )
    
) {
  
  data_source <- match.arg(data_source)
  download_format = "tsv"
  
  url <- paste0(
    "https://apps.wrd.state.or.us/apps/sw/hydro_near_real_time/display_hydro_graph.aspx?station_nbr=",
    station_nbr
  )
  
  # preserve cookies/session
  h <- handle(url)
  
  # initial GET
  resp_get <- GET(url, handle = h)
  stop_for_status(resp_get)
  
  page <- read_html(content(resp_get, as = "text", encoding = "UTF-8"))
  frm <- html_form(page)[[1]]
  
  get_field_value <- function(form, nm) {
    x <- form$fields[[nm]]
    if (is.null(x)) return(NULL)
    x$value
  }
  
  body <- list(
    "__VIEWSTATE" = get_field_value(frm, "__VIEWSTATE"),
    "__VIEWSTATEGENERATOR" = get_field_value(frm, "__VIEWSTATEGENERATOR"),
    "__EVENTVALIDATION" = get_field_value(frm, "__EVENTVALIDATION"),
    "ctl00$PageData$tb_start_date" = format(as.Date(start_date), "%m/%d/%Y"),
    "ctl00$PageData$tb_end_date" = format(as.Date(end_date), "%m/%d/%Y"),
    "ctl00$PageData$ddl_data_source" = data_source,
    "ctl00$PageData$ddl_axis_type" = "LINEAR",
    "ctl00$PageData$ddl_download_format" = download_format,
    "ctl00$PageData$btn_download" = "Download"
  )
  
  body <- body[!vapply(body, is.null, logical(1))]
  
  # classic form POST
  resp_post <- POST(
    url,
    handle = h,
    body = body,
    encode = "form",
    add_headers(
      Referer = url,
      Origin = "https://apps.wrd.state.or.us"
    )
  )
  
  stop_for_status(resp_post)
  
  ctype <- headers(resp_post)[["content-type"]] %||% ""
  raw <- content(resp_post, as = "raw")
  txt <- content(resp_post, as = "text", encoding = "UTF-8")
  
  if (download_format == "tsv" || str_detect(ctype, "tab|plain|octet-stream")) {
    result <- read_tsv(I(txt), show_col_types = FALSE) |> clean_names()
    if (nrow(result) == 0) {
      stop(
        "OWRD returned 0 rows for station ", station_nbr,
        " (", data_source, ", ", start_date, " to ", end_date, "). ",
        "The near-real-time endpoint only retains ~100 days of data. "
      )
    }
    return(result)
  }
  
  cat(substr(txt, 1, 1000))
  stop("Unrecognized response type.")
}

#' Null coalescing operator
#'
#' Returns \code{x} if it is neither \code{NULL} nor length zero, otherwise
#' returns \code{y}. Equivalent to the null coalescing operator in other
#' languages.
#'
#' @param x The primary value to test.
#' @param y The fallback value returned when \code{x} is \code{NULL} or
#'   has length zero.
#'
#' @return \code{x} if \code{!is.null(x) && length(x) > 0}, otherwise \code{y}.
#'
#' @examples
#' NULL %||% "default"   # returns "default"
#' "value" %||% "default" # returns "value"
#' character(0) %||% "default" # returns "default"
#'
#' @export
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x