-- Gold layer: tickers where trading volume recently exceeded 2.5× the 20-day average.
-- A volume spike of this magnitude often signals institutional activity ("whale" moves):
-- large fund entries/exits, earnings reactions, or macro-driven repositioning.
-- Only covers stocks (not indices — index volume is a composite and less meaningful).
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
        -- Rolling 20-day average volume, excluding the current day
        AVG(p.volume) OVER (
            PARTITION BY p.ticker
            ORDER BY p.date
            ROWS BETWEEN 20 PRECEDING AND 1 PRECEDING
        ) AS avg_volume_20d
    FROM {{ ref('stg_stock_prices') }} p
    INNER JOIN {{ ref('tickers') }} t ON p.ticker = t.ticker
    WHERE t.type = 'stock'
),

spikes AS (
    SELECT
        ticker,
        name,
        sector,
        date,
        close,
        volume,
        ROUND(avg_volume_20d::numeric, 0)                           AS avg_volume_20d,
        ROUND((volume / NULLIF(avg_volume_20d, 0))::numeric, 2)    AS volume_ratio,
        -- Close Location Value: -1 (closed at the low) to +1 (closed at the high)
        ROUND((
            ((close - low) - (high - close)) / NULLIF(high - low, 0)
        )::numeric, 2)                                              AS clv
    FROM prices
    WHERE date >= CURRENT_DATE - INTERVAL '7 days'
      AND volume > avg_volume_20d * 2.5
      AND avg_volume_20d IS NOT NULL  -- exclude first 20 rows where rolling avg is not yet stable
)

SELECT
    *,
    CASE
        WHEN clv >  0.5 THEN 'likely buying'
        WHEN clv < -0.5 THEN 'likely selling'
        ELSE 'mixed'
    END AS pressure_hint
FROM spikes
ORDER BY volume_ratio DESC
