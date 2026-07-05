#!/usr/bin/env python3
"""
CartHive universe -- deterministic, seeded data generator for DataDojo.

Emits one RFC4180 CSV per table (categories, sellers, products, customers,
orders, order_items, returns, events) into an output directory.

Usage:
    python3 generator.py --seed N --scale {sample|blue|purple|black|red} --out DIR

Design guarantees
-----------------
* Deterministic: identical (seed, scale) => byte-identical CSVs. All randomness
  flows from a single random.Random(seed); no global random, no clock reads.
* Memory-safe at every scale: dimension tables (categories, sellers, products)
  are held in memory (tens of MB at most); the large fact tables (orders,
  order_items, returns, events) are streamed row-by-row to disk and never
  accumulated in a list.
* Pure standard library (random, csv, datetime, math, argparse, os).

Landmines planted (see universe.md for the mapping to CONTENT-SPEC families):
  NULLs in meaningful columns, duplicate line/event rows, ranking ties (shared
  price points, small equal sale counts), boundary dates (Feb 29 2024, month
  ends, year rollover), late / out-of-order events, partial-return fan-out,
  zero-denominator groups (dormant customers, sale-less sellers/categories,
  return-less months). A handful of small-index customers carry *forced* plants
  so every landmine is present even at `sample` scale.
"""

import argparse
import csv
import datetime as dt
import math
import os
import random

# --------------------------------------------------------------------------- #
# Simulation window
# --------------------------------------------------------------------------- #
START_DATE = dt.date(2022, 1, 1)
END_DATE = dt.date(2024, 12, 31)          # includes leap day 2024-02-29
SIM_DAYS = (END_DATE - START_DATE).days
RETURN_MAX_DATE = dt.date(2025, 2, 28)    # returns may trail the sales window

# --------------------------------------------------------------------------- #
# Per-scale dimension sizes. Fact tables (orders/items/returns/events) are
# derived stochastically per customer, so they stay proportional automatically.
# Row-count budgets (approx totals): sample ~600, blue <50k, purple <500k,
# black 1M-5M largest fact, red 5M-10M largest fact.
# --------------------------------------------------------------------------- #
SCALES = {
    "sample": dict(customers=40,     sellers=10,    categories=18,  products=80),
    "blue":   dict(customers=3000,   sellers=120,   categories=48,  products=1500),
    "purple": dict(customers=30000,  sellers=1200,  categories=64,  products=15000),
    "black":  dict(customers=250000, sellers=10000, categories=90,  products=120000),
    "red":    dict(customers=900000, sellers=30000, categories=120, products=400000),
}

# Shared price points => many products share a price => guaranteed ranking ties.
PRICE_POINTS = [
    4.99, 7.99, 9.99, 12.99, 14.99, 19.99, 24.99, 29.99, 39.99, 49.99,
    59.99, 79.99, 99.99, 129.99, 149.99, 199.99, 249.99, 299.99,
]

DEPARTMENTS = [
    "Electronics", "Home & Kitchen", "Apparel", "Sports & Outdoors",
    "Beauty", "Toys & Games", "Books & Media", "Grocery",
    "Automotive", "Garden", "Office", "Pet Supplies",
]
SUB_WORDS = [
    "Accessories", "Essentials", "Pro", "Basics", "Deluxe", "Compact",
    "Everyday", "Premium", "Starter", "Ultra", "Classic", "Eco",
    "Portable", "Smart", "Value", "Signature",
]
ADJ = ["Rapid", "Silent", "Solar", "Nordic", "Urban", "Vivid", "Mellow",
       "Brisk", "Cobalt", "Amber", "Nimble", "Lucid", "Ember", "Quartz"]
NOUN = ["Kettle", "Lamp", "Charger", "Bottle", "Backpack", "Mixer", "Speaker",
        "Blanket", "Sensor", "Wallet", "Tripod", "Router", "Planter", "Mug"]

CHANNELS = ["organic", "paid_search", "social", "referral", "email"]
CHANNEL_W = [40, 22, 18, 10, 10]
COUNTRIES = ["US", "GB", "DE", "FR", "CA", "AU", "IN", "BR", "JP", "MX"]
COUNTRY_W = [45, 12, 9, 8, 7, 5, 5, 4, 3, 2]
PAYMENTS = ["card", "paypal", "wallet", "giftcard"]
PAYMENT_W = [58, 24, 12, 6]
ORDER_STATUS = ["delivered", "shipped", "paid", "placed", "cancelled", "refunded"]
ORDER_STATUS_W = [62, 12, 9, 6, 6, 5]
RETURN_REASONS = ["defective", "wrong_item", "too_small", "too_large",
                  "not_as_described", "changed_mind", "damaged_in_transit",
                  "late_delivery"]
