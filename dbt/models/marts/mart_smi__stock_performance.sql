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

-- First close price per stock for normalization base
stock_base as (

    select
        ticker,
        min(close_price) over (partition by ticker order by date rows between unbounded preceding and unbounded following) as base_close,
        min(date)        over (partition by ticker order by date rows between unbounded preceding and unbounded following) as base_date
    from {{ ref('stg_smi__daily_prices') }}

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

select * from final
