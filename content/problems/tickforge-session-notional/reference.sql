-- Session Notional Leaderboard (Blue)
-- Notional lives at fill grain: sum fill_price * fill_quantity over the day's
-- fills, count the fills, and join to instruments for symbol/sector.
SELECT
    i.symbol,
    i.sector,
    COUNT(*)                                      AS fill_count,
    ROUND(SUM(f.fill_price * f.fill_quantity), 2) AS notional
FROM fills f
JOIN instruments i ON i.instrument_id = f.instrument_id
WHERE f.session_date = '2023-01-09'
GROUP BY i.instrument_id, i.symbol, i.sector
ORDER BY notional DESC, i.symbol;
