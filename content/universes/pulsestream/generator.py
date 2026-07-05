#!/usr/bin/env python3
"""
PulseStream universe — deterministic, seeded data generator.

Emits one RFC-4180 CSV per table into an output directory. Given the same
--seed and --scale the output is byte-identical (single seeded PRNG, no wall
clock, no global random, deterministic dict iteration via explicit sorting).

Usage:
    python3 generator.py --seed 42 --scale sample --out /tmp/pulsestream

Scales (row targets per CONTENT-SPEC section 1; `plays` is the largest fact):
    sample  ~ hundreds of rows total       (visible sample fixture)
    blue    total <= 50k
    purple  total <= 500k
    black   plays 1M-5M
    red     plays 5M-10M (largest fact table)

Design notes and the full landmine inventory live in universe.md. The generator
is pure standard library (random, csv, datetime, math, argparse) and streams the
plays firehose straight to disk, so it is memory-safe at red scale.
"""

import argparse
import bisect
import csv
import math
import os
import random
from datetime import date, datetime, timedelta

# ---------------------------------------------------------------------------
# Fixed world constants (identical across scales so semantics are stable).
# ---------------------------------------------------------------------------
RANGE_START = date(2023, 1, 1)     # first day a play can occur
RANGE_END = date(2024, 12, 31)     # last day a play can occur (2024 is a leap year)
RATE_EPOCH_BREAK = date(2024, 1, 1)  # rate card revision boundary

PLANS = ["free", "trial", "student", "family", "premium"]
PLAN_PRECEDENCE = {"free": 1, "trial": 2, "student": 3, "family": 4, "premium": 5}
PLAN_PRICE = {"free": 0.00, "trial": 0.00, "student": 5.99, "family": 15.99, "premium": 10.99}

# Countries with bespoke royalty rates; everything else uses the global (NULL) rate.
RATE_COUNTRIES = ["US", "GB", "DE"]
ALL_COUNTRIES = ["US", "GB", "DE", "FR", "BR", "IN", "JP", "CA", "AU", "MX", "SE", "NG"]

GENRES = [
    "pop", "rock", "hiphop", "electronic", "jazz", "classical", "country",
    "rnb", "latin", "metal", "folk", "reggae", "blues", "kpop", "indie",
]
DEVICES = ["ios", "android", "web", "desktop", "smart_speaker"]
SOURCES = ["search", "playlist", "album", "radio", "artist_page", "daily_mix"]
ALBUM_TYPES = ["album", "album", "album", "ep", "single", "compilation"]
REFERRALS = ["organic", "friend", "ad_instagram", "ad_tiktok", "ad_youtube", "partner_bundle"]

# Word banks for original, copyright-free synthetic names.
ADJ = ["velvet", "neon", "midnight", "golden", "silent", "electric", "crimson",
       "hollow", "lunar", "wild", "paper", "glass", "iron", "coral", "amber",
       "silver", "distant", "fading", "restless", "gentle", "frozen", "bright"]
NOUN = ["echo", "harbor", "signal", "ember", "current", "circuit", "meadow",
        "static", "vertigo", "lantern", "orbit", "cascade", "monsoon", "mirage",
        "anthem", "pulse", "drift", "canyon", "halo", "riptide", "cinder", "grove"]
FIRST = ["Ava", "Leo", "Mara", "Ivo", "Noa", "Kai", "Rey", "Sena", "Tovi", "Juno",
         "Odis", "Priya", "Bram", "Nika", "Cato", "Lira", "Emet", "Sol", "Wren", "Zeya"]
GIVEN = ["alex", "sam", "jordan", "casey", "riley", "morgan", "quinn", "devon",
         "harper", "rowan", "sage", "reese", "toby", "nova", "indi", "milo"]


