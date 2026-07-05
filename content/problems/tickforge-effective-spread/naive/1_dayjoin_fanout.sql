-- NAIVE 1: day-level join. Fans each fill out across all of the day's quotes
-- (order-book fan-out, #4), so COUNT(*) is inflated and the averaged mid is the
-- day's mean quote, not the prevailing top-of-book at the fill.
SELECT i.symbol,
       COUNT(*) AS n_fills,
       ROUND(AVG(2.0*ABS(f.fill_price - (q.bid_price+q.ask_price)/2.0)),6) AS avg_effective_spread,
       ROUND(AVG(CASE WHEN f.fill_price > q.bid_price AND f.fill_price < q.ask_price
                      THEN 1.0 ELSE 0.0 END),6) AS price_improve_share
FROM fills f
JOIN quotes q ON q.instrument_id = f.instrument_id AND q.session_date = f.session_date
JOIN instruments i ON i.instrument_id = f.instrument_id
WHERE f.session_date BETWEEN '2023-01-03' AND '2023-01-31'
GROUP BY i.instrument_id, i.symbol
ORDER BY i.symbol;
