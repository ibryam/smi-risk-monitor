{{
    config(materialized='view')
}}

/*
    Daily returns per SMI constituent.

    daily_return: simple percentage change in closing price vs prior trading day.
    Uses LAG() partitioned by ticker so we never cross stock boundaries.
*/

with prices as (

    select * from {{ ref('stg_smi__daily_prices') }}

),

with_returns as (

    select
        date,
        ticker,
        company_name,
        open_price,
        high_price,
        low_price,
        close_price,
        volume,

        lag(close_price) over (
            partition by ticker
            order by date
        )                                                           as prev_close_price,

        round(
            safe_divide(
                close_price - lag(close_price) over (
                    partition by ticker order by date
                ),
                lag(close_price) over (
                    partition by ticker order by date
                )
            ) * 100,
            4
        )                                                           as daily_return_pct,

        -- Log return: better for statistical analysis (additive, normally distributed)
        round(
            ln(
                safe_divide(
                    close_price,
                    lag(close_price) over (
                        partition by ticker order by date
                    )
                )
            ) * 100,
            4
        )                                                           as log_return_pct

    from prices

)

select * from with_returns
-- Exclude the first row per ticker (no prior day to calculate return against)
where prev_close_price is not null
