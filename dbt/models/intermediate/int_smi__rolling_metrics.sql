{{
    config(materialized='view')
}}

/*
    Rolling risk and trend metrics per SMI constituent.

    Volatility: annualised standard deviation of daily log returns over a rolling window.
    Annualisation factor: sqrt(252) — standard for daily equity data (252 trading days/year).

    Moving averages: simple MA on closing price over 30 and 90 day windows.

    Drawdown: how far the current close is below the 52-week (252-day) rolling high.
    A key risk metric used by portfolio managers.
*/

with returns as (

    select * from {{ ref('int_smi__daily_returns') }}

),

rolling as (

    select
        date,
        ticker,
        company_name,
        close_price,
        daily_return_pct,
        log_return_pct,

        -- Rolling volatility (annualised), 3 window sizes for comparison
        round(
            stddev(log_return_pct) over (
                partition by ticker
                order by date
                rows between 29 preceding and current row
            ) * sqrt(252),
            4
        )                                                           as volatility_30d,

        round(
            stddev(log_return_pct) over (
                partition by ticker
                order by date
                rows between 59 preceding and current row
            ) * sqrt(252),
            4
        )                                                           as volatility_60d,

        round(
            stddev(log_return_pct) over (
                partition by ticker
                order by date
                rows between 89 preceding and current row
            ) * sqrt(252),
            4
        )                                                           as volatility_90d,

        -- Simple moving averages
        round(
            avg(close_price) over (
                partition by ticker
                order by date
                rows between 29 preceding and current row
            ),
            4
        )                                                           as sma_30d,

        round(
            avg(close_price) over (
                partition by ticker
                order by date
                rows between 89 preceding and current row
            ),
            4
        )                                                           as sma_90d,

        -- 52-week rolling high and drawdown from that high
        max(close_price) over (
            partition by ticker
            order by date
            rows between 251 preceding and current row
        )                                                           as high_52w,

        round(
            safe_divide(
                close_price - max(close_price) over (
                    partition by ticker
                    order by date
                    rows between 251 preceding and current row
                ),
                max(close_price) over (
                    partition by ticker
                    order by date
                    rows between 251 preceding and current row
                )
            ) * 100,
            4
        )                                                           as drawdown_from_52w_high_pct

    from returns

)

select * from rolling
