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
usr AS (
  SELECT u.user_id, c.wk AS signup_wk, c.wk_start AS cohort_start
  FROM users u JOIN cal c ON u.signup_ts>=c.wk_start AND u.signup_ts<c.wk_end
  WHERE u.is_internal=0
),
uwk AS (
  SELECT DISTINCT e.user_id AS user_id, c.wk AS active_wk
  FROM events e JOIN cal c ON e.event_ts>=c.wk_start AND e.event_ts<c.wk_end
  WHERE e.user_id IN (SELECT user_id FROM usr)
),
act AS (
  SELECT usr.signup_wk, usr.cohort_start, uwk.user_id, (uwk.active_wk - usr.signup_wk) AS off
  FROM usr JOIN uwk ON uwk.user_id=usr.user_id
  WHERE (uwk.active_wk - usr.signup_wk) BETWEEN 0 AND 8
),
csize AS (SELECT signup_wk, cohort_start, COUNT(*) AS cohort_size FROM usr GROUP BY signup_wk, cohort_start),
cnt AS (SELECT signup_wk, off, COUNT(DISTINCT user_id) AS active_users FROM act GROUP BY signup_wk, off),
offs(off) AS (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
              UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8)
SELECT cs.cohort_start AS cohort_week, o.off AS week_offset, cs.cohort_size,
       COALESCE(cnt.active_users,0) AS active_users,
       ROUND(1.0*COALESCE(cnt.active_users,0)/NULLIF(cs.cohort_size,0),6) AS retention_rate
FROM csize cs CROSS JOIN offs o
LEFT JOIN cnt ON cnt.signup_wk=cs.signup_wk AND cnt.off=o.off
ORDER BY cohort_week, week_offset;
