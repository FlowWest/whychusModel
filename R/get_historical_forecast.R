#' Retrieve historical forecast data at specific lead times
#'
#' Pulls archived GFS/NWS forecast model output from the Open-Meteo
#' Historical Forecast API for a given location, date range, and set of
#' forecast lead times. Returns the forecast that would have been issued
#' `lead_days` before the valid date — i.e. what a model would have
#' received as input on that day.
#'
#' @param lat Numeric. Latitude of target point.
#' @param lon Numeric. Longitude of target point.
#' @param start_date Character or Date. Start of valid date range.
#' @param end_date Character or Date. End of valid date range.
#' @param lead_days Integer vector. Forecast lead times in days.
#'   e.g. c(1, 3, 7) returns the day-1, day-3, and day-7 forecasts.
#' @param variables Character vector. Daily forecast variables to retrieve.
#' @param model Character. Forecast model to use. "gfs_seamless" is the
#'   closest to NWS operational output. Other options: "ecmwf_ifs04",
#'   "gfs025", "icon_seamless".
#' @param timezone Character. Timezone. Defaults to "UTC".
#'
#' @return A tibble with columns: valid_date, issue_date, lead_days,
#'   variable, value, units, lat, lon
#'
#' @details
#' The Open-Meteo Historical Forecast API archives GFS model runs from
#' 2020 onwards at daily resolution. The \code{forecast_days} parameter
#' controls how many days ahead each archived run extends. By requesting
#' the same valid date from runs issued at different lead times, you can
#' reconstruct what the forecast said at each lead time.
#'
#' @examples
#' \dontrun{
#' get_historical_forecast(
#'   lat        = 44.390278,
#'   lon        = -121.406792,
#'   start_date = "2023-07-01",
#'   end_date   = "2023-07-31",
#'   lead_days  = c(1, 3, 7)
#' )
#' }
#'
#' @importFrom httr2 request req_url_query req_perform resp_body_json
#' @importFrom purrr map_dfr
#' @importFrom dplyr mutate select bind_rows
#' @importFrom tibble tibble
#' @importFrom lubridate as_date ymd
#' @export
get_historical_forecast <- function(
    lat        = 44.390278,
    lon        = -121.406792,
    start_date,
    end_date,
    lead_days  = c(1, 3, 7),
    variables  = c(
      "temperature_2m_max",
      "temperature_2m_min",
      "cloud_cover_mean"
    ),
    model      = "gfs_seamless",
    timezone   = "UTC"
) {
  
  start <- as.Date(start_date)
  end   <- as.Date(end_date)
  
  # For each lead time, shift the request window back by lead_days
  # so the issue_date range covers start:end as valid dates
  map_dfr(lead_days, function(lead) {
    
    issue_start <- start - lead
    issue_end   <- end   - lead
    
    message("Pulling lead = day ", lead,
            " | issue dates: ", issue_start, " to ", issue_end)
    
    resp <- tryCatch({
      # Build query — daily must be repeated per variable, not comma-joined
      base_params <- list(
        latitude   = lat,
        longitude  = lon,
        start_date = format(issue_start, "%Y-%m-%d"),
        end_date   = format(issue_end,   "%Y-%m-%d"),
        model      = model,
        timezone   = timezone
      )
      daily_params <- set_names(
        as.list(variables), rep("daily", length(variables))
      )
      
      request("https://historical-forecast-api.open-meteo.com/v1/forecast") |>
        req_url_query(!!!base_params) |>
        req_url_query(!!!daily_params) |>
        req_perform() |>
        resp_body_json()
    }, error = function(e) {
      warning("API call failed for lead ", lead, ": ", e$message)
      return(NULL)
    })
    
    if (is.null(resp)) return(tibble())
    
    units_lookup <- resp$daily_units
    
    # Issue dates returned by API
    issue_dates <- as.Date(unlist(resp$daily$time))
    
    map_dfr(variables, function(v) {
      vals <- unlist(resp$daily[[v]])
      if (is.null(vals)) {
        warning("Variable not found: ", v)
        return(tibble())
      }
      tibble(
        valid_date = issue_dates + lead,   # shift forward = valid date
        issue_date = issue_dates,
        lead_days  = lead,
        variable   = v,
        value      = vals,
        units      = units_lookup[[v]] %||% NA_character_,
        lat        = lat,
        lon        = lon
      )
    })
  }) |>
    # Keep only rows within the requested valid date range
    filter(valid_date >= start, valid_date <= end) |>
    arrange(variable, lead_days, valid_date)
}


#' Pull historical forecasts across a long date range in annual chunks
#'
#' @param lat Numeric. Latitude.
#' @param lon Numeric. Longitude.
#' @param start_date Character or Date.
#' @param end_date Character or Date.
#' @param lead_days Integer vector. Lead times in days.
#' @param variables Character vector. Variables to retrieve.
#' @param model Character. Forecast model. Default "gfs_seamless".
#' @param save_dir Character or NULL. Directory for annual CSV checkpoints.
#' @param sleep Numeric. Seconds between API calls.
#'
#' @return A tibble of all results combined.
#' @export
get_historical_forecast_range <- function(
    lat,
    lon,
    start_date,
    end_date,
    lead_days  = c(1, 3, 7),
    variables  = c("temperature_2m_max", "temperature_2m_min", "cloud_cover_mean"),
    model      = "gfs_seamless",
    save_dir   = NULL,
    sleep      = 1
) {
  
  start <- as.Date(start_date)
  end   <- as.Date(end_date)
  years <- seq(year(start), year(end))
  
  if (!is.null(save_dir)) {
    dir.create(save_dir, showWarnings = FALSE, recursive = TRUE)
  }
  
  map_dfr(years, function(yr) {
    
    yr_start <- max(start, as.Date(paste0(yr, "-01-01")))
    yr_end   <- min(end,   as.Date(paste0(yr, "-12-31")))
    
    message("\n=== Year: ", yr, " ===")
    
    result <- tryCatch(
      get_nws_historical_forecast(
        lat, lon, yr_start, yr_end, lead_days, variables, model
      ),
      error = function(e) {
        warning("Failed for year ", yr, ": ", e$message)
        tibble()
      }
    )
    
    if (!is.null(save_dir) && nrow(result) > 0) {
      out_path <- file.path(save_dir, paste0("nws_forecast_", yr, ".csv"))
      write_csv(result, out_path)
      message("Saved: ", out_path)
    }
    
    Sys.sleep(sleep)
    result
  })
}
