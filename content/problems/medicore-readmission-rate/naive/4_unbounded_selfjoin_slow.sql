-- NAIVE (WA + TLE): the "correlated self-join" attempt, and the designated TLE-slow
-- solution. Two faults:
--   1. Correctness: it flags an index as readmitted if ANY later admission of the
--      patient falls within 30 days (regardless of admit_type and not restricted to the
--      IMMEDIATE next). Planned/transfer returns and non-adjacent bounce-backs are all
--      counted, over-stating readmissions.
--   2. Performance: for each eligible index it re-scans admissions in a correlated
--      EXISTS -- O(index stays x admissions). At black scale (~1.3M admissions) this
--      blows the time limit, whereas the reference's single LEAD window pass finishes
--      well under it.
WITH idx AS (
    SELECT a.admission_id, a.patient_id, w.department AS department, a.discharge_ts
    FROM admissions a JOIN wards w ON w.ward_id = a.ward_id
    WHERE a.discharge_ts IS NOT NULL
      AND a.discharge_disposition NOT IN ('EXPIRED', 'TRANSFER')
),
flag AS (
    SELECT i.department,
           CASE WHEN EXISTS (
                    SELECT 1 FROM admissions r
                    WHERE r.patient_id = i.patient_id
                      AND r.admit_ts >  i.discharge_ts
                      AND r.admit_ts <= datetime(i.discharge_ts, '+30 days')
                ) THEN 1 ELSE 0 END AS readmitted
    FROM idx i
)
SELECT department,
       COUNT(*)        AS eligible_index_stays,
       SUM(readmitted) AS readmissions,
       ROUND(1.0 * SUM(readmitted) / COUNT(*), 4) AS readmission_rate
FROM flag
GROUP BY department
ORDER BY department ASC;
