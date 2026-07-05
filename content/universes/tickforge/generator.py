#!/usr/bin/env python3
"""TickForge deterministic dataset generator.

Emits one RFC4180 CSV per table for the TickForge exchange universe. The
generator is fully deterministic: the same (seed, scale) pair produces
byte-identical output. It uses only the Python standard library and streams
every fact table row-by-row to disk, so it is memory-safe at red scale
(millions of fills) -- the only in-memory state that grows with the dataset is
the running position book, which is bounded by the number of distinct
(account, instrument) pairs, not by the number of trades.

Usage:
    python3 generator.py --seed N --scale {sample|blue|purple|black|red} --out DIR

Landmine families planted (see universe.md for the full inventory):
    NULLs in meaningful columns, business-duplicate rows, ranking ties,
    empty/one-row groups, boundary dates (leap day, month/quarter/year ends),
    join fan-out, type-coercion (string codes / 'a:b' ratios), gaps vs islands
    (halts), late / out-of-order events, and division-by-zero setups.
"""

import argparse
import csv
import math
import os
import random
from datetime import date, datetime, timedelta

# ---------------------------------------------------------------------------
# Scale configuration. `fills_rate` and `quotes_rate` are the *average* number
# of rows per instrument-session; power-law popularity spreads them unevenly.
# `regime` gates how aggressive the landmines are:
#   clean -> Blue      (no dirty landmines; structural realism only)
#   mild  -> Purple / sample
#   full  -> Black / Red
# ---------------------------------------------------------------------------
SCALES = {
    "sample": dict(instruments=10,  accounts=12,   sessions=22,  fills_rate=0.65, quotes_rate=0.55, regime="mild"),
    "blue":   dict(instruments=40,  accounts=90,   sessions=130, fills_rate=4.0,  quotes_rate=3.2, regime="clean"),
    "purple": dict(instruments=130, accounts=300,  sessions=270, fills_rate=9.0,  quotes_rate=7.0, regime="mild"),
    "black":  dict(instruments=420, accounts=800,  sessions=520, fills_rate=9.5,  quotes_rate=7.5, regime="full"),
    "red":    dict(instruments=820, accounts=1400, sessions=760, fills_rate=11.5, quotes_rate=8.0, regime="full"),
}

START_DATE = date(2023, 1, 2)  # a Monday; span reaches the 2024-02-29 leap day

SECTORS = [
    "Technology", "Financials", "Energy", "Healthcare", "Industrials",
    "Consumer", "Materials", "Utilities", "RealEstate", "Communications",
]
CURRENCIES = ["USD", "USD", "USD", "USD", "EUR", "GBP", "JPY"]
NAME_SUFFIX = ["Holdings", "Corp", "Industries", "Group", "Partners",
               "Technologies", "Capital", "Systems", "Global", "Labs"]
ACCT_TYPES = ["RETAIL", "RETAIL", "RETAIL", "INSTITUTIONAL", "MARKET_MAKER"]
REGIONS = ["Americas", "EMEA", "APAC", "LATAM"]
VENUES = ["XNAS", "XNYS", "BATS", "EDGX", "IEXG", "DARK"]
TIF = ["DAY", "DAY", "DAY", "GTC", "IOC", "FOK"]

TABLES = ["instruments", "accounts", "trading_days", "orders", "fills",
          "quotes", "positions", "corporate_actions"]

HEADERS = {
    "instruments": ["instrument_id", "symbol", "company_name", "sector",
                    "currency", "listing_date", "delisting_date", "tick_size",
                    "lot_size", "status", "is_marginable"],
    "accounts": ["account_id", "account_code", "display_name", "account_type",
                 "region", "base_currency", "opened_date", "risk_tier"],
    "trading_days": ["session_date", "session_seq", "session_type",
                     "open_ts", "close_ts"],
    "orders": ["order_id", "account_id", "instrument_id", "side", "order_type",
               "limit_price", "quantity", "time_in_force", "status",
               "created_at", "updated_at", "session_date", "parent_order_id"],
    "fills": ["fill_id", "order_id", "instrument_id", "account_id", "side",
              "fill_price", "fill_quantity", "fill_time", "liquidity_flag",
              "venue", "fee", "session_date"],
    "quotes": ["quote_id", "instrument_id", "quote_time", "bid_price",
               "bid_size", "ask_price", "ask_size", "session_date"],
    "positions": ["position_id", "account_id", "instrument_id", "as_of_date",
                  "quantity", "avg_cost", "mark_price", "realized_pnl",
                  "unrealized_pnl"],
    "corporate_actions": ["action_id", "instrument_id", "action_type",
                          "ex_date", "record_date", "split_ratio",
                          "cash_amount", "new_symbol", "announced_at"],
}


