WITH vq AS (
    SELECT instrument_id, quote_time AS t, bid_price, ask_price, quote_id
    FROM quotes
    WHERE bid_price IS NOT NULL AND ask_price IS NOT NULL AND ask_price > bid_price AND bid_size > 0 AND ask_size > 0
),
ff AS (
    SELECT fill_id, instrument_id, fill_price, fill_time AS t
    FROM fills
    WHERE session_date BETWEEN '2023-01-03' AND '2023-01-31'
),
ev AS (
    SELECT instrument_id, t, 0 AS is_fill, quote_id AS ord2,
           bid_price, ask_price, CAST(NULL AS INTEGER) AS fill_id,
           CAST(NULL AS REAL) AS fill_price
    FROM vq
    UNION ALL
    SELECT instrument_id, t, 1 AS is_fill, fill_id AS ord2,
           CAST(NULL AS REAL), CAST(NULL AS REAL), fill_id, fill_price
    FROM ff
),
idx AS (
    SELECT ev.*,
        SUM(CASE WHEN is_fill = 0 THEN 1 ELSE 0 END)
            OVER (PARTITION BY instrument_id
                  ORDER BY t, is_fill, ord2
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS qrank
    FROM ev
),
qlist AS (
    SELECT instrument_id, qrank, bid_price, ask_price
    FROM idx WHERE is_fill = 0
),
scored AS (
    SELECT f.instrument_id, f.fill_id, f.fill_price,
           (q.bid_price + q.ask_price) / 2.0 AS mid,
           q.bid_price AS bid, q.ask_price AS ask
    FROM idx f
    JOIN qlist q
      ON q.instrument_id = f.instrument_id AND q.qrank = f.qrank
    WHERE f.is_fill = 1 AND f.qrank >= 1
)
SELECT i.symbol,
       COUNT(*) AS n_fills,
       ROUND(AVG(2.0 * ABS(s.fill_price - s.mid)), 6) AS avg_effective_spread,
       ROUND(AVG(CASE WHEN s.fill_price > s.bid AND s.fill_price < s.ask
                      THEN 1.0 ELSE 0.0 END), 6) AS price_improve_share
FROM scored s
JOIN instruments i ON i.instrument_id = s.instrument_id
GROUP BY i.instrument_id, i.symbol
ORDER BY i.symbol;