# ---------------------------------------------------------------------------
# Scale configuration. `plays` is the main-loop event count; a small number of
# duplicate and boundary events are appended on top (kept within the belt cap).
# ---------------------------------------------------------------------------
SCALES = {
    "sample": dict(artists=12,    albums=32,     tracks=70,     users=35,     plays=480),
    "blue":   dict(artists=150,   albums=520,    tracks=2500,   users=1200,   plays=38000),
    "purple": dict(artists=1000,  albums=3500,   tracks=14000,  users=9000,   plays=430000),
    "black":  dict(artists=5000,  albums=22000,  tracks=100000, users=70000,  plays=3000000),
    "red":    dict(artists=12000, albums=48000,  tracks=220000, users=140000, plays=6000000),
}

TABLES = ["artists", "albums", "tracks", "users", "subscriptions",
          "plays", "royalty_rates", "artist_payouts"]

HEADERS = {
    "artists": ["artist_id", "name", "country", "primary_genre", "signed_date",
                "monthly_listeners_est"],
    "albums": ["album_id", "artist_id", "title", "release_date", "album_type"],
    "tracks": ["track_id", "artist_id", "album_id", "title", "genre",
               "duration_sec", "release_date", "is_explicit", "isrc"],
    "users": ["user_id", "display_name", "country", "birth_year", "signup_date",
              "referral_source"],
    "subscriptions": ["subscription_id", "user_id", "plan", "started_at",
                      "ended_at", "price_usd", "is_auto_renew"],
    "plays": ["play_id", "user_id", "track_id", "played_at", "ms_played",
              "device", "source", "is_offline"],
    "royalty_rates": ["rate_id", "plan", "country", "effective_from",
                      "effective_to", "per_play_usd"],
    "artist_payouts": ["payout_id", "artist_id", "period_month", "amount_usd",
                       "status"],
}


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
def title_case_phrase(rng):
    return f"{rng.choice(ADJ).capitalize()} {rng.choice(NOUN).capitalize()}"


def weighted_index(cum, total, rng):
    """Draw an index in [0, len(cum)) proportional to precomputed weights."""
    x = rng.random() * total
    i = bisect.bisect_right(cum, x)
    if i >= len(cum):
        i = len(cum) - 1
    return i


def build_cumulative(weights):
    cum = []
    running = 0.0
    for w in weights:
        running += w
        cum.append(running)
    return cum, running


