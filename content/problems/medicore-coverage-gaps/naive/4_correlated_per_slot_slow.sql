-- NAIVE (TLE-only): the designated TLE-slow solution. It is CORRECT -- it produces the
-- same breach rows as the reference on the sample -- but it evaluates a correlated
-- COUNT(DISTINCT staff_id) subquery over roster_shifts once per spine slot (and again in
-- the WHERE), so its cost is O(slots x roster). At black scale (~1.1M roster rows across
-- ~80 wards x 29 days x 3 shifts of spine) this blows the time limit, whereas the
-- reference's single grouped LEFT JOIN finishes well under it. Included so the farm can
-- calibrate the per-engine time limit (section 6): reference_time <= 0.5 * limit <
-- naive_time.
WITH RECURSIVE cal(d) AS (
    SELECT '2024-02-01' UNION ALL SELECT date(d, '+1 day') FROM cal WHERE d < '2024-02-29'
),
shift_types(shift_type) AS ( SELECT 'DAY' UNION ALL SELECT 'NIGHT' UNION ALL SELECT 'SWING' ),
spine AS (
    SELECT w.ward_id, w.min_nurses_per_shift, c.d AS shift_date, st.shift_type
    FROM wards w CROSS JOIN cal c CROSS JOIN shift_types st
    WHERE w.min_nurses_per_shift > 0
)
SELECT
    sp.ward_id, sp.shift_date, sp.shift_type,
    sp.min_nurses_per_shift AS required_nurses,
    ( SELECT COUNT(DISTINCT r.staff_id)
      FROM roster_shifts r JOIN staff s ON s.staff_id = r.staff_id
      WHERE s.role = 'NURSE' AND r.status = 'WORKED'
        AND r.ward_id = sp.ward_id AND r.shift_date = sp.shift_date AND r.shift_type = sp.shift_type
    ) AS nurses_worked,
    sp.min_nurses_per_shift -
    ( SELECT COUNT(DISTINCT r.staff_id)
      FROM roster_shifts r JOIN staff s ON s.staff_id = r.staff_id
      WHERE s.role = 'NURSE' AND r.status = 'WORKED'
        AND r.ward_id = sp.ward_id AND r.shift_date = sp.shift_date AND r.shift_type = sp.shift_type
    ) AS shortfall
FROM spine sp
WHERE ( SELECT COUNT(DISTINCT r.staff_id)
        FROM roster_shifts r JOIN staff s ON s.staff_id = r.staff_id
        WHERE s.role = 'NURSE' AND r.status = 'WORKED'
          AND r.ward_id = sp.ward_id AND r.shift_date = sp.shift_date AND r.shift_type = sp.shift_type
      ) < sp.min_nurses_per_shift
ORDER BY sp.ward_id ASC, sp.shift_date ASC, sp.shift_type ASC;
