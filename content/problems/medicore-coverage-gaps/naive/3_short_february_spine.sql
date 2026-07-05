-- NAIVE (WA): the spine stops at 2024-02-28, treating February as a 28-day month. Every
-- 29-February slot is dropped from the report -- including the guaranteed uncovered
-- leap-day gaps (ward 2 / 29-Feb NIGHT and DAY). 2024 is a leap year, so the reporting
-- month has 29 days, the recursion bound must be 2024-02-29. Everything else matches the
-- reference, so the single fault is the short spine.
WITH RECURSIVE cal(d) AS (
    SELECT '2024-02-01' UNION ALL SELECT date(d, '+1 day') FROM cal WHERE d < '2024-02-28'  -- drops 29 Feb
),
shift_types(shift_type) AS ( SELECT 'DAY' UNION ALL SELECT 'NIGHT' UNION ALL SELECT 'SWING' ),
spine AS (
    SELECT w.ward_id, w.min_nurses_per_shift, c.d AS shift_date, st.shift_type
    FROM wards w CROSS JOIN cal c CROSS JOIN shift_types st
    WHERE w.min_nurses_per_shift > 0
),
worked AS (
    SELECT r.ward_id, r.shift_date, r.shift_type, COUNT(DISTINCT r.staff_id) AS nurses
    FROM roster_shifts r
    JOIN staff s ON s.staff_id = r.staff_id
    WHERE s.role = 'NURSE' AND r.status = 'WORKED'
      AND r.shift_date >= '2024-02-01' AND r.shift_date <= '2024-02-29'
    GROUP BY r.ward_id, r.shift_date, r.shift_type
)
SELECT
    sp.ward_id, sp.shift_date, sp.shift_type,
    sp.min_nurses_per_shift              AS required_nurses,
    COALESCE(wk.nurses, 0)               AS nurses_worked,
    sp.min_nurses_per_shift - COALESCE(wk.nurses, 0) AS shortfall
FROM spine sp
LEFT JOIN worked wk
       ON wk.ward_id = sp.ward_id AND wk.shift_date = sp.shift_date AND wk.shift_type = sp.shift_type
WHERE COALESCE(wk.nurses, 0) < sp.min_nurses_per_shift
ORDER BY sp.ward_id ASC, sp.shift_date ASC, sp.shift_type ASC;
