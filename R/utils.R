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