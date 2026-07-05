WITH cal(wk, wk_start, wk_end) AS (
  SELECT 0 AS wk, '2024-01-01' AS wk_start, '2024-01-08' AS wk_end UNION ALL
  SELECT 1 AS wk, '2024-01-08' AS wk_start, '2024-01-15' AS wk_end UNION ALL
  SELECT 2 AS wk, '2024-01-15' AS wk_start, '2024-01-22' AS wk_end UNION ALL
  SELECT 3 AS wk, '2024-01-22' AS wk_start, '2024-01-29' AS wk_end UNION ALL
  SELECT 4 AS wk, '2024-01-29' AS wk_start, '2024-02-05' AS wk_end UNION ALL
  SELECT 5 AS wk, '2024-02-05' AS wk_start, '2024-02-12' AS wk_end UNION ALL
  SELECT 6 AS wk, '2024-02-12' AS wk_start, '2024-02-19' AS wk_end UNION ALL
  SELECT 7 AS wk, '2024-02-19' AS wk_start, '2024-02-26' AS wk_end UNION ALL
  SELECT 8 AS wk, '2024-02-26' AS wk_start, '2024-03-04' AS wk_end UNION ALL
  SELECT 9 AS wk, '2024-03-04' AS wk_start, '2024-03-11' AS wk_end UNION ALL
  SELECT 10 AS wk, '2024-03-11' AS wk_start, '2024-03-18' AS wk_end UNION ALL
  SELECT 11 AS wk, '2024-03-18' AS wk_start, '2024-03-25' AS wk_end UNION ALL
  SELECT 12 AS wk, '2024-03-25' AS wk_start, '2024-04-01' AS wk_end UNION ALL
  SELECT 13 AS wk, '2024-04-01' AS wk_start, '2024-04-08' AS wk_end UNION ALL
  SELECT 14 AS wk, '2024-04-08' AS wk_start, '2024-04-15' AS wk_end UNION ALL
  SELECT 15 AS wk, '2024-04-15' AS wk_start, '2024-04-22' AS wk_end UNION ALL
  SELECT 16 AS wk, '2024-04-22' AS wk_start, '2024-04-29' AS wk_end UNION ALL
  SELECT 17 AS wk, '2024-04-29' AS wk_start, '2024-05-06' AS wk_end UNION ALL
  SELECT 18 AS wk, '2024-05-06' AS wk_start, '2024-05-13' AS wk_end UNION ALL
  SELECT 19 AS wk, '2024-05-13' AS wk_start, '2024-05-20' AS wk_end UNION ALL
  SELECT 20 AS wk, '2024-05-20' AS wk_start, '2024-05-27' AS wk_end UNION ALL
  SELECT 21 AS wk, '2024-05-27' AS wk_start, '2024-06-03' AS wk_end UNION ALL
  SELECT 22 AS wk, '2024-06-03' AS wk_start, '2024-06-10' AS wk_end UNION ALL
  SELECT 23 AS wk, '2024-06-10' AS wk_start, '2024-06-17' AS wk_end UNION ALL
  SELECT 24 AS wk, '2024-06-17' AS wk_start, '2024-06-24' AS wk_end UNION ALL
  SELECT 25 AS wk, '2024-06-24' AS wk_start, '2024-07-01' AS wk_end UNION ALL
  SELECT 26 AS wk, '2024-07-01' AS wk_start, '2024-07-08' AS wk_end UNION ALL
  SELECT 27 AS wk, '2024-07-08' AS wk_start, '2024-07-15' AS wk_end UNION ALL
  SELECT 28 AS wk, '2024-07-15' AS wk_start, '2024-07-22' AS wk_end UNION ALL
  SELECT 29 AS wk, '2024-07-22' AS wk_start, '2024-07-29' AS wk_end UNION ALL
  SELECT 30 AS wk, '2024-07-29' AS wk_start, '2024-08-05' AS wk_end UNION ALL
  SELECT 31 AS wk, '2024-08-05' AS wk_start, '2024-08-12' AS wk_end UNION ALL
  SELECT 32 AS wk, '2024-08-12' AS wk_start, '2024-08-19' AS wk_end UNION ALL
  SELECT 33 AS wk, '2024-08-19' AS wk_start, '2024-08-26' AS wk_end UNION ALL
  SELECT 34 AS wk, '2024-08-26' AS wk_start, '2024-09-02' AS wk_end UNION ALL
  SELECT 35 AS wk, '2024-09-02' AS wk_start, '2024-09-09' AS wk_end UNION ALL
  SELECT 36 AS wk, '2024-09-09' AS wk_start, '2024-09-16' AS wk_end UNION ALL
  SELECT 37 AS wk, '2024-09-16' AS wk_start, '2024-09-23' AS wk_end UNION ALL
  SELECT 38 AS wk, '2024-09-23' AS wk_start, '2024-09-30' AS wk_end UNION ALL
  SELECT 39 AS wk, '2024-09-30' AS wk_start, '2024-10-07' AS wk_end UNION ALL
  SELECT 40 AS wk, '2024-10-07' AS wk_start, '2024-10-14' AS wk_end UNION ALL
  SELECT 41 AS wk, '2024-10-14' AS wk_start, '2024-10-21' AS wk_end UNION ALL
  SELECT 42 AS wk, '2024-10-21' AS wk_start, '2024-10-28' AS wk_end UNION ALL
  SELECT 43 AS wk, '2024-10-28' AS wk_start, '2024-11-04' AS wk_end UNION ALL
  SELECT 44 AS wk, '2024-11-04' AS wk_start, '2024-11-11' AS wk_end UNION ALL
  SELECT 45 AS wk, '2024-11-11' AS wk_start, '2024-11-18' AS wk_end UNION ALL
  SELECT 46 AS wk, '2024-11-18' AS wk_start, '2024-11-25' AS wk_end UNION ALL
  SELECT 47 AS wk, '2024-11-25' AS wk_start, '2024-12-02' AS wk_end UNION ALL
  SELECT 48 AS wk, '2024-12-02' AS wk_start, '2024-12-09' AS wk_end UNION ALL
  SELECT 49 AS wk, '2024-12-09' AS wk_start, '2024-12-16' AS wk_end UNION ALL
  SELECT 50 AS wk, '2024-12-16' AS wk_start, '2024-12-23' AS wk_end UNION ALL
  SELECT 51 AS wk, '2024-12-23' AS wk_start, '2024-12-30' AS wk_end UNION ALL
  SELECT 52 AS wk, '2024-12-30' AS wk_start, '2025-01-06' AS wk_end UNION ALL
  SELECT 53 AS wk, '2025-01-06' AS wk_start, '2025-01-13' AS wk_end UNION ALL
  SELECT 54 AS wk, '2025-01-13' AS wk_start, '2025-01-20' AS wk_end UNION ALL
  SELECT 55 AS wk, '2025-01-20' AS wk_start, '2025-01-27' AS wk_end UNION ALL
  SELECT 56 AS wk, '2025-01-27' AS wk_start, '2025-02-03' AS wk_end UNION ALL
  SELECT 57 AS wk, '2025-02-03' AS wk_start, '2025-02-10' AS wk_end UNION ALL
  SELECT 58 AS wk, '2025-02-10' AS wk_start, '2025-02-17' AS wk_end UNION ALL
  SELECT 59 AS wk, '2025-02-17' AS wk_start, '2025-02-24' AS wk_end UNION ALL
  SELECT 60 AS wk, '2025-02-24' AS wk_start, '2025-03-03' AS wk_end UNION ALL
  SELECT 61 AS wk, '2025-03-03' AS wk_start, '2025-03-10' AS wk_end UNION ALL
  SELECT 62 AS wk, '2025-03-10' AS wk_start, '2025-03-17' AS wk_end UNION ALL
  SELECT 63 AS wk, '2025-03-17' AS wk_start, '2025-03-24' AS wk_end UNION ALL
  SELECT 64 AS wk, '2025-03-24' AS wk_start, '2025-03-31' AS wk_end UNION ALL
  SELECT 65 AS wk, '2025-03-31' AS wk_start, '2025-04-07' AS wk_end
),
comp AS (SELECT experiment_id, experiment_key, start_date, COALESCE(end_date,'2025-03-31') AS end_eff, primary_metric
         FROM experiments WHERE status='completed' AND end_date IS NOT NULL),
