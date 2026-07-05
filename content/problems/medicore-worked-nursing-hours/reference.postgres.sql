-- PostgreSQL: to_char(shift_date, 'YYYY-MM') builds the month key from the DATE.
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
    to_char(shift_date, 'YYYY-MM')              AS shift_month,
    ROUND(SUM(COALESCE(actual_hours, 0)), 2)    AS worked_hours
FROM nurse_shifts
GROUP BY ward_id, to_char(shift_date, 'YYYY-MM')
ORDER BY ward_id ASC, shift_month ASC;