SELLER_STATUS = ["active", "suspended", "closed"]
SELLER_STATUS_W = [86, 9, 5]

# --------------------------------------------------------------------------- #
# Formatting helpers (None -> empty field is handled by csv automatically).
# --------------------------------------------------------------------------- #
def d_iso(d):
    return d.isoformat()


def ts_iso(t):
    return t.strftime("%Y-%m-%d %H:%M:%S")


def money(x):
    # Fixed 2dp string so DECIMAL columns are byte-stable across runs.
    return "%.2f" % (x + 0.0)


def day_of(offset):
    return START_DATE + dt.timedelta(days=offset)


def rand_time(rng):
    return dt.time(rng.randint(0, 23), rng.randint(0, 59), rng.randint(0, 59))


# --------------------------------------------------------------------------- #
# Dimension builders (held in memory; written eagerly).
# --------------------------------------------------------------------------- #
def build_categories(rng, n, writer):
    """Return (leaf_ids, empty_leaf_ids). Departments have NULL parent_id."""
    n_dept = max(4, min(12, n // 6))
    n_dept = min(n_dept, len(DEPARTMENTS))
    rows = []
    dept_ids = []
    for i in range(n_dept):
        cid = i + 1
        dept_ids.append(cid)
        rows.append((cid, None, DEPARTMENTS[i]))
    leaf_ids = []
    for i in range(n_dept, n):
        cid = i + 1
        parent = rng.choice(dept_ids)
        name = DEPARTMENTS[parent - 1].split(" ")[0] + " " + rng.choice(SUB_WORDS)
        rows.append((cid, parent, name))
        leaf_ids.append(cid)
    # Guarantee at least a couple of product-less leaf categories (empty groups).
    empty_leaves = set()
    if len(leaf_ids) >= 4:
        empty_leaves = {leaf_ids[-1], leaf_ids[-2]}
    for r in rows:
        writer.writerow(r)
    stockable = [c for c in leaf_ids if c not in empty_leaves]
    return stockable, empty_leaves


def build_sellers(rng, n, writer):
    ids = []
    for i in range(n):
        sid = i + 1
        name = "%s %s Co" % (rng.choice(ADJ), rng.choice(NOUN))
        country = rng.choices(COUNTRIES, COUNTRY_W)[0]
        joined = day_of(int(SIM_DAYS * (rng.random() ** 1.1)))
        status = rng.choices(SELLER_STATUS, SELLER_STATUS_W)[0]
        writer.writerow((sid, name, country, d_iso(joined), status))
        ids.append(sid)
    return ids


def build_products(rng, n, seller_ids, leaf_ids, writer):
    """Products are index-ordered by popularity (index 0 = most popular)."""
    products = []
    for i in range(n):
        pid = i + 1
        seller_id = rng.choice(seller_ids)
        category_id = rng.choice(leaf_ids)
        title = "%s %s" % (rng.choice(ADJ), rng.choice(NOUN))
        list_price = rng.choices(PRICE_POINTS, k=1)[0]
        launch = day_of(int(SIM_DAYS * (rng.random() ** 1.3)))
        is_active = 0 if rng.random() < 0.08 else 1
        writer.writerow((pid, seller_id, category_id, title,
                         money(list_price), d_iso(launch), is_active))
        # keep only what item generation needs
        products.append((pid, seller_id, list_price))
    return products


# --------------------------------------------------------------------------- #
# Forced plants: keyed by customer index so every landmine exists at sample.
# Values are lists of (year, month, day) that MUST become a purchasing session.
# --------------------------------------------------------------------------- #
FORCED_PURCHASE_DATES = {
    0: [(2024, 2, 29)],                                  # leap day
    1: [(2023, 12, 31)],                                 # year end + dup line
    2: [(2023, 1, 31)],                                  # month end + guest order
    3: [(2023, 11, 15), (2023, 12, 20),                  # consecutive-month streak
        (2024, 1, 10), (2024, 2, 14)],                   #   crossing a year boundary
}
FORCED_ANON_IDX = 4        # an anonymous browsing session
FORCED_OOO_IDX = 5         # a session with out-of-order event timestamps
FORCED_DORMANT_IDX = 6     # signed up, never active


class Counters:
    __slots__ = ("order", "item", "ret", "event", "session")

    def __init__(self):
        self.order = 0
        self.item = 0
        self.ret = 0
        self.event = 0
        self.session = 0


def sample_product(rng, products, pop_exp=2.0):
    n = len(products)
    idx = int(n * (rng.random() ** pop_exp))
    if idx >= n:
        idx = n - 1
    return products[idx]


def gen_returns(rng, cnt, item_id, quantity, unit_price, order_ts, w_returns, forced):
    """Emit 0..k return rows for one order line. Fan-out + NULL reason + late ts."""
    if not forced and rng.random() >= 0.065:
        return
    remaining = quantity
    # Full or partial first return.
    parts = 1
    if quantity >= 2 and (forced or rng.random() < 0.30):
        parts = 2                       # multi-part partial return => fan-out
    for p in range(parts):
        if remaining <= 0:
            break
        if p == parts - 1:
            qret = remaining
        else:
            qret = rng.randint(1, max(1, remaining - 1))
        remaining -= qret
        # Late / out-of-order: a small share of returns predate their order.
        if (forced and p == 0) or rng.random() < 0.02:
            delta = -rng.randint(1, 3)
        else:
            delta = rng.randint(1, 40)
        rts = order_ts + dt.timedelta(days=delta, seconds=rng.randint(0, 86399))
        if rts.date() > RETURN_MAX_DATE:
            rts = dt.datetime.combine(RETURN_MAX_DATE, rand_time(rng))
        reason = None if (forced and p == 0) or rng.random() < 0.40 \
            else rng.choice(RETURN_REASONS)
        refund = round(unit_price * qret, 2)
        cnt.ret += 1
        w_returns.writerow((cnt.ret, item_id, ts_iso(rts), reason, qret,
                            money(refund)))


def gen_order(rng, cust_id, purchase_dt, focus_product, products, cust_country,
              cnt, w_orders, w_items, w_returns, forced_dup, force_guest=False,
              anchor=False):
    """Create one order + its line items + returns. Returns the order_id."""
    cnt.order += 1
    order_id = cnt.order
    # Guest checkout: a small share of orders carry no customer link. Forced
    # "anchor" orders (boundary-date/streak plants) never randomly go guest, so
    # their landmines stay attributable to the planted customer.
    guest = force_guest or ((not anchor) and rng.random() < 0.03)
    o_customer = None if guest else cust_id
    status = rng.choices(ORDER_STATUS, ORDER_STATUS_W)[0]
    # ship_country usually matches the customer; occasionally differs or missing.
    if cust_country is None or rng.random() < 0.15:
        ship_country = rng.choices(COUNTRIES, COUNTRY_W)[0]
    else:
        ship_country = cust_country
    if rng.random() < 0.02:
        ship_country = None
    payment = None if rng.random() < 0.05 else rng.choices(PAYMENTS, PAYMENT_W)[0]
    shipping = 0.0 if rng.random() < 0.45 else round(rng.uniform(2.5, 12.5), 2)
    w_orders.writerow((order_id, o_customer, ts_iso(purchase_dt), status,
                       ship_country, payment, money(shipping)))

    # Line items: focus product first, then a skewed number of extras.
    n_items = 1
    while rng.random() < 0.55 and n_items < 12:
        n_items += 1
    line_products = [focus_product]
    for _ in range(n_items - 1):
        line_products.append(sample_product(rng, products))

    for j, prod in enumerate(line_products):
        pid, seller_id, list_price = prod
        # unit_price: usually the list price, sometimes a promo price point.
        if rng.random() < 0.25:
            unit_price = rng.choices(PRICE_POINTS, k=1)[0]
            if unit_price > list_price:
                unit_price = list_price
        else:
            unit_price = list_price
        quantity = 1
        while rng.random() < 0.30 and quantity < 6:
            quantity += 1
        # The forced-plant anchor line must carry a multi-part (partial) return,
        # which requires at least two units. Guarantee it seed-independently.
        if forced_dup and j == 0 and quantity < 2:
            quantity = 2
        # discount NULL most of the time; a real amount sometimes.
        if rng.random() < 0.72:
            discount = None
        else:
            discount = round(unit_price * quantity * rng.choice([0.05, 0.10, 0.15, 0.20]), 2)
        cnt.item += 1
        item_id = cnt.item
        w_items.writerow((item_id, order_id, pid, seller_id, quantity,
                          money(unit_price),
                          None if discount is None else money(discount)))
        gen_returns(rng, cnt, item_id, quantity, unit_price, purchase_dt,
                    w_returns, forced=(forced_dup and j == 0))
        # Duplicate line row: same (order_id, product_id) as a second line.
        if (forced_dup and j == 0) or rng.random() < 0.02:
            cnt.item += 1
            dup_id = cnt.item
            w_items.writerow((dup_id, order_id, pid, seller_id, quantity,
                              money(unit_price),
                              None if discount is None else money(discount)))
    return order_id


def gen_session(rng, cust_id, sess_date, products, cust_country, cnt,
                writers, force_purchase=False, anonymous=False,
                out_of_order=False, forced_dup=False, force_guest=False):
    """Emit a funnel session's events, and an order when it converts."""
    w_orders, w_items, w_returns, w_events = writers
    cnt.session += 1
    session_id = cnt.session
    ev_customer = None if anonymous else cust_id

    focus = sample_product(rng, products)
    # Build the logical funnel first; timestamps assigned afterwards.
    stages = []  # (event_type, product_id)
    if rng.random() < 0.20:
        stages.append(("view", None))            # homepage / non-product view
    stages.append(("view", focus[0]))
    for _ in range(rng.randint(0, 2)):
        stages.append(("view", sample_product(rng, products)[0]))

    do_cart = force_purchase or rng.random() < 0.60
    do_checkout = do_cart and (force_purchase or rng.random() < 0.80)
    do_purchase = (not anonymous) and do_checkout and (force_purchase or rng.random() < 0.85)

    purchase_index = None
    if do_cart:
        stages.append(("add_to_cart", focus[0]))
        # Analytics double-fire: duplicate add_to_cart row.
        if rng.random() < 0.10:
            stages.append(("add_to_cart", focus[0]))
    checkout_index = None
    if do_checkout:
        checkout_index = len(stages)
        stages.append(("checkout", focus[0]))
    if do_purchase:
        purchase_index = len(stages)
        stages.append(("purchase", focus[0]))

    # Assign timestamps increasing in logical funnel order. For an out-of-order
    # session, guarantee a detectable inversion: swap checkout<->purchase when
    # both exist (purchase ends up timestamped before checkout), else swap an
    # adjacent pair. So ordering events by ts no longer follows the funnel.
    base = dt.datetime.combine(sess_date, rand_time(rng))
    times = []
    cur = base
    for _ in range(len(stages)):
        times.append(cur)
        cur = cur + dt.timedelta(seconds=rng.randint(20, 600))
    if out_of_order and len(stages) >= 2:
        if purchase_index is not None and checkout_index is not None:
            times[purchase_index], times[checkout_index] = \
                times[checkout_index], times[purchase_index]
        else:
            i = rng.randint(0, len(stages) - 2)
            times[i], times[i + 1] = times[i + 1], times[i]

    order_id = None
    if do_purchase:
        purchase_dt = times[purchase_index]
        order_id = gen_order(rng, cust_id, purchase_dt, focus, products,
                             cust_country, cnt, w_orders, w_items, w_returns,
                             forced_dup, force_guest=force_guest,
                             anchor=force_purchase)

    for k, (etype, pid) in enumerate(stages):
        cnt.event += 1
        oid = order_id if etype == "purchase" else None
        w_events.writerow((cnt.event, session_id, ev_customer, pid, etype,
                           ts_iso(times[k]), oid))


def gen_customer(rng, idx, products, cnt, writers, w_customers):
    cust_id = idx + 1
    forced_dates = FORCED_PURCHASE_DATES.get(idx)

    # Attributes (NULL-bearing). Forced-plant customers get an early signup so
    # their forced boundary purchases are always valid.
    if forced_dates is not None:
        signup = dt.date(2022, 1, 10)
    else:
        signup = day_of(int(SIM_DAYS * (rng.random() ** 0.85)))
    country = None if rng.random() < 0.04 else rng.choices(COUNTRIES, COUNTRY_W)[0]
    channel = None if rng.random() < 0.08 else rng.choices(CHANNELS, CHANNEL_W)[0]
    birth_year = None if rng.random() < 0.12 else rng.randint(1955, 2005)
    # Seed-independent guarantees so the NULL-attribute landmines are present even
    # at sample scale (the RNG draws above still happen -> stream is unchanged).
    if idx == 0:
        country = None
    if idx == 1:
        channel = None
    if idx == 2:
        birth_year = None
    w_customers.writerow((cust_id, d_iso(signup), country, channel, birth_year))

    if idx == FORCED_DORMANT_IDX:
        return                                    # signed up, never active

    # Forced boundary-date purchasing sessions.
    if forced_dates:
        for (y, m, d) in forced_dates:
            gen_session(rng, cust_id, dt.date(y, m, d), products, country, cnt,
                        writers, force_purchase=True,
                        forced_dup=(idx == 1),      # idx 1 also plants a dup line
                        force_guest=(idx == 2))     # idx 2's order is a guest order

    # Dormant share: signed up but no browsing at all.
    if forced_dates is None and rng.random() < 0.10:
        return

    days_avail = (END_DATE - signup).days
    if days_avail < 0:
        days_avail = 0

    n_sessions = 1
    while rng.random() < 0.62 and n_sessions < 18:
        n_sessions += 1

    for s in range(n_sessions):
        off = rng.randint(0, days_avail) if days_avail > 0 else 0
        sess_date = signup + dt.timedelta(days=off)
        # Forced out-of-order plant: this session must convert so the funnel
        # timestamp inversion (purchase before checkout) is guaranteed present.
        force_p = (idx == FORCED_OOO_IDX and s == 0)
        anon = False if force_p else \
            ((idx == FORCED_ANON_IDX and s == 0) or rng.random() < 0.05)
        ooo = force_p or rng.random() < 0.05
        gen_session(rng, cust_id, sess_date, products, country, cnt,
                    writers, anonymous=anon, out_of_order=ooo,
                    force_purchase=force_p)


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #
HEADERS = {
    "categories": ["category_id", "parent_id", "name"],
    "sellers": ["seller_id", "seller_name", "country", "joined_date", "status"],
    "products": ["product_id", "seller_id", "category_id", "title",
                 "list_price", "launch_date", "is_active"],
    "customers": ["customer_id", "signup_date", "country",
                  "acquisition_channel", "birth_year"],
    "orders": ["order_id", "customer_id", "order_ts", "status",
               "ship_country", "payment_method", "shipping_fee"],
    "order_items": ["order_item_id", "order_id", "product_id", "seller_id",
                    "quantity", "unit_price", "discount"],
    "returns": ["return_id", "order_item_id", "return_ts", "reason",
                "quantity_returned", "refund_amount"],
    "events": ["event_id", "session_id", "customer_id", "product_id",
               "event_type", "event_ts", "order_id"],
}


def open_writer(out_dir, table, handles):
    f = open(os.path.join(out_dir, table + ".csv"), "w", newline="", encoding="utf-8")
    handles.append(f)
    w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator="\r\n")
    w.writerow(HEADERS[table])
    return w


def generate(seed, scale, out_dir):
    if scale not in SCALES:
        raise SystemExit("unknown scale: %s" % scale)
    os.makedirs(out_dir, exist_ok=True)
    params = SCALES[scale]
    rng = random.Random(seed)
    handles = []
    try:
        w_categories = open_writer(out_dir, "categories", handles)
        w_sellers = open_writer(out_dir, "sellers", handles)
        w_products = open_writer(out_dir, "products", handles)
        w_customers = open_writer(out_dir, "customers", handles)
        w_orders = open_writer(out_dir, "orders", handles)
        w_items = open_writer(out_dir, "order_items", handles)
        w_returns = open_writer(out_dir, "returns", handles)
        w_events = open_writer(out_dir, "events", handles)

        # Dimensions (order fixed so the RNG stream is stable).
        leaf_ids, _empty = build_categories(rng, params["categories"], w_categories)
        seller_ids = build_sellers(rng, params["sellers"], w_sellers)
        products = build_products(rng, params["products"], seller_ids, leaf_ids,
                                  w_products)

        cnt = Counters()
        writers = (w_orders, w_items, w_returns, w_events)
        for idx in range(params["customers"]):
            gen_customer(rng, idx, products, cnt, writers, w_customers)
    finally:
        for f in handles:
            f.close()


def main():
    ap = argparse.ArgumentParser(description="CartHive deterministic data generator")
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--scale", required=True, choices=list(SCALES.keys()))
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    generate(args.seed, args.scale, args.out)


if __name__ == "__main__":
    main()
