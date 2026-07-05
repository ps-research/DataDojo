-- NAIVE (WA): the designed kill. It computes breaches from roster_shifts alone --
-- GROUP BY (ward, date, shift) over WORKED nurse rows, then HAVING count < min. Because
-- the group only exists when at least one WORKED nurse row exists, it can NEVER emit a
-- slot that has zero worked nurses: a slot with no roster rows at all, or one where
-- every assigned nurse no-showed or cancelled, simply produces no group and is silently
-- omitted. Those fully-uncovered slots are exactly the worst gaps -- and exactly what
-- the safety review needs. On the fixtures it misses the guaranteed ward-2 / 29-Feb
-- NIGHT (no rows) and DAY (all no-show) breaches, and every other empty slot.
SELECT
    r.ward_id,
    r.shift_date,
    r.shift_type,
    w.min_nurses_per_shift                       AS required_nurses,
    COUNT(DISTINCT r.staff_id)                   AS nurses_worked,
    w.min_nurses_per_shift - COUNT(DISTINCT r.staff_id) AS shortfall
FROM roster_shifts r
JOIN staff s ON s.staff_id = r.staff_id
JOIN wards w ON w.ward_id = r.ward_id
WHERE s.role = 'NURSE'
  AND r.status = 'WORKED'
  AND w.min_nurses_per_shift > 0
  AND r.shift_date >= '2024-02-01' AND r.shift_date <= '2024-02-29'
GROUP BY r.ward_id, r.shift_date, r.shift_type, w.min_nurses_per_shift
HAVING COUNT(DISTINCT r.staff_id) < w.min_nurses_per_shift
ORDER BY r.ward_id ASC, r.shift_date ASC, r.shift_type ASC;
