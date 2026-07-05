-- Actual nursing hours per ward and start-month.
-- nurse_shifts: SELECT DISTINCT over the business columns of each nurse, non-cancelled
--   roster row. The DISTINCT collapses a double-booked duplicate (same nurse, ward,
--   date, shift type, scheduled times, hours and status but a new shift_id) into one
--   row, so it is counted once. Restricting to role = 'NURSE' and status <> 'CANCELLED'
--   keeps worked, no-show and swapped shifts and drops cancellations.
-- Aggregate: group by ward and the START month (substr of shift_date, the date the
--   shift begins) -- so a month-end NIGHT shift stays in the month it starts, not the
--   month scheduled_end rolls into. COALESCE(actual_hours,0) scores a no-show as 0
--   while still keeping its ward-month present in the report.
-- SQLite form: substr(shift_date,1,7) is the 'YYYY-MM' key. Per-engine month-key
-- overrides live in reference.postgres.sql, reference.mysql.sql, reference.duckdb.sql.
WITH nurse_shifts AS (
    SELECT DISTINCT
        r.staff_id, r.ward_id, r.shift_date, r.shift_type,
        r.scheduled_start, r.scheduled_end, r.scheduled_hours, r.actual_hours, r.status
    FROM roster_shifts r
    JOIN staff s ON s.staff_id = r.staff_id
    WHERE s.role = 'NURSE'
      AND r.status <> 'CANCELLED'
)
SELECT
    ward_id,
    substr(shift_date, 1, 7)                    AS shift_month,
    ROUND(SUM(COALESCE(actual_hours, 0)), 2)    AS worked_hours
FROM nurse_shifts
GROUP BY ward_id, substr(shift_date, 1, 7)
ORDER BY ward_id ASC, shift_month ASC;
