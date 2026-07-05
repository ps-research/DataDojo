# TickForge — universe design

| | |
|---|---|
| **Slug** | `tickforge` |
| **Theme** | Electronic securities exchange / order-book: instruments, quotes, orders, fills, positions, corporate actions, PnL |
| **Problem budget** | Blue 1 · Purple 2 · Black 2 · Red 2 (7 total; 2 Reds — the quant crown jewel) |
| **Largest fact table** | `fills` (executions) |
| **Generator** | `generator.py` — pure stdlib, deterministic, streaming |

---

## 1. Narrative

TickForge is a mid-sized electronic exchange and the clearing tape that runs
beneath it. Every weekday morning the matching engine wakes, the calendar
decides whether the doors open at all, and a few hundred to a few hundred
thousand accounts — retail dabblers, institutional desks, and a handful of
tireless market makers — begin firing orders at a book of listed names. Orders
rest, cross, partially fill, get cancelled or rejected; each execution prints a
*fill* to the tape with a price, a size, a venue, and a fee that is sometimes a
rebate. Above the book, a market-data feed publishes top-of-book *quotes* —
best bid, best offer, and the sizes behind them — many times a second. The feed
is not clean: sizes go to zero when one side pulls, prices occasionally cross,
and the odd tick is replayed twice.

Underneath the noise the exchange must keep an honest set of books. A risk
system snapshots every account's net position at each month's close — signed
inventory, average cost, the end-of-day mark, realized and unrealized PnL — and
those snapshots have to tie out against what actually traded. They frequently do
not, because the world is messy: a fill is stamped a few seconds *before* the
order that spawned it when two clocks disagree; a late report lands just after
midnight but belongs to yesterday's session; a stock splits three-for-one and
every pre-split share count and cost basis has to be re-based on the ex-date; a
dividend pays the holders of record, not whoever happens to hold it when the
cash arrives. Corporate actions are sometimes announced *after* the ex-date they
apply to, which is exactly the kind of thing that quietly poisons a naive query.

TickForge is the universe where analytical discipline is not optional. The easy
questions — how much notional printed in a session — are genuinely easy. The
hard ones — what was each desk's true best-execution slippage after you strip
the dirty market data and de-duplicate the double-booked prints, or how does a
day's PnL decompose into price, trading, dividend and corporate-action
components so that it reconciles to the change in book equity — reward people
who respect grain, ordering, NULLs, boundaries, and division by zero, and
punish everyone else with a wrong answer that looks plausible.

---

## 2. Table dictionary

Eight tables. `fills` is the crown-jewel fact table; `quotes` is the second
large fact; `orders` and `positions` are supporting facts; `instruments`,
`accounts` and `trading_days` are dimensions; `corporate_actions` is a small
event table. Foreign keys are declared as comments in `schema.sql` (loaders add
constraints per engine).

### instruments — the securities master (dimension)
| Column | Type | Meaning / notes |
|---|---|---|
| `instrument_id` | INTEGER PK | Surrogate id. Reserved ids: **1, 2** = "twin" names with scripted equal volume (rank ties); **3, 4** = names with a scripted consecutive HALT window; **N−1, N** = newly listed, never traded. |
| `symbol` | VARCHAR(12) | Ticker, unique. String — sorts lexically, not numerically. |
| `company_name` | VARCHAR(120) | Display name. |
| `sector` | VARCHAR(40) | GICS-style sector. **NULLABLE** — a cohort of names is unclassified (planted outside the clean regime). |
| `currency` | VARCHAR(3) | Quote currency (USD/EUR/GBP/JPY). |
| `listing_date` | DATE | First listed. |
| `delisting_date` | DATE | **NULLABLE** — NULL while still listed. |
| `tick_size` | DECIMAL(10,5) | Minimum price increment. |
| `lot_size` | INTEGER | Round-lot share multiple. |
| `status` | VARCHAR(12) | ACTIVE / HALTED / DELISTED. |
| `is_marginable` | INTEGER | 0/1 flag. |

