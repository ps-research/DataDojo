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
ev AS (
  SELECT c.wk AS wk, c.wk_start AS week_start
  FROM events e JOIN cal c ON e.event_ts>=c.wk_start AND e.event_ts<c.wk_end
),
wau AS (SELECT wk, week_start, COUNT(*) AS wau FROM ev GROUP BY wk, week_start)
SELECT week_start, wau,
  ROUND(1.0*(wau - LAG(wau) OVER (ORDER BY wk))/NULLIF(LAG(wau) OVER (ORDER BY wk),0),6) AS wow_growth
FROM wau ORDER BY wk;
