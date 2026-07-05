-- NAIVE: silently drops the NULL referral_channel segment (L1) via IS NOT NULL,
-- and uses a bare division (no NULLIF) for the rates (L10, RE on postgres).
WITH sess AS (
  SELECT s.session_id, u.referral_channel AS channel,
         MIN(CASE WHEN e.event_type='view_plans'     THEN e.event_ts END) AS t1,
         MIN(CASE WHEN e.event_type='start_checkout' THEN e.event_ts END) AS t2,
         MIN(CASE WHEN e.event_type='enter_payment'  THEN e.event_ts END) AS t3,
         MIN(CASE WHEN e.event_type='purchase'       THEN e.event_ts END) AS t4
  FROM sessions s JOIN users u ON u.user_id=s.user_id
  LEFT JOIN events e ON e.session_id=s.session_id
  WHERE u.referral_channel IS NOT NULL
  GROUP BY s.session_id, u.referral_channel
),
fl AS (
  SELECT channel,
    CASE WHEN t1 IS NOT NULL THEN 1 ELSE 0 END AS r1,
    CASE WHEN t1 IS NOT NULL AND t2 IS NOT NULL AND t2>=t1 THEN 1 ELSE 0 END AS r2,
    CASE WHEN t1 IS NOT NULL AND t2 IS NOT NULL AND t2>=t1 AND t3 IS NOT NULL AND t3>=t2 THEN 1 ELSE 0 END AS r3,
    CASE WHEN t1 IS NOT NULL AND t2 IS NOT NULL AND t2>=t1 AND t3 IS NOT NULL AND t3>=t2 AND t4 IS NOT NULL AND t4>=t3 THEN 1 ELSE 0 END AS r4
  FROM sess
)
SELECT channel AS referral_channel, SUM(r1) AS entered,
  SUM(r2) AS reached_checkout, SUM(r3) AS reached_payment, SUM(r4) AS reached_purchase,
  ROUND(1.0*SUM(r2)/SUM(r1),6) AS cr_checkout,
  ROUND(1.0*SUM(r3)/SUM(r2),6) AS cr_payment,
  ROUND(1.0*SUM(r4)/SUM(r3),6) AS cr_purchase
FROM fl GROUP BY channel ORDER BY entered DESC, referral_channel;
