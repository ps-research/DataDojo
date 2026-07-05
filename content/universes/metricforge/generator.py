#!/usr/bin/env python3
"""
MetricForge -- deterministic, seeded data generator for the SaaS product-analytics
universe of DataDojo.

    python3 generator.py --seed N --scale {sample|blue|purple|black|red} --out DIR

Emits one RFC4180 CSV per table (header row + rows) into DIR:
    accounts.csv  users.csv  feature_flags.csv  experiments.csv
    experiment_assignments.csv  subscriptions.csv  sessions.csv  events.csv

Design contract
---------------
* Deterministic: identical --seed and --scale produce byte-identical output.
  All randomness comes from a single random.Random(seed); no global random,
  no datetime.now(), no reliance on set/dict iteration order for output.
* Memory-safe at red scale: sessions and the multi-million-row events table are
  streamed row-by-row to disk. Only the small dimension tables (accounts,
  flags, experiments) are held in memory.
* Pure standard library (random, csv, datetime, math, argparse, bisect, os).

The landmine inventory that this generator plants is documented in universe.md;
inline comments below tag each trap with [LANDMINE: family].
"""

import argparse
import bisect
import csv
import math
import os
import random
from datetime import date, datetime, timedelta

# ---------------------------------------------------------------------------
# Fixed simulation window (identical across scales so date landmines are stable)
#   2024-01-01 .. 2025-03-31  (456 days)
#   -> includes the leap day 2024-02-29 and the 2024/2025 year boundary
#      (ISO week-53 / week-1 numbering trap).
# ---------------------------------------------------------------------------
WINDOW_START = date(2024, 1, 1)
WINDOW_END = date(2025, 3, 31)
WINDOW_DAYS = (WINDOW_END - WINDOW_START).days + 1  # 456
LEAP_DAY_IDX = (date(2024, 2, 29) - WINDOW_START).days      # 59
YEAR_BND_IDX = (date(2024, 12, 31) - WINDOW_START).days     # 365

# ---------------------------------------------------------------------------
# Per-scale sizing. Row counts are driven by user population; the events fact
# table (largest) lands in the CONTENT-SPEC band for each belt:
#   sample ~hundreds total | blue <=50k | purple <=500k | black 1M-5M | red 5M-10M
# ---------------------------------------------------------------------------
SCALES = {
    "sample": dict(n_accounts=6,     n_users=24,      n_flags=6,  n_experiments=4),
    "blue":   dict(n_accounts=120,   n_users=1500,    n_flags=12, n_experiments=8),
    "purple": dict(n_accounts=1200,  n_users=15000,   n_flags=20, n_experiments=16),
    "black":  dict(n_accounts=7000,  n_users=90000,   n_flags=40, n_experiments=40),
    "red":    dict(n_accounts=20000, n_users=290000,  n_flags=60, n_experiments=80),
}

# ---------------------------------------------------------------------------
# Categorical vocabularies (weights encode realistic skew).
# ---------------------------------------------------------------------------
REGIONS = ["NA", "EMEA", "APAC", "LATAM"]
REGION_W = [0.45, 0.30, 0.18, 0.07]

INDUSTRIES = ["SaaS", "Fintech", "Ecommerce", "Healthcare", "Media",
              "Education", "Gaming", "Logistics"]

COUNTRIES = ["US", "GB", "DE", "IN", "CA", "FR", "AU", "BR", "JP", "NL", "SG", "ES"]
COUNTRY_W = [0.30, 0.10, 0.09, 0.11, 0.06, 0.05, 0.05, 0.05, 0.04, 0.04, 0.03, 0.08]

CHANNELS = ["organic", "paid_search", "social", "referral", "email", "partner"]
CHANNEL_W = [0.34, 0.22, 0.15, 0.12, 0.10, 0.07]

DEVICES = ["desktop", "mobile", "tablet"]
DEVICE_W = [0.58, 0.36, 0.06]

