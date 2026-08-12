#!/usr/bin/env python3
"""
Pull historical GFS air-temperature forecasts from dynamical.org for the
RM 8.5 forecast point (Whychus Creek).

dynamical.org archives raw NOAA GFS forecast output in Icechunk/Zarr format
on S3 (s3://dynamical-noaa-gfs), covering May 2021-present, initialized
every 6h with 0-384h lead. This script selects the nearest grid point to
RM 8.5, reconstructs true calendar-day max/min air temp and mean cloud
cover at the requested lead days, and writes the result to a long-format
CSV (init_date, valid_date, lead_days, variable, value) — the same shape
used elsewhere in this project (e.g. output/nws-forecasts-log.csv).

IMPORTANT — this source's max/min/cloud variables are NOT calendar-day
aggregates. Per the dataset's own variable metadata, `maximum_temperature_2m`
and `minimum_temperature_2m` are each "Maximum/Minimum over the previous
1-6 hours, reset every 6-hour forecast step (00Z, 06Z, 12Z, 18Z)", and
`total_cloud_cover_atmosphere` is likewise a 6-hour rolling average. Naively
selecting the single step landing on a target day's 00Z only captures the
last 6 hours before midnight — comparison against Open-Meteo's daily
archive showed this produces a ~-2.7 degC bias on daily max (misses the
afternoon peak) and a ~+8 degC bias on daily min (misses the pre-dawn low).
This script instead pulls all four non-overlapping 6h steps that tile a
target calendar day (steps ending at +6h, +12h, +18h, +24h past midnight)
and reduces them the same way a true calendar-day aggregate would: max of
the four maximum-temperature steps, min of the four minimum-temperature
steps, mean of the four cloud-cover steps.

This mirrors the access pattern already prototyped in
data-raw/forecast-comparison.Rmd's `dyn-fetch-forecast` chunk, but pulls a
full historical range instead of a 60-day demo window, and selects the
whole init_time/lead_time range in one xarray query instead of looping
one .sel() call per day (looping is what that chunk does to keep a demo
notebook fast over 30 days; it does not scale to a multi-year pull against
a remote Zarr store).

Setup:
    pip install icechunk xarray zarr s3fs numpy pandas
    # or, if it's available in your environment:
    pip install dynamical

Usage:
    python pull_dynamical_forecasts.py
    python pull_dynamical_forecasts.py --start-date 2021-05-01 --end-date 2025-12-31
    python pull_dynamical_forecasts.py --lead-days 1 3 7 --out data-raw/dyn_gfs_temp.csv
    python pull_dynamical_forecasts.py --append   # merge into an existing --out file
"""

import argparse
import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")

# RM 8.5 forecast point (Whychus Creek) — same coordinates used in
# data-raw/forecast-comparison.Rmd.
DEFAULT_LAT = 44.390278
DEFAULT_LON = -121.406792

DATASET_START = "2011-01-01"

GFS_FORECAST_BUCKET = "dynamical-noaa-gfs"
GFS_FORECAST_PREFIX = "noaa-gfs-forecast/v0.2.7.icechunk/"
GFS_FORECAST_REGION = "us-west-2"  # per https://stac.dynamical.org/noaa-gfs-forecast/collection.json

# Raw GFS variable name -> (this project's clean name, calendar-day
# reduction function). Matches all_historical_forecasts / NWS log naming
# conventions elsewhere in this repo. Reduction functions turn the four
# 6-hourly period values covering one calendar day into that day's true
# aggregate — see module docstring.
VARS_WANT = {
    "maximum_temperature_2m": ("temperature_2m_max", np.max),
    "minimum_temperature_2m": ("temperature_2m_min", np.min),
    "total_cloud_cover_atmosphere": ("cloud_cover_mean", np.mean),
}


