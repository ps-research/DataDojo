-- NAIVE (WA): uses a STRICT less-than 30-day window, so a readmission that admits
-- exactly 30 days after the index discharge is excluded. The regulator definition is
-- inclusive of day 30. On the fixtures the guaranteed exact-30-day bounce-back (in
-- Cardiology) is dropped, understating that department's readmission count and rate.
-- Everything else matches the reference -- the single fault is the exclusive bound.
WITH seq AS (
    SELECT a.admission_id, a.patient_id, w.department AS department, a.admit_ts, a.discharge_ts, a.discharge_disposition,
           LEAD(a.admit_ts)   OVER (PARTITION BY a.patient_id ORDER BY a.admit_ts, a.admission_id) AS next_admit_ts,
           LEAD(a.admit_type) OVER (PARTITION BY a.patient_id ORDER BY a.admit_ts, a.admission_id) AS next_admit_type
    FROM admissions a JOIN wards w ON w.ward_id = a.ward_id
),
idx AS (
    SELECT department,
           CASE WHEN next_admit_type = 'EMERGENCY' AND next_admit_ts IS NOT NULL
                     AND next_admit_ts >= discharge_ts
                     AND next_admit_ts <  datetime(discharge_ts, '+30 days')   -- exclusive: misses day 30
                THEN 1 ELSE 0 END AS readmitted
    FROM seq
    WHERE discharge_ts IS NOT NULL AND discharge_disposition NOT IN ('EXPIRED', 'TRANSFER')
),
agg AS ( SELECT department, COUNT(*) AS e, SUM(readmitted) AS r FROM idx GROUP BY department )
SELECT d.department, COALESCE(g.e, 0) AS eligible_index_stays, COALESCE(g.r, 0) AS readmissions,
       ROUND(1.0 * g.r / NULLIF(g.e, 0), 4) AS readmission_rate
FROM (SELECT DISTINCT department FROM wards) d
LEFT JOIN agg g ON g.department = d.department
ORDER BY d.department ASC;
