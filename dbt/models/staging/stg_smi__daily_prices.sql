{{
    config(
        materialized='incremental',
        unique_key=['date', 'ticker'],
        incremental_strategy='merge'
    )
}}

with source as (

    select * from {{ source('smi_raw', 'raw_daily_prices') }}

    {% if is_incremental() %}
        where ingested_at > (select max(ingested_at) from {{ this }})
    {% endif %}

),

cleaned as (

    select
        cast(date as date)                          as date,
        upper(trim(ticker))                         as ticker,
        trim(company_name)                          as company_name,
        cast(open as numeric)                       as open_price,
        cast(high as numeric)                       as high_price,
        cast(low as numeric)                        as low_price,
        cast(close as numeric)                      as close_price,
        cast(volume as int64)                       as volume,
        cast(ingested_at as timestamp)              as ingested_at

    from source

    where
        -- Remove any rows with null prices (non-trading days slipping through)
        close is not null
        and open is not null
        and high is not null
        and low is not null
        -- Basic sanity: prices must be positive
        and close > 0
        and open > 0

)

select * from cleaned
