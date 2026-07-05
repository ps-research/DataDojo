-- NAIVE 4: correct result, but the arrival mid is found by a correlated
-- subquery scanning quotes per fill (no windowed as-of). O(fills x quotes)
-- per instrument -> Time Limit Exceeded at black scale (~2M fills). Output
-- matches the reference on small inputs; it fails on time, not correctness.
WITH taker AS (
    SELECT fill_id, order_id, instrument_id, side, fill_price, fill_quantity, fill_time,
           ROW_NUMBER() OVER (PARTITION BY order_id, side, fill_price, fill_quantity, fill_time
                              ORDER BY fill_id) AS rn
    FROM fills
    WHERE liquidity_flag = 'TAKER'
      AND session_date BETWEEN '2023-01-01' AND '2023-03-31'
),
ff AS (
    SELECT t.fill_id, t.instrument_id,
           CASE WHEN t.side='BUY' THEN 1 ELSE -1 END AS side_sign,
           t.fill_price, t.fill_quantity, t.fill_time,
      (SELECT q.quote_id FROM quotes q
       WHERE q.instrument_id = t.instrument_id AND q.quote_time <= t.fill_time
         AND q.bid_price IS NOT NULL AND q.ask_price IS NOT NULL AND q.ask_price>q.bid_price AND q.bid_size>0 AND q.ask_size>0
       ORDER BY q.quote_time DESC, q.quote_id DESC LIMIT 1) AS qid
    FROM taker t WHERE t.rn=1
),
per_fill AS (
    SELECT f.instrument_id, f.side_sign, f.fill_price, f.fill_quantity,
           (qq.bid_price+qq.ask_price)/2.0 AS mid
    FROM ff f LEFT JOIN quotes qq ON qq.quote_id=f.qid
),
agg AS (
    SELECT i.instrument_id, i.symbol,
           SUM(p.fill_quantity) AS taker_volume,
           ROUND(SUM(p.fill_price*p.fill_quantity)/SUM(p.fill_quantity),6) AS realized_vwap,
           ROUND(AVG(CASE WHEN p.mid IS NOT NULL AND p.mid>0
                          THEN p.side_sign*(p.fill_price-p.mid)/p.mid*10000.0 END),4) AS avg_slippage_bps
    FROM per_fill p JOIN instruments i ON i.instrument_id=p.instrument_id
    GROUP BY i.instrument_id, i.symbol
)
SELECT RANK() OVER (ORDER BY taker_volume DESC) AS vol_rank,
       symbol, taker_volume, realized_vwap, avg_slippage_bps
FROM agg ORDER BY vol_rank, symbol;
