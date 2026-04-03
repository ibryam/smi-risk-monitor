{{
    config(materialized='table')
}}

/*
    mart_smi__stock_performance

    One row per stock per trading day. Powers:
      - Tab 1: Normalized performance chart, top gainers/losers
      - Tab 2: Drawdown chart, volatility heatmap
      - Tab 3: OHLC price chart, volume, SMA crossover signals

    Normalized price: all stocks rebased to 100 on their first available date,
    enabling direct performance comparison across stocks with very different price levels.

    SMA crossover: golden_cross = 1 when 30d SMA crosses above 90d SMA (bullish signal).
                   death_cross  = 1 when 30d SMA crosses below 90d SMA (bearish signal).
*/

with metrics as (

    select * from {{ ref('int_smi__rolling_metrics') }}

),

-- Bring back OHLCV fields not carried through the metrics chain
ohlcv as (

    select
        date,
        ticker,
        open_price,
        high_price,
        low_price,
        volume
    from {{ ref('stg_smi__daily_prices') }}

),

sectors as (

    select * from {{ ref('smi_sectors') }}

),

-- Benchmarks pivoted to columns for easy comparison in Tableau
benchmarks as (

    select
        date,
        max(case when ticker = '^SSMI' then close_price end) as smi_index_close,
        max(case when ticker = '^GSPC' then close_price end) as sp500_close
    from {{ ref('stg_smi__benchmarks') }}
    group by date

),

-- Normalize benchmarks to 100 on their first available date
benchmark_base as (

    select
        min(case when ticker = '^SSMI' then close_price end) as smi_index_base,
        min(case when ticker = '^GSPC' then close_price end) as sp500_base
    from {{ ref('stg_smi__benchmarks') }}
    where date = (select min(date) from {{ ref('stg_smi__benchmarks') }})

),

-- First close price per stock for normalization base (price on the earliest available date)
stock_base as (

    select
        ticker,
        max(case when rn = 1 then close_price end) as base_close
    from (
        select
            ticker,
            close_price,
            row_number() over (partition by ticker order by date asc) as rn
        from {{ ref('stg_smi__daily_prices') }}
    )
    group by ticker

),

-- SMA crossover signals
crossover as (

    select
        date,
        ticker,
        sma_30d,
        sma_90d,
        lag(sma_30d) over (partition by ticker order by date) as prev_sma_30d,
        lag(sma_90d) over (partition by ticker order by date) as prev_sma_90d
    from metrics

),

final as (

    select
        m.date,
        m.ticker,
        s.company_name,
        s.sector,
        s.industry,

        -- Raw prices (OHLCV — open/high/low/volume joined from staging)
        m.close_price,
        o.high_price,
        o.low_price,
        o.open_price,
        o.volume,

        -- Returns
        m.daily_return_pct,
        m.log_return_pct,

        -- Trend indicators
        m.sma_30d,
        m.sma_90d,

        -- Crossover signals (1 on the day the cross happens, else 0)
        case
            when c.sma_30d > c.sma_90d and c.prev_sma_30d <= c.prev_sma_90d then 1
            else 0
        end                                                     as golden_cross,

        case
            when c.sma_30d < c.sma_90d and c.prev_sma_30d >= c.prev_sma_90d then 1
            else 0
        end                                                     as death_cross,

        -- Risk metrics
        m.volatility_30d,
        m.volatility_60d,
        m.volatility_90d,
        m.high_52w,
        m.drawdown_from_52w_high_pct,

        -- Normalized price (rebased to 100 on first available date)
        round(
            safe_divide(m.close_price, sb.base_close) * 100,
            4
        )                                                       as normalized_price,

        -- Benchmark levels and normalized benchmarks for comparison
        b.smi_index_close,
        b.sp500_close,

        round(
            safe_divide(b.smi_index_close, bb.smi_index_base) * 100,
            4
        )                                                       as smi_index_normalized,

        round(
            safe_divide(b.sp500_close, bb.sp500_base) * 100,
            4
        )                                                       as sp500_normalized

    from metrics             m
    left join ohlcv          o  on m.ticker = o.ticker and m.date = o.date
    left join sectors        s  on m.ticker = s.ticker
    left join benchmarks     b  on m.date   = b.date
    cross join benchmark_base bb
    left join stock_base     sb on m.ticker = sb.ticker
    left join crossover      c  on m.ticker = c.ticker and m.date = c.date

)

-- Stock rows
select
    date,
    ticker,
    company_name,
    sector,
    industry,
    'stock'                     as row_type,
    close_price,
    high_price,
    low_price,
    open_price,
    volume,
    daily_return_pct,
    log_return_pct,
    sma_30d,
    sma_90d,
    golden_cross,
    death_cross,
    volatility_30d,
    volatility_60d,
    volatility_90d,
    high_52w,
    drawdown_from_52w_high_pct,
    normalized_price,
    smi_index_close,
    sp500_close,
    smi_index_normalized,
    sp500_normalized
from final

union all

-- Benchmark rows — so Tableau can treat ^SSMI and ^GSPC as lines on the same chart
select
    b.date,
    b.ticker,
    b.index_name                as company_name,
    'Benchmark'                 as sector,
    'Benchmark'                 as industry,
    'benchmark'                 as row_type,
    b.close_price,
    b.high_price,
    b.low_price,
    b.open_price,
    b.volume,
    null                        as daily_return_pct,
    null                        as log_return_pct,
    null                        as sma_30d,
    null                        as sma_90d,
    0                           as golden_cross,
    0                           as death_cross,
    null                        as volatility_30d,
    null                        as volatility_60d,
    null                        as volatility_90d,
    null                        as high_52w,
    null                        as drawdown_from_52w_high_pct,
    round(safe_divide(b.close_price, bb.base_close) * 100, 4) as normalized_price,
    null                        as smi_index_close,
    null                        as sp500_close,
    null                        as smi_index_normalized,
    null                        as sp500_normalized
from {{ ref('stg_smi__benchmarks') }}  b
inner join (
    select
        ticker,
        max(case when rn = 1 then close_price end) as base_close
    from (
        select
            ticker,
            close_price,
            row_number() over (partition by ticker order by date asc) as rn
        from {{ ref('stg_smi__benchmarks') }}
    )
    group by ticker
)                                      bb on b.ticker = bb.ticker
