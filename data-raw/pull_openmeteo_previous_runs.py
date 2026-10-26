#!/usr/bin/env python3
"""
Pull historical NWS-comparable air-temperature / cloud-cover forecasts from
Open-Meteo's Previous Runs API for the RM 8.5 forecast point (Whychus Creek).

WHY THIS SOURCE
---------------
This is a *different* endpoint from the `all_historical_forecasts` dataset in
the `whychusModel` R package. That one returns the same value for a given
calendar date regardless of which lead is requested (a stitched best-estimate
series, confirmed empirically elsewhere in this project) — so a model trained
on it never sees real forecast uncertainty grow with lead.

The Previous Runs API (`previous-runs-api.open-meteo.com`) instead exposes
what a past model run actually predicted: `temperature_2m_previous_dayN` at
valid date D is the forecast for D that was issued N days earlier. That maps
directly onto (valid_date = D, lead_days = N), and it genuinely varies by
lead — measured over summer 2024, only ~2% of days had identical lead-1 and
lead-7 values, and error grows the way real forecast skill decays
(MAE 0.91 degC at lead 1 -> 2.64 degC at lead 7).

Measured against the NWS forecasts this project actually serves in
production (`output/nws-forecasts-log.csv`, 2026), this source also tracks
NWS more closely than dynamical.org's raw GFS at every lead:

    max air temp   bias    MAE     r
    Open-Meteo    +0.03   1.58   0.949
    dynamical.org -0.47   2.03   0.913

Output schema deliberately matches
`data-raw/dynamical_gfs_air_temp_historical.csv` so the two are drop-in
comparable:  init_date, valid_date, lead_days, variable, value
with variable in {temperature_2m_max, temperature_2m_min, cloud_cover_mean}.

Daily aggregates are computed from local-time (America/Los_Angeles) hourly
values — max/min of temperature and mean of cloud cover — rather than taken
from the API's own daily block, so that a "day" here means the same calendar
day the RM 8.5 logger and Camp Polk gage report on.

Coverage notes (both measured against the live API, not assumed):
  * The archive begins ~2021 — 2019 and earlier return all nulls. That is the
    same practical start as dynamical.org. Open-Meteo's `all_historical_
    forecasts` remains the only source in this project reaching back to 2011.
  * `cloud_cover_previous_dayN` only exists from **2024-04-15** onward;
    temperature reaches back to 2021. So a model that requires cloud from
    this source is limited to ~2.5 seasons, while a temperature-only model
    gets the full ~5. Cloud is also the worst-matched variable against NWS in
    every source tested (+13 to +15 pp bias, r 0.76-0.80), and dropping it
    measured as roughly performance-neutral, so the temperature-only route is
    usually the better trade.

Setup:
    pip install requests

Usage:
    python pull_openmeteo_previous_runs.py
    python pull_openmeteo_previous_runs.py --start-year 2021 --end-year 2026
    python pull_openmeteo_previous_runs.py --all-year   # not just May-Oct
"""

import argparse
import csv
import sys
import time
from datetime import date

try:
    import requests
except ImportError:
    print("This script needs `requests`:  pip install requests", file=sys.stderr)
    sys.exit(1)

API = "https://previous-runs-api.open-meteo.com/v1/forecast"

# RM 8.5 forecast point (Whychus Creek) — same coordinates used elsewhere.
DEFAULT_LAT = 44.390278
DEFAULT_LON = -121.406792
TZ = "America/Los_Angeles"

LEADS = [1, 2, 3, 4, 5, 6, 7]

# The model's season window is May-Oct on the TARGET date. A lead-7 target on
# May 1 needs trajectory days back to Apr 25, so pull with a margin either side.
SEASON_START = (4, 15)
SEASON_END = (11, 5)


def build_hourly_vars():
    v = ["temperature_2m", "cloud_cover"]
    for n in LEADS:
        v.append(f"temperature_2m_previous_day{n}")
        v.append(f"cloud_cover_previous_day{n}")
    return v