def iso_ts(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def make_isrc(rng):
    # 2 country letters + 3 registrant alnum + 2 year digits + 5 designation digits.
    letters = "".join(rng.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZ") for _ in range(2))
    reg = "".join(rng.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") for _ in range(3))
    yy = rng.choice(["07", "08", "09", "10", "18", "23"])  # includes leading zeros
    desig = "".join(rng.choice("0123456789") for _ in range(5))
    return f"{letters}{reg}{yy}{desig}"


# ---------------------------------------------------------------------------
# Dimension builders
# ---------------------------------------------------------------------------
def gen_artists(cfg, rng, out_dir):
    n = cfg["artists"]
    artist_country = [None] * n
    with open(os.path.join(out_dir, "artists.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADERS["artists"])
        for i in range(n):
            aid = i + 1
            name = title_case_phrase(rng)
            # ~7% NULL country, ~6% NULL primary_genre.
            country = None if rng.random() < 0.07 else rng.choice(ALL_COUNTRIES)
            genre = None if rng.random() < 0.06 else rng.choice(GENRES)
            signed = RANGE_START - timedelta(days=rng.randint(30, 3650))
            # monthly_listeners_est: power-ish, occasionally NULL (stale/unknown).
            if rng.random() < 0.05:
                listeners = None
            else:
                listeners = int(10 ** (rng.uniform(2.0, 6.3)))
            w.writerow([aid, name, country or "", genre or "",
                        signed.isoformat(), "" if listeners is None else listeners])
            artist_country[i] = country
    return artist_country


def gen_albums(cfg, rng, out_dir):
    """One pass: give each artist a handful of albums until the album target is hit."""
    n_albums = cfg["albums"]
    n_artists = cfg["artists"]
    artist_albums = [[] for _ in range(n_artists)]
    album_id = 0
    with open(os.path.join(out_dir, "albums.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADERS["albums"])
        # Round-robin-ish assignment weighted so some artists have deeper catalogs.
        while album_id < n_albums:
            ai = rng.randrange(n_artists)
            album_id += 1
            atype = rng.choice(ALBUM_TYPES)
            title = title_case_phrase(rng)
            rel = RANGE_START - timedelta(days=rng.randint(0, 3000))
            w.writerow([album_id, ai + 1, title, rel.isoformat(), atype])
            artist_albums[ai].append((album_id, rel))
    return artist_albums


def gen_tracks(cfg, rng, out_dir, artist_albums):
    n_tracks = cfg["tracks"]
    n_artists = cfg["artists"]
    track_artist = [0] * n_tracks
    track_dur = [0] * n_tracks
    with open(os.path.join(out_dir, "tracks.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADERS["tracks"])
        for i in range(n_tracks):
            tid = i + 1
            ai = rng.randrange(n_artists)
            albums = artist_albums[ai]
            # ~18% are non-album singles => NULL album_id.
            if albums and rng.random() > 0.18:
                album_id, rel = albums[rng.randrange(len(albums))]
            else:
                album_id = None
                rel = RANGE_START - timedelta(days=rng.randint(0, 3000))
            title = title_case_phrase(rng)
            genre = None if rng.random() < 0.06 else rng.choice(GENRES)
            # duration in SECONDS. Mixture: interludes, normal, long-form.
            r = rng.random()
            if r < 0.02:
                dur = None
            elif r < 0.10:
                dur = rng.randint(30, 90)
            elif r < 0.90:
                dur = rng.randint(150, 260)
            else:
                dur = rng.randint(300, 620)
            is_explicit = 1 if rng.random() < 0.20 else 0
            isrc = make_isrc(rng)
            w.writerow([tid, ai + 1, "" if album_id is None else album_id, title,
                        genre or "", "" if dur is None else dur, rel.isoformat(),
                        is_explicit, isrc])
            track_artist[i] = ai + 1
            track_dur[i] = dur if dur is not None else 210
    return track_artist, track_dur


def gen_users(cfg, rng, out_dir):
    n = cfg["users"]
    user_country = [None] * n
    user_signup = [None] * n
    signup_min = date(2021, 1, 1)
    signup_max = date(2024, 11, 1)
    signup_span = (signup_max - signup_min).days
    with open(os.path.join(out_dir, "users.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADERS["users"])
        for i in range(n):
            uid = i + 1
            name = f"{rng.choice(GIVEN)}_{rng.choice(NOUN)}{rng.randint(1, 999)}"
            country = None if rng.random() < 0.05 else rng.choice(ALL_COUNTRIES)
            birth = None if rng.random() < 0.12 else rng.randint(1955, 2010)
            # Skew signups early (platform matured before the play window).
            off = int((rng.random() ** 1.6) * signup_span)
            signup = signup_min + timedelta(days=off)
            ref = None if rng.random() < 0.15 else rng.choice(REFERRALS)
            w.writerow([uid, name, country or "", "" if birth is None else birth,
                        signup.isoformat(), ref or ""])
            user_country[i] = country
            user_signup[i] = signup
    return user_country, user_signup


def gen_subscriptions(cfg, rng, out_dir, user_signup):
    """
    Emit plan periods per user and return, per user index, a list of active-plan
    tuples (start_date, end_date_or_None, plan) used to resolve royalties.

    Semantics (documented in universe.md):
      * A subscription is active on day p iff start <= p <= end (or end is NULL).
      * ended_at NULL == still active.
      * A small fraction of paid users get a SECOND paid row that OVERLAPS an
        existing paid period (join fan-out landmine). When several plans are
        active at once, the highest PLAN_PRECEDENCE wins (tie: latest start).
    """
    n = cfg["users"]
    user_subs = [None] * n
    sub_id = 0
    with open(os.path.join(out_dir, "subscriptions.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADERS["subscriptions"])
        for i in range(n):
            signup = user_signup[i]
            subs = []          # (start, end, plan) for royalty resolution
            rows = []          # csv rows to emit
            paid = rng.random() < 0.45
            if not paid:
                # free-only; usually still active.
                end = None if rng.random() < 0.8 else signup + timedelta(days=rng.randint(30, 700))
                subs.append((signup, end, "free"))
                rows.append(("free", signup, end))
            else:
                # free intro that converts to paid.
                t1 = signup + timedelta(days=rng.randint(7, 400))
                subs.append((signup, t1 - timedelta(days=1), "free"))
                rows.append(("free", signup, t1 - timedelta(days=1)))
                cursor = t1
                periods = rng.randint(1, 3)
                for _ in range(periods):
                    plan = rng.choices(["trial", "student", "family", "premium"],
                                       weights=[1, 2, 2, 4])[0]
                    length = rng.randint(60, 500)
                    end = cursor + timedelta(days=length)
                    active = rng.random() < 0.35   # some still active => NULL end
                    end_val = None if active else end
                    subs.append((cursor, end_val, plan))
                    rows.append((plan, cursor, end_val))
                    if active:
                        break
                    # gap before possible resubscribe
                    cursor = end + timedelta(days=rng.randint(1, 180))
                    if cursor > RANGE_END:
                        break
                # Overlap glitch: ~9% of paid users get an overlapping paid row.
                if rng.random() < 0.09 and len(rows) >= 2:
                    # pick an existing paid period to overlap
                    paid_rows = [r for r in rows if r[0] != "free"]
                    if paid_rows:
                        base = paid_rows[rng.randrange(len(paid_rows))]
                        b_start, b_end = base[1], base[2]
                        eff_end = b_end if b_end is not None else RANGE_END
                        ov_start = b_start + timedelta(days=rng.randint(1, 20))
                        ov_end = eff_end + timedelta(days=rng.randint(1, 60))
                        ov_plan = rng.choice(["premium", "family", "student"])
                        subs.append((ov_start, ov_end, ov_plan))
                        rows.append((ov_plan, ov_start, ov_end))
            # emit
            for (plan, start, end) in rows:
                sub_id += 1
                price = PLAN_PRICE[plan]
                auto = 1 if (plan != "free" and rng.random() < 0.85) else 0
                w.writerow([sub_id, i + 1, plan, start.isoformat(),
                            "" if end is None else end.isoformat(),
                            f"{price:.2f}", auto])
            user_subs[i] = subs
    return user_subs


def gen_royalty_rates(rng, out_dir):
    """Rate card: (plan, market, epoch). free/trial are 0. Returns a lookup dict
    keyed (plan, country) -> list of (from_date, to_date_or_None, rate)."""
    base = {  # global (NULL-country) per-play rate, epoch 1
        "free": 0.0, "trial": 0.0, "student": 0.00250,
        "family": 0.00300, "premium": 0.00350,
    }
    country_bump = {"US": 0.0010, "GB": 0.0006, "DE": 0.0004}
    epoch2_bump = 0.00030  # revision that takes effect 2024-01-01

    lookup = {}
    rows = []
    rate_id = 0
    # Deterministic ordering: plan, then global(None) + specific countries, then epoch.
    for plan in PLANS:
        markets = [None] + RATE_COUNTRIES
        for country in markets:
            g = base[plan]
            cbump = 0.0 if (country is None or g == 0.0) else country_bump.get(country, 0.0)
            for epoch, (efrom, eto) in enumerate([
                (RANGE_START, RATE_EPOCH_BREAK),
                (RATE_EPOCH_BREAK, None),
            ]):
                rate = g + cbump + (epoch2_bump if (epoch == 1 and g > 0) else 0.0)
                rate = round(rate, 6)
                rate_id += 1
                rows.append((rate_id, plan, country, efrom, eto, rate))
                lookup.setdefault((plan, country), []).append((efrom, eto, rate))
    with open(os.path.join(out_dir, "royalty_rates.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADERS["royalty_rates"])
        for (rid, plan, country, efrom, eto, rate) in rows:
            w.writerow([rid, plan, country or "", efrom.isoformat(),
                        "" if eto is None else eto.isoformat(), f"{rate:.6f}"])
    return lookup


def resolve_plan(subs, p_date):
    """Highest-precedence plan active on p_date; None if nothing active."""
    best = None
    best_key = None
    for (start, end, plan) in subs:
        if start <= p_date and (end is None or p_date <= end):
            key = (PLAN_PRECEDENCE[plan], start)
            if best_key is None or key > best_key:
                best_key = key
                best = plan
    return best


def rate_for(lookup, plan, country, p_date):
    """Per-play USD for (plan, country) as-of p_date, country-specific then global."""
    for key in ((plan, country), (plan, None)):
        epochs = lookup.get(key)
        if not epochs:
            continue
        for (efrom, eto, rate) in epochs:
            if efrom <= p_date and (eto is None or p_date < eto):
                return rate
        return 0.0
    return 0.0


# ---------------------------------------------------------------------------
# Day / hour weighting for played_at
# ---------------------------------------------------------------------------
def build_day_weights():
    days = []
    d = RANGE_START
    while d <= RANGE_END:
        days.append(d)
        d += timedelta(days=1)
    n = len(days)
    weights = []
    for idx, d in enumerate(days):
        # growth trend across the window
        growth = 1.0 + 0.7 * (idx / (n - 1))
        # seasonal: winter + summer bumps
        seasonal = 1.0 + 0.30 * math.sin(2 * math.pi * (d.month - 1) / 12.0 + 1.1)
        # weekend boost
        weekend = 1.25 if d.weekday() >= 5 else 1.0
        # a couple of viral spike days
        spike = 1.0
        weights.append(growth * seasonal * weekend * spike)
    return days, weights


HOUR_WEIGHTS = [
    2, 1, 1, 1, 1, 2, 4, 7, 9, 8, 8, 9,       # 00..11
    10, 10, 9, 9, 10, 12, 14, 15, 14, 11, 7, 4  # 12..23
]


# ---------------------------------------------------------------------------
# Plays firehose + royalty accrual + payouts
# ---------------------------------------------------------------------------
def gen_plays_and_payouts(cfg, rng, out_dir, track_artist, track_dur,
                          user_country, user_signup, user_subs, rate_lookup):
    n_plays = cfg["plays"]
    n_tracks = cfg["tracks"]
    n_users = cfg["users"]

    # Popularity (tracks) and activity (users) power-law weights, decorrelated
    # from id order via a shuffled rank.
    tr_ranks = list(range(1, n_tracks + 1))
    rng.shuffle(tr_ranks)
    tr_weights = [1.0 / (r ** 0.9) for r in tr_ranks]
    # Zero-denominator landmine: force ~2% of the catalog (min 2) to be NEVER
    # played (region-locked / unreleased). LEFT JOIN plays => 0 -> rate divides
    # by zero. Guaranteed present at every scale, including the visible sample.
    n_dark = max(2, n_tracks // 50)
    for di in rng.sample(range(n_tracks), n_dark):
        tr_weights[di] = 0.0
    tr_cum, tr_total = build_cumulative(tr_weights)

    us_ranks = list(range(1, n_users + 1))
    rng.shuffle(us_ranks)
    us_cum, us_total = build_cumulative([1.0 / (r ** 0.8) for r in us_ranks])

    days, day_w = build_day_weights()
    day_cum, day_total = build_cumulative(day_w)
    n_days = len(days)
    hour_cum, hour_total = build_cumulative(HOUR_WEIGHTS)

    # signup as day-index (or negative if before window)
    signup_idx = []
    for i in range(n_users):
        signup_idx.append((user_signup[i] - RANGE_START).days)

    # royalty accrual: (artist_id, month_date) -> summed USD
    accrual = {}

    def accrue(track_idx, p_date, user_idx):
        subs = user_subs[user_idx]
        plan = resolve_plan(subs, p_date) if subs else None
        if plan is None or plan in ("free", "trial"):
            return  # zero-value plays contribute nothing
        rate = rate_for(rate_lookup, plan, user_country[user_idx], p_date)
        if rate <= 0.0:
            return
        artist_id = track_artist[track_idx]
        key = (artist_id, date(p_date.year, p_date.month, 1))
        accrual[key] = accrual.get(key, 0.0) + rate

    def sample_played_at(user_idx):
        di = weighted_index(day_cum, day_total, rng)
        s_idx = signup_idx[user_idx]
        if s_idx > di and s_idx < n_days:
            # play cannot precede signup; redraw uniformly within valid range
            di = rng.randint(s_idx, n_days - 1)
        d = days[di]
        hh = weighted_index(hour_cum, hour_total, rng)
        mm = rng.randint(0, 59)
        ss = rng.randint(0, 59)
        return datetime(d.year, d.month, d.day, hh, mm, ss)

    def sample_ms(track_idx):
        dur = track_dur[track_idx]  # seconds, never None here
        full_ms = dur * 1000
        r = rng.random()
        if r < 0.04:
            return None                       # missing telemetry
        if r < 0.28:
            return rng.randint(1000, 30000)   # early skip (< 30s zone)
        if r < 0.31:
            return 30000                       # EXACTLY 30s boundary
        if r < 0.34:
            return full_ms                     # completed
        return rng.randint(int(full_ms * 0.55), full_ms)

    play_id = 0
    with open(os.path.join(out_dir, "plays.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADERS["plays"])
        for _ in range(n_plays):
            ui = weighted_index(us_cum, us_total, rng)
            ti = weighted_index(tr_cum, tr_total, rng)
            dt = sample_played_at(ui)
            ms = sample_ms(ti)
            device = None if rng.random() < 0.03 else rng.choice(DEVICES)
            source = rng.choice(SOURCES)
            is_offline = 1 if rng.random() < 0.12 else 0
            play_id += 1
            w.writerow([play_id, ui + 1, ti + 1, iso_ts(dt),
                        "" if ms is None else ms, device or "", source, is_offline])
            accrue(ti, dt.date(), ui)
            # Duplicate-event landmine: ~0.6% retries logged twice (same natural
            # key, new play_id). Counts them for royalty too (finance saw them).
            if rng.random() < 0.006:
                play_id += 1
                w.writerow([play_id, ui + 1, ti + 1, iso_ts(dt),
                            "" if ms is None else ms, device or "", source, is_offline])
                accrue(ti, dt.date(), ui)

        # Boundary-date injection: guarantee events on leap day, year boundary,
        # and month ends even at tiny scales. Uses valid users/tracks.
        boundary_days = [
            date(2024, 2, 29), date(2023, 12, 31), date(2024, 1, 1),
            date(2023, 1, 31), date(2024, 6, 30), date(2024, 12, 31),
        ]
        n_bound = max(2, n_plays // 20000 + 2)
        for bd in boundary_days:
            for _ in range(n_bound):
                ui = weighted_index(us_cum, us_total, rng)
                # ensure play not before signup
                if signup_idx[ui] > (bd - RANGE_START).days:
                    ui = 0 if signup_idx[0] <= (bd - RANGE_START).days else ui
                ti = weighted_index(tr_cum, tr_total, rng)
                dt = datetime(bd.year, bd.month, bd.day,
                              weighted_index(hour_cum, hour_total, rng),
                              rng.randint(0, 59), rng.randint(0, 59))
                ms = sample_ms(ti)
                play_id += 1
                w.writerow([play_id, ui + 1, ti + 1, iso_ts(dt),
                            "" if ms is None else ms,
                            rng.choice(DEVICES), rng.choice(SOURCES), 0])
                accrue(ti, dt.date(), ui)

    # ---- artist_payouts derived from accrual, with deliberate discrepancies ---
    n_artists = cfg["artists"]
    # Withhold a top slice of artist ids from payouts ENTIRELY (min 1): newly
    # onboarded acts whose royalties accrue but no statement has issued. This
    # guarantees a non-empty "artists absent from artist_payouts" population, so
    # the NULL-in-NOT-IN trap (naive NOT IN returns nothing) actually diverges
    # from the correct NOT EXISTS answer at every scale.
    withheld = set(a for a in range(1, n_artists + 1) if a > n_artists * 0.985)
    if not withheld:
        withheld = {n_artists}
    with open(os.path.join(out_dir, "artist_payouts.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADERS["artist_payouts"])
        payout_id = 0
        for (artist_id, month) in sorted(accrual.keys()):
            if artist_id in withheld:
                continue
            true_amt = accrual[(artist_id, month)]
            if true_amt <= 0:
                continue
            roll = rng.random()
            if roll < 0.06:
                # owed but NEVER paid: emit no row (NOT EXISTS / anti-join target)
                continue
            if roll < 0.14:
                status = "pending"
                amt = round(true_amt, 2)
            elif roll < 0.22:
                # overpaid or underpaid (reconciliation mismatch)
                factor = rng.choice([0.85, 0.90, 1.10, 1.20])
                status = "paid"
                amt = round(true_amt * factor, 2)
            elif roll < 0.25:
                status = "reversed"
                amt = round(true_amt, 2)
            else:
                status = "paid"
                amt = round(true_amt, 2)
            payout_id += 1
            w.writerow([payout_id, artist_id, month.isoformat(), f"{amt:.2f}", status])

        # A few 'paid but not owed' rows (artist-months with no accrual).
        extra = max(1, n_artists // 500)
        for _ in range(extra):
            payout_id += 1
            aid = rng.randint(1, n_artists)
            if aid in withheld:
                aid = 1
            m = date(2023 + rng.randint(0, 1), rng.randint(1, 12), 1)
            w.writerow([payout_id, aid, m.isoformat(),
                        f"{rng.uniform(5, 60):.2f}", "paid"])

        # NULL-artist adjustment rows (NULL-in-NOT-IN landmine).
        n_adj = max(1, n_artists // 800)
        for _ in range(n_adj):
            payout_id += 1
            m = date(2023 + rng.randint(0, 1), rng.randint(1, 12), 1)
            w.writerow([payout_id, "", m.isoformat(),
                        f"{rng.uniform(50, 500):.2f}",
                        rng.choice(["paid", "reversed"])])


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def generate(seed, scale, out_dir):
    cfg = SCALES[scale]
    os.makedirs(out_dir, exist_ok=True)
    rng = random.Random(seed)

    # Order matters for determinism; every table draws from the same PRNG.
    gen_artists(cfg, rng, out_dir)
    artist_albums = gen_albums(cfg, rng, out_dir)
    track_artist, track_dur = gen_tracks(cfg, rng, out_dir, artist_albums)
    user_country, user_signup = gen_users(cfg, rng, out_dir)
    user_subs = gen_subscriptions(cfg, rng, out_dir, user_signup)
    rate_lookup = gen_royalty_rates(rng, out_dir)
    gen_plays_and_payouts(cfg, rng, out_dir, track_artist, track_dur,
                          user_country, user_signup, user_subs, rate_lookup)


def main():
    ap = argparse.ArgumentParser(description="PulseStream deterministic data generator")
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--scale", choices=list(SCALES.keys()), required=True)
    ap.add_argument("--out", required=True, help="output directory for CSVs")
    args = ap.parse_args()
    generate(args.seed, args.scale, args.out)


if __name__ == "__main__":
    main()
