# Each Listener's Signature Genre

The personalization team wants each listener's **signature genre**: the single genre
they have played the most. It drives the "Your sound" banner, so every listener may
have **exactly one** signature — no ties allowed in the output.

Rules:

- Count **every** play row a listener has for each genre (join `plays` to `tracks`).
  Duplicate events count as they appear; do not deduplicate.
- A track's `genre` may be **NULL** (uncategorized). Uncategorized plays are **not a
  genre** — exclude them *before* ranking. A listener whose only plays are
  uncategorized therefore has no signature and does not appear.
- When a listener's top two genres tie on play count, break the tie
  **alphabetically** (the earlier genre name wins). This guarantees a single
  signature per listener.

## Task

For every listener that has at least one play of a non-NULL genre, return the
listener, their signature genre, and how many plays that genre has.

## Output columns

| # | Column | Meaning |
|---|--------|---------|
| 1 | `user_id` | the listener |
| 2 | `signature_genre` | the most-played non-NULL genre (alphabetical tiebreak) |
| 3 | `play_count` | number of plays of that genre by that listener |

**Order matters.** `ORDER BY user_id` ascending. Exactly one row per qualifying
listener.

## Worked example

Three listeners' non-NULL genre play counts:

| user_id | genre | plays |
|---|---|---|
| 1 | classical | 5 |
| 1 | hiphop | 3 |
| 2 | rnb | 4 |
| 2 | reggae | 1 |
| 3 | classical | 2 |
| 3 | electronic | 2 |

Expected output:

| user_id | signature_genre | play_count |
|---|---|---|
| 1 | classical | 5 |
| 2 | rnb | 4 |
| 3 | classical | 2 |

Listener 1's clear top is `classical` (5). Listener 3 ties between `classical` and
`electronic` at 2 plays; the alphabetical tiebreak picks `classical`, and only that
one row is returned — not two. These are exactly the first three rows the reference
produces on the visible sample fixture.
