# Session Upgrade-Funnel Conversion by Channel

Growth wants the in-session upgrade funnel

```
view_plans  ->  start_checkout  ->  enter_payment  ->  purchase
```

broken down by the user's acquisition channel (`users.referral_channel`). For each
channel, report how many sessions **entered** the funnel (reached `view_plans`),
how many reached each later step, and the step-to-step conversion rates.

A session is one row in `sessions`; its events are the `events` rows sharing its
`session_id`, and the session's channel is the `referral_channel` of its user. The
event stream is not clean: `event_id` is **not** in time order, and roughly one
session in twenty has a **clock-skewed event delivered before the session even
started**. So the funnel must be established on **event time** (`event_ts`), not on
insertion/`event_id` order.

A session counts for a step only if it reached that step **after** the previous
step in event-time order. Concretely, take the **earliest `event_ts` of each step**
in the session; the session reaches a step only when those earliest step times are
monotonically non-decreasing:

```
min(view_plans) <= min(start_checkout) <= min(enter_payment) <= min(purchase)
```

Sessions that emit no events (bounces) and sessions that never enter the funnel
contribute 0 to every step, but **their channel still appears** in the result.

## Task

Group all sessions by their user's `referral_channel` (**keep the NULL channel as
its own segment** — it is a real, unattributed slice of traffic). For each channel
report:

1. `entered` — sessions that reached `view_plans`;
2. `reached_checkout` — sessions that reached `start_checkout` in order;
3. `reached_payment` — sessions that reached `enter_payment` in order;
4. `reached_purchase` — sessions that reached `purchase` in order;
5. `cr_checkout` = `reached_checkout / entered`;
6. `cr_payment` = `reached_payment / reached_checkout`;
7. `cr_purchase` = `reached_purchase / reached_payment`.

Each rate is a step count divided by the previous step count, **guarded with
`NULLIF(denominator, 0)`** so a channel (or step) with a zero denominator yields
NULL rather than an error. Round each rate to 6 decimals.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `referral_channel` | acquisition channel, or NULL for unattributed traffic |
| 2 | `entered` | sessions reaching `view_plans` |
| 3 | `reached_checkout` | sessions reaching `start_checkout` (in event-time order) |
| 4 | `reached_payment` | sessions reaching `enter_payment` (in event-time order) |
| 5 | `reached_purchase` | sessions reaching `purchase` (in event-time order) |
| 6 | `cr_checkout` | `reached_checkout / entered`, NULLIF-guarded, 6 dp |
| 7 | `cr_payment` | `reached_payment / reached_checkout`, NULLIF-guarded, 6 dp |
| 8 | `cr_purchase` | `reached_purchase / reached_payment`, NULLIF-guarded, 6 dp |

**Order does not matter** — the grader sorts rows before comparing (so the NULL
segment's position is not your concern).

## Worked example

On the visible sample fixture:

| referral_channel | entered | reached_checkout | reached_payment | reached_purchase | cr_checkout | cr_payment | cr_purchase |
|---|---|---|---|---|---|---|---|
| organic | 19 | 10 | 4 | 1 | 0.526316 | 0.4 | 0.25 |
| social | 8 | 5 | 3 | 2 | 0.625 | 0.6 | 0.666667 |
| paid_search | 6 | 4 | 1 | 0 | 0.666667 | 0.25 | 0.0 |
| referral | 5 | 3 | 2 | 2 | 0.6 | 0.666667 | 1.0 |
| partner | 2 | 1 | 1 | 0 | 0.5 | 1.0 | 0.0 |
| *(NULL)* | 0 | 0 | 0 | 0 | *(NULL)* | *(NULL)* | *(NULL)* |

The unattributed (NULL) segment has sessions but none reached `view_plans`, so
`entered = 0` and every rate is NULL (the `NULLIF` guard turning a `0 / 0` into
NULL rather than a crash). `paid_search` reached payment once but never purchased,
so `cr_purchase = 0 / 1 = 0.0` — a defined zero, distinct from the NULL above.
These are exactly the rows the reference produces on the visible sample fixture.
