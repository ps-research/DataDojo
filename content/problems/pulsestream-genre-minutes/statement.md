# Listening Minutes by Genre

Marketing is sizing its next round of genre campaigns and needs to know where
listening time actually goes. For the **entire catalog and the entire play
history**, total the listening **minutes** delivered by each genre, ranked from
most-listened to least.

Two facts about the data matter:

- **`plays.ms_played` is in milliseconds.** One minute is `60000` milliseconds, so
  minutes are `ms_played / 60000` — not `ms_played / 60`.
- Some plays have a **NULL `ms_played`** (telemetry was lost). Those rows
  contribute no time, but they must not blow up the total — a plain `SUM` already
  ignores them.
- Some tracks have a **NULL `genre`** (uncategorized). They must not disappear:
  report their listening time under a single bucket labelled `(uncategorized)`.

## Task

Join `plays` to `tracks`, and for each genre report the total listening time as
both raw milliseconds and as minutes. Group tracks whose `genre` is NULL into one
bucket named exactly `(uncategorized)`.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `genre` | the track genre, or `(uncategorized)` for NULL |
| 2 | `total_ms` | `SUM(ms_played)` in milliseconds (integer) |
| 3 | `total_minutes` | `total_ms / 60000`, rounded to 2 decimals |

**Order matters.** `ORDER BY total_ms DESC, genre ASC` (ties on total time break
alphabetically by genre label).

## Worked example

Consider four plays joined to their tracks:

| play | track genre | ms_played |
|---|---|---|
| 1 | pop | 180000 |
| 2 | pop | 120000 |
| 3 | (NULL genre) | 60000 |
| 4 | pop | NULL |

- `pop`: `180000 + 120000 = 300000` ms (play 4's NULL is ignored, not counted as
  0) → `total_ms = 300000`, `total_minutes = 5.00`.
- `(uncategorized)`: `60000` ms → `total_minutes = 1.00`.

Expected rows (ordered by `total_ms` descending):

| genre | total_ms | total_minutes |
|---|---|---|
| pop | 300000 | 5.00 |
| (uncategorized) | 60000 | 1.00 |

On the visible sample fixture the top bucket is `rnb` (26,683,132 ms ≈ 444.72
minutes) and the `(uncategorized)` bucket appears mid-table, never dropped.
