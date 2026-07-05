#!/usr/bin/env python3
"""
RideLoop deterministic data generator (DataDojo universe: rideloop).

Emits one RFC4180 CSV per table into an output directory, driven purely by a
seed and a scale. Same (seed, scale) => byte-identical output.

    python3 generator.py --seed N --scale {sample|blue|purple|black|red} --out DIR

Design rules honoured:
  * Pure stdlib only (random, csv, datetime, math, argparse).
  * A single random.Random(seed) instance; never the global random module,
    never datetime.now(). Control flow is deterministic given the seed.
  * Dimension tables are held in memory (small); fact tables (trips,
    trip_ratings, trip_promotions, surge_events) are streamed row-by-row to
    disk so red scale never materialises millions of rows in a list.
  * Realistic, correlated distributions plus deliberately planted landmines
    (see universe.md "Landmine inventory"). Landmine intensity scales up with
    the belt: 'blue' data is kept clean, harsher traps switch on for
    purple/black/red.

Table column orders match schema.sql exactly.
"""

import argparse
import csv
import datetime as dt
import math
import os
import random
from bisect import bisect_right

# ---------------------------------------------------------------------------
# Scale configuration
#   trips is the largest fact table; everything else is proportional.
#   date windows are chosen to straddle month ends, a leap day (2024-02-29)
#   and a year boundary so boundary-date landmines are reachable.
# ---------------------------------------------------------------------------
SCALES = {
    # sample: a few hundred rows total; window includes 2024-02-29.
    "sample": dict(trips=220,     riders=60,     drivers=30,    zones=8,
                   promos=6,  start="2024-02-01", days=40,  surge_per_zone_day=0.6),
    "blue":   dict(trips=40_000,  riders=6_000,  drivers=1_200, zones=16,
                   promos=12, start="2023-09-01", days=150, surge_per_zone_day=1.0),
    "purple": dict(trips=400_000, riders=40_000, drivers=6_000, zones=30,
                   promos=20, start="2023-06-01", days=270, surge_per_zone_day=1.4),
    "black":  dict(trips=3_000_000, riders=250_000, drivers=30_000, zones=48,
                   promos=30, start="2023-01-01", days=440, surge_per_zone_day=1.8),
    "red":    dict(trips=7_000_000, riders=500_000, drivers=60_000, zones=60,
                   promos=40, start="2022-11-01", days=520, surge_per_zone_day=2.0),
}

# Belts at/above this index get the full landmine treatment.
HARSH_SCALES = {"purple", "black", "red"}

TABLES = {
    "geozones": ["zone_id", "zone_code", "zone_name", "city", "is_airport",
                 "area_km2", "base_fare"],
    "riders": ["rider_id", "signup_date", "home_zone_id", "rider_tier",
               "referral_source"],
    "drivers": ["driver_id", "onboard_date", "home_zone_id", "status", "rating"],
    "vehicles": ["vehicle_id", "driver_id", "vehicle_class", "make", "model",
                 "model_year", "seats", "active_from", "active_to"],
    "trips": ["trip_id", "rider_id", "driver_id", "vehicle_id", "request_ts",
              "pickup_ts", "dropoff_ts", "pickup_zone_id", "dropoff_zone_id",
              "distance_km", "duration_s", "fare_amount", "surge_multiplier",
              "status", "payment_type"],
    "surge_events": ["surge_id", "zone_id", "effective_ts", "multiplier",
                     "reason"],
    "trip_ratings": ["rating_id", "trip_id", "rider_stars", "driver_stars",
                     "tip_amount", "rated_ts"],
    "promotions": ["promo_id", "promo_code", "promo_type", "discount_value",
                   "valid_from", "valid_to"],
    "trip_promotions": ["application_id", "trip_id", "promo_id",
                        "discount_amount", "applied_ts"],
}