def fetch_chunk(lat, lon, start, end, retries=4):
    params = {
        "latitude": lat, "longitude": lon,
        "start_date": start.isoformat(), "end_date": end.isoformat(),
        "hourly": ",".join(build_hourly_vars()),
        "timezone": TZ,
    }
    for attempt in range(retries):
        try:
            r = requests.get(API, params=params, timeout=180)
            if r.status_code == 200:
                return r.json()["hourly"]
            # Open-Meteo signals throttling / transient issues with 429 / 5xx
            if r.status_code in (429, 500, 502, 503, 504):
                wait = 5 * (attempt + 1)
                print(f"  HTTP {r.status_code}, retrying in {wait}s ...")
                time.sleep(wait)
                continue
            raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")
        except requests.RequestException as e:
            wait = 5 * (attempt + 1)
            print(f"  request error ({e}), retrying in {wait}s ...")
            time.sleep(wait)
    raise RuntimeError(f"failed to fetch {start}..{end} after {retries} attempts")


def daily_rows(hourly):
    """Collapse hourly local-time values into one row per (valid_date, lead)."""
    buckets = {}
    times = hourly["time"]
    for i, t in enumerate(times):
        day = t[:10]
        b = buckets.setdefault(day, {})
        for key, series in hourly.items():
            if key == "time":
                continue
            val = series[i]
            if val is not None:
                b.setdefault(key, []).append(val)

    out = []
    for day in sorted(buckets):
        b = buckets[day]
        for n in LEADS:
            tk, ck = f"temperature_2m_previous_day{n}", f"cloud_cover_previous_day{n}"
            # A day is only usable if the temperature series is present; skip
            # partial edges rather than emitting a max/min over a few hours.
            if len(b.get(tk, [])) < 20:
                continue
            valid = date.fromisoformat(day)
            init = date.fromordinal(valid.toordinal() - n)
            out.append((init, valid, n, "temperature_2m_max", round(max(b[tk]), 3)))
            out.append((init, valid, n, "temperature_2m_min", round(min(b[tk]), 3)))
            if b.get(ck):
                out.append((init, valid, n, "cloud_cover_mean",
                            round(sum(b[ck]) / len(b[ck]), 3)))
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--lat", type=float, default=DEFAULT_LAT)
    p.add_argument("--lon", type=float, default=DEFAULT_LON)
    p.add_argument("--start-year", type=int, default=2021)
    p.add_argument("--end-year", type=int, default=date.today().year)
    p.add_argument("--all-year", action="store_true",
                   help="pull Jan-Dec instead of the Apr-Nov season window")
    p.add_argument("--out", default="data-raw/openmeteo_previous_runs_historical.csv")
    args = p.parse_args()

    today = date.today()
    all_rows = []
    for yr in range(args.start_year, args.end_year + 1):
        if args.all_year:
            start, end = date(yr, 1, 1), date(yr, 12, 31)
        else:
            start = date(yr, *SEASON_START)
            end = date(yr, *SEASON_END)
        if end > today:
            end = today
        if start > end:
            print(f"{yr}: skipped (start {start} is in the future)")
            continue
        print(f"{yr}: fetching {start} .. {end}")
        hourly = fetch_chunk(args.lat, args.lon, start, end)
        rows = daily_rows(hourly)
        print(f"  -> {len(rows)} rows")
        all_rows.extend(rows)
        time.sleep(1)  # be polite between chunks

    if not all_rows:
        print("No rows pulled.", file=sys.stderr)
        sys.exit(1)

    all_rows.sort(key=lambda r: (r[0], r[2], r[3]))
    with open(args.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["init_date", "valid_date", "lead_days", "variable", "value"])
        for init, valid, lead, var, val in all_rows:
            w.writerow([init.isoformat(), valid.isoformat(), lead, var, val])

    dates = [r[1] for r in all_rows]
    print(f"\nWrote {len(all_rows)} rows to {args.out}")
    print(f"valid_date range: {min(dates)} .. {max(dates)}")


if __name__ == "__main__":
    main()
