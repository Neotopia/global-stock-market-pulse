-- Gold layer: last available close price per index, per calendar month.
-- Built for the Global Markets trend charts — a proper monthly closing series,
-- following the same "point-in-time, not averaged" convention as index_performance.
-- Only covers indices (type = 'index'); one row per ticker per month.
-- Uses DISTINCT ON (PostgreSQL-specific) to pick the last close within each month.

WITH prices AS (
    SELECT
        p.ticker,
        p.date,
        p.close,
        t.name,
        t.market,
        DATE_TRUNC('month', p.date)::date AS month
    FROM {{ ref('stg_stock_prices') }} p
    INNER JOIN {{ ref('tickers') }} t ON p.ticker = t.ticker
    WHERE t.type = 'index'
),

monthly AS (
    -- One row per ticker/month: the last trading day's close within that month
    SELECT DISTINCT ON (ticker, month)
        ticker,
        name,
        market,
        month,
        date                        AS close_date,
        ROUND(close::numeric, 2)   AS close
    FROM prices
    ORDER BY ticker, month, date DESC
)

SELECT
    ticker,
    name,
    market,
    month,
    close_date,
    close,
    -- Previous month's close — used for month-over-month return
    LAG(close) OVER (PARTITION BY ticker ORDER BY month)                              AS close_prev_month,
    ROUND(
        (
            (close - LAG(close) OVER (PARTITION BY ticker ORDER BY month))
            / LAG(close) OVER (PARTITION BY ticker ORDER BY month)
            * 100
        )::numeric, 2
    )                                                                                  AS return_mom_pct
FROM monthly
ORDER BY ticker, month