allexp AS (SELECT experiment_id, start_date, COALESCE(end_date,'2025-03-31') AS end_eff FROM experiments),
both_variant AS (SELECT experiment_id, user_id FROM experiment_assignments GROUP BY experiment_id, user_id HAVING COUNT(DISTINCT variant)>1),
multi AS (SELECT DISTINCT a.experiment_id, a.user_id FROM experiment_assignments a
  JOIN comp c ON c.experiment_id=a.experiment_id
  JOIN experiment_assignments a2 ON a2.user_id=a.user_id AND a2.experiment_id<>a.experiment_id
  JOIN allexp y ON y.experiment_id=a2.experiment_id WHERE y.start_date<=c.end_eff AND c.start_date<=y.end_eff),
contaminated AS (SELECT experiment_id, user_id FROM both_variant UNION SELECT experiment_id, user_id FROM multi),
clean AS (SELECT a.experiment_id, c.experiment_key, c.primary_metric, a.user_id, MIN(a.variant) variant, MIN(a.assigned_ts) assigned_ts
  FROM experiment_assignments a JOIN comp c ON c.experiment_id=a.experiment_id
  JOIN users u ON u.user_id=a.user_id AND u.is_internal=0
  WHERE NOT EXISTS (SELECT 1 FROM contaminated x WHERE x.experiment_id=a.experiment_id AND x.user_id=a.user_id)
  GROUP BY a.experiment_id, c.experiment_key, c.primary_metric, a.user_id),
