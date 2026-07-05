-- NAIVE 2: arrival mid taken from the latest quote with no validity filter, so
-- NULL-side, crossed/locked (bid>=ask), and one-sided (size-0) quotes corrupt the
-- mid and therefore the slippage.
WITH taker AS (
    SELECT fill_id, order_id, instrument_id, side, fill_price, fill_quantity, fill_time,
           ROW_NUMBER() OVER (PARTITION BY order_id, side, fill_price, fill_quantity, fill_time
                              ORDER BY fill_id) AS rn
    FROM fills
    WHERE liquidity_flag = 'TAKER'
      AND session_date BETWEEN '2023-01-01' AND '2023-03-31'
),
ff AS (
    SELECT fill_id, instrument_id,
           CASE WHEN side = 'BUY' THEN 1 ELSE -1 END AS side_sign,
           fill_price, fill_quantity, fill_time AS t
    FROM taker WHERE rn = 1
),
vq AS (
    SELECT instrument_id, quote_time AS t, bid_price, ask_price, quote_id
    FROM quotes
    WHERE 1 = 1  -- NO VALIDITY FILTER: NULL-side, crossed/locked, and one-sided quotes pollute the mid
),
ev AS (
    SELECT instrument_id, t, 0 AS is_fill, quote_id AS ord2,
           bid_price, ask_price,
           CAST(NULL AS INTEGER) AS fill_id, CAST(NULL AS INTEGER) AS side_sign,
           CAST(NULL AS REAL) AS fill_price, CAST(NULL AS INTEGER) AS fill_quantity
    FROM vq
    UNION ALL
    SELECT instrument_id, t, 1 AS is_fill, fill_id AS ord2,
           CAST(NULL AS REAL), CAST(NULL AS REAL),
           fill_id, side_sign, fill_price, fill_quantity
    FROM ff
),
idx AS (
    SELECT ev.*,
        SUM(CASE WHEN is_fill = 0 THEN 1 ELSE 0 END)
            OVER (PARTITION BY instrument_id ORDER BY t, is_fill, ord2
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS qrank
    FROM ev
),
qlist AS (
    SELECT instrument_id, qrank, bid_price, ask_price FROM idx WHERE is_fill = 0
),
per_fill AS (
    SELECT f.instrument_id, f.side_sign, f.fill_price, f.fill_quantity,
           (q.bid_price + q.ask_price) / 2.0 AS mid
    FROM idx f
    LEFT JOIN qlist q ON q.instrument_id = f.instrument_id AND q.qrank = f.qrank
    WHERE f.is_fill = 1
),
agg AS (
    SELECT i.instrument_id, i.symbol,
           SUM(p.fill_quantity) AS taker_volume,
           ROUND(SUM(p.fill_price * p.fill_quantity) / SUM(p.fill_quantity), 6) AS realized_vwap,
           ROUND(AVG(CASE WHEN p.mid IS NOT NULL AND p.mid > 0
                          THEN p.side_sign * (p.fill_price - p.mid) / p.mid * 10000.0
                          END), 4) AS avg_slippage_bps
    FROM per_fill p
    JOIN instruments i ON i.instrument_id = p.instrument_id
    GROUP BY i.instrument_id, i.symbol
)
SELECT RANK() OVER (ORDER BY taker_volume DESC) AS vol_rank,
       symbol, taker_volume, realized_vwap, avg_slippage_bps
FROM agg
ORDER BY vol_rank, symbol;