CITIES = [
    "Northgate", "Rivermouth", "Fair Harbor", "Ashfield", "Blue Mesa",
    "Port Alder", "Westrun", "Calder City", "Verdant Falls", "Old Quay",
    "Sable Ridge", "Kingsford",
]
ZONE_ADJ = ["Central", "North", "South", "East", "West", "Upper", "Lower",
            "Old", "New", "Harbor", "Airport", "University", "Market",
            "Riverside", "Industrial", "Midtown"]
VEHICLE_CLASSES = ["economy", "economy", "economy", "xl", "lux"]  # weighted toward economy
MAKES = {
    "economy": [("Toyota", "Corolla"), ("Honda", "Civic"), ("Hyundai", "Elantra"),
                ("Kia", "Rio"), ("Nissan", "Sentra")],
    "xl": [("Toyota", "Sienna"), ("Honda", "Odyssey"), ("Kia", "Carnival"),
           ("Chrysler", "Voyager")],
    "lux": [("BMW", "5 Series"), ("Mercedes", "E-Class"), ("Audi", "A6"),
            ("Tesla", "Model S")],
}
PAYMENT_TYPES = ["card", "card", "card", "wallet", "cash"]
REFERRALS = ["organic", "organic", "promo", "referral", "app_store", "social"]
SURGE_REASONS = ["demand", "demand", "weather", "event", "manual"]
PROMO_TYPES = ["percent", "percent", "flat", "first_ride"]


# ---------------------------------------------------------------------------
# Small deterministic helpers
# ---------------------------------------------------------------------------
def money(x):
    """Format a currency/decimal value with 2 dp, deterministically."""
    return f"{x:.2f}"


def ts(dtobj):
    return dtobj.strftime("%Y-%m-%d %H:%M:%S")


def dstr(dobj):
    return dobj.strftime("%Y-%m-%d")


def weighted_pick(rng, cum, items):
    """Pick an item given a cumulative-weight list (last entry = total)."""
    r = rng.random() * cum[-1]
    return items[bisect_right(cum, r)]


def build_cum(weights):
    cum = []
    running = 0.0
    for w in weights:
        running += w
        cum.append(running)
    return cum


def power_index(rng, n, exp):
    """Power-law-ish index in [0, n). Larger exp => more mass on low indices."""
    idx = int(n * (rng.random() ** exp))
    if idx >= n:
        idx = n - 1
    return idx


