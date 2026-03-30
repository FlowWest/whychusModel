#' Retrieve weather forecast data from the National Weather Service API
#'
#' Fetches gridpoint forecast data from the NWS API and returns a tibble
#' for a specified weather variable.
#'
#' @param gridpoint Character. NWS gridpoint in the format \code{"office/x,y"},
#'   e.g. \code{"PDT/35,57"}. Find your gridpoint at
#'   \url{https://api.weather.gov/points/{lat},{lon}}.
#' @param variable Character. The forecast variable to return. One of:
#'   \describe{
#'     \item{\code{"temperature"}}{Hourly air temperature (°C)}
#'     \item{\code{"maxTemperature"}}{Daily maximum air temperature (°C)}
#'     \item{\code{"minTemperature"}}{Daily minimum air temperature (°C)}
#'     \item{\code{"skyCover"}}{Sky cover (percent)}
#'   }
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{\code{datetime}}{POSIXct forecast valid time (UTC)}
#'     \item{\code{value}}{Numeric forecast value in native units}
#'     \item{\code{duration}}{Character ISO 8601 duration string (e.g. \code{"PT1H"})}
#'     \item{\code{variable}}{Character name of the returned variable}
#'   }
#'
#' @examples
#' \dontrun{
#' get_nws_forecast("PDT/35,57", "temperature")
#' get_nws_forecast("PDT/35,57", "skyCover")
#' }
#'
#' @importFrom httr2 request req_perform resp_body_json
#' @importFrom purrr map_dfr
#' @importFrom tibble tibble
#' @importFrom dplyr mutate select
#' @importFrom lubridate ymd_hms
#' @importFrom stringr str_extract
#' @export
get_nws_forecast <- function(
    gridpoint,
    variable = c("temperature", "maxTemperature", "minTemperature", "skyCover")
) {
  
  variable <- match.arg(variable)
  
  link <- paste0("https://api.weather.gov/gridpoints/", gridpoint)
  
  weather_forecast <- request(link) |>
    req_perform() |>
    resp_body_json()
  
  values <- weather_forecast$properties[[variable]]$values
  
  if (is.null(values)) {
    stop("Variable '", variable, "' not found in API response for gridpoint: ", gridpoint)
  }
  
  values |>
    map_dfr(~ tibble(
      validTime = .x$validTime,
      value     = .x$value
    )) |>
    mutate(
      datetime = ymd_hms(str_extract(validTime, "^[^/]+")),
      duration = str_extract(validTime, "(?<=/)PT\\d+H"),
      variable = variable
    ) |>
    select(datetime, value, duration, variable)
}
