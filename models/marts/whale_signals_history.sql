-- Gold layer: full historical whale signals — all dates, no 7-day window.
-- Used by backtest.py to simulate trades over the full 2-year price history.
-- For the live dashboard (last 7 days only), see whale_signals.sql.
--
-- clv (Close Location Value) adds a directional hint: where the close fell within the
-- day's high/low range. This is a proxy, not a certainty — real buy/sell classification
-- would require order-flow (bid/ask) data, which isn't available for free.

WITH prices AS (
    SELECT
        p.ticker,
        p.date,
        p.high,
        p.low,
        p.close,
        p.volume,
        t.name,
        t.sector,
        AVG(p.volume) OVER (
            PARTITION BY p.ticker
            ORDER BY p.date
            ROWS BETWEEN 20 PRECEDING AND 1 PRECEDING
        ) AS avg_volume_20d
    FROM {{ ref('stg_stock_prices') }} p
    INNER JOIN {{ ref('tickers') }} t ON p.ticker = t.ticker
    WHERE t.type = 'stock'
)

SELECT
    ticker,
    name,
    sector,
    date,
    close,
    volume,
    ROUND(avg_volume_20d::numeric, 0)                        AS avg_volume_20d,
    ROUND((volume / NULLIF(avg_volume_20d, 0))::numeric, 2) AS volume_ratio,
    ROUND((
        ((close - low) - (high - close)) / NULLIF(high - low, 0)
    )::numeric, 2)                                            AS clv,
    CASE
        WHEN ((close - low) - (high - close)) / NULLIF(high - low, 0) >  0.5 THEN 'likely buying'
        WHEN ((close - low) - (high - close)) / NULLIF(high - low, 0) < -0.5 THEN 'likely selling'
        ELSE 'mixed'
    END AS pressure_hint
FROM prices
WHERE volume > avg_volume_20d * 2.5
  AND avg_volume_20d IS NOT NULL
ORDER BY date DESC, volume_ratio DESC
