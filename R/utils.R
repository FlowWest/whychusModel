#' Convert a date to Julian day of year
#'
#' Returns the day of year (1–366) for a given date.
#'
#' @param date A \code{Date}, \code{POSIXct}, or character vector coercible
#'   to \code{Date} via \code{as.Date()}.
#'
#' @return An integer vector of day-of-year values between 1 and 366.
#'
#' @examples
#' to_julian("2023-07-15")   # returns 196
#' to_julian(Sys.Date())
#'
#' # use in a dplyr pipeline
#' df |> mutate(julian_day = to_julian(date))
#'
#' @export
to_julian <- function(date) {
  as.integer(format(as.Date(date), "%j"))
}
#' Convert water pressure to depth
#'
#' Converts hydrostatic pressure to water depth, optionally
#' correcting water density for temperature. Defaults match the units stored
#' in the HydroVu readings (pressure in psi, temperature in degrees C).
#'
#' @param pressure Numeric vector of pressure readings.
#' @param temp Optional numeric vector of water temperatures, parallel to
#'   \code{pressure} (same length, element-wise paired). Used to compute water
#'   density when \code{density} is not given.
#' @param pressure_units Units of \code{pressure}: one of \code{"psi"}
#'   (default), \code{"kpa"}, \code{"pa"}, \code{"mbar"}, or \code{"cmh2o"}.
#' @param temp_units Units of \code{temp}: one of \code{"c"} (default),
#'   \code{"f"}, or \code{"k"}.
#' @param density Optional water density in kg/m^3 (scalar or vector). Overrides
#'   \code{temp}. If neither is given, 999.972 kg/m^3 (pure water at 4 C) is used.
#' @param g Gravitational acceleration in m/s^2.
#' @param depth_units Units of the returned depth: \code{"m"} (default) or
#'   \code{"ft"}.
#'
#' @return A numeric vector of depths in \code{depth_units}, the same length as
#'   \code{pressure}.
#'
#' @details Temperature-dependent density uses the Kell (1975) equation for
#'   pure water, valid from 0 to 40 C.
#'
#' @examples
#' pressure_to_depth(1.5, 12)   # 1.5 psi at 12 C, depth in m
#'
#' # use in a dplyr pipeline
#' tibble::tibble(pressure_psi = c(1.2, 1.5, 1.8), temp_c = c(8, 12, 16)) |>
#'   dplyr::mutate(
#'     depth_ft = pressure_to_depth(pressure_psi, temp_c, depth_units = "ft")
#'   )
#'
#' @export
pressure_to_depth <- function(pressure,
                              temp = NULL,
                              pressure_units = c("psi", "kpa", "pa", "mbar", "cmh2o"),
                              temp_units = c("c", "f", "k"),
                              density = NULL,
                              g = 9.80665,
                              depth_units = c("m", "ft")) {
  pressure_units <- match.arg(pressure_units)
  temp_units <- match.arg(temp_units)
  depth_units <- match.arg(depth_units)
  if (!is.null(temp) && length(temp) != length(pressure)) {
    stop("`temp` must be the same length as `pressure`.", call. = FALSE)
  }
  pa <- pressure * switch(pressure_units,
    psi   = 6894.757,
    kpa   = 1e3,
    pa    = 1,
    mbar  = 100,
    cmh2o = 98.0665
  )
  rho <- if (!is.null(density)) {
    density
  } else if (!is.null(temp)) {
    t <- switch(temp_units,
      c = temp,
      f = (temp - 32) * 5 / 9,
      k = temp - 273.15
    )
    # Kell (1975) temperature-dependent formula
    (999.83952 + 16.945176 * t - 7.9870401e-3 * t^2 -
       46.170461e-6 * t^3 + 105.56302e-9 * t^4 -
       280.54253e-12 * t^5) / (1 + 16.879850e-3 * t)
  } else {
    999.972
  }
  pa / (rho * g) / switch(depth_units,
    m  = 1,
    ft = 0.3048
  )
}
