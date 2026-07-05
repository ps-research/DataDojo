-- TLE candidate: correct result, but conversion tested with a correlated per-user
-- scan of events instead of a set-based join+aggregate.
WITH comp AS (
  SELECT experiment_id, experiment_key, start_date, COALESCE(end_date,'2025-03-31') AS end_eff, primary_metric
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
  WHERE NOT EXISTS (SELECT 1 FROM contaminated x WHERE x.experiment_id=a.experiment_id AND x.user_id=a.user_id)
  GROUP BY a.experiment_id, c.experiment_key, c.primary_metric, a.user_id),
conv AS (
  SELECT cl.experiment_id, cl.experiment_key, cl.variant,
    CASE WHEN EXISTS (SELECT 1 FROM events e WHERE e.user_id=cl.user_id AND e.event_type=cl.primary_metric AND e.event_ts>cl.assigned_ts) THEN 1 ELSE 0 END AS converted
  FROM clean cl),
agg AS (SELECT experiment_id, experiment_key, variant, COUNT(*) n_users, SUM(converted) n_conv FROM conv GROUP BY experiment_id, experiment_key, variant)
SELECT c.experiment_key,
  COALESCE(ct.n_users,0) control_users, COALESCE(ct.n_conv,0) control_conversions, ROUND(1.0*ct.n_conv/NULLIF(ct.n_users,0),6) control_rate,
  COALESCE(tr.n_users,0) treatment_users, COALESCE(tr.n_conv,0) treatment_conversions, ROUND(1.0*tr.n_conv/NULLIF(tr.n_users,0),6) treatment_rate,
  ROUND(1.0*tr.n_conv/NULLIF(tr.n_users,0)-1.0*ct.n_conv/NULLIF(ct.n_users,0),6) lift
FROM comp c
LEFT JOIN agg ct ON ct.experiment_id=c.experiment_id AND ct.variant='control'
LEFT JOIN agg tr ON tr.experiment_id=c.experiment_id AND tr.variant='treatment'
ORDER BY lift DESC, c.experiment_key;
