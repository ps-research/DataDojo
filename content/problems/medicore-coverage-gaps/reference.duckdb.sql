-- DuckDB: the date spine uses DATE literals and an INTERVAL step (DATE + INTERVAL
-- 1 DAY stays a DATE).
WITH RECURSIVE cal(d) AS (
    SELECT DATE '2024-02-01'
    UNION ALL
    SELECT d + INTERVAL 1 DAY FROM cal WHERE d < DATE '2024-02-29'
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
      AND r.shift_date >= DATE '2024-02-01' AND r.shift_date <= DATE '2024-02-29'
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
