# data-raw/isi_data/data_setup.R
# One-time setup: seed data-live/whychus_rm8p5.Rds from an isi-data.com CSV
# export, then backfill from HydroVu so the scheduled refresh
# (scripts/fetch_hydrovu.R) picks up where this leaves off. Run on the `data`
# branch and commit the resulting .rds there.

library(rhydrovu)
library(dplyr)
library(tidyr)
library(lubridate)

source(here::here("scripts", "hydrovu_config.R"))

## CONFIG =====================================================================

CSV_FILE <- here::here("data-raw", "isi_data", "isi_data_export_20261021T120000.csv")

OVERWRITE <- FALSE

if (file.exists(HV_DATA_FILE) && !OVERWRITE) {
  stop(HV_DATA_FILE, " already exists; set OVERWRITE <- TRUE to rebuild it.")
}

## READ CSV ====================================================================

# Line 1 is the device label ("201-03261:"); line 2 holds the column headers.
# Status pings with no readings come through as blank rows. "Received"
# timestamps are local time.
csv <- read.csv(CSV_FILE, skip = 1, check.names = FALSE, fileEncoding = "UTF-8",
                na.strings = c("", " "), strip.white = TRUE)

stopifnot(all(hv_params$csv_col %in% names(csv)))

con <- hv_connect()
loc <- hv_site_location(con)

seed <- csv |>
  mutate(timestamp = with_tz(as.POSIXct(Received, format = "%d-%b-%y %I:%M %p",
                                        tz = HV_DEVICE_TZ), "UTC")) |>
  select(timestamp, all_of(hv_params$csv_col)) |>
  pivot_longer(-timestamp, names_to = "csv_col", values_to = "value") |>
  filter(!is.na(timestamp), !is.na(value)) |>
  inner_join(hv_params, by = join_by(csv_col)) |>
  mutate(location_id = loc$location_id, name = loc$name) |>
  select(location_id, name, parameter_id, parameter_name, unit_id, timestamp, value)

## BACKFILL FROM HYDROVU =======================================================

# Readings over the CSV period through now (padded a day for the device-time
# offset). These take precedence over CSV values wherever both exist.
hv_data <- hv_readings(con,
                       location_ids = loc$location_id,
                       start        = min(seed$timestamp) - days(1),
                       end          = now(tzone = "UTC") + days(1)) |>
  filter(parameter_id %in% hv_params$parameter_id) |>
  hv_fix_device_time() |>
  inner_join(loc, by = join_by(location_id)) |>
  relocate(name, .after = location_id)

message("Seed: ", nrow(seed), " records from CSV; HydroVu: ", nrow(hv_data), " records.")

## SAVE ========================================================================

combined <- hv_append(seed, hv_data) |>
  arrange(parameter_id, timestamp)

dir.create(dirname(HV_DATA_FILE), showWarnings = FALSE)
saveRDS(combined, HV_DATA_FILE)

message("Saved ", nrow(combined), " total records to ", HV_DATA_FILE)
