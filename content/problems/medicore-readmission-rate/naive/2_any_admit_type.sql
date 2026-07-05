-- NAIVE (WA): counts the immediate next admission as a readmission regardless of its
-- admit_type, so a planned ELECTIVE return or an internal TRANSFER that happens to land
-- within 30 days is wrongly counted. Only an unplanned EMERGENCY return should qualify.
-- Departments whose patients have planned within-30-day returns over-report their
-- readmission count and rate. The window and eligibility here are correct -- the single
-- fault is the missing next_admit_type = 'EMERGENCY' condition.
WITH seq AS (
    SELECT a.admission_id, a.patient_id, w.department AS department, a.admit_ts, a.discharge_ts, a.discharge_disposition,
           LEAD(a.admit_ts) OVER (PARTITION BY a.patient_id ORDER BY a.admit_ts, a.admission_id) AS next_admit_ts
    FROM admissions a JOIN wards w ON w.ward_id = a.ward_id
),
idx AS (
    SELECT department,
           CASE WHEN next_admit_ts IS NOT NULL
                     AND next_admit_ts >= discharge_ts
                     AND next_admit_ts <= datetime(discharge_ts, '+30 days')
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
