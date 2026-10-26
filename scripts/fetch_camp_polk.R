# scripts/fetch_camp_polk.R
# Updates camp_polk.csv in the whychusData repo's input/ folder (see
# DATA_INPUT_DIR in common.R) with Camp Polk daily flow, water temperature
# (daily max) and 7DADM from OWRD station 14076100.
#
# Keyed by `date`: each run re-pulls the last `pull_days` days and replaces
# those dates, so provisional readings are corrected as OWRD revises them.
# If Camp Polk is unavailable, flow and temperature fall back to backup gages
# via regression; `flow_source` / `temp_source` record which was used.
#
# Run daily by .github/workflows/daily-forecast.yml. To run locally:
#   Rscript scripts/fetch_camp_polk.R
library(tidyverse)
library(lubridate)
library(zoo)
library(here)
library(whychusModel)

source(here("scripts", "common.R"))

# ── Config ────────────────────────────────────────────────────────────────────
owrd_station             <- "14076100"  # Camp Polk
owrd_flow_backup_station <- "14076050"  # Whychus Cr at Sisters (WAS) — flow backup
owrd_temp_backup_station <- "14075000"  # Whychus Cr nr Sisters — temperature backup

camp_polk_file <- file.path(DATA_INPUT_DIR, "camp_polk.csv")

# Days of history to pull. The forecast reads values back to run date - 5 and a
# 7DADM needs 7 days of daily maxima behind it, so 12 is the minimum; 14 leaves
# a margin for gaps.
pull_days <- 14

# Backup relationships used only when Camp Polk is unavailable. Each is flagged
# in the output (flow_source / temp_source) so a run that used one is traceable.
#
# Flow: lm(cp_flow ~ was_flow) from the WAS gage (14076050),
# R² = 0.9908, n = 248.
CP_FROM_WAS_INTERCEPT <- 3.293170
CP_FROM_WAS_SLOPE     <- 1.026917

# Temperature: lm(camp_polk_daily_max ~ gage_14075000_daily_max), fit on the
# package's historical records over May-October (the model season) —
# n = 1,268 days, 2016-2026, R² = 0.9119, RMSE = 1.08 °C. Using the upstream
# gage's reading directly instead would run ~2.8 °C too cold, so the
# regression is not optional. Refit these if the historical records are
# extended substantially.
CP_FROM_14075000_INTERCEPT <- 1.658134
CP_FROM_14075000_SLOPE     <- 1.106763

cat(sprintf("Fetching Camp Polk data for %s\n", today))

#' Pull Camp Polk daily flow/temp/7DADM, falling back to backup gages if
#' Camp Polk is unavailable: flow uses gage 14076050 (WAS) via the flow
#' regression; temperature uses gage 14075000 via the temp regression.
get_camp_polk_daily <- function(pull_start, pull_end) {

  cp_flow_raw <- tryCatch(
    get_owrd_hydro(owrd_station, pull_start, pull_end, "Instantaneous_Flow"),
    error = function(e) { message("Camp Polk flow pull failed: ", conditionMessage(e)); NULL }
  )
  cp_tmax_raw <- tryCatch(
    get_owrd_hydro(owrd_station, pull_start, pull_end, "WTEMP15"),
    error = function(e) { message("Camp Polk temp pull failed: ", conditionMessage(e)); NULL }
  )

  flow_source <- "camp_polk"
  temp_source <- "camp_polk"

  if (is.null(cp_flow_raw) || nrow(cp_flow_raw) == 0) {
    message("Camp Polk flow unavailable — falling back to WAS gage 14076050 (regression)")
    was_flow_raw <- tryCatch(
      get_owrd_hydro(owrd_flow_backup_station, pull_start, pull_end, "Instantaneous_Flow"),
      error = function(e) { message("WAS gage flow pull failed: ", conditionMessage(e)); NULL }
    )
    if (is.null(was_flow_raw) || nrow(was_flow_raw) == 0) {
      abort_missing("Camp Polk and WAS backup flow both unavailable.")
    }
    cp_flow_raw <- was_flow_raw |>
      mutate(instananteous_flow_cfs = CP_FROM_WAS_INTERCEPT + CP_FROM_WAS_SLOPE * instananteous_flow_cfs)
    flow_source <- "was_regression"
  }

  if (is.null(cp_tmax_raw) || nrow(cp_tmax_raw) == 0) {
    message("Camp Polk temp unavailable — falling back to gage 14075000 (regression)")
    backup_temp_raw <- tryCatch(
      get_owrd_hydro(owrd_temp_backup_station, pull_start, pull_end, "WTEMP15"),
      error = function(e) { message("Gage 14075000 temp pull failed: ", conditionMessage(e)); NULL }
    )
    if (is.null(backup_temp_raw) || nrow(backup_temp_raw) == 0) {
      abort_missing("Camp Polk and gage 14075000 temperature both unavailable.")
    }
    cp_tmax_raw <- backup_temp_raw |>
      mutate(instantaneous_water_temp_c = CP_FROM_14075000_INTERCEPT + CP_FROM_14075000_SLOPE * instantaneous_water_temp_c)
    temp_source <- "gage14075000_regression"
  }

  cp_flow <- cp_flow_raw |>
    mutate(date = as.Date(parse_date_time(record_date, orders = c("mdy", "mdy HM")))) |>
    group_by(date) |>
    summarise(cp_flow_mean = mean(instananteous_flow_cfs, na.rm = TRUE)) |>
    arrange(date)

  cp_tmax <- cp_tmax_raw |>
    mutate(date = as.Date(parse_date_time(record_date, orders = c("mdy", "mdy HM")))) |>
    group_by(date) |>
    summarise(cp_tmax = max(instantaneous_water_temp_c, na.rm = TRUE)) |>
    arrange(date)

  cp_7dadm <- cp_tmax |>
    mutate(cp_7dadm = rollmean(cp_tmax, k = 7, fill = NA, align = "right"))

  list(cp_flow = cp_flow, cp_tmax = cp_tmax, cp_7dadm = cp_7dadm,
       flow_source = flow_source, temp_source = temp_source)
}

cp <- get_camp_polk_daily(today - pull_days, today)

# Keep only days with a complete 7DADM. The first six days of the window have
# none (not enough history yet), and writing them as NA would overwrite good
# values saved by earlier runs when the upsert below replaces matching dates.
camp_polk_daily <- cp$cp_flow |>
  full_join(cp$cp_tmax, by = "date") |>
  left_join(select(cp$cp_7dadm, date, cp_7dadm), by = "date") |>
  filter(!is.na(cp_7dadm)) |>
  mutate(flow_source = cp$flow_source,
         temp_source = cp$temp_source,
         pulled_on   = today) |>
  arrange(date)

print(camp_polk_daily, n = Inf)

if (!today %in% camp_polk_daily$date) {
  message("WARNING: no Camp Polk row for today (", today,
          ") — the forecast will lack current-day Camp Polk inputs.")
}

upsert_by_date(camp_polk_daily, camp_polk_file)