def open_gfs_forecast():
    """Open the GFS forecast dataset via `dynamical` if installed, else
    fall back to anonymous S3 access through icechunk + xarray."""
    try:
        import dynamical
        print("Using dynamical package")
        return dynamical.open_dataset("noaa-gfs-forecast")
    except ImportError:
        pass

    try:
        import icechunk
        import xarray as xr
    except ImportError:
        print(
            "Neither `dynamical` nor `icechunk`+`xarray` is installed.\n"
            "Install one of:\n"
            "  pip install dynamical\n"
            "  pip install icechunk xarray",
            file=sys.stderr,
        )
        sys.exit(1)

    print("Using icechunk + xarray (anonymous S3)")
    storage = icechunk.s3_storage(
        bucket=GFS_FORECAST_BUCKET,
        prefix=GFS_FORECAST_PREFIX,
        region=GFS_FORECAST_REGION,
        anonymous=True,
    )
    repo = icechunk.Repository.open(storage=storage)
    session = repo.readonly_session("main")
    return xr.open_zarr(session.store, consolidated=False)


def kelvin_to_celsius(values):
    """No-op if already Celsius (this dataset's temperature variables are),
    converts if the source ever changes to Kelvin."""
    values = np.asarray(values, dtype=float)
    return np.where(values > 100, values - 273.15, values)


