-- NAIVE (WA): sums actual_hours over the raw roster rows with no de-duplication, so a
-- double-booked shift (the same shift emitted twice with a new shift_id) is counted
-- twice. Wards that carry a duplicated shift report hours above the true figure. (The
-- month attribution here is correct -- grouping on shift_date -- so the ONLY error is
-- the missing DISTINCT over the business columns.)
SELECT
    r.ward_id,
    substr(r.shift_date, 1, 7)                    AS shift_month,
    ROUND(SUM(COALESCE(r.actual_hours, 0)), 2)    AS worked_hours
FROM roster_shifts r
JOIN staff s ON s.staff_id = r.staff_id
WHERE s.role = 'NURSE'
  AND r.status <> 'CANCELLED'
GROUP BY r.ward_id, substr(r.shift_date, 1, 7)
ORDER BY r.ward_id ASC, shift_month ASC;
