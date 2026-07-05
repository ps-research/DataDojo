# Monthly Active Listeners and Growth

The growth team tracks **monthly active listeners** (MAU): the number of *distinct*
users who pressed play in a given calendar month, and how that number moves
month over month.

The `plays` firehose is messy on purpose. It contains **duplicate events** (a flaky
client retries and logs the same stream twice, with a new `play_id`) and events
arrive **out of order** (`play_id` order is not `played_at` order; an offline
subway listen can sync hours later). None of that changes the metric: a listener
is active in the month their play *happened* (`played_at`), and each distinct
listener counts once no matter how many times they played.

## Task

For every calendar month in the data, report:

1. the month, as a `YYYY-MM` string taken from `played_at`;
2. the number of **distinct active listeners** that month;
3. the **month-over-month growth**, in percent, versus the immediately preceding
   month in the result: `100 * (this_month - prev_month) / prev_month`, rounded to
   2 decimals.

The **earliest month has no preceding month**, so its growth is **undefined** —
report it as NULL, not `0`. (Guard the division so a hypothetical zero prior month
also yields NULL rather than an error.)

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `month` | `YYYY-MM` derived from `played_at` |
| 2 | `active_listeners` | `COUNT(DISTINCT user_id)` for that month |
| 3 | `mom_growth_pct` | percent change vs the previous month, or NULL for the first month |

**Order matters.** `ORDER BY month` ascending (chronological, since `YYYY-MM` sorts
lexically).

## Worked example

Three consecutive months of plays reduce to these distinct-listener counts:

| month | distinct listeners |
|---|---|
| 2023-01 | 6 |
| 2023-02 | 5 |
| 2023-03 | 10 |

Expected output:

| month | active_listeners | mom_growth_pct |
|---|---|---|
| 2023-01 | 6 | *(NULL)* |
| 2023-02 | 5 | -16.67 |
| 2023-03 | 10 | 100.00 |

`2023-01` has no prior month, so growth is NULL. `2023-02`: `100*(5-6)/6 = -16.67`.
`2023-03`: `100*(10-5)/5 = 100.00`. These are exactly the first three rows the
reference produces on the visible sample fixture.