# ---------------------------------------------------------------------------
# Dimension builders (held in memory)
# ---------------------------------------------------------------------------
def build_geozones(rng, cfg):
    n = cfg["zones"]
    rows = []
    zone_meta = []  # parallel: (city_idx, is_airport, base_fare, demand_weight)
    n_cities = max(2, min(len(CITIES), n // 3))
    for zid in range(1, n + 1):
        city_idx = (zid - 1) % n_cities
        city = CITIES[city_idx]
        adj = ZONE_ADJ[(zid * 7) % len(ZONE_ADJ)]
        is_airport = 1 if adj == "Airport" and rng.random() < 0.7 else (
            1 if rng.random() < 0.06 else 0)
        area = round(rng.uniform(3.0, 55.0), 2)
        base_fare = round(rng.uniform(2.20, 4.80), 2)
        # zone_code: zero-padded external code (type-coercion trap)
        zone_code = f"{(zid * 13) % 1000:03d}"
        rows.append([zid, zone_code, f"{city} {adj}", city, is_airport,
                     money(area), money(base_fare)])
        # demand weight: airports and low-id "downtown" zones busier (power-law)
        demand = (1.0 / (1 + 0.15 * ((zid - 1) % n_cities))) * (2.2 if is_airport else 1.0)
        zone_meta.append((city_idx, is_airport, base_fare, demand))
    return rows, zone_meta, n_cities


def build_riders(rng, cfg, n_zones, start_date):
    n = cfg["riders"]
    rows = []
    home_zone = [0] * n
    signup_ord = [0] * n
    # riders sorted implicitly by activity: low index => power-user (see power_index)
    for rid in range(1, n + 1):
        # signup strictly before the trip window keeps days-to-first-trip >= 0
        days_before = rng.randint(1, 500)
        sd = start_date - dt.timedelta(days=days_before)
        # ~4% of riders have no recorded home zone (nullable FK)
        hz = "" if rng.random() < 0.04 else rng.randint(1, n_zones)
        tier = rng.choice(["basic", "basic", "plus"])
        if rng.random() < 0.03:
            tier = ""  # legacy account, tier unknown
        ref = "" if rng.random() < 0.05 else rng.choice(REFERRALS)
        rows.append([rid, dstr(sd), hz, tier, ref])
        home_zone[rid - 1] = hz
        signup_ord[rid - 1] = sd.toordinal()
    return rows, home_zone, signup_ord


def build_drivers_and_vehicles(rng, cfg, n_zones, start_date):
    nd = cfg["drivers"]
    driver_rows = []
    vehicle_rows = []
    driver_vehicles = [None] * nd     # driver index -> list of (vehicle_id, class)
    driver_active = [True] * nd
    vid = 0
    for did in range(1, nd + 1):
        days_before = rng.randint(5, 600)
        od = start_date - dt.timedelta(days=days_before)
        roll = rng.random()
        if roll < 0.08:
            status = "suspended"
        elif roll < 0.20:
            status = "churned"
        else:
            status = "active"
        driver_active[did - 1] = (status == "active")
        # ~5% of drivers have no rating yet (nullable)
        rating = "" if rng.random() < 0.05 else money(
            min(5.0, max(3.10, rng.gauss(4.75, 0.25))))
        driver_rows.append([did, dstr(od), rng.randint(1, n_zones), status, rating])
        # 1 vehicle usually; ~18% of drivers have registered a 2nd over time
        n_veh = 2 if rng.random() < 0.18 else 1
        vlist = []
        for k in range(n_veh):
            vid += 1
            vclass = rng.choice(VEHICLE_CLASSES)
            make, model = rng.choice(MAKES[vclass])
            year = rng.randint(2012, 2023)
            seats = 6 if vclass == "xl" else 4
            af = od + dt.timedelta(days=rng.randint(0, 30) + k * rng.randint(120, 400))
            # older (first) vehicle may be retired; current vehicle active_to NULL
            if k == 0 and n_veh == 2:
                at = dstr(af + dt.timedelta(days=rng.randint(90, 300)))
            else:
                at = ""
            vehicle_rows.append([vid, did, vclass, make, model, year, seats,
                                 dstr(af), at])
            vlist.append((vid, vclass))
        driver_vehicles[did - 1] = vlist
    return driver_rows, vehicle_rows, driver_vehicles, driver_active


def build_promotions(rng, cfg, start_date, days):
    n = cfg["promos"]
    rows = []
    meta = []  # (promo_type, discount_value)
    for pid in range(1, n + 1):
        ptype = rng.choice(PROMO_TYPES)
        if ptype == "percent":
            val = rng.choice([10, 15, 20, 25, 30])
        elif ptype == "flat":
            val = rng.choice([3, 5, 7, 10])
        else:  # first_ride
            val = rng.choice([5, 8, 10, 15])
        code = f"RIDE{rng.randint(100, 999)}{chr(65 + (pid % 26))}"
        vf = start_date - dt.timedelta(days=rng.randint(0, 60))
        vt = start_date + dt.timedelta(days=days + rng.randint(0, 60))
        rows.append([pid, code, ptype, money(val), dstr(vf), dstr(vt)])
        meta.append((ptype, float(val)))
    return rows, meta


# ---------------------------------------------------------------------------
# Time-shape weights (weekday / hour / seasonal)
# ---------------------------------------------------------------------------
def hour_weights():
    # 24-hour demand profile: morning + evening rush, weekend-agnostic base.
    base = [0.3, 0.2, 0.15, 0.12, 0.2, 0.5, 1.2, 2.4, 2.6, 1.6, 1.2, 1.3,
            1.5, 1.4, 1.3, 1.5, 2.0, 2.8, 2.7, 1.9, 1.5, 1.3, 1.0, 0.6]
    return base


def weekday_weight(wd):
    # Mon=0 .. Sun=6 ; Thu-Sat busier.
    return [0.9, 0.9, 1.0, 1.15, 1.35, 1.4, 1.05][wd]


def seasonal_weight(day_index, total_days):
    # gentle upward ramp plus an annual sinusoid.
    ramp = 1.0 + 0.35 * (day_index / max(1, total_days))
    seasonal = 1.0 + 0.18 * math.sin(2 * math.pi * (day_index / 365.0))
    return ramp * seasonal


# ---------------------------------------------------------------------------
# Surge feed generation (streamed)
# ---------------------------------------------------------------------------
def gen_surge_events(rng, writer, cfg, zone_meta, start_date, days, harsh):
    surge_id = 0
    per_zone_day = cfg["surge_per_zone_day"]
    for zidx, (_city, is_airport, _bf, demand) in enumerate(zone_meta):
        zone_id = zidx + 1
        # walk days; emit events at jittered intra-day boundaries
        for d in range(days):
            day = start_date + dt.timedelta(days=d)
            wd = day.weekday()
            # expected events today for this zone
            lam = per_zone_day * (1.3 if is_airport else 1.0) * weekday_weight(wd)
            n_today = int(lam) + (1 if rng.random() < (lam - int(lam)) else 0)
            for _ in range(n_today):
                hour = min(23, int(24 * (rng.random() ** 0.9)))
                minute = rng.randint(0, 59)
                sec = rng.randint(0, 59)
                eff = dt.datetime.combine(day, dt.time(hour, minute, sec))
                # late/out-of-order: occasionally backdate the effective_ts
                if harsh and rng.random() < 0.08:
                    eff = eff - dt.timedelta(minutes=rng.randint(5, 90))
                mult = 1.0
                if rng.random() < 0.45:
                    mult = round(1.0 + abs(rng.gauss(0.0, 0.6)) *
                                 (1.4 if is_airport else 1.0), 2)
                    mult = min(mult, 4.90)
                reason = rng.choice(SURGE_REASONS)
                if rng.random() < 0.04:
                    reason = ""  # unlabelled event (nullable)
                surge_id += 1
                writer.writerow([surge_id, zone_id, ts(eff), money(mult), reason])
                # duplicate (zone, effective_ts) event: as-of ambiguity landmine
                if harsh and rng.random() < 0.015:
                    surge_id += 1
                    dup_mult = min(4.90, round(mult + rng.uniform(-0.2, 0.3), 2))
                    dup_mult = max(1.0, dup_mult)
                    writer.writerow([surge_id, zone_id, ts(eff),
                                     money(dup_mult), reason])


# ---------------------------------------------------------------------------
# Trip + rating + promo streaming generation
# ---------------------------------------------------------------------------
def gen_facts(rng, writers, cfg, zone_meta, n_zones, driver_vehicles,
              driver_active, promo_meta, start_date, days, harsh):
    trips_w = writers["trips"]
    ratings_w = writers["trip_ratings"]
    promos_w = writers["trip_promotions"]

    n_target = cfg["trips"]
    n_drivers = cfg["drivers"]
    n_riders = cfg["riders"]
    n_promos = cfg["promos"]

    # precompute time-shape cumulative weights
    hw = hour_weights()
    hour_cum = build_cum(hw)
    hours = list(range(24))
    day_weights = []
    for d in range(days):
        day = start_date + dt.timedelta(days=d)
        day_weights.append(weekday_weight(day.weekday()) *
                           seasonal_weight(d, days))
    day_cum = build_cum(day_weights)
    day_idx_list = list(range(days))

    # zone demand cumulative (power-law popularity)
    zone_dem = [m[3] for m in zone_meta]
    zone_cum = build_cum(zone_dem)
    zone_ids = list(range(1, n_zones + 1))

    counters = {"trip": 0, "rating": 0, "app": 0, "written": 0}

    def pick_request_ts():
        d = weighted_pick(rng, day_cum, day_idx_list)
        day = start_date + dt.timedelta(days=d)
        hour = weighted_pick(rng, hour_cum, hours)
        return dt.datetime.combine(day, dt.time(hour, rng.randint(0, 59),
                                                rng.randint(0, 59)))

    def surge_for(zone_id, when):
        """Applied surge, correlated with hour/weekday/airport + noise."""
        is_airport = zone_meta[zone_id - 1][1]
        h = when.hour
        rush = 1.0
        if h in (7, 8, 17, 18, 19):
            rush = 1.5
        elif h in (22, 23, 0, 1, 2) and when.weekday() >= 4:
            rush = 1.7
        base = 1.0
        if rng.random() < 0.42 * rush:
            base = 1.0 + abs(rng.gauss(0.0, 0.35)) * rush * (1.3 if is_airport else 1.0)
        return min(4.90, round(base, 2))

    def emit_rating(trip_id, dropoff_time, fare, applied_surge):
        # ~62% of completed trips are rated
        if rng.random() >= 0.62:
            return
        counters["rating"] += 1
        rid = counters["rating"]
        # rider_stars: usually high; sometimes NULL
        if rng.random() < 0.10:
            rider_stars = ""
        else:
            rider_stars = min(5, max(1, int(round(rng.gauss(4.6, 0.7)))))
        if rng.random() < 0.35:
            driver_stars = ""
        else:
            driver_stars = min(5, max(1, int(round(rng.gauss(4.8, 0.5)))))
        # tip: NULL (no info) vs explicit 0.00 vs positive. Distinct landmine.
        troll = rng.random()
        if troll < 0.45:
            tip = ""  # no tip information recorded
        elif troll < 0.70:
            tip = money(0.0)  # explicit zero tip
        else:
            tip = money(round(min(fare * 0.4, abs(rng.gauss(2.5, 1.8))), 2))
        rated = dropoff_time + dt.timedelta(minutes=rng.randint(0, 240))
        ratings_w.writerow([rid, trip_id, rider_stars, driver_stars, tip, ts(rated)])
        # duplicate rating (double submission) — only in harsh belts
        if harsh and rng.random() < 0.012:
            counters["rating"] += 1
            ratings_w.writerow([counters["rating"], trip_id, rider_stars,
                                driver_stars, tip, ts(rated + dt.timedelta(seconds=2))])

    def emit_promos(trip_id, request_time, fare):
        if rng.random() >= 0.25:
            return
        n_apply = 1
        r = rng.random()
        if r < 0.22:
            n_apply = 2
        elif r < 0.30:
            n_apply = 3
        for _ in range(n_apply):
            pid = rng.randint(1, n_promos)
            ptype, val = promo_meta[pid - 1]
            if ptype == "percent":
                disc = round(fare * (val / 100.0), 2)
            else:
                disc = round(min(val, fare), 2)
            counters["app"] += 1
            applied = request_time + dt.timedelta(seconds=rng.randint(0, 30))
            promos_w.writerow([counters["app"], trip_id, pid, money(disc), ts(applied)])
            # duplicate application of the same promo (double-apply landmine)
            if harsh and rng.random() < 0.02:
                counters["app"] += 1
                promos_w.writerow([counters["app"], trip_id, pid, money(disc),
                                   ts(applied + dt.timedelta(seconds=1))])

    def make_trip(rider_id, request_time, allow_followup):
        if counters["written"] >= n_target:
            return
        counters["trip"] += 1
        trip_id = counters["trip"]
        counters["written"] += 1

        pickup_zone = weighted_pick(rng, zone_cum, zone_ids)
        applied_surge = surge_for(pickup_zone, request_time)

        # outcome probabilities; higher surge => more no_driver / cancels
        surge_press = max(0.0, applied_surge - 1.0)
        p_complete = max(0.30, 0.72 - 0.14 * surge_press)
        p_no_driver = min(0.40, 0.10 + 0.14 * surge_press)
        roll = rng.random()
        if roll < p_complete:
            status = "completed"
        elif roll < p_complete + p_no_driver:
            status = "no_driver"
        else:
            # remaining requests are cancellations, split rider/driver
            status = "cancelled_rider" if rng.random() < 0.55 else "cancelled_driver"

        driver_id = ""
        vehicle_id = ""
        pickup_ts_v = ""
        dropoff_ts_v = ""
        dropoff_zone = ""
        distance = ""
        duration = ""
        fare_v = ""
        payment = ""
        surge_out = money(applied_surge)

        if status == "no_driver":
            driver_id = ""
            # some non-completed rows have NULL surge / payment (nullable landmine)
            if harsh and rng.random() < 0.30:
                surge_out = ""
        else:
            didx = power_index(rng, n_drivers, 1.7)
            driver_id = didx + 1
            vlist = driver_vehicles[didx]
            vehicle_id, vclass = vlist[rng.randint(0, len(vlist) - 1)]
            if status == "completed":
                wait = rng.randint(30, 480)
                pickup = request_time + dt.timedelta(seconds=wait)
                # distance correlated with a base + noise; airport longer
                is_airport = zone_meta[pickup_zone - 1][1]
                base_km = abs(rng.gauss(4.5 if not is_airport else 12.0, 3.0)) + 0.4
                distance_v = round(base_km, 2)
                speed_kmh = rng.uniform(18, 40)
                dur = int(distance_v / speed_kmh * 3600) + rng.randint(30, 180)
                dropoff = pickup + dt.timedelta(seconds=dur)
                base_fare = zone_meta[pickup_zone - 1][2]
                per_km = 1.15 if vclass == "economy" else (1.6 if vclass == "xl" else 2.4)
                raw_fare = (base_fare + per_km * distance_v) * applied_surge
                fare_val = round(max(2.5, raw_fare + rng.gauss(0, 0.6)), 2)
                pickup_ts_v = ts(pickup)
                dropoff_ts_v = ts(dropoff)
                dropoff_zone = weighted_pick(rng, zone_cum, zone_ids)
                distance = money(distance_v)
                duration = dur
                fare_v = money(fare_val)
                payment = rng.choice(PAYMENT_TYPES)
            elif status == "cancelled_driver":
                # driver matched then cancelled; sometimes a pickup ts exists
                if rng.random() < 0.25:
                    pickup_ts_v = ts(request_time + dt.timedelta(seconds=rng.randint(60, 400)))
                payment = "" if rng.random() < 0.5 else rng.choice(PAYMENT_TYPES)
                if harsh and rng.random() < 0.25:
                    surge_out = ""
            else:  # cancelled_rider
                if rng.random() < 0.4:
                    driver_id = ""  # rider cancelled before match
                    vehicle_id = ""
                payment = ""
                if harsh and rng.random() < 0.25:
                    surge_out = ""

        trips_w.writerow([
            trip_id, rider_id, driver_id, vehicle_id, ts(request_time),
            pickup_ts_v, dropoff_ts_v, pickup_zone, dropoff_zone, distance,
            duration, fare_v, surge_out, status, payment,
        ])

        if status == "completed":
            emit_rating(trip_id, dt.datetime.strptime(dropoff_ts_v, "%Y-%m-%d %H:%M:%S"),
                        float(fare_v), applied_surge)
            emit_promos(trip_id, request_time, float(fare_v))

        # Re-request sessionization structure: an unfulfilled request often
        # triggers a follow-up request by the SAME rider within a few minutes.
        # This is what the Red problem must sessionize correctly.
        if (allow_followup and status in ("no_driver", "cancelled_driver")
                and counters["written"] < n_target and rng.random() < 0.55):
            n_follow = 1 if rng.random() < 0.7 else 2
            for _ in range(n_follow):
                if counters["written"] >= n_target:
                    break
                gap = rng.randint(15, 290)
                # late/out-of-order: sometimes the follow-up timestamp precedes
                # the original by a hair (clock skew) — only in harsh belts.
                if harsh and rng.random() < 0.10:
                    gap = -rng.randint(1, 40)
                follow_ts = request_time + dt.timedelta(seconds=gap)
                make_trip(rider_id, follow_ts, allow_followup=False)

    # main generation loop
    while counters["written"] < n_target:
        rider_id = power_index(rng, n_riders, 2.0) + 1
        request_time = pick_request_ts()
        make_trip(rider_id, request_time, allow_followup=True)

    return counters


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------
def open_writer(path, header):
    f = open(path, "w", newline="", encoding="utf-8")
    w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
    w.writerow(header)
    return f, w


def generate(seed, scale, out_dir):
    if scale not in SCALES:
        raise SystemExit(f"unknown scale {scale!r}; choose from {sorted(SCALES)}")
    cfg = SCALES[scale]
    harsh = scale in HARSH_SCALES
    rng = random.Random(seed)
    os.makedirs(out_dir, exist_ok=True)

    start_date = dt.datetime.strptime(cfg["start"], "%Y-%m-%d").date()
    days = cfg["days"]

    # ---- dimensions (in memory) ----
    geo_rows, zone_meta, _n_cities = build_geozones(rng, cfg)
    rider_rows, _home_zone, _signup = build_riders(rng, cfg, cfg["zones"], start_date)
    driver_rows, vehicle_rows, driver_vehicles, driver_active = \
        build_drivers_and_vehicles(rng, cfg, cfg["zones"], start_date)
    promo_rows, promo_meta = build_promotions(rng, cfg, start_date, days)

    # write dimension CSVs
    for name, rows in (("geozones", geo_rows), ("riders", rider_rows),
                       ("drivers", driver_rows), ("vehicles", vehicle_rows),
                       ("promotions", promo_rows)):
        f, w = open_writer(os.path.join(out_dir, f"{name}.csv"), TABLES[name])
        for r in rows:
            w.writerow(r)
        f.close()

    # ---- surge feed (streamed) ----
    sf, sw = open_writer(os.path.join(out_dir, "surge_events.csv"),
                         TABLES["surge_events"])
    gen_surge_events(rng, sw, cfg, zone_meta, start_date, days, harsh)
    sf.close()

    # ---- trips + ratings + trip_promotions (streamed together) ----
    tf, tw = open_writer(os.path.join(out_dir, "trips.csv"), TABLES["trips"])
    rf, rw = open_writer(os.path.join(out_dir, "trip_ratings.csv"),
                         TABLES["trip_ratings"])
    pf, pw = open_writer(os.path.join(out_dir, "trip_promotions.csv"),
                         TABLES["trip_promotions"])
    writers = {"trips": tw, "trip_ratings": rw, "trip_promotions": pw}
    counters = gen_facts(rng, writers, cfg, zone_meta, cfg["zones"],
                         driver_vehicles, driver_active, promo_meta,
                         start_date, days, harsh)
    tf.close()
    rf.close()
    pf.close()

    return counters


def main():
    ap = argparse.ArgumentParser(description="RideLoop deterministic generator")
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--scale", required=True, choices=sorted(SCALES))
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    counters = generate(args.seed, args.scale, args.out)
    print(f"rideloop: scale={args.scale} seed={args.seed} -> {args.out}")
    print(f"  trips={counters['trip']} ratings={counters['rating']} "
          f"promo_apps={counters['app']}")


if __name__ == "__main__":
    main()
