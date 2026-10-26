# scripts/hydrovu_config.R
# Shared config for the HydroVu pipeline (sourced by scripts/fetch_hydrovu.R
# and data-raw/isi_data/data_setup.R)

# HydroVu locations to pull (names as in hv_locations(con))
HV_LOCATIONS <- c("Whychus Creek RM 8.5")

# Readings live in the separate whychusData repo (input/ folder, main branch),
# expected to be cloned next to this repo; set WHYCHUS_DATA_DIR to override.
# They are stored as CSV in the rhydrovu schema (location_id, parameter_id,
# unit_id, timestamp, value); resolve names with the hydrovu_locations,
# hydrovu_parameters and hydrovu_units package datasets.
HV_DATA_DIR <- Sys.getenv("WHYCHUS_DATA_DIR",
                          file.path(dirname(here::here()), "whychusData", "input"))
HV_DATA_FILE <- file.path(HV_DATA_DIR, "hv_data.csv")

if (!dir.exists(dirname(HV_DATA_DIR))) {
  stop("whychusData repo not found at ", normalizePath(dirname(HV_DATA_DIR), mustWork = FALSE),
       "; clone it next to whychusModel or set WHYCHUS_DATA_DIR.", call. = FALSE)
}

# The device logs in local clock time, which HydroVu returns as UTC epochs
# (e.g. a 12:00 PDT reading comes back as 12:00 UTC). Timestamps are corrected
# to true UTC with hv_fix_device_time(). The device is configured on
# isi-data.com as UTC-8 with "+1 in Daylight Saving Time", i.e. Pacific time.
# If that setting changes, update this to match (e.g. "Etc/GMT+8" for a fixed
# UTC-8 clock with no DST).
HV_DEVICE_TZ <- "America/Los_Angeles"

# Parameters to keep. `csv_col` is the matching column in isi-data.com CSV
# exports (used for one-time seeding only). Battery Voltage is in the CSV
# export but not reported to HydroVu for this location, so it is left out.
hv_params <- tibble::tribble(
  ~parameter_id, ~unit_id, ~csv_col,
  "1",           "1",      "Temperature C",                     # Temperature (C)
  "2",           "17",     "Pressure PSI",                      # Pressure (psi)
  "10",          "65",     "Specific Conductivity µS/cm"   # Specific Conductivity (µS/cm)
)

# Look up the location rows (location_id, name) for HV_LOCATIONS
hv_site_locations <- function(con) {
  locs <- rhydrovu::hv_locations(con) |>
    dplyr::filter(name %in% HV_LOCATIONS) |>
    dplyr::select(location_id, name)
  missing <- setdiff(HV_LOCATIONS, locs$name)
  if (length(missing) > 0L || anyDuplicated(locs$name)) {
    stop("Could not resolve exactly one HydroVu location for: ",
         paste(union(missing, locs$name[duplicated(locs$name)]), collapse = ", "),
         call. = FALSE)
  }
  locs
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