clean_wk AS (SELECT cl.experiment_id, cl.experiment_key, cl.primary_metric, cl.user_id, cl.variant, cl.assigned_ts, ca.wk AS assign_wk
  FROM clean cl JOIN cal ca ON cl.assigned_ts>=ca.wk_start AND cl.assigned_ts<ca.wk_end),
uwk AS (SELECT DISTINCT s.user_id AS user_id, c.wk AS sess_wk FROM sessions s JOIN cal c ON s.started_ts>=c.wk_start AND s.started_ts<c.wk_end),
island AS (
  SELECT cw.experiment_id, cw.experiment_key, cw.primary_metric, cw.variant, cw.user_id, cw.assigned_ts
  FROM clean_wk cw JOIN uwk uw ON uw.user_id=cw.user_id AND uw.sess_wk BETWEEN cw.assign_wk+1 AND cw.assign_wk+2
  GROUP BY cw.experiment_id, cw.experiment_key, cw.primary_metric, cw.variant, cw.user_id, cw.assigned_ts
  HAVING COUNT(DISTINCT uw.sess_wk) = 2),
conv AS (SELECT i.experiment_id, i.experiment_key, i.variant, i.user_id,
    MAX(CASE WHEN e.event_type=i.primary_metric AND e.event_ts>i.assigned_ts THEN 1 ELSE 0 END) AS converted
  FROM island i LEFT JOIN events e ON e.user_id=i.user_id
  GROUP BY i.experiment_id, i.experiment_key, i.variant, i.user_id),
agg AS (SELECT experiment_id, experiment_key, variant, COUNT(*) n_users, SUM(converted) n_conv FROM conv GROUP BY experiment_id, experiment_key, variant),
pivot AS (SELECT c.experiment_id, c.experiment_key, COALESCE(ct.n_users,0) control_qualified, COALESCE(ct.n_conv,0) control_conv,
    COALESCE(tr.n_users,0) treatment_qualified, COALESCE(tr.n_conv,0) treatment_conv
  FROM comp c LEFT JOIN agg ct ON ct.experiment_id=c.experiment_id AND ct.variant='control'
  LEFT JOIN agg tr ON tr.experiment_id=c.experiment_id AND tr.variant='treatment'),
rated AS (SELECT experiment_key, control_qualified, treatment_qualified, control_qualified+treatment_qualified AS qualified_size,
    1.0*control_conv/NULLIF(control_qualified,0) AS control_rate, 1.0*treatment_conv/NULLIF(treatment_qualified,0) AS treatment_rate
  FROM pivot WHERE control_qualified>0 AND treatment_qualified>0)
SELECT ROW_NUMBER() OVER (ORDER BY (treatment_rate-control_rate) DESC, experiment_key ASC) AS rank_pos,
  experiment_key, control_qualified, treatment_qualified, qualified_size,
  ROUND(control_rate,6) control_rate, ROUND(treatment_rate,6) treatment_rate, ROUND(treatment_rate-control_rate,6) uplift
FROM rated ORDER BY rank_pos;
