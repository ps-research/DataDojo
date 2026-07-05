# Feature Adoption Leaderboard

The product team is preparing a launch review. For a single calendar month they
want a clean leaderboard of feature flags ranked by **how many distinct users
actually used each feature** that month. The result feeds a simple bar chart, so
it must be exactly one row per feature, most-adopted first.

Usage is recorded in `events`: a row with `event_type = 'feature_used'` carries the
`flag_id` of the feature that was exercised (every other event type leaves
`flag_id` NULL). The instrumentation is noisy — a user who leans on a feature all
day emits many `feature_used` rows for it, and a flaky client occasionally
**double-fires** the same event a second time with a new `event_id`. None of that
changes adoption: a feature's *adopters* are the **distinct users** who used it,
each counted once no matter how many times (or how many duplicate rows) they fired.

## Task

For the calendar month **February 2024**, report for every feature that was used at
least once that month:

1. the feature's `flag_key`;
2. `adopters` — the number of **distinct users** who triggered a `feature_used`
   event for that feature during the month.

Restrict to `event_type = 'feature_used'` and to events whose `event_ts` falls in
the month, using the half-open range `event_ts >= '2024-02-01' AND event_ts <
'2024-03-01'`. Join `events` to `feature_flags` on `flag_id`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `flag_key` | the feature flag's human key |
| 2 | `adopters` | `COUNT(DISTINCT user_id)` of `feature_used` events for that flag in the month |

**Order matters.** `ORDER BY adopters DESC, flag_key ASC` (the feature key is the
deterministic tie-break when two features have the same adopter count).

## Worked example

On the visible sample fixture, February 2024 produces this leaderboard:

| flag_key | adopters |
|---|---|
| advanced_search | 4 |
| dark_mode | 4 |
| bulk_export | 3 |
| sso_login | 3 |
| ai_assist | 2 |
| custom_dashboard | 2 |

`advanced_search` and `dark_mode` tie at 4 adopters, so the key breaks the tie
alphabetically (`advanced_search` first). Note the trap: `sso_login` fired **8**
`feature_used` rows that month but from only **3 distinct users**, so counting rows
instead of distinct users would wrongly promote it above the true leaders. These
are exactly the rows the reference produces on the visible sample fixture.