def fetch_forecasts(lat, lon, start_date, end_date, lead_days, init_hour=0):
    ds = open_gfs_forecast()
    print("Dataset opened. Variables available:", list(ds.data_vars)[:10], "...")

    # `.sel(..., method="nearest")` has no bounds checking: a request outside
    # the dataset's actual init_time range doesn't get dropped, it silently
    # snaps onto whichever boundary value is nearest — so every day requested
    # before real coverage begins would otherwise collapse onto the single
    # earliest available date, duplicating it once per out-of-range day
    # requested. Clamp to the dataset's real bounds first so out-of-range
    # dates are excluded rather than silently duplicating an edge value.
    actual_start = pd.Timestamp(ds.init_time.min().values)
    actual_end = pd.Timestamp(ds.init_time.max().values)
    req_start, req_end = pd.Timestamp(start_date), pd.Timestamp(end_date)
    clamped_start = max(req_start, actual_start)
    clamped_end = min(req_end, actual_end)
    if clamped_start > req_start or clamped_end < req_end:
        print(
            f"Note: requested range {start_date} to {end_date} extends beyond this source's "
            f"actual coverage ({actual_start.date()} to {actual_end.date()}). Clamping to "
            f"{clamped_start.date()} to {clamped_end.date()} — dynamical.org's GFS forecast "
            f"archive does not reach back to 2011; use Open-Meteo (all_historical_forecasts in "
            f"the R package) for pre-2021 coverage."
        )
    if clamped_start > clamped_end:
        print("Requested range has no overlap with actual dataset coverage — nothing to pull.")
        return pd.DataFrame(columns=["init_date", "valid_date", "lead_days", "variable", "value"])

    missing = [v for v in VARS_WANT if v not in ds.data_vars]
    if missing:
        print(f"Warning: variables not found in dataset and will be skipped: {missing}")

    keep_vars = [v for v in VARS_WANT if v in ds.data_vars]
    if not keep_vars:
        raise RuntimeError(f"None of the requested variables {list(VARS_WANT)} exist in the dataset")

    point = ds[keep_vars].sel(latitude=lat, longitude=lon, method="nearest")

    # Each requested lead day d needs the four non-overlapping 6h steps that
    # tile calendar day (init_date + d): steps ending 6h, 12h, 18h, and 24h
    # past that day's midnight. Build one flat, collision-free offset->lead
    # map (offsets never collide across different d, since d's range
    # [24d+6, 24d+24] sits entirely below (d+1)'s range starting at 24d+30).
    offset_to_lead = {}
    for d in lead_days:
        for h in (d * 24 + 6, d * 24 + 12, d * 24 + 18, (d + 1) * 24):
            offset_to_lead[h] = d
    offset_hours_sorted = sorted(offset_to_lead)
    lead_time_vals = [pd.Timedelta(hours=h) for h in offset_hours_sorted]

    print(f"Selecting lead days {lead_days} and init_time {clamped_start.date()} to "
          f"{clamped_end.date()} (init_hour={init_hour}Z) ...")

    # GFS is initialized every 6h (00/06/12/18Z), so a plain date-range slice
    # would return 4 forecast runs per calendar day. This project's
    # downstream feature pipeline (rm85-*.Rmd) expects one row per
    # date/lead/variable (like Open-Meteo's all_historical_forecasts and the
    # NWS log), so this keeps only the requested init hour — 00Z by default.
    daily_inits = pd.date_range(start=clamped_start, end=clamped_end, freq="D") + pd.Timedelta(hours=init_hour)

    # Nearest-match the requested lead offsets first (lead_time steps may
    # not land exactly on 24h boundaries), then the requested daily init
    # times — one combined query rather than one round trip per day/step.
    subset = point.sel(lead_time=lead_time_vals, method="nearest")
    subset = subset.sel(init_time=daily_inits, method="nearest")

    df = subset.to_dataframe().reset_index()
    if df.empty:
        return pd.DataFrame(columns=["init_date", "valid_date", "lead_days", "variable", "value"])

    df["offset_hours"] = (df["lead_time"] / pd.Timedelta(hours=1)).round().astype(int)
    df["lead_days_target"] = df["offset_hours"].map(offset_to_lead)

    long_rows = []
    for raw_var, (clean_var, reduce_fn) in VARS_WANT.items():
        if raw_var not in df.columns:
            continue
        sub = df[["init_time", "lead_days_target", raw_var]].dropna(subset=[raw_var])
        # Reduce the 4 six-hourly steps covering each calendar day into that
        # day's true aggregate (max/min/mean per variable — see VARS_WANT).
        grouped = (
            sub.groupby(["init_time", "lead_days_target"])[raw_var]
            .agg(reduce_fn)
            .reset_index()
        )
        values = grouped[raw_var].values
        if "temperature" in raw_var:
            values = kelvin_to_celsius(values)
        long_rows.append(
            pd.DataFrame(
                {
                    "init_date": grouped["init_time"].dt.date,
                    "valid_date": (grouped["init_time"] + pd.to_timedelta(grouped["lead_days_target"], unit="D")).dt.date,
                    "lead_days": grouped["lead_days_target"],
                    "variable": clean_var,
                    "value": np.round(values, 3),
                }
            )
        )

    result = pd.concat(long_rows, ignore_index=True) if long_rows else pd.DataFrame()
    return result.sort_values(["init_date", "lead_days", "variable"]).reset_index(drop=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--lat", type=float, default=DEFAULT_LAT, help=f"Latitude (default: RM 8.5, {DEFAULT_LAT})")
    parser.add_argument("--lon", type=float, default=DEFAULT_LON, help=f"Longitude (default: RM 8.5, {DEFAULT_LON})")
    parser.add_argument("--start-date", default=DATASET_START, help=f"Init-time range start (default: dataset start, {DATASET_START})")
    parser.add_argument("--end-date", default=pd.Timestamp.now(tz="UTC").strftime("%Y-%m-%d"), help="Init-time range end (default: today)")
    parser.add_argument("--lead-days", type=int, nargs="+", default=[1, 2, 3, 4, 5, 6, 7], help="Lead days to pull (default: 1-7)")
    parser.add_argument("--init-hour", type=int, default=0, choices=[0, 6, 12, 18], help="Which daily GFS init cycle to use (default: 0Z)")
    parser.add_argument("--out", default="data-raw/dynamical_gfs_air_temp_historical.csv", help="Output CSV path")
    parser.add_argument("--append", action="store_true", help="Merge into --out if it already exists, deduping on (init_date, lead_days, variable)")
    args = parser.parse_args()

    result = fetch_forecasts(args.lat, args.lon, args.start_date, args.end_date, args.lead_days, args.init_hour)
    print(f"Pulled {len(result)} rows.")

    out_path = Path(args.out)
    if args.append and out_path.exists():
        existing = pd.read_csv(out_path)
        combined = pd.concat([existing, result], ignore_index=True)
        combined = combined.drop_duplicates(subset=["init_date", "lead_days", "variable"], keep="last")
        combined = combined.sort_values(["init_date", "lead_days", "variable"]).reset_index(drop=True)
        combined.to_csv(out_path, index=False)
        print(f"Appended and wrote {len(combined)} total rows to {out_path}")
    else:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        result.to_csv(out_path, index=False)
        print(f"Wrote {len(result)} rows to {out_path}")


if __name__ == "__main__":
    main()
