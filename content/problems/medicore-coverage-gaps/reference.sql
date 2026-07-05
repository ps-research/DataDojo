-- Nurse coverage gaps for February 2024, one row per breached (ward, date, shift) slot.
-- cal: a recursive date CTE enumerating all 29 days 2024-02-01 .. 2024-02-29 (the leap
--   day is included by construction -- no month arithmetic that could drop it).
-- spine: every slot that SHOULD exist = wards requiring > 0 nurses CROSS JOINed with the
--   29 dates and the 3 shift types. This is what lets a fully-uncovered slot -- one with
--   no roster rows at all -- surface, because the slot exists in the spine even when the
--   roster has nothing for it.
-- worked: actual coverage = COUNT(DISTINCT staff_id) over nurse rows that were WORKED
--   (no-shows, cancellations and swaps are excluded, a double-booked duplicate collapses
--   under DISTINCT).
-- Final: LEFT JOIN worked onto the spine, COALESCE the missing counts to 0, and keep the
--   slots below the ward minimum. shortfall = required - covered.
-- SQLite form. Per-engine spine overrides live in reference.postgres.sql,
-- reference.mysql.sql and reference.duckdb.sql.
WITH RECURSIVE cal(d) AS (
    SELECT '2024-02-01'
    UNION ALL
    SELECT date(d, '+1 day') FROM cal WHERE d < '2024-02-29'
),
shift_types(shift_type) AS (
    SELECT 'DAY' UNION ALL SELECT 'NIGHT' UNION ALL SELECT 'SWING'
),
spine AS (
    SELECT w.ward_id, w.min_nurses_per_shift, c.d AS shift_date, st.shift_type
    FROM wards w
    CROSS JOIN cal c
    CROSS JOIN shift_types st
    WHERE w.min_nurses_per_shift > 0
),
worked AS (
    SELECT r.ward_id, r.shift_date, r.shift_type, COUNT(DISTINCT r.staff_id) AS nurses
    FROM roster_shifts r
    JOIN staff s ON s.staff_id = r.staff_id
    WHERE s.role = 'NURSE'
      AND r.status = 'WORKED'
      AND r.shift_date >= '2024-02-01' AND r.shift_date <= '2024-02-29'
    GROUP BY r.ward_id, r.shift_date, r.shift_type
)
SELECT
    sp.ward_id,
    sp.shift_date,
    sp.shift_type,
    sp.min_nurses_per_shift              AS required_nurses,
    COALESCE(wk.nurses, 0)               AS nurses_worked,
    sp.min_nurses_per_shift - COALESCE(wk.nurses, 0) AS shortfall
FROM spine sp
LEFT JOIN worked wk
       ON wk.ward_id    = sp.ward_id
      AND wk.shift_date = sp.shift_date
      AND wk.shift_type = sp.shift_type
WHERE COALESCE(wk.nurses, 0) < sp.min_nurses_per_shift
ORDER BY sp.ward_id ASC, sp.shift_date ASC, sp.shift_type ASC;
