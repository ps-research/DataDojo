# Session Notional Leaderboard

The TickForge trading desk wants a simple end-of-session tape report: for a single
named session, which listed names printed the most business, and how active was
each one.

**Notional** is the cash value that changed hands on an execution — the fill price
times the number of shares in that fill. It lives at **fill grain**: one order can
break into many fills, so you must sum the value of the *executions* on the tape,
never the ordered quantity from the `orders` table (an order's quantity is what was
*requested*, and summing it over its many fills would multiply it).

## Task

For the session **`2023-01-09`**, report one row per instrument that traded that
day, with:

| Column | Meaning |
|---|---|
| `symbol` | the instrument's ticker (from `instruments`) |
| `sector` | the instrument's GICS sector (from `instruments`) |
| `fill_count` | number of fills (executions) that printed for the instrument that session |
| `notional` | total traded notional `SUM(fill_price * fill_quantity)`, rounded to 2 decimals |

Use `fills.session_date` as the authoritative session (not `date(fill_time)`).
Join to `instruments` for the symbol and sector. Only instruments that actually
traded on the session appear (an inner join is correct here — never-traded names
have no place on the leaderboard).

## Output

Columns exactly: `symbol`, `sector`, `fill_count`, `notional`.

**Order:** by `notional` descending, then `symbol` ascending as a deterministic
tie-break. `orderMatters` is true.

## Worked example (visible sample, session `2023-01-09`)

Instruments `AAB` and `AAC` are a scripted "twin" pair that print the same fill
count every session — note they tie on `fill_count` (3 each) but are ordered
correctly by `notional`.

| symbol | sector | fill_count | notional |
|---|---|---|---|
| AAG | Materials | 4 | 590183.00 |
| AAC | Energy | 3 | 113994.69 |
| AAB | Financials | 3 | 70124.00 |
| AAH | Utilities | 1 | 55252.00 |
| AAI | RealEstate | 1 | 29568.19 |
| AAD | Healthcare | 1 | 381.72 |

Names that never traded on `2023-01-09` (including instruments that have never
traded at all) do not appear.
