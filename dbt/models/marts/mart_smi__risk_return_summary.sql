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

-- Rank rows per ticker by date for endpoint and period lookups
ranked_prices as (

    select
        ticker,
        date,
        close_price,
        row_number() over (partition by ticker order by date asc)  as rn_asc,
        row_number() over (partition by ticker order by date desc) as rn_desc,
        count(*) over (partition by ticker)                        as total_rows

    from prices

),

-- First and last price per stock for CAGR calculation
price_endpoints as (

    select
        ticker,
        min(date)                                               as first_date,
        max(date)                                               as last_date,
        max(case when rn_asc  = 1 then close_price end)        as first_close,
        max(case when rn_desc = 1 then close_price end)        as last_close,
        date_diff(max(date), min(date), day)                    as days_in_period

    from ranked_prices
    group by ticker

),

-- First trading date of current year per ticker (for YTD)
ytd_start as (

    select
        ticker,
        min(date) as ytd_start_date
    from prices
    where extract(year from date) = extract(year from current_date())
    group by ticker

),

-- Period returns at different horizons (for rankings)
period_returns as (

    select
        rp.ticker,
        max(case when rp.rn_desc = 1  then rp.close_price end) as current_close,
        max(case when rp.rn_desc = 22 then rp.close_price end) as close_1m_ago,
        max(case when rp.rn_desc = 64 then rp.close_price end) as close_3m_ago,
        max(case when rp.date = ys.ytd_start_date
                 then rp.close_price end)                       as close_ytd_start

    from ranked_prices      rp
    left join ytd_start     ys on rp.ticker = ys.ticker
    group by rp.ticker

),

period_return_calcs as (

    select
        ticker,
        round(safe_divide(current_close - close_1m_ago,  close_1m_ago)  * 100, 2) as return_1m_pct,
        round(safe_divide(current_close - close_3m_ago,  close_3m_ago)  * 100, 2) as return_3m_pct,
        round(safe_divide(current_close - close_ytd_start, close_ytd_start) * 100, 2) as return_ytd_pct

    from period_returns

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
from with_sharpe            w
left join period_return_calcs pr on w.ticker = pr.ticker
