# scripts/hydrovu_config.R
# Shared config for the HydroVu pipeline (sourced by scripts/fetch_hydrovu.R
# and data-raw/isi_data/data_setup.R)

HV_LOCATION_NAME <- "Whychus Creek RM 8.5"

HV_DATA_FILE <- here::here("data-live", "hydrovu_readings.rds")

# The device logs in local clock time, which HydroVu returns as UTC epochs
# (e.g. a 12:00 PDT reading comes back as 12:00 UTC). Timestamps are corrected
# to true UTC with hv_fix_device_time(). The device is configured on
# isi-data.com as UTC-8 with "+1 in Daylight Saving Time", i.e. Pacific time.
# If that setting changes, update this to match (e.g. "Etc/GMT+8" for a fixed
# UTC-8 clock with no DST).
HV_DEVICE_TZ <- "America/Los_Angeles"

# Parameters to keep, with IDs from hv_parameters(con) and the
# /sispec/friendlynames unit list. `csv_col` is the matching column in
# isi-data.com CSV exports (used for one-time seeding only). Battery Voltage is
# not currently reported to HydroVu for this location, so it only comes from
# the CSV seed until it is.
hv_params <- tibble::tribble(
  ~parameter_id, ~parameter_name,          ~unit_id, ~csv_col,
  "1",           "Temperature",            "1",      "Temperature C",
  "2",           "Pressure",               "17",     "Pressure PSI",
  "10",          "Specific Conductivity",  "65",     "Specific Conductivity µS/cm",
  "26",          "Battery Voltage",        "163",    "TL Battery V"
)

# Look up the location row (location_id, name) for HV_LOCATION_NAME
hv_site_location <- function(con) {
  loc <- rhydrovu::hv_locations(con) |>
    dplyr::filter(name == HV_LOCATION_NAME) |>
    dplyr::select(location_id, name)
  if (nrow(loc) != 1L) {
    stop("Expected exactly one HydroVu location named '", HV_LOCATION_NAME,
         "', found ", nrow(loc), ".", call. = FALSE)
  }
  loc
}

# Reinterpret HydroVu timestamps as HV_DEVICE_TZ wall-clock time, return in UTC.
# Clock times skipped by the spring DST shift roll forward and the repeated
# fall-back hour resolves to its first (PDT) occurrence, so the result is never NA.
hv_fix_device_time <- function(readings) {
  out <- dplyr::mutate(readings, timestamp = lubridate::with_tz(
    lubridate::force_tz(timestamp, HV_DEVICE_TZ, roll_dst = c("post", "pre")), "UTC"
  ))
  latest <- suppressWarnings(max(out$timestamp))
  if (is.finite(latest) && latest > Sys.time() + 30 * 60) {
    stop("Corrected timestamps run into the future (latest ",
         format(latest, tz = HV_DEVICE_TZ, usetz = TRUE),
         "); HV_DEVICE_TZ is likely wrong for this device clock.", call. = FALSE)
  }
  out
}
