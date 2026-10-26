# scripts/fetch_hydrovu.R
# Appends new HydroVu readings to hv_data.csv in the whychusData repo (see
# HV_DATA_FILE in hydrovu_config.R). The file is kept in time order, so each
# refresh mostly commits as a block of lines added at the bottom; late readings
# are inserted at their place in time.
#
# Run daily by .github/workflows/hydrovu_refresh.yml. To run locally:
#   cd ../whychusData && git pull
#   Rscript scripts/fetch_hydrovu.R
#   cd ../whychusData && git add input && git commit -m "HydroVu refresh" && git push
library(rhydrovu)
library(dplyr)
library(lubridate)

source(here::here("scripts", "hydrovu_config.R"))

## CONFIG =====================================================================

# Credentials are read from HYDROVU_CLIENT_ID / HYDROVU_CLIENT_SECRET
stopifnot(nzchar(Sys.getenv("HYDROVU_CLIENT_ID")),
          nzchar(Sys.getenv("HYDROVU_CLIENT_SECRET")))

DATA_FILE <- HV_DATA_FILE

# Safety overlap when appending (prevents boundary misses)
OVERLAP_DAYS <- 2

# Lookback for locations with no existing data
FRESH_START_DAYS <- 14

START_FRESH <- FALSE

## LOAD EXISTING DATA ==========================================================

# hv_validate_readings() projects onto the rhydrovu schema columns
existing_data <- if (file.exists(DATA_FILE) && !START_FRESH) {
  message("Loading existing dataset.")
  hv_read_csv(DATA_FILE) |>
    hv_validate_readings()
} else {
  message("No existing dataset loaded.")
  NULL
}

## FETCH NEW DATA ==============================================================

con <- hv_connect()

locs <- hv_site_locations(con)

windows <- hv_compute_windows(existing_data, locs,
                              overlap_days     = OVERLAP_DAYS,
                              fresh_start_days = FRESH_START_DAYS,
                              start_fresh      = is.null(existing_data))

raw_data <- hv_readings(con,
                        location_ids = windows$location_id,
                        start        = windows$start_ts,
                        end          = windows$end_ts)

# hv_readings() returns a column-less tibble when there is nothing new
if (nrow(raw_data) == 0L) {
  message("No new records; leaving ", DATA_FILE, " unchanged.")
  quit(save = "no")
}

new_data <- raw_data |>
  filter(parameter_id %in% hv_params$parameter_id) |>
  hv_fix_device_time() |>
  hv_validate_readings()

message("Loaded ", nrow(new_data), " new records.")

## APPEND + SAVE ===============================================================

# Sorted by timestamp, then location_id, parameter_id (revised values update
# in place)
combined <- hv_append(existing_data, new_data, order = "time")

dir.create(dirname(DATA_FILE), showWarnings = FALSE)
hv_write_csv(combined, DATA_FILE)

message("Saved ", nrow(combined), " total records (",
        nrow(combined) - NROW(existing_data), " added).")
