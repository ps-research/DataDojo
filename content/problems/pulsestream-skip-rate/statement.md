# Track Skip-Rate Leaderboard

The catalog team hunts down tracks listeners bail on early. A **skip** is a play
that lasted **under 30 seconds** — and because `plays.ms_played` is in
**milliseconds**, that threshold is `ms_played < 30000`. A play of exactly 30
seconds (`ms_played = 30000`) is **not** a skip.

Some plays have a **NULL `ms_played`** (telemetry was lost). Those plays are
unusable — exclude them from **both** the skip count and the play count. To keep
the rate statistically meaningful, only rank tracks with **at least 50 usable
plays** (plays with a non-NULL `ms_played`). Tracks that were never played, or
barely played, do not appear — and there is never a division by zero.

## Task

For every track with **50 or more** non-NULL-`ms_played` plays, compute its skip
rate and return the leaderboard, worst offenders first.

- `qualifying_plays` = number of plays with non-NULL `ms_played`.
- `skips` = number of those plays with `ms_played < 30000`.
- `skip_rate` = `skips / qualifying_plays`, rounded to 4 decimals.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `track_id` | the track |
| 2 | `track_title` | `tracks.title` |
| 3 | `qualifying_plays` | count of non-NULL-`ms_played` plays |
| 4 | `skips` | count of those with `ms_played < 30000` |
| 5 | `skip_rate` | `skips / qualifying_plays`, rounded to 4 decimals |

**Order matters.** `ORDER BY skip_rate DESC, qualifying_plays DESC, track_id ASC`.

## Worked example

Four tracks:

| track | plays (`ms_played`) |
|---|---|
| 100 "Skippy Single" | 40 plays of `10000`, 20 plays of `45000`, 5 plays of `NULL` |
| 200 "Sticky Song" | 55 plays of `50000` |
| 300 "Dark Track" | *(never played)* |
| 400 "Rare Cut" | 30 plays of `10000` |

- **Track 100**: usable plays `= 60` (the 5 NULLs are dropped), skips `= 40`
  (the `10000`-ms plays), `skip_rate = 40 / 60 = 0.6667`.
- **Track 200**: 55 usable plays, 0 skips (`50000 >= 30000`), `skip_rate = 0.0`.
- **Track 300**: never played → excluded (no divide-by-zero).
- **Track 400**: only 30 usable plays → below the 50 threshold → excluded.

Expected output:

| track_id | track_title | qualifying_plays | skips | skip_rate |
|---|---|---|---|---|
| 100 | Skippy Single | 60 | 40 | 0.6667 |
| 200 | Sticky Song | 55 | 0 | 0.0 |

On the visible sample fixture only one track clears the 50-play bar: track 66
(`Electric Harbor`) with 68 usable plays, 22 skips, `skip_rate = 0.3235`.