# ---------------------------------------------------------------------------
# Small deterministic helpers
# ---------------------------------------------------------------------------
def poisson(rng, lam):
    """Draw a Poisson sample using the seeded RNG (stdlib only)."""
    if lam <= 0:
        return 0
    if lam > 30:  # normal approximation for the heavy tail
        return max(0, int(rng.gauss(lam, math.sqrt(lam)) + 0.5))
    L = math.exp(-lam)
    k = 0
    p = 1.0
    while True:
        k += 1
        p *= rng.random()
        if p <= L:
            return k - 1


def d(x, s):
    """Format a decimal value to s places; None -> empty (SQL NULL)."""
    if x is None:
        return ""
    return f"{x:.{s}f}"


def ts(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def dstr(dt):
    return dt.strftime("%Y-%m-%d")


def symbol_for(i):
    """Deterministic unique-ish 3-4 char ticker from an integer id."""
    letters = ""
    n = i
    for _ in range(3):
        letters = chr(ord("A") + (n % 26)) + letters
        n //= 26
    # append a 4th char for higher ids to keep uniqueness beyond 26^3
    if i >= 26 * 26 * 26:
        letters += chr(ord("A") + (i % 26))
    return letters


def is_month_end(sessions, idx):
    """True if sessions[idx] is the last session in its calendar month."""
    cur = sessions[idx][0]
    if idx + 1 >= len(sessions):
        return True
    nxt = sessions[idx + 1][0]
    return (cur.year, cur.month) != (nxt.year, nxt.month)


# ---------------------------------------------------------------------------
# Calendar construction
# ---------------------------------------------------------------------------
def build_calendar(n_sessions):
    """Return a list of (session_date, session_type) with weekends and a
    rule-based holiday set removed. Guarantees leap-day 2024-02-29 is present
    (it is a weekday) and injects half-days near year-end holidays."""
    sessions = []
    day = START_DATE
    while len(sessions) < n_sessions:
        wd = day.weekday()  # 0=Mon .. 6=Sun
        if wd < 5 and not _is_holiday(day):
            stype = "HALF_DAY" if _is_half_day(day) else "REGULAR"
            sessions.append((day, stype))
        day += timedelta(days=1)
    return sessions


def _is_holiday(day):
    y, m, dd = day.year, day.month, day.day
    if (m, dd) in [(1, 1), (7, 4), (12, 25), (1, 2)]:  # fixed-date closures
        return True
    # US Thanksgiving: 4th Thursday of November -> exchange closed
    if m == 11 and day.weekday() == 3 and 22 <= dd <= 28:
        return True
    # Good-Friday-ish spring closure: last Friday of March
    if m == 3 and day.weekday() == 4 and dd >= 25:
        return True
    return False


def _is_half_day(day):
    m, dd = day.month, day.day
    if (m, dd) == (12, 24) or (m, dd) == (7, 3):
        return True
    # Day after Thanksgiving (4th Friday of November)
    if m == 11 and day.weekday() == 4 and 23 <= dd <= 29:
        return True
    return False


# ---------------------------------------------------------------------------
# Dimension builders
# ---------------------------------------------------------------------------
def build_instruments(rng, cfg, sessions):
    """Create the instrument master and per-instrument simulation state.

    Reserved ids:
        1, 2                 -> twin names with scripted equal volume (rank ties)
        3, 4                 -> names with a scripted consecutive HALT window
        N-1, N               -> newly listed, never traded (empty groups / NOT IN)
    Returns (instruments_rows, sim) where sim holds mutable price/meta state.
    """
    n = cfg["instruments"]
    regime = cfg["regime"]
    last_date = sessions[-1][0]

    # Power-law popularity: shuffle ids, assign rank, weight = 1/rank^0.85.
    ids = list(range(1, n + 1))
    order = ids[:]
    rng.shuffle(order)
    rank = {iid: r + 1 for r, iid in enumerate(order)}
    raw = {iid: 1.0 / (rank[iid] ** 0.85) for iid in ids}
    # Force the twins to share an identical popularity weight.
    if n >= 2:
        raw[1] = raw[2] = raw.get(3, list(raw.values())[0])
    mean_w = sum(raw.values()) / n
    weight = {iid: min(raw[iid] / mean_w, 25.0) for iid in ids}

    untraded = set()
    if n >= 6:
        untraded = {n, n - 1}

    # Scripted halt window for ids 3 and 4 (a contiguous run of dark sessions).
    halt = {}
    if n >= 4 and len(sessions) >= 12:
        h0 = len(sessions) // 3
        h1 = min(len(sessions) - 2, h0 + max(4, len(sessions) // 10))
        halt[3] = (h0, h1)
        halt[4] = (h0 + 2, min(len(sessions) - 2, h1 + 3))

    rows = []
    sim = {}
    used_symbols = set()
    for iid in ids:
        sym = symbol_for(iid)
        while sym in used_symbols:
            sym = sym + "X"
        used_symbols.add(sym)
        sector = SECTORS[iid % len(SECTORS)]
        # NULL sector landmine: only outside the clean regime.
        if regime != "clean" and iid % 13 == 0 and iid not in (1, 2):
            sector = None
        currency = CURRENCIES[iid % len(CURRENCIES)]
        price0 = round(8 + (iid * 37 % 490) + rng.random() * 12, 2)
        vol = 0.006 + rng.random() * 0.02
        lot = rng.choice([1, 1, 10, 100])
        tick = rng.choice([0.01, 0.01, 0.005, 0.0001])

        if iid in untraded:
            # Newly listed near the end of the window; never trades.
            listing = last_date - timedelta(days=rng.randint(2, 10))
            status = "ACTIVE"
        else:
            listing = START_DATE - timedelta(days=rng.randint(30, 4000))
            status = "ACTIVE"
        delist = None

        rows.append([
            iid, sym, f"{sym} {NAME_SUFFIX[iid % len(NAME_SUFFIX)]}",
            sector, currency, dstr(listing),
            "" if delist is None else dstr(delist),
            d(tick, 5), lot, status, 1 if iid % 3 else 0,
        ])
        sim[iid] = dict(price=price0, vol=vol, tick=tick, lot=lot,
                        weight=weight[iid], currency=currency, sector=sector,
                        status=status)

    return rows, sim, untraded, halt


def build_accounts(rng, cfg, sim, untraded):
    """Create accounts and assign each a power-law-weighted portfolio.

    Reserved ids:
        1, 2 -> dedicated market makers for the twin names (accounts 1 and 2
                trade ONLY instruments 1 and 2 respectively, guaranteeing an
                account-level volume tie mirroring the instrument tie).
    Returns (accounts_rows, portfolios, holders, activity)
        portfolios[account_id]  -> list of instrument_ids the account trades
        holders[instrument_id]  -> list of (account_id, activity_weight)
        activity[account_id]    -> float trading intensity weight
    """
    n = cfg["accounts"]
    n_instr = cfg["instruments"]
    tradable = [i for i in range(1, n_instr + 1) if i not in untraded]
    weights = [sim[i]["weight"] for i in tradable]

    rows = []
    portfolios = {}
    activity = {}
    holders = {i: [] for i in range(1, n_instr + 1)}

    for aid in range(1, n + 1):
        atype = ACCT_TYPES[aid % len(ACCT_TYPES)]
        code = "AC" + str(aid).zfill(7)  # zero-padded -> string/number coercion trap
        region = REGIONS[aid % len(REGIONS)]
        base_ccy = "USD" if aid % 4 else rng.choice(["EUR", "GBP", "USD"])
        opened = START_DATE - timedelta(days=rng.randint(60, 3000))
        risk = 1 + (aid % 5)
        # Trading intensity: market makers and institutions are far busier.
        if atype == "MARKET_MAKER":
            act = 4.0 + rng.random() * 4
        elif atype == "INSTITUTIONAL":
            act = 1.5 + rng.random() * 3
        else:
            act = 0.3 + rng.random() * 1.2
        activity[aid] = act

        if aid == 1 and n_instr >= 1:
            portfolios[aid] = [1]
        elif aid == 2 and n_instr >= 2:
            portfolios[aid] = [2]
        else:
            size = 1 + poisson(rng, 3.0 if atype == "RETAIL" else 7.0)
            size = min(size, 30, len(tradable))
            portfolios[aid] = _weighted_sample(rng, tradable, weights, size)

        for iid in portfolios[aid]:
            holders[iid].append((aid, act))

        rows.append([aid, code, f"Account {aid} {atype.title()}",
                     atype, region, base_ccy, dstr(opened), risk])

    return rows, portfolios, holders, activity


def _weighted_sample(rng, items, weights, k):
    """Weighted sampling without replacement (deterministic given rng)."""
    pool = list(items)
    w = list(weights)
    chosen = []
    for _ in range(min(k, len(pool))):
        total = sum(w)
        if total <= 0:
            break
        r = rng.random() * total
        acc = 0.0
        pick = len(pool) - 1
        for idx, wi in enumerate(w):
            acc += wi
            if r <= acc:
                pick = idx
                break
        chosen.append(pool.pop(pick))
        w.pop(pick)
    return sorted(chosen)


def build_corporate_actions(rng, cfg, sim, sessions, untraded):
    """Pre-generate corporate actions keyed by ex-date session index."""
    n_instr = cfg["instruments"]
    regime = cfg["regime"]
    month_ends = [i for i in range(len(sessions)) if is_month_end(sessions, i)]
    if not month_ends:
        month_ends = [len(sessions) - 1]

    tradable = [i for i in range(1, n_instr + 1) if i not in untraded]
    n_actions = max(3, int(n_instr * 0.25))
    by_session = {}
    rows = []
    split_ratios = ["2:1", "3:1", "3:2", "4:1", "1:5", "1:10"]  # last two are reverse splits
    aid = 0
    for _ in range(n_actions):
        iid = rng.choice(tradable)
        # Skip the very earliest sessions so history exists before the action.
        cand = [m for m in month_ends if m >= 2]
        if not cand:
            cand = month_ends
        sidx = rng.choice(cand)
        ex_date = sessions[sidx][0]
        rtype = rng.random()
        if rtype < 0.5:
            atype = "DIVIDEND"
            split = None
            cash = round(0.05 + rng.random() * 2.4, 4)
            newsym = None
        elif rtype < 0.82:
            atype = "SPLIT"
            split = rng.choice(split_ratios)
            cash = None
            newsym = None
        else:
            atype = "SYMBOL_CHANGE"
            split = None
            cash = None
            newsym = symbol_for(iid) + "Z"
        aid += 1
        record_date = ex_date - timedelta(days=2)
        # announced_at usually precedes ex_date; at full regime a fraction is
        # retroactive (announced AFTER the ex-date) -> late-event landmine.
        if regime == "full" and rng.random() < 0.18:
            announced = datetime.combine(ex_date, datetime.min.time()) + timedelta(days=1, hours=15)
        else:
            announced = datetime.combine(ex_date, datetime.min.time()) - timedelta(days=rng.randint(5, 20))
            announced += timedelta(hours=9, minutes=rng.randint(0, 300))
        rows.append([aid, iid, atype, dstr(ex_date), dstr(record_date),
                     "" if split is None else split,
                     d(cash, 6) if cash is not None else "",
                     "" if newsym is None else newsym, ts(announced)])
        by_session.setdefault(sidx, []).append(
            dict(instrument_id=iid, type=atype, split=split, cash=cash))
    return rows, by_session


# ---------------------------------------------------------------------------
# Position book (bounded in-memory running state)
# ---------------------------------------------------------------------------
def apply_trade(book, key, signed_qty, price):
    """Average-cost position update. Returns realized pnl from this trade."""
    q, a, realized = book.get(key, (0, 0.0, 0.0))
    realized_delta = 0.0
    if q == 0 or (q > 0) == (signed_qty > 0):
        # opening or increasing magnitude in the same direction
        new_q = q + signed_qty
        new_a = (abs(q) * a + abs(signed_qty) * price) / (abs(q) + abs(signed_qty))
        book[key] = (new_q, new_a, realized)
    else:
        # reducing / closing / flipping
        closing = min(abs(q), abs(signed_qty))
        sign_q = 1 if q > 0 else -1
        realized_delta = closing * (price - a) * sign_q
        new_q = q + signed_qty
        if abs(signed_qty) > abs(q):  # flipped through zero
            book[key] = (new_q, price, realized + realized_delta)
        elif new_q == 0:
            book[key] = (0, 0.0, realized + realized_delta)
        else:
            book[key] = (new_q, a, realized + realized_delta)
    return realized_delta


# ---------------------------------------------------------------------------
# Main generation
# ---------------------------------------------------------------------------
def generate(seed, scale, out_dir):
    cfg = SCALES[scale]
    regime = cfg["regime"]
    rng = random.Random(seed)
    os.makedirs(out_dir, exist_ok=True)

    sessions = build_calendar(cfg["sessions"])
    instr_rows, sim, untraded, halt = build_instruments(rng, cfg, sessions)
    acct_rows, portfolios, holders, activity = build_accounts(rng, cfg, sim, untraded)
    ca_rows, ca_by_session = build_corporate_actions(rng, cfg, sim, sessions, untraded)

    # Open all CSV writers (RFC4180: minimal quoting, CRLF line endings).
    files = {}
    writers = {}
    for t in TABLES:
        fh = open(os.path.join(out_dir, f"{t}.csv"), "w", newline="",
                  encoding="utf-8")
        w = csv.writer(fh, quoting=csv.QUOTE_MINIMAL, lineterminator="\r\n")
        w.writerow(HEADERS[t])
        files[t] = fh
        writers[t] = w

    # Static dimensions first.
    for r in instr_rows:
        writers["instruments"].writerow(r)
    for r in acct_rows:
        writers["accounts"].writerow(r)
    for r in ca_rows:
        writers["corporate_actions"].writerow(r)
    for idx, (sday, stype) in enumerate(sessions):
        midnight = datetime.combine(sday, datetime.min.time())
        opent = midnight + timedelta(hours=9, minutes=30)
        closet = midnight + timedelta(hours=(13 if stype == "HALF_DAY" else 16))
        writers["trading_days"].writerow(
            [dstr(sday), idx + 1, stype, ts(opent), ts(closet)])

    n_instr = cfg["instruments"]
    order_seq = 0
    fill_seq = 0
    quote_seq = 0
    pos_seq = 0
    book = {}                 # (account_id, instrument_id) -> (qty, avg_cost, realized)
    touched_month = set()     # pairs traded in the current month
    eod_mid = {}              # instrument_id -> last mid price seen today
    last_order = {}           # (account_id, instrument_id) -> most recent order_id

    tradable_ids = [i for i in range(1, n_instr + 1) if i not in untraded]

    for idx, (sday, stype) in enumerate(sessions):
        day_open = datetime.combine(sday, datetime.min.time()) + timedelta(hours=9, minutes=30)
        half = (stype == "HALF_DAY")
        # weekday / seasonal activity multiplier, centred near 1.0
        wd = sday.weekday()
        wd_factor = [1.15, 1.0, 0.95, 1.0, 1.1][wd]
        seas = 1.0 + 0.12 * math.sin((sday.month - 1) / 12.0 * 2 * math.pi)
        day_factor = wd_factor * seas * (0.6 if half else 1.0)

        # --- apply corporate actions effective this ex-date ---
        for act in ca_by_session.get(idx, []):
            iid = act["instrument_id"]
            if act["type"] == "SPLIT" and act["split"]:
                a, b = act["split"].split(":")
                mult = float(a) / float(b)  # a-for-b: shares scale by a/b, price by b/a
                sim[iid]["price"] = sim[iid]["price"] / mult
                for key in list(book.keys()):
                    if key[1] == iid:
                        q, ac, rl = book[key]
                        book[key] = (int(round(q * mult)), ac / mult, rl)
            elif act["type"] == "DIVIDEND" and act["cash"] is not None:
                for key in list(book.keys()):
                    if key[1] == iid:
                        q, ac, rl = book[key]
                        book[key] = (q, ac, rl + q * act["cash"])

        # --- price random walk for the day ---
        eod_mid = {}
        for iid in range(1, n_instr + 1):
            s = sim[iid]
            z = rng.gauss(0, 1)
            s["price"] = max(0.5, s["price"] * math.exp(-0.5 * s["vol"] ** 2 + s["vol"] * z))

        # --- quotes (top of book) ---
        for iid in range(1, n_instr + 1):
            if iid in untraded and rng.random() < 0.7:
                continue  # untraded names are only thinly quoted
            in_halt = _in_halt(halt, iid, idx)
            base = sim[iid]["price"]
            tick = sim[iid]["tick"]
            nq = poisson(rng, cfg["quotes_rate"] * min(sim[iid]["weight"], 6) * day_factor + 0.4)
            nq = max(1, nq)
            last_mid = None
            for _ in range(nq):
                qmid = base * (1 + rng.gauss(0, sim[iid]["vol"] * 0.4))
                spr = max(tick, qmid * (0.0004 + rng.random() * 0.0025))
                bid = _round_tick(qmid - spr / 2, tick)
                ask = _round_tick(qmid + spr / 2, tick)
                bsize = rng.choice([1, 2, 3, 5, 8, 10]) * sim[iid]["lot"] * 100
                asize = rng.choice([1, 2, 3, 5, 8, 10]) * sim[iid]["lot"] * 100
                bid_out, ask_out = bid, ask

                # ---- landmines on quotes ----
                if regime != "clean":
                    # one-sided book: zero size on a side (division-by-zero setup)
                    if rng.random() < (0.03 if regime == "full" else 0.012):
                        if rng.random() < 0.5:
                            bsize = 0
                        else:
                            asize = 0
                    # missing side price (NULL) very occasionally
                    if rng.random() < (0.010 if regime == "full" else 0.004):
                        if rng.random() < 0.5:
                            bid_out = None
                        else:
                            ask_out = None
                if regime == "full":
                    # crossed / locked book: bid >= ask (bad market data)
                    if rng.random() < 0.02 and bid_out is not None and ask_out is not None:
                        ask_out = _round_tick(min(ask, bid), tick)
                if in_halt:
                    bsize = asize = 0  # halted: no liquidity

                qtime = day_open + timedelta(seconds=rng.randint(0, 22000 if not half else 11000))
                quote_seq += 1
                writers["quotes"].writerow([
                    quote_seq, iid, ts(qtime), d(bid_out, 6), bsize,
                    d(ask_out, 6), asize, dstr(sday)])
                if bid_out is not None and ask_out is not None and ask_out > bid_out:
                    last_mid = (bid_out + ask_out) / 2

                # duplicate quote landmine (replayed tick): re-emit same values
                if regime != "clean" and rng.random() < (0.02 if regime == "full" else 0.008):
                    quote_seq += 1
                    writers["quotes"].writerow([
                        quote_seq, iid, ts(qtime), d(bid_out, 6), bsize,
                        d(ask_out, 6), asize, dstr(sday)])
            if last_mid is not None:
                eod_mid[iid] = last_mid

        # --- twin instruments: scripted identical volume for the rank tie ---
        if n_instr >= 2 and not half:
            twin_count = 2 + poisson(rng, 1.3 * day_factor)
            twin_qtys = [rng.choice([1, 2, 3, 5]) * 100 for _ in range(twin_count)]
            for twin_iid, twin_acct in ((1, 1), (2, 2)):
                if _in_halt(halt, twin_iid, idx):
                    continue
                base = sim[twin_iid]["price"]
                order_seq += 1
                parent_id = order_seq
                oqty = sum(twin_qtys)
                otime = day_open + timedelta(seconds=rng.randint(1, 3000))
                writers["orders"].writerow([
                    parent_id, twin_acct, twin_iid, "BUY", "LIMIT",
                    d(_round_tick(base * 1.001, sim[twin_iid]["tick"]), 6), oqty,
                    "DAY", "FILLED", ts(otime), ts(otime + timedelta(seconds=90)),
                    dstr(sday), ""])
                for q in twin_qtys:
                    price = _round_tick(base * (1 + rng.gauss(0, 0.0006)), sim[twin_iid]["tick"])
                    ftime = otime + timedelta(seconds=rng.randint(1, 120))
                    fill_seq += 1
                    writers["fills"].writerow([
                        fill_seq, parent_id, twin_iid, twin_acct, "BUY",
                        d(price, 6), q, ts(ftime), "TAKER",
                        VENUES[fill_seq % len(VENUES)], d(0.0003 * q * price, 6),
                        dstr(sday)])
                    apply_trade(book, (twin_acct, twin_iid), q, price)
                    touched_month.add((twin_acct, twin_iid))

        # --- ordinary order / fill generation, per instrument ---
        for iid in tradable_ids:
            if iid in (1, 2):
                continue  # handled by the scripted twin path
            if _in_halt(halt, iid, idx):
                continue  # halted -> no trading (gaps / islands)
            hold = holders.get(iid, [])
            if not hold:
                continue
            lam = cfg["fills_rate"] / 1.28 * min(sim[iid]["weight"], 22) * day_factor
            n_orders = poisson(rng, lam)
            base = sim[iid]["price"]
            tick = sim[iid]["tick"]
            lot = sim[iid]["lot"]
            hold_ids = [h[0] for h in hold]
            hold_w = [h[1] for h in hold]
            tot_w = sum(hold_w)
            for _ in range(n_orders):
                # choose account weighted by trading intensity
                r = rng.random() * tot_w
                acc = 0.0
                aid = hold_ids[-1]
                for j, wj in enumerate(hold_w):
                    acc += wj
                    if r <= acc:
                        aid = hold_ids[j]
                        break
                side = "BUY" if rng.random() < 0.5 else "SELL"
                signed = 1 if side == "BUY" else -1
                otype = rng.choices(["LIMIT", "MARKET", "STOP"], weights=[70, 25, 5])[0]
                qty = max(lot, rng.choice([1, 1, 2, 3, 5, 10]) * lot * rng.choice([1, 1, 1, 2]))
                tif = rng.choice(TIF)
                limit_price = None
                if otype != "MARKET":
                    off = rng.gauss(0, 0.004)
                    limit_price = _round_tick(base * (1 + off), tick)
                created = day_open + timedelta(seconds=rng.randint(1, 22000 if not half else 11000))

                order_seq += 1
                oid = order_seq
                # parent_order_id: NULL for top-level; in dirty regimes a small
                # share are child / routed slices of an earlier order for the
                # same (account, instrument) -> self-FK with mostly-NULL column.
                parent = ""
                prev = last_order.get((aid, iid))
                if regime != "clean" and prev is not None and \
                        rng.random() < (0.07 if regime == "full" else 0.03):
                    parent = prev
                last_order[(aid, iid)] = oid
                # fan-out: how many fills this order produces (0 => no execution)
                if rng.random() < 0.8:
                    nf = 1 + poisson(rng, 0.6)
                    status = "FILLED" if rng.random() < 0.7 else "PARTIAL"
                else:
                    nf = 0
                    status = "CANCELLED" if rng.random() < 0.6 else "REJECTED"

                remaining = qty
                last_fill_time = created
                for fi in range(nf):
                    if remaining <= 0:
                        break
                    fq = remaining if fi == nf - 1 else max(lot, int(remaining * rng.uniform(0.3, 0.9)))
                    fq = min(fq, remaining)
                    remaining -= fq
                    # execution price: near limit/mid with slippage
                    px = base * (1 + rng.gauss(0, 0.0018))
                    if limit_price is not None:
                        # taker crosses through, maker rests at limit
                        px = limit_price if rng.random() < 0.4 else px
                    price = _round_tick(max(tick, px), tick)
                    ftime = created + timedelta(seconds=rng.randint(1, 300))

                    # ---- late / out-of-order landmine ----
                    if regime != "clean" and rng.random() < (0.03 if regime == "full" else 0.012):
                        # fill stamped BEFORE its order (clock skew / late report)
                        ftime = created - timedelta(seconds=rng.randint(5, 900))
                    if regime == "full" and rng.random() < 0.015:
                        # fill timestamp bleeds across midnight while session_date stays
                        ftime = datetime.combine(sday, datetime.min.time()) + timedelta(days=1, seconds=rng.randint(60, 3600))

                    liq = "MAKER" if (limit_price is not None and rng.random() < 0.55) else "TAKER"
                    fee = (-0.0001 if liq == "MAKER" else 0.0003) * fq * price
                    last_fill_time = max(last_fill_time, ftime)
                    fill_seq += 1
                    writers["fills"].writerow([
                        fill_seq, oid, iid, aid, side, d(price, 6), fq, ts(ftime),
                        liq, VENUES[fill_seq % len(VENUES)], d(fee, 6), dstr(sday)])
                    # true position update (duplicates below are NOT applied)
                    apply_trade(book, (aid, iid), signed * fq, price)
                    touched_month.add((aid, iid))

                    # ---- duplicate fill landmine (double-booked report) ----
                    if regime == "full" and rng.random() < 0.012:
                        fill_seq += 1
                        writers["fills"].writerow([
                            fill_seq, oid, iid, aid, side, d(price, 6), fq, ts(ftime),
                            liq, VENUES[fill_seq % len(VENUES)], d(fee, 6), dstr(sday)])
                        # deliberately NOT applied to the book -> dedup required

                writers["orders"].writerow([
                    oid, aid, iid, side, otype,
                    "" if limit_price is None else d(limit_price, 6), qty, tif,
                    status, ts(created), ts(max(created, last_fill_time)),
                    dstr(sday), parent])

        # --- month reset bookkeeping for corporate-action months etc. ---
        if is_month_end(sessions, idx):
            _emit_positions(writers, book, touched_month, eod_mid, sday,
                            lambda: _next(pos_counter), rng, regime)
            pos_seq = pos_counter[0]
            touched_month = set()


# helper mutable counter for position ids (kept simple + deterministic)
pos_counter = [0]


def _next(counter):
    counter[0] += 1
    return counter[0]


def _emit_positions(writers, book, touched, eod_mid, sday, nextid, rng, regime):
    for key in sorted(touched):
        aid, iid = key
        q, a, realized = book.get(key, (0, 0.0, 0.0))
        mark = eod_mid.get(iid)
        if q == 0:
            avg_cost = None
            unreal = None
        else:
            avg_cost = a
            unreal = q * (mark - a) if mark is not None else None
        row = [aid, iid, dstr(sday), q, d(avg_cost, 6),
               d(mark, 6) if mark is not None else "", d(realized, 4),
               d(unreal, 4) if unreal is not None else ""]
        writers["positions"].writerow([nextid()] + row)
        # duplicate-row landmine: rare double-posted EOD snapshot (new
        # position_id, identical business key) at full-landmine scales.
        if regime == "full" and rng.random() < 0.008:
            writers["positions"].writerow([nextid()] + row)


def _in_halt(halt, iid, idx):
    if iid not in halt:
        return False
    lo, hi = halt[iid]
    return lo <= idx <= hi


def _round_tick(price, tick):
    if tick <= 0:
        return round(price, 6)
    return round(round(price / tick) * tick, 6)


def main():
    ap = argparse.ArgumentParser(description="TickForge dataset generator")
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--scale", choices=list(SCALES.keys()), required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    # reset module-level counter so repeated in-process calls stay deterministic
    pos_counter[0] = 0
    generate(args.seed, args.scale, args.out)


if __name__ == "__main__":
    main()
