-- NAIVE (WA): buckets each shift by the month of scheduled_end instead of shift_date.
-- A NIGHT shift ends on the following calendar day, so a shift that starts on the last
-- day of a month (e.g. 29 Feb 2024) has a scheduled_end in the next month and is
-- misfiled there. Its hours leak out of the month it was actually worked in. (This
-- query keeps the DISTINCT de-duplication, so the ONLY error is the month attribution.)
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
    substr(scheduled_end, 1, 7)                 AS shift_month,
    ROUND(SUM(COALESCE(actual_hours, 0)), 2)    AS worked_hours
FROM nurse_shifts
GROUP BY ward_id, substr(scheduled_end, 1, 7)
ORDER BY ward_id ASC, shift_month ASC;
