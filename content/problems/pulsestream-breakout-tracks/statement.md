# Breakout Tracks of the Month

PulseStream's editorial team curates a "Breakout" shelf every month: the ten
tracks that listeners pressed play on most during that calendar month, shown with
a human-readable track title and the artist behind them. This month the shelf is
for **December 2024**.

A play is one row in the `plays` firehose. For this shelf you count **every** play
whose `played_at` falls inside December 2024 — a play counts the same regardless of
how long it was listened to or which device it came from.

## Task

Return the **ten most-played tracks in December 2024** (that is, plays with
`played_at` on or after `2024-12-01` and before `2025-01-01`), each with its track
id, title, artist name, and its December play count.

Rank by play count, highest first. Play counts tie often at the bottom of the
shelf, so the ordering is made unique by a deterministic tiebreak: **more plays
first, then by track title A→Z, then by the smaller `track_id`.** Return at most
ten rows.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `track_id` | the track's id |
| 2 | `track_title` | `tracks.title` |
| 3 | `artist_name` | `artists.name` of the track's artist |
| 4 | `play_count` | number of December-2024 plays of this track |

**Order matters.** `ORDER BY play_count DESC, track_title ASC, track_id ASC`, then
keep the first 10 rows.

## Worked example

Suppose December 2024 plays reduce to these per-track counts (already joined to
titles and artists):

| track_id | track_title | artist_name | Dec plays |
|---|---|---|---|
| 66 | Electric Harbor | Silver Monsoon | 8 |
| 15 | Distant Anthem | Velvet Circuit | 6 |
| 34 | Silver Cascade | Paper Monsoon | 3 |
| 48 | Wild Pulse | Frozen Ember | 3 |
| 1 | Amber Canyon | Golden Cascade | 2 |
| 19 | Electric Anthem | Paper Monsoon | 2 |
| 5 | Fading Meadow | Frozen Canyon | 2 |

The two tracks tied at 3 plays are ordered by title (`Silver Cascade` before
`Wild Pulse`); the tracks tied at 2 are ordered by title as well. The shelf reads
`Electric Harbor (8), Distant Anthem (6), Silver Cascade (3), Wild Pulse (3),
Amber Canyon (2), Electric Anthem (2), Fading Meadow (2), …` down to ten rows.

Running the reference against the visible sample fixture produces exactly ten rows
with `Electric Harbor` first (8 plays) and `Distant Anthem` second (6 plays).
