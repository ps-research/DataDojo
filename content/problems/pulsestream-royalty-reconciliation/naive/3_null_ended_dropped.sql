-- NAIVE (WA): the active-subscription predicate omits the NULL guard on ended_at.
-- With ended_at NULL the comparison `play_date <= CONCAT(ended_at,'')` is false /
-- UNKNOWN on every engine, so every play made under a still-active (open-ended)
-- subscription is dropped. Those are exactly the current premium/family listeners,
-- so a large share of royalty vanishes and the reconciliation is wrong. NULL
-- ended_at means "still active", not "excluded".
WITH play_dates AS (
    SELECT play_id, user_id, track_id,
           SUBSTR(CONCAT(played_at, ''), 1, 10)               AS play_date,
           CONCAT(SUBSTR(CONCAT(played_at, ''), 1, 7), '-01') AS period_month
    FROM plays
),
active_plan AS (
    SELECT pd.play_id, pd.track_id, pd.user_id, pd.play_date, pd.period_month, s.plan,
           ROW_NUMBER() OVER (
               PARTITION BY pd.play_id
               ORDER BY CASE s.plan WHEN 'premium' THEN 5 WHEN 'family' THEN 4
                                    WHEN 'student' THEN 3 WHEN 'trial' THEN 2
                                    WHEN 'free' THEN 1 ELSE 0 END DESC,
                        s.started_at DESC, s.subscription_id ASC) AS rn
    FROM play_dates pd
    JOIN subscriptions s
      ON s.user_id = pd.user_id
     AND CONCAT(s.started_at, '') <= pd.play_date
     AND pd.play_date <= CONCAT(s.ended_at, '')      -- BUG: drops open-ended (NULL) subs
),
paid_plays AS (
    SELECT play_id, track_id, user_id, play_date, period_month, plan
    FROM active_plan WHERE rn = 1 AND plan IN ('student', 'family', 'premium')
),
play_royalty AS (
    SELECT t.artist_id, pp.period_month,
           COALESCE(rc.per_play_usd, rg.per_play_usd, 0) AS rate
    FROM paid_plays pp
    JOIN tracks t ON t.track_id = pp.track_id
    JOIN users  u ON u.user_id  = pp.user_id
    LEFT JOIN royalty_rates rc ON rc.plan = pp.plan AND rc.country = u.country
          AND CONCAT(rc.effective_from, '') <= pp.play_date AND (rc.effective_to IS NULL OR pp.play_date < CONCAT(rc.effective_to, ''))
    LEFT JOIN royalty_rates rg ON rg.plan = pp.plan AND rg.country IS NULL
          AND CONCAT(rg.effective_from, '') <= pp.play_date AND (rg.effective_to IS NULL OR pp.play_date < CONCAT(rg.effective_to, ''))
),
computed AS (
    SELECT artist_id, period_month, ROUND(SUM(rate), 2) AS computed_usd
    FROM play_royalty GROUP BY artist_id, period_month HAVING ROUND(SUM(rate), 2) > 0
),
payout_agg AS (
    SELECT artist_id, CONCAT(period_month, '') AS period_month, 1 AS has_payout,
           SUM(CASE WHEN status = 'paid' THEN amount_usd ELSE 0 END) AS paid_usd,
           MAX(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) AS any_paid,
           MAX(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS any_pending
    FROM artist_payouts WHERE artist_id IS NOT NULL GROUP BY artist_id, CONCAT(period_month, '')
)
SELECT c.artist_id, a.name AS artist_name, c.period_month, c.computed_usd,
       COALESCE(pa.paid_usd, 0) AS paid_usd,
       CASE WHEN pa.has_payout IS NULL THEN 'missing'
            WHEN pa.any_paid = 1 THEN 'paid'
            WHEN pa.any_pending = 1 THEN 'pending'
            ELSE 'reversed' END AS payout_status,
       ROUND(c.computed_usd - COALESCE(pa.paid_usd, 0), 2) AS discrepancy_usd
FROM computed c
JOIN artists a ON a.artist_id = c.artist_id
LEFT JOIN payout_agg pa ON pa.artist_id = c.artist_id AND pa.period_month = c.period_month
WHERE pa.has_payout IS NULL
   OR (pa.has_payout = 1 AND pa.any_paid = 0)
   OR (pa.any_paid = 1 AND ABS(c.computed_usd - pa.paid_usd) > 0.01)
ORDER BY c.artist_id, c.period_month;
