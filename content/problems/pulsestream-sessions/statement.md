# Listening-Session Reconstruction

Product wants to understand how listeners *binge*. Reconstruct each listener's
**sessions** from the raw play firehose and report, per listener, how many sessions
they had, the length of their **longest** session (in plays), and how many of their
sessions spilled across a **calendar-day boundary**.

The firehose is hostile:

- **Events arrive out of order.** `play_id` is ingestion order, not time order
  (offline syncs, retries, backfills). Sessions must be built from **`played_at`**,
  never `play_id`.
- **Duplicate events exist.** A client retry logs the same stream twice — the same
  `(user_id, track_id, played_at)` with a new `play_id`. **Deduplicate on that
  natural key**: a repeated event counts once.
- **Exact-timestamp ties happen.** Two different tracks can share a `played_at`;
  order such ties by `track_id` so the sequence is deterministic (a zero-minute gap
  never starts a session).

## Session rule

Walk each listener's deduplicated events in `played_at` order. A **new session**
starts at the first event and whenever the gap since the previous event is **more
than 30 minutes** — strictly greater than 30:00. A gap of **exactly** 30 minutes
stays in the same session.

A session **crosses a day** when its first and last events fall on different
calendar dates (so a session running 23:50 → 00:10 counts as day-crossing, once).

## Task

For every listener, return their session count, longest session length in plays,
and how many of their sessions cross a day boundary.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `user_id` | the listener |
| 2 | `num_sessions` | number of reconstructed sessions |
| 3 | `longest_session_plays` | plays in the listener's longest session |
| 4 | `day_crossing_sessions` | how many of the listener's sessions span two dates |

**Order matters.** `ORDER BY user_id`.

## Worked example

Three listeners (times shown as `played_at`):

- **Listener 1** — `09:00`, `09:30`, `09:55`, `10:40` (all on 2024-03-10). The
  `09:00 → 09:30` gap is exactly 30 minutes (same session); `09:30 → 09:55` is 25
  minutes (same session) — that is a **3-play** session. `09:55 → 10:40` is 45
  minutes (**new** session of 1 play). → 2 sessions, longest 3, 0 day-crossing.
- **Listener 2** — `2024-02-28 23:50`, `2024-02-29 00:05`, and a **duplicate** of the
  `00:05` event. After dedup, two events 15 minutes apart form **one** session that
  crosses from Feb 28 into the leap day Feb 29. → 1 session, longest 2, 1 day-crossing.
- **Listener 3** — a single play. → 1 session, longest 1, 0 day-crossing.

Expected output:

| user_id | num_sessions | longest_session_plays | day_crossing_sessions |
|---|---|---|---|
| 1 | 2 | 3 | 0 |
| 2 | 1 | 2 | 1 |
| 3 | 1 | 1 | 0 |

Note how the duplicate at `00:05` does **not** stretch listener 2's session to 3
plays, and how the exact-30-minute gap keeps listener 1's first session intact.

*(Timestamp arithmetic differs by engine; the judge ships a reference per engine —
SQLite `unixepoch`, PostgreSQL `EXTRACT(EPOCH …)`, DuckDB `date_diff`, MySQL
`TIMESTAMPDIFF` — all producing identical results.)*
