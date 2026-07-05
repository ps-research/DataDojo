-- NAIVE 2: correct as-of shape, but NO validity filter on the quote used for the
-- mid. It takes the latest quote by time regardless of NULL prices, crossed
-- books, or one-sided (size-0) markets, so (bid+ask)/2 is NULL-poisoned or
-- garbage for the fills whose prevailing tick was dirty.
WITH ff AS (
    SELECT fill_id, instrument_id, fill_price, fill_time
    FROM fills
    WHERE session_date BETWEEN '2023-01-03' AND '2023-01-31'
),
scored AS (
    SELECT f.instrument_id, f.fill_id, f.fill_price,
      (SELECT q.quote_id FROM quotes q
       WHERE q.instrument_id = f.instrument_id
         AND q.quote_time <= f.fill_time
       ORDER BY q.quote_time DESC, q.quote_id DESC
       LIMIT 1) AS qid
    FROM ff f
)
SELECT i.symbol,
       COUNT(*) AS n_fills,
       ROUND(AVG(2.0*ABS(s.fill_price - (qq.bid_price+qq.ask_price)/2.0)),6) AS avg_effective_spread,
       ROUND(AVG(CASE WHEN s.fill_price > qq.bid_price AND s.fill_price < qq.ask_price
                      THEN 1.0 ELSE 0.0 END),6) AS price_improve_share
FROM scored s
JOIN quotes qq ON qq.quote_id = s.qid
JOIN instruments i ON i.instrument_id = s.instrument_id
GROUP BY i.instrument_id, i.symbol
ORDER BY i.symbol;