### accounts — trading accounts / customers (dimension)
| Column | Type | Meaning / notes |
|---|---|---|
| `account_id` | INTEGER PK | Surrogate id. Reserved ids **1, 2** = dedicated market makers for the twin names (each trades exactly one twin), giving an account-level volume tie. |
| `account_code` | VARCHAR(12) | External code, zero-padded (`AC0000007`). **Type-coercion trap:** string order ≠ numeric order. |
| `display_name` | VARCHAR(80) | Display name. |
| `account_type` | VARCHAR(16) | RETAIL / INSTITUTIONAL / MARKET_MAKER. |
| `region` | VARCHAR(24) | Americas / EMEA / APAC / LATAM. |
| `base_currency` | VARCHAR(3) | Settlement currency (may differ from an instrument's quote currency). |
| `opened_date` | DATE | Account open date. |
| `risk_tier` | INTEGER | 1 (tightest) .. 5 (widest). |

### trading_days — the exchange session calendar (dimension)
Contains **only real sessions**; weekends and holidays are simply absent, so a
missing date is information. This is the correct source for date bucketing and
business-day math (do not use raw calendar arithmetic).
| Column | Type | Meaning / notes |
|---|---|---|
| `session_date` | DATE PK | A day the exchange was open. |
| `session_seq` | INTEGER | Dense 1..N index. **Off-by-one trap:** seq gaps ≠ calendar-day gaps. |
| `session_type` | VARCHAR(10) | REGULAR / HALF_DAY (early close). |
| `open_ts` / `close_ts` | TIMESTAMP | Session open/close; half-days close early. |

### orders — order submissions and lifecycle (fact)
| Column | Type | Meaning / notes |
|---|---|---|
| `order_id` | BIGINT PK | Surrogate id. |
| `account_id` | INTEGER | FK → accounts. |
| `instrument_id` | INTEGER | FK → instruments. |
| `side` | VARCHAR(4) | BUY / SELL. |
| `order_type` | VARCHAR(8) | LIMIT / MARKET / STOP. |
| `limit_price` | DECIMAL(18,6) | **NULLABLE** — NULL for MARKET orders. |
| `quantity` | INTEGER | Ordered shares (> 0). |
| `time_in_force` | VARCHAR(4) | DAY / GTC / IOC / FOK. |
| `status` | VARCHAR(10) | NEW / PARTIAL / FILLED / CANCELLED / REJECTED. Cancelled/rejected orders have **zero fills** (empty groups). |
| `created_at` / `updated_at` | TIMESTAMP | Lifecycle timestamps. |
| `session_date` | DATE | FK → trading_days (the trading session). |
| `parent_order_id` | BIGINT | **NULLABLE self-FK** → orders. NULL for top-level; populated for a small share of routed child slices (dirty regimes only). |

### fills — executions / trades (primary fact, largest table)
One order can produce **many** fills (fan-out). `account_id`, `instrument_id`,
`side` are denormalized from the parent order.
| Column | Type | Meaning / notes |
|---|---|---|
| `fill_id` | BIGINT PK | Surrogate id (always unique — even on a double-booked print). |
| `order_id` | BIGINT | FK → orders. |
| `instrument_id` / `account_id` / `side` | — | Denormalized from the order. |
| `fill_price` | DECIMAL(18,6) | Execution price. |
| `fill_quantity` | INTEGER | Shares in this execution (> 0). |
| `fill_time` | TIMESTAMP | May skew **before** `orders.created_at`, or bleed across **midnight** while `session_date` stays on the true session. |
| `liquidity_flag` | VARCHAR(6) | MAKER / TAKER. |
| `venue` | VARCHAR(8) | Routing venue code. |
| `fee` | DECIMAL(12,6) | **Signed** — negative = maker rebate (sign trap). |
| `session_date` | DATE | FK → trading_days — the authoritative session (use this, not `date(fill_time)`). |

### quotes — top-of-book market-data snapshots (fact)
| Column | Type | Meaning / notes |
|---|---|---|
| `quote_id` | BIGINT PK | Surrogate id (unique even on a replayed tick). |
| `instrument_id` | INTEGER | FK → instruments. |
| `quote_time` | TIMESTAMP | Snapshot time. |
| `bid_price` / `ask_price` | DECIMAL(18,6) | **NULLABLE** — NULL when a side is absent. May be **crossed/locked** (`bid ≥ ask`) at full scale — a bad-data trap; a valid mid needs both present and `ask > bid`. |
| `bid_size` / `ask_size` | INTEGER | May be **0** (one-sided book) — division-by-zero fuel for size-weighted metrics. |
| `session_date` | DATE | FK → trading_days. |

### positions — end-of-month risk snapshots (fact)
Emitted on the **last session of each calendar month** for pairs active that
month. Logical key `(account_id, instrument_id, as_of_date)` is **not** unique —
rare double-posts occur at full scale.
| Column | Type | Meaning / notes |
|---|---|---|
| `position_id` | BIGINT PK | Surrogate id. |
| `account_id` / `instrument_id` | INTEGER | FKs. |
| `as_of_date` | DATE | Month-end session (FK → trading_days). Snapshots land only on real month-end sessions — never on the 30th/31st by calendar. |
| `quantity` | INTEGER | **Signed** net position; **0 = flat** (return% denominator trap). |
| `avg_cost` | DECIMAL(18,6) | **NULLABLE** — NULL when flat. |
| `mark_price` | DECIMAL(18,6) | **NULLABLE** — NULL when the name had no valid EOD quote that day. |
| `realized_pnl` | DECIMAL(18,4) | Cumulative realized (includes dividend income). |
| `unrealized_pnl` | DECIMAL(18,4) | **NULLABLE** — NULL when flat or unmarked. |

### corporate_actions — splits, dividends, symbol changes (event table)
| Column | Type | Meaning / notes |
|---|---|---|
| `action_id` | INTEGER PK | Surrogate id. |
| `instrument_id` | INTEGER | FK → instruments. |
| `action_type` | VARCHAR(12) | SPLIT / DIVIDEND / SYMBOL_CHANGE. |
| `ex_date` | DATE | Ex-date (FK → trading_days). The date the adjustment takes effect — use this, not `announced_at`. |
| `record_date` | DATE | Holder-of-record date. |
| `split_ratio` | VARCHAR(8) | **NULLABLE**, SPLIT only. `'a:b'` string (e.g. `'3:1'`, reverse `'1:5'`) — must be **parsed** (type-coercion). |
| `cash_amount` | DECIMAL(12,6) | **NULLABLE**, DIVIDEND only (per-share cash). |
| `new_symbol` | VARCHAR(12) | **NULLABLE**, SYMBOL_CHANGE only. |
| `announced_at` | TIMESTAMP | May **post-date** `ex_date` at full scale (retroactive announcement — late-event trap). |

---

## 3. Scale targets

Row targets follow CONTENT-SPEC §1 with `fills` as the largest fact table.
Landmine intensity is gated by scale so one generator serves every belt:
`blue` is **clean**, `sample`/`purple` are **mild**, `black`/`red` are **full**.

| Scale | instruments | accounts | sessions | ≈ fills (largest) | regime |
|---|---|---|---|---|---|
| sample | 10 | 12 | 22 | ~220 (≈680 rows total) | mild |
| blue | 40 | 90 | 130 | ~25k (≤ 50k) | clean |
| purple | 130 | 300 | 270 | ~275k (≤ 500k) | mild |
| black | 420 | 800 | 520 | ~2.0M (1M–5M) | full |
| red | 820 | 1400 | 760 | ~7.1M (5M–10M) | full |

Determinism: single `random.Random(seed)`, drawn in fixed order; same
`(seed, scale)` ⇒ byte-identical CSVs (verified). Memory: fact rows are streamed
to disk; the only growing in-memory state is the running position book, bounded
by the number of distinct `(account, instrument)` pairs, not by trade count.

Calendar spans from 2023-01-02. `blue`/`purple` cover 2023 into early 2024
(year-end and quarter boundaries); `black`/`red` reach the **2024-02-29 leap
trading day** (a Thursday) and multiple year-ends.

---

## 4. Landmine inventory

Every landmine below is a *provable* data trap, mapped to a CONTENT-SPEC §5
family, with a representative naive query it defeats. "Regime" says where it is
planted (mild = sample/purple, full = black/red; structural = all scales).

| # | CONTENT-SPEC family | Planted where | Regime | Naive query it kills |
|---|---|---|---|---|
| 1 | **NULL-in-NOT-IN** | `instruments.sector` NULL for an unclassified cohort | mild+ | `... WHERE sector NOT IN (SELECT sector FROM instruments)` → NULL-poisoned to empty. Verified: naive returns 0. |
| 2 | **NULL** in operations | `orders.limit_price` NULL (MARKET); `quotes.bid/ask_price` NULL; `positions.avg_cost/mark_price/unrealized_pnl` NULL (flat/unmarked); `corporate_actions.cash_amount`/`split_ratio` NULL | structural / mild+ | `AVG((bid+ask)/2)` and `SUM(qty*avg_cost)` silently drop or NULL-propagate. |
| 3 | **Ranking ties** | Twin instruments **1 & 2** print identical volume + fill count every session; twin accounts **1 & 2** hold identical volume; round-lot collisions | structural | `ROW_NUMBER() OVER (ORDER BY volume DESC)` drops one tied twin; top-N by `LIMIT` returns an arbitrary member of the tie. Use RANK/DENSE_RANK. |
| 4 | **Join fan-out** | one `order` → many `fills`; `fills`×`quotes` on `session_date` fans out; `instrument`×`corporate_actions` | structural | `SUM(o.quantity)` after `orders JOIN fills` double-counts ordered qty; `fills JOIN quotes ON session_date` multiplies every fill by the day's quote count. |
| 5 | **Empty / one-row groups** | untraded instruments (ids N−1, N); CANCELLED/REJECTED orders (0 fills); halted names (0 fills over the halt window); instrument-days with no valid quote | structural | `INNER JOIN fills` silently omits never-traded names; `AVG(fill_price)` over an empty fill set returns NULL, not 0. |
| 6 | **Boundary dates** | 2024-02-29 leap trading day; month-end-only `positions`; quarter/year ends; HALF_DAY sessions; trading-day-vs-calendar-day gaps | full (leap) / structural | `GROUP BY strftime('%Y-%m', ...)` and `date +/- 30` assume calendar months; `WHERE day=31` misses February; business-day counts using raw date diff are wrong across holidays. |
| 7 | **Duplicate rows** | business-duplicate `fills` (same order/price/qty/time, new `fill_id`, **not** applied to the true book); duplicate `quotes` (replayed tick); double-posted `positions` snapshots | full / mild+ | `SUM(fill_quantity)` and `COUNT(*)` over-count; VWAP inflates. Dedup on the business key (`COUNT(DISTINCT ...)` / `NOT EXISTS`). Verified present. |
| 8 | **Type-coercion** | `account_code` zero-padded string; `split_ratio` `'a:b'` string; symbol strings | structural | `ORDER BY account_code` ≠ numeric order; splitting `'3:1'` requires string parsing, not a cast. |
| 9 | **Gaps vs islands (off-by-one)** | scripted HALT windows (islands of no-trade); running position sign-flips through zero (long/flat/short islands); `session_seq` vs `session_date` gaps | structural | "consecutive active/halted sessions" via `date` arithmetic off by weekends/holidays; streak logic that assumes `session_seq = session_date` spacing. |
| 10 | **Late / out-of-order events** | `fills.fill_time` < `orders.created_at` (clock skew); midnight-cross fills (`date(fill_time) ≠ session_date`); retroactive `corporate_actions` (`announced_at` > `ex_date`) | mild+ / full | ordering a running total by `fill_time` alone is non-deterministic across skew; bucketing by `date(fill_time)` misattributes midnight fills; using `announced_at` applies actions on the wrong day. Verified present. |
| 11 | **Division by zero in rates** | one-sided `quotes` (`bid_size`/`ask_size` = 0) from **halts** (structural) and **pulled liquidity** (mild+); flat `positions` (`quantity` = 0); taker-less instrument-days; zero mid from a one-sided book | structural (halt) / mild+ (pulled) | `ask_size / bid_size`, `pnl / (quantity*avg_cost)`, `maker_fills / taker_fills` divide by zero → RE or NULL. Verified present. |

---

## 5. Problem plan

Ladder (enforced): every Red locks behind a Black in this universe, every Black
behind a Purple. Chains:
**B1 → P1 → Bk1 → R1** and **B1 → P2 → Bk2 → R2**.

```
                 ┌────────── P1 (spread vs mid) ── Bk1 (VWAP slippage) ── R1 (best-ex scorecard)
  B1 (session ──┤
     notional)   └────────── P2 (rolling inv.) ── Bk2 (position recon)  ── R2 (PnL attribution)
```

### B1 — Blue — "Session Notional Leaderboard"
- **Scenario.** For one named trading session, report each instrument's total
  traded notional (`SUM(fill_price × fill_quantity)`) and its fill count, joined
  to `instruments` for the symbol and sector, ordered by notional descending.
  A genuine reporting task on clean (`blue`, regime=clean) data.
- **Techniques.** INNER JOIN, `GROUP BY`, `SUM`/`COUNT`, `ORDER BY`, date
  filter on `session_date`. One core idea: **notional lives at fill grain**.
- **Landmines it steps on.** Fan-out (#4) is *defused by construction* — it
  teaches that you aggregate fill-level values, not order-level quantity;
  empty groups (#5) — never-traded names are correctly absent under INNER JOIN
  at this belt.
- **Naive solution it kills.** Hardcoding the visible-sample leaderboard as
  literals (fails the hidden fixture, G2); and the tempting
  `SUM(o.quantity*...)` off the `orders` table, which double-counts against
  fan-out. Foundation for both Purple chains.

### P1 — Purple — "Effective Spread vs Mid" (prereq: B1)
- **Scenario.** For fills over a date range, score execution quality against the
  prevailing top-of-book mid *at or just before* each fill: per instrument,
  average effective spread `2 × |fill_price − mid|` and the share of fills that
  received price improvement (executed inside the quoted spread). Needs an
  **as-of** join from each fill to the latest valid quote at/before `fill_time`.
- **Techniques.** As-of join (correlated subquery or windowed `LAST_VALUE`),
  `CASE`-aggregation for the improvement share, `AVG`, `GROUP BY`, mid =
  `(bid+ask)/2` with validity filtering.
- **Landmines (#2, #4, #5, #10, #11 — mild).** Must skip NULL bid/ask and
  one-sided (size-0) quotes when forming a mid; late/out-of-order fills mean the
  as-of predicate must be `quote_time ≤ fill_time` robustly; instrument with no
  prior quote yields no mid (empty group) and must be handled explicitly.
- **Naive solution it kills.** `fills JOIN quotes ON session_date` then
  `AVG((bid+ask)/2)` — the day-level join **fans out** every fill across all the
  day's quotes and averages the wrong mid (WA); a size-weighted mid divides by a
  zero bid_size (RE); ignoring NULL prices NULL-poisons the average.

### P2 — Purple — "Rolling Inventory & Realized Cash" (prereq: B1)
- **Scenario.** For one account, reconstruct the running signed inventory per
  instrument from fills (BUY +, SELL −) and a cumulative realized cash flow,
  producing an ordered end-of-day series. Cross-checked against the `positions`
  snapshot.
- **Techniques.** Window `SUM() OVER (PARTITION BY account, instrument ORDER BY
  session_date, fill_time, fill_id)`, signed quantity via `CASE`, running total,
  deterministic tie-break ordering.
- **Landmines (#3, #10 — mild).** Multiple fills share a `fill_time` (ties):
  the running sum is ambiguous without a `fill_id` tiebreaker; late/out-of-order
  fills mean `fill_id` order ≠ chronological order.
- **Naive solution it kills.** Running `SUM` ordered by `fill_time` only — under
  output normalization the partial sums differ across tied timestamps (WA); or
  ordering by `fill_id` assuming it tracks time (broken by skewed/midnight
  fills).

### Bk1 — Black — "Best-Execution VWAP Slippage" (prereq: P1)
- **Scenario.** Over a full quarter at `black` scale, compute each instrument's
  realized taker VWAP from genuine executions and its average signed slippage
  (in basis points) versus the arrival mid, then rank instruments by slippage.
  Full landmines, real TLE pressure (~2M fills).
- **Techniques.** As-of join to the latest **valid, two-sided, uncrossed**
  quote; dedup of double-booked fills (`COUNT(DISTINCT` business key `)` /
  `NOT EXISTS`); VWAP `= SUM(price×qty)/SUM(qty)`; slippage bps guarded against a
  zero mid; tie-aware ranking (`RANK`/`DENSE_RANK`).
- **Landmines (#2, #3, #4, #7, #10, #11 — full).** Business-duplicate fills
  inflate VWAP; crossed/locked quotes yield garbage/negative mids; one-sided
  books divide by zero; midnight-cross fills misattribute the session;
  **twins 1 & 2 tie exactly** so `ROW_NUMBER` silently drops one.
- **Naive solution it kills.** `SUM(price×qty)/SUM(qty)` over raw (un-deduped)
  fills → inflated volume (WA); mid from `(bid+ask)/2` without filtering crossed
  quotes → nonsense slippage (WA); `slippage / mid` where mid can be 0 → RE;
  top-N by `ROW_NUMBER` → loses a tied twin (WA); a per-fill correlated scan
  over all quotes without a windowed as-of → **TLE** at black scale.

### Bk2 — Black — "Position Reconstruction & Mark-to-Market" (prereq: P2)
- **Scenario.** Rebuild each account/instrument **month-end** signed position
  and mark-to-market unrealized PnL purely from `fills` + EOD mid, **re-basing
  share counts across split ex-dates**, and reconcile against the `positions`
  snapshot. Report month-end unrealized PnL per account. Full landmines, TLE
  pressure.
- **Techniques.** Windowed running signed inventory, average-cost basis, split
  adjustment by parsing `split_ratio` and applying it on `ex_date`, month-end
  detection via `trading_days` (last session per month — **not** day 30/31),
  dedup, as-of EOD mark (skip NULL/crossed), carry-forward over trade-less
  months, guarded division for flat positions.
- **Landmines (#2, #6, #7, #8, #10, #11 — full).** Split ex-date re-basing;
  month-end boundary (incl. 2024-02-29); duplicate fills; double-posted
  `positions` snapshots; midnight/late fills landing in the wrong month; flat
  (`quantity=0`) positions with NULL cost.
- **Naive solution it kills.** `SUM(signed qty)` from fills with **no split
  re-basing** → position off by the split factor after the ex-date (WA);
  `GROUP BY strftime('%Y-%m', fill_time)` → midnight-cross fills fall in the
  wrong month and February boundary breaks (WA); reconciling via
  `SUM(positions.quantity)` double-counts the double-posted snapshot (WA);
  `pnl/(quantity*avg_cost)` blows up on flat rows (RE).

### R1 — Red — "Adverse-Selection Best-Execution Scorecard" (prereq: Bk1)
- **Scenario.** Quant-grade, `red` scale (~7M fills). For each liquidity-
  providing account, build a yearly best-execution scorecard: fill-weighted
  effective spread capture, realized **markout** (mid move from the fill to the
  mid N minutes later — the adverse-selection signal), and a **percentile rank
  of slippage within each instrument's sector**, after stripping dirty market
  data. Unclassified (NULL-sector) names form their own explicit cohort rather
  than vanishing. Adversarially verified (G5).
- **Techniques.** Backward as-of join (arrival mid) **and** forward as-of join
  (markout mid at ≥ N minutes after the fill), `PERCENT_RANK`/`NTILE` within a
  sector partition, `COALESCE(sector,'UNCLASSIFIED')` cohorting, dedup, guarded
  division, tie-aware `DENSE_RANK`, all under hard TLE.
- **Landmines (#1, #2, #3, #7, #10, #11 + boundary — full).** NULL sector
  (must not disappear from cohorts; a naive `sector NOT IN (...)` is NULL-
  poisoned to empty); twin ties; crossed/one-sided/NULL quotes for the mid;
  **zero-denominator markout** when no future quote exists within the horizon;
  duplicate fills; forward markout must use `quote_time` strictly *after*
  `fill_time` by ≥ the horizon; horizon windows crossing the session close.
- **Naive solution it kills.** Percentiles over raw slippage with dupes and
  unfiltered mids (WA); sector cohorts via `GROUP BY sector` that silently drop
  NULLs, or `WHERE sector NOT IN (SELECT sector ...)` → empty result (WA);
  `markout / future_mid` where the future mid is missing → RE/NULL; `ROW_NUMBER`
  ranking that loses a tied twin (WA); a naive `fills × quotes` self-join for
  markout → **TLE** at 7M rows.

### R2 — Red — "End-of-Day PnL Attribution across Corporate Actions" (prereq: Bk2)
- **Scenario.** Quant-grade, `red` scale. Produce a **daily PnL attribution**
  per account decomposing the change in book equity into **price PnL**
  (mark-to-market on held inventory), **trading PnL** (realized on the day's
  fills vs mid), **dividend income** (holdings across ex-dates), and
  **split/carry adjustments** — such that the components **reconcile** to the
  snapshot equity change. Adversarially verified (G5).
- **Techniques.** Multi-source running reconstruction (`fills` + `quotes` +
  `corporate_actions`), gaps-and-islands **carry-forward** of the last known
  mark over non-trading gaps, boundary-correct bucketing by joining
  `trading_days` (never date math), signed running inventory with split
  re-basing on `ex_date`, dividend accrual to record-date holders, guarded
  division, dedup, deterministic ordered windows.
- **Landmines (all families — full).** Split ex-date re-basing (#6/#8);
  dividend ex-date with NULL cash on splits (#2); leap-day / month / quarter /
  year boundaries incl. 2024-02-29 (#6); gaps carried over holidays — trading-
  vs calendar-day (#9); late/midnight fills (#10); duplicate fills / double-
  posted snapshots (#7); **retroactive** corporate actions — must key on
  `ex_date`, not `announced_at` (#10); NULL-mark carry-forward (#2); flat
  positions (#11).
- **Naive solution it kills.** Attribution bucketed by `date()`/`strftime` on
  timestamps → midnight fills, leap-day and holiday gaps make the components
  fail to reconcile (WA); ignoring split re-basing → price PnL off by the split
  factor (WA); applying actions on `announced_at` (retroactive) instead of
  `ex_date` (WA); carry-forward via `LAG` over calendar days rather than trading
  gaps → wrong marks (WA); unguarded division on flat positions (RE); per-day
  per-account recomputation without windowed running state → **TLE** at 7M rows.

---

## 6. Deviations & notes

- **"Clean" (Blue) means free of the *injected* dirty-data traps** — no
  duplicate fills, crossed books, replayed quotes, NULL sectors, child-order
  self-references, or late/midnight/retroactive events. Structural realism is
  still present at every scale (order→fill fan-out, market-order NULL limits,
  ties, untraded names, halts with zero-size books, coincidental same-second
  fills), because none of it breaks the intended fill-grain aggregation the Blue
  problem asks for. Verified: at `blue` scale all injected traps are absent.
- **Landmine intensity is a function of `--scale`**, so a single generator can
  emit genuinely clean Blue fixtures *and* full-landmine Black/Red fixtures.
  A Black/Red problem's **hidden** fixture (scale `black`/`red`, regime full)
  carries the killer landmines; its small **visible** sample (scale `sample`,
  regime mild) is a deliberately gentler teaser. This is intentional: a solver
  who validates only against the visible sample and does not code defensively
  passes visible but fails the hidden fixture — exactly the intended difficulty
  gradient.
- **Week-53 (ISO) boundary is intentionally out of the generated window.** To
  guarantee the more valuable **2024-02-29 leap *trading* day** (a Thursday, so
  a real session — unlike 2020-02-29, a Saturday), the calendar starts in 2023;
  a 3-year span does not also contain a 53-week ISO year. The boundary-date
  family (#6) is instead covered by the leap trading day, month/quarter/year
  ends, half-days, and the trading-day-vs-calendar-day gap — all present and
  verified.
- **`positions` is computed from the same fills as ground truth**, so it is a
  faithful risk record; the reconciliation problems (Bk2, R2) are hard precisely
  because a *naive* recomputation from fills trips the landmines (dupes, splits,
  midnight fills, double-posts) and drifts from the honest snapshot.
- **Referential integrity holds fully** (0 orphans across every FK at sample and
  purple scale, verified). All "orphan-like" traps are semantic (NULLs,
  out-of-order timestamps), never dangling foreign keys.
