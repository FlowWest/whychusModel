#' Fit or apply a linear model predicting RM 6 7DADM from RM 8.5 7DADM
#'
#' Trains a simple linear regression of seven-day average daily maximum
#' temperature (7DADM) at RM 6 on observed 7DADM at RM 8.5 using the
#' package's built-in historical data. If \code{newdata} is supplied, the
#' function returns a tibble of RM 6 predictions; otherwise it returns the
#' fitted \code{lm} object for further inspection or prediction elsewhere.
#'
#' @param newdata A data frame or tibble with a column named \code{rm85_7dadm}
#'   (numeric, degrees C). A \code{date} column, if present, is carried
#'   through to the output unchanged. If \code{NULL} (default), the fitted
#'   \code{lm} object is returned instead of predictions.
#' @param months Integer vector of calendar months to include in model
#'   training. Defaults to May–September (\code{5:9}).
#'
#' @return
#' If \code{newdata} is \code{NULL}: a fitted \code{\link[stats]{lm}} object
#' with formula \code{rm6_7dadm ~ rm85_7dadm}, trained on historical data
#' from the specified months.
#'
#' If \code{newdata} is supplied: a tibble containing all columns from
#' \code{newdata} plus \code{rm6_7dadm_pred} (predicted RM 6 7DADM in
#' degrees C).
#'
#' @examples
#' # Inspect the fitted model
#' m <- lm_rm6_7dadm()
#' summary(m)
#'
#' # Predict from new RM 8.5 values
#' library(tibble)
#' new <- tibble(date = Sys.Date() + 0:6, rm85_7dadm = c(15, 16, 17, 18, 19, 20, 21))
#' lm_rm6_7dadm(newdata = new)
#'
#' @importFrom tibble as_tibble
#' @export
lm_rm6_7dadm <- function(newdata = NULL, months = 5:9) {
  rm6 <- rm_6_historical |>
    dplyr::mutate(date = as.Date(date), cal_month = as.integer(format(date, "%m"))) |>
    dplyr::filter(statistic == "7DADM", cal_month %in% months) |>
    dplyr::select(date, rm6_7dadm = temperature)

  rm85 <- rm_8_5_historical |>
    dplyr::mutate(date = as.Date(date), cal_month = as.integer(format(date, "%m"))) |>
    dplyr::filter(statistic == "7DADM", cal_month %in% months) |>
    dplyr::select(date, rm85_7dadm = temperature)

  train <- dplyr::inner_join(rm6, rm85, by = "date") |>
    dplyr::filter(!is.na(rm6_7dadm), !is.na(rm85_7dadm))

  model <- lm(rm6_7dadm ~ rm85_7dadm, data = train)

  if (is.null(newdata)) {
    return(model)
  }

  if (!is.data.frame(newdata) || !"rm85_7dadm" %in% names(newdata)) {
    stop("`newdata` must be a data frame with a column named `rm85_7dadm`.")
  }

  result <- newdata
  result$rm6_7dadm_pred <- unname(predict(model, newdata = newdata))
  as_tibble(result)
}

#' Predict RM 6 7DADM from an RM 8.5 temperature value
#'
#' Convenience wrapper around \code{\link{lm_rm6_7dadm}} that accepts a plain
#' numeric temperature (or vector of temperatures) at RM 8.5 and returns the
#' predicted 7DADM at RM 6.
#'
#' @param temp_8_5 Numeric vector. Observed or forecast 7DADM temperature at
#'   RM 8.5 in degrees C.
#' @param months Integer vector of calendar months used to train the underlying
#'   linear model. Defaults to May–September (\code{5:9}).
#'
#' @return A numeric vector of predicted RM 6 7DADM temperatures (°C), the
#'   same length as \code{temp_8_5}.
#'
#' @examples
#' rm_6_predict(6)          # single value
#' rm_6_predict(c(15, 18, 20, 22))  # vector
#'
#' @export
rm_6_predict <- function(temp_8_5, months = 5:9) {
  model <- lm_rm6_7dadm(months = months)
  unname(predict(model, newdata = data.frame(rm85_7dadm = temp_8_5)))
}