# Deliberately versioned so lexical order != numeric order:
#   "9.10" < "9.2" as text; "10.0" < "9.0" as text.   [LANDMINE: type-coercion]
APP_VERSIONS = ["8.9", "9.0", "9.2", "9.10", "10.0", "10.1", "10.12", "11.0"]
APP_VERSION_W = [0.05, 0.10, 0.12, 0.10, 0.20, 0.18, 0.13, 0.12]

# Ordered subscription tiers. free carries MRR 0.00 -> zero denominators. [LANDMINE: div-by-zero]
TIERS = [("free", 0.00), ("starter", 29.00), ("pro", 99.00), ("enterprise", 499.00)]

FLAG_BASES = [
    "dark_mode", "bulk_export", "ai_assist", "advanced_search", "custom_dashboard",
    "sso_login", "api_v2", "realtime_sync", "mobile_push", "team_mentions",
    "audit_log", "saved_views", "inline_comments", "keyboard_shortcuts", "csv_import",
    "webhook_alerts", "role_permissions", "two_factor", "usage_billing", "smart_filters",
    "onboarding_wizard", "data_residency", "slack_integration", "scheduled_reports",
]

EXP_BASES = [
    "checkout_redesign", "onboarding_flow", "pricing_page", "trial_length",
    "email_cadence", "recommendation_v2", "search_ranking", "signup_cta",
    "paywall_copy", "dashboard_default", "mobile_nav", "upsell_banner",
    "annual_discount", "referral_reward", "activation_nudge", "empty_state",
]

# Funnel steps, in canonical order. A session may enter a prefix of this ladder.
FUNNEL = ["view_plans", "start_checkout", "enter_payment", "purchase"]
# Non-funnel "filler" events.
FILLERS = ["page_view", "feature_used", "search", "error"]
FILLER_W = [0.52, 0.34, 0.10, 0.04]

PAGE_PATHS = ["/home", "/dashboard", "/reports", "/settings", "/pricing",
              "/team", "/integrations", "/profile", "/search", "/billing"]

PURCHASE_PRICES = [29.0, 49.0, 99.0, 199.0, 499.0]  # repeated values -> ties. [LANDMINE: ties]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def build_cum(weights):
    """Cumulative-sum a weight list for O(log n) weighted sampling via bisect."""
    cum, s = [], 0.0
    for w in weights:
        s += w
        cum.append(s)
    return cum


def pick_idx(rng, cum):
    """Return an index in [0, len(cum)) with probability proportional to weights."""
    return bisect.bisect_right(cum, rng.random() * cum[-1])


def wchoice(rng, items, cum):
    return items[pick_idx(rng, cum)]


