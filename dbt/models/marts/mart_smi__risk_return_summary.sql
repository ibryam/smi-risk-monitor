{{
    config(materialized='table')
}}

/*
    mart_smi__risk_return_summary

    One row per stock — aggregated metrics across the full available period.
    Powers:
      - Tab 2: Risk/Return scatter plot, volatility heatmap (monthly grain)
      - Tab 1: KPI tiles, period return rankings

    Annualized return: compound annual growth rate (CAGR) from first to last close.
    Annualized volatility: average of daily 30d rolling volatility readings.
    Sharpe proxy: annualized return / annualized volatility (no risk-free rate — simplified).
*/

with metrics as (

    select * from {{ ref('int_smi__rolling_metrics') }}

),

sectors as (

    select * from {{ ref('smi_sectors') }}

),

prices as (

    select * from {{ ref('stg_smi__daily_prices') }}

),

-- First and last price per stock for CAGR calculation
price_endpoints as (

    select
        ticker,
        min(date)                                               as first_date,
        max(date)                                               as last_date,
        min_by(close_price, date)                               as first_close,
        max_by(close_price, date)                               as last_close,
        date_diff(max(date), min(date), day)                    as days_in_period

    from prices
    group by ticker

),

-- Period returns at different horizons (for rankings)
period_returns as (

    select
        ticker,

        -- 1-month return
        round(
            safe_divide(
                max_by(close_price, date) - min_by(close_price, date order by date desc limit 21),
                min_by(close_price, date order by date desc limit 21)
            ) * 100,
            2
        )                                                       as return_1m_pct,

        -- 3-month return
        round(
            safe_divide(
                max_by(close_price, date) - min_by(close_price, date order by date desc limit 63),
                min_by(close_price, date order by date desc limit 63)
            ) * 100,
            2
        )                                                       as return_3m_pct,

        -- YTD return (since Jan 1 of current year)
        round(
            safe_divide(
                max_by(close_price, date) - min_by(close_price, case when extract(month from date) = 1 and extract(day from date) <= 5 then date end),
                min_by(close_price, case when extract(month from date) = 1 and extract(day from date) <= 5 then date end)
            ) * 100,
            2
        )                                                       as return_ytd_pct

    from prices
    group by ticker

),

aggregated as (

    select
        m.ticker,
        s.company_name,
        s.sector,
        s.industry,

        pe.first_date,
        pe.last_date,
        pe.first_close,
        pe.last_close,
        pe.days_in_period,

        -- CAGR: annualized compound return over full period
        round(
            (pow(
                safe_divide(pe.last_close, pe.first_close),
                safe_divide(365.0, pe.days_in_period)
            ) - 1) * 100,
            4
        )                                                       as cagr_pct,

        -- Annualized volatility (average of rolling 30d readings)
        round(avg(m.volatility_30d), 4)                        as avg_volatility_30d,
        round(avg(m.volatility_60d), 4)                        as avg_volatility_60d,
        round(avg(m.volatility_90d), 4)                        as avg_volatility_90d,

        -- Current (most recent) volatility
        round(max_by(m.volatility_30d, m.date), 4)             as current_volatility_30d,

        -- Maximum drawdown over full period
        round(min(m.drawdown_from_52w_high_pct), 4)            as max_drawdown_pct,

        -- Current drawdown
        round(max_by(m.drawdown_from_52w_high_pct, m.date), 4) as current_drawdown_pct,

        -- Best and worst single-day return
        round(max(m.daily_return_pct), 4)                      as best_day_return_pct,
        round(min(m.daily_return_pct), 4)                      as worst_day_return_pct,

        -- Total trading days in dataset
        count(*)                                                as trading_days

    from metrics             m
    left join sectors        s  on m.ticker = s.ticker
    left join price_endpoints pe on m.ticker = pe.ticker
    group by
        m.ticker,
        s.company_name,
        s.sector,
        s.industry,
        pe.first_date,
        pe.last_date,
        pe.first_close,
        pe.last_close,
        pe.days_in_period

),

with_sharpe as (

    select
        *,
        -- Sharpe proxy (no risk-free rate for simplicity)
        round(
            safe_divide(cagr_pct, avg_volatility_30d),
            4
        )                                                       as sharpe_proxy

    from aggregated

)

select
    w.*,
    pr.return_1m_pct,
    pr.return_3m_pct,
    pr.return_ytd_pct
from with_sharpe         w
left join period_returns pr on w.ticker = pr.ticker
