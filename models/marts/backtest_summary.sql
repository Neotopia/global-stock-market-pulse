-- Gold layer: aggregated backtest results per holding period.
-- Mirrors the logic of print_summary() in backtest.py, computed in SQL so
-- Metabase can plug into it directly — no averaging/grouping needed downstream.
-- One row per hold_days (3, 5, 10): does the whale signal actually beat the market?

SELECT
    hold_days,
    COUNT(*)                                                          AS trade_count,
    ROUND((AVG(CASE WHEN profitable THEN 1.0 ELSE 0.0 END) * 100)::numeric, 2) AS win_rate_pct,
    ROUND(AVG(return_pct)::numeric, 2)                                AS avg_return_pct,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY return_pct))::numeric, 2) AS median_return_pct,
    ROUND(MAX(return_pct)::numeric, 2)                                AS best_return_pct,
    ROUND(MIN(return_pct)::numeric, 2)                                AS worst_return_pct,
    ROUND(AVG(alpha_pct)::numeric, 2)                                 AS avg_alpha_pct
FROM {{ source('public', 'backtest_whale_signals') }}
WHERE alpha_pct IS NOT NULL
GROUP BY hold_days
ORDER BY hold_days