def ts_str(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def date_str(d):
    return d.strftime("%Y-%m-%d")


def month_end(d):
    """Last calendar day of d's month (exercises month-end boundary dates)."""
    if d.month == 12:
        nxt = date(d.year + 1, 1, 1)
    else:
        nxt = date(d.year, d.month + 1, 1)
    return nxt - timedelta(days=1)


def day_at(idx, hour, minute, second):
    return datetime.combine(WINDOW_START + timedelta(days=idx),
                            datetime.min.time()).replace(hour=hour, minute=minute, second=second)


def build_day_cum():
    """Per-day activity weights: weekday>weekend, gentle growth trend, summer &
    holiday dips -> realistic weekday/seasonal shape."""
    weights = []
    for i in range(WINDOW_DAYS):
        d = WINDOW_START + timedelta(days=i)
        wd = 1.0 if d.weekday() < 5 else 0.45          # weekend dip
        growth = 0.7 + 0.6 * (i / (WINDOW_DAYS - 1))   # SaaS grows over time
        seasonal = 1.0
        if d.month in (7, 8):
            seasonal = 0.82                            # summer slowdown
        if d.month == 12 and d.day >= 20:
            seasonal = 0.65                            # year-end holidays
        weights.append(wd * growth * seasonal)
    return build_cum(weights)


def build_hour_cum():
    """Intra-day shape: business-hours peak with an evening shoulder."""
    base = [0.2, 0.1, 0.08, 0.06, 0.05, 0.06, 0.12, 0.3, 0.7, 1.0,
            1.1, 1.0, 0.9, 1.0, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6,
            0.5, 0.45, 0.4, 0.3]
    return build_cum(base)


# ---------------------------------------------------------------------------
# Dimension builders (small tables held in memory)
# ---------------------------------------------------------------------------
def gen_accounts(rng, n, region_cum):
    accounts = []
    for aid in range(1, n + 1):
        # signup within first 70% of window
        sd = WINDOW_START + timedelta(days=int(rng.random() * WINDOW_DAYS * 0.7))
        # [LANDMINE: NULL-in-NOT-IN] region NULL for ~10% of accounts
        region = None if rng.random() < 0.10 else wchoice(rng, REGIONS, region_cum)
        accounts.append({
            "account_id": aid,
            "signup_date": sd,
            "region": region,
            "industry": rng.choice(INDUSTRIES),
        })
    return accounts


def write_accounts(w, accounts, plan_by_acct, active_by_acct):
    for a in accounts:
        w.writerow([
            a["account_id"],
            "Account %05d" % a["account_id"],
            plan_by_acct[a["account_id"]],
            date_str(a["signup_date"]),
            a["region"],
            a["industry"],
            active_by_acct[a["account_id"]],
        ])


def gen_flags(rng, n):
    flags = []
    for i in range(n):
        base = FLAG_BASES[i % len(FLAG_BASES)]
        key = base if i < len(FLAG_BASES) else "%s_v%d" % (base, i // len(FLAG_BASES) + 1)
        created = WINDOW_START + timedelta(days=int(rng.random() * WINDOW_DAYS * 0.5))
        # later-created flags are more likely deprecated experiments left behind
        deprecated = 1 if (i >= n * 0.7 and rng.random() < 0.4) else 0
        rollout = rng.choice([5, 10, 25, 50, 50, 75, 100, 100, 100])
        flags.append({
            "flag_id": i + 1,
            "flag_key": key,
            "description": "Feature flag for %s" % key.replace("_", " "),
            "created_date": created,
            "rollout_pct": rollout,
            "is_deprecated": deprecated,
        })
    # Zipf popularity by creation order (earlier flags more used).
    pop = [1.0 / ((i + 1) ** 0.7) for i in range(n)]
    return flags, build_cum(pop)


def write_flags(w, flags):
    for f in flags:
        w.writerow([f["flag_id"], f["flag_key"], f["description"],
                    date_str(f["created_date"]), f["rollout_pct"], f["is_deprecated"]])


def gen_experiments(rng, n, n_flags):
    exps = []
    metrics = ["purchase", "start_checkout", "view_plans", "feature_used", "activation"]
    for i in range(n):
        base = EXP_BASES[i % len(EXP_BASES)]
        key = base if i < len(EXP_BASES) else "%s_%d" % (base, i // len(EXP_BASES) + 1)
        start = WINDOW_START + timedelta(days=int(rng.random() * (WINDOW_DAYS - 60)))
        dur = rng.randint(14, 60)
        running = rng.random() < 0.25
        if running:
            end = None
            status = "running"
        else:
            end = start + timedelta(days=dur)
            if end > WINDOW_END:
                end = WINDOW_END
            status = "aborted" if rng.random() < 0.12 else "completed"
        # ~40% flag-backed; else NULL flag_id  [LANDMINE: NULL-in-NOT-IN]
        flag_id = (rng.randint(1, n_flags) if rng.random() < 0.4 else None)
        exps.append({
            "experiment_id": i + 1,
            "experiment_key": key,
            "flag_id": flag_id,
            "start_date": start,
            "end_date": end,
            "status": status,
            "primary_metric": rng.choice(metrics),
        })
    # subscription popularity: earlier experiments enroll more users
    pop = [1.0 / ((i + 1) ** 0.6) for i in range(n)]
    return exps, build_cum(pop)


def write_experiments(w, exps):
    for e in exps:
        w.writerow([e["experiment_id"], e["experiment_key"], e["flag_id"],
                    date_str(e["start_date"]),
                    date_str(e["end_date"]) if e["end_date"] else None,
                    e["status"], e["primary_metric"]])


def gen_subscriptions(rng, accounts, sub_writer):
    """Stream subscription history; returns current plan_tier + is_active per account.
    Multiple rows per account -> join fan-out. free tier -> MRR 0.00 (zero denom).
    Superseded/churn rows end on a month-end -> boundary dates."""
    sub_id = 0
    plan_by_acct, active_by_acct = {}, {}
    for a in accounts:
        n_sub = 1 + (1 if rng.random() < 0.45 else 0) + (1 if rng.random() < 0.18 else 0)
        tier_idx = 0 if rng.random() < 0.35 else 1     # some start free, most on starter
        cur_start = a["signup_date"]
        last_tier, last_active = TIERS[tier_idx][0], 1
        for k in range(n_sub):
            tier_name, tier_mrr = TIERS[tier_idx]
            # free tier stays exactly 0.00; paid tiers jitter around list price
            if tier_mrr == 0.0:
                mrr = 0.00
            else:
                mrr = round(tier_mrr * (0.85 + 0.30 * rng.random()), 2)
            is_last = (k == n_sub - 1)
            if not is_last:
                # superseded by an upgrade; ended on a month-end boundary
                span = rng.randint(30, 210)
                ended = month_end(cur_start + timedelta(days=span))
                if ended > WINDOW_END:
                    ended = WINDOW_END
                status = "upgraded"
            else:
                r = rng.random()
                if r < 0.55:
                    ended = None                       # [LANDMINE: NULL] active
                    status = "active"
                elif r < 0.85:
                    ended = month_end(cur_start + timedelta(days=rng.randint(30, 240)))
                    if ended > WINDOW_END:
                        ended = WINDOW_END
                    status = "churned"
                else:
                    ended = month_end(cur_start + timedelta(days=rng.randint(30, 180)))
                    if ended > WINDOW_END:
                        ended = WINDOW_END
                    status = "paused"
            sub_id += 1
            sub_writer.writerow([
                sub_id, a["account_id"], tier_name, date_str(cur_start),
                date_str(ended) if ended else None, "%.2f" % mrr, status,
            ])
            last_tier = tier_name
            last_active = 1 if status in ("active", "paused") else 0
            if ended is not None:
                cur_start = ended + timedelta(days=1)
            tier_idx = min(tier_idx + 1, len(TIERS) - 1)
        plan_by_acct[a["account_id"]] = last_tier
        active_by_acct[a["account_id"]] = last_active
    return plan_by_acct, active_by_acct


# ---------------------------------------------------------------------------
# Session + event generation (streamed)
# ---------------------------------------------------------------------------
def gen_events_for_session(rng, ctx, session_id, user_id, started_dt, force_active=False):
    """Yield event rows for one session and return (n_events, last_dt, is_bounce).
    Plants: out-of-order/late events, duplicate double-fires, NULL revenue,
    revenue ties, feature-flag power-law, funnel ordering.
    force_active guarantees a non-bounce session that reaches purchase (used to
    seed boundary-date coverage deterministically)."""
    ev_writer = ctx["ev_writer"]
    flags, flag_cum = ctx["flags"], ctx["flag_cum"]

    # always consume the same rng draws so force_active does not desync the stream
    bounce_roll = rng.random() < 0.10
    is_bounce = bounce_roll and not force_active
    if is_bounce:
        return 0, started_dt, 1

    n_filler = 1 + int(min(rng.expovariate(1 / 5.0), 40))
    # funnel depth: most sessions never enter the upgrade funnel
    d_roll = pick_idx(rng, ctx["funnel_depth_cum"])     # 0..4
    d = 4 if force_active else d_roll
    funnel_types = FUNNEL[:d]
    total = n_filler + d

    # place funnel steps at increasing positions -> funnel order preserved
    if d > 0:
        fpos = set(rng.sample(range(total), d))
    else:
        fpos = set()

    seq = []
    fi = 0
    for pos in range(total):
        if pos in fpos:
            seq.append(funnel_types[fi]); fi += 1
        else:
            seq.append(wchoice(rng, FILLERS, ctx["filler_cum"]))

    # assign increasing timestamps
    t = started_dt
    rows = []
    for etype in seq:
        gap = rng.randint(3, 240)
        t = t + timedelta(seconds=gap)
        flag_id = None
        value = None
        page = None
        if etype == "feature_used":
            flag_id = flags[pick_idx(rng, flag_cum)]["flag_id"]  # power-law popularity
        elif etype == "purchase":
            # [LANDMINE: ties] discrete SaaS price points -> guaranteed exact
            # revenue ties for rank vs dense_rank vs row_number.
            # [LANDMINE: NULL] ~3% of purchases log NULL revenue (dirty data).
            if rng.random() < 0.03:
                value = None
            else:
                value = float(rng.choice(PURCHASE_PRICES))
            page = "/billing"
        elif etype in ("page_view", "view_plans", "start_checkout", "enter_payment"):
            page = "/pricing" if etype != "page_view" else rng.choice(PAGE_PATHS)
        rows.append([etype, t, flag_id, value, page])

    last_dt = t

    # [LANDMINE: late / out-of-order events] ~4% of sessions get one event
    # pushed before the session start (clock skew / late delivery).
    if len(rows) >= 2 and rng.random() < 0.04:
        j = rng.randrange(1, len(rows))
        rows[j][1] = started_dt - timedelta(seconds=rng.randint(5, 180))

    # [LANDMINE: duplicate rows] ~2.5% of sessions double-fire one event
    # (identical business columns, new event_id).
    if rows and rng.random() < 0.025:
        rows.append(list(rows[rng.randrange(len(rows))]))

    n = 0
    for etype, tt, flag_id, value, page in rows:
        ctx["event_id"] += 1
        ev_writer.writerow([
            ctx["event_id"], session_id, user_id, ts_str(tt), etype,
            flag_id, ("%.2f" % value) if value is not None else None, page,
        ])
        n += 1
    return n, last_dt, 0


def gen_assignments(rng, ctx, user_id, forced=None):
    """Stream experiment assignments for a user. Plants contamination:
    duplicate assignments, both-variant enrollment, multi-experiment overlap."""
    exps, exp_cum = ctx["exps"], ctx["exp_cum"]
    aw = ctx["assign_writer"]

    def emit(exp, variant):
        ctx["assign_id"] += 1
        at = datetime.combine(exp["start_date"], datetime.min.time()) + timedelta(
            days=rng.randint(0, 6), hours=rng.randint(0, 23), minutes=rng.randint(0, 59))
        aw.writerow([ctx["assign_id"], exp["experiment_id"], user_id, variant, ts_str(at)])

    if forced == "contaminated":
        # guaranteed within-experiment contamination + duplicate (for the sample)
        e0 = exps[0]
        emit(e0, "control")
        emit(e0, "treatment")            # both variants -> contamination
        emit(e0, "control")              # exact duplicate variant -> dup + fan-out
        return
    if forced == "multi":
        # guaranteed multi-experiment overlap (for the sample)
        emit(exps[0], "treatment")
        if len(exps) > 1:
            emit(exps[1], "control")
        return

    if rng.random() < 0.45:
        exp = exps[pick_idx(rng, exp_cum)]
        variant = "treatment" if rng.random() < 0.5 else "control"
        emit(exp, variant)
        # [LANDMINE: duplicate rows] re-logged assignment
        if rng.random() < 0.03:
            emit(exp, variant)
        # [LANDMINE: join fan-out] same experiment, opposite variant (contamination)
        if rng.random() < 0.04:
            emit(exp, "control" if variant == "treatment" else "treatment")
        # [LANDMINE: join fan-out] enrolled in a second experiment
        if rng.random() < 0.15:
            exp2 = exps[pick_idx(rng, exp_cum)]
            emit(exp2, "treatment" if rng.random() < 0.5 else "control")


def gen_users(rng, ctx):
    """Stream users + their sessions + events + assignments."""
    n_users = ctx["n_users"]
    accounts = ctx["accounts"]
    acct_cum = ctx["acct_cum"]
    day_cum = ctx["day_cum"]
    hour_cum = ctx["hour_cum"]
    uw, sw = ctx["user_writer"], ctx["session_writer"]

    for uid in range(1, n_users + 1):
        # power-law account assignment (a few whales, many small accounts)
        acct = accounts[pick_idx(rng, acct_cum)]

        # number of sessions: heavy-tailed, mean ~4
        n_sessions = 1 + int(min(rng.expovariate(1 / 3.2), 79))
        day_idxs = sorted(pick_idx(rng, day_cum) for _ in range(n_sessions))

        # force boundary-date coverage on the very first user (leap day + year end)
        if uid == 1:
            day_idxs = sorted(set(day_idxs) | {LEAP_DAY_IDX, YEAR_BND_IDX})

        # signup ~ just before earliest activity (defines the retention cohort)
        first_idx = day_idxs[0]
        signup_dt = day_at(first_idx, rng.randint(6, 10), rng.randint(0, 59), rng.randint(0, 59))
        signup_dt = signup_dt - timedelta(minutes=rng.randint(1, 90))

        # [LANDMINE: NULL-in-NOT-IN] geo/channel unknown for a slice of users
        country = None if rng.random() < 0.08 else wchoice(rng, COUNTRIES, ctx["country_cum"])
        channel = None if rng.random() < 0.05 else wchoice(rng, CHANNELS, ctx["channel_cum"])
        device = wchoice(rng, DEVICES, ctx["device_cum"])
        # internal/test users that must be excluded from real metrics
        # (uid 4 is forced internal so every scale's sample carries the trap)
        is_internal = 1 if (rng.random() < 0.04 or uid == 4) else 0

        uw.writerow([uid, acct["account_id"], ts_str(signup_dt),
                     country, channel, device, is_internal])

        # experiment assignments (with forced contamination on early users)
        forced = None
        if uid == 2:
            forced = "contaminated"
        elif uid == 3:
            forced = "multi"
        gen_assignments(rng, ctx, uid, forced=forced)

        # sessions + events
        for didx in day_idxs:
            ctx["session_id"] += 1
            sid = ctx["session_id"]
            hour = pick_idx(rng, hour_cum)
            started = day_at(didx, hour, rng.randint(0, 59), rng.randint(0, 59))
            force_active = (uid == 1 and didx in (LEAP_DAY_IDX, YEAR_BND_IDX))
            n_ev, last_dt, is_bounce = gen_events_for_session(
                rng, ctx, sid, uid, started, force_active=force_active)
            # [LANDMINE: NULL] ~12% of sessions never close (abandoned/ongoing)
            if rng.random() < 0.12:
                ended = None
            elif is_bounce:
                ended = started + timedelta(seconds=rng.randint(1, 30))
            else:
                ended = last_dt + timedelta(seconds=rng.randint(1, 120))
            sw.writerow([
                sid, uid, ts_str(started),
                ts_str(ended) if ended else None,
                wchoice(rng, DEVICES, ctx["device_cum"]),
                wchoice(rng, APP_VERSIONS, ctx["appver_cum"]),
                is_bounce,
            ])


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------
HEADERS = {
    "accounts": ["account_id", "account_name", "plan_tier", "signup_date",
                 "region", "industry", "is_active"],
    "users": ["user_id", "account_id", "signup_ts", "country",
              "referral_channel", "device_type", "is_internal"],
    "feature_flags": ["flag_id", "flag_key", "description", "created_date",
                      "rollout_pct", "is_deprecated"],
    "experiments": ["experiment_id", "experiment_key", "flag_id", "start_date",
                    "end_date", "status", "primary_metric"],
    "experiment_assignments": ["assignment_id", "experiment_id", "user_id",
                               "variant", "assigned_ts"],
    "subscriptions": ["subscription_id", "account_id", "plan_tier", "started_date",
                      "ended_date", "mrr_amount", "status"],
    "sessions": ["session_id", "user_id", "started_ts", "ended_ts",
                 "device_type", "app_version", "is_bounce"],
    "events": ["event_id", "session_id", "user_id", "event_ts", "event_type",
               "flag_id", "event_value", "page_path"],
}


def open_writer(out_dir, name, handles):
    fh = open(os.path.join(out_dir, name + ".csv"), "w", newline="", encoding="utf-8")
    handles.append(fh)
    w = csv.writer(fh, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
    w.writerow(HEADERS[name])
    return w


def generate(seed, scale, out_dir):
    if scale not in SCALES:
        raise SystemExit("unknown scale: %s" % scale)
    cfg = SCALES[scale]
    os.makedirs(out_dir, exist_ok=True)
    rng = random.Random(seed)

    # shared cumulative weight tables
    region_cum = build_cum(REGION_W)
    country_cum = build_cum(COUNTRY_W)
    channel_cum = build_cum(CHANNEL_W)
    device_cum = build_cum(DEVICE_W)
    appver_cum = build_cum(APP_VERSION_W)
    day_cum = build_day_cum()
    hour_cum = build_hour_cum()
    filler_cum = build_cum(FILLER_W)
    # funnel depth distribution: [0,1,2,3,4] entrants decay steeply
    funnel_depth_cum = build_cum([0.60, 0.18, 0.10, 0.07, 0.05])

    handles = []
    try:
        w_acc = open_writer(out_dir, "accounts", handles)
        w_usr = open_writer(out_dir, "users", handles)
        w_flag = open_writer(out_dir, "feature_flags", handles)
        w_exp = open_writer(out_dir, "experiments", handles)
        w_asg = open_writer(out_dir, "experiment_assignments", handles)
        w_sub = open_writer(out_dir, "subscriptions", handles)
        w_ses = open_writer(out_dir, "sessions", handles)
        w_evt = open_writer(out_dir, "events", handles)

        # --- dimensions (in memory) ---
        accounts = gen_accounts(rng, cfg["n_accounts"], region_cum)
        # power-law account sizes: earlier accounts hold more users
        acct_cum = build_cum([1.0 / ((i + 1) ** 0.85) for i in range(len(accounts))])

        flags, flag_cum = gen_flags(rng, cfg["n_flags"])
        write_flags(w_flag, flags)

        exps, exp_cum = gen_experiments(rng, cfg["n_experiments"], cfg["n_flags"])
        write_experiments(w_exp, exps)

        # subscriptions streamed; returns current plan/active per account
        plan_by_acct, active_by_acct = gen_subscriptions(rng, accounts, w_sub)
        write_accounts(w_acc, accounts, plan_by_acct, active_by_acct)

        # --- streamed fact generation ---
        ctx = {
            "n_users": cfg["n_users"],
            "accounts": accounts, "acct_cum": acct_cum,
            "flags": flags, "flag_cum": flag_cum,
            "exps": exps, "exp_cum": exp_cum,
            "day_cum": day_cum, "hour_cum": hour_cum,
            "country_cum": country_cum, "channel_cum": channel_cum,
            "device_cum": device_cum, "appver_cum": appver_cum,
            "filler_cum": filler_cum, "funnel_depth_cum": funnel_depth_cum,
            "user_writer": w_usr, "session_writer": w_ses,
            "ev_writer": w_evt, "assign_writer": w_asg,
            "session_id": 0, "event_id": 0, "assign_id": 0,
        }
        gen_users(rng, ctx)
    finally:
        for fh in handles:
            fh.close()


def main():
    ap = argparse.ArgumentParser(description="MetricForge deterministic data generator")
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--scale", required=True, choices=list(SCALES.keys()))
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    generate(args.seed, args.scale, args.out)


if __name__ == "__main__":
    main()
