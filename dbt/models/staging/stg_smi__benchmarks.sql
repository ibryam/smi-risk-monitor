{{
    config(materialized='view')
}}

with source as (

    select * from {{ source('smi_raw', 'raw_benchmark_prices') }}

),

cleaned as (

    select
        cast(date as date)              as date,
        upper(trim(ticker))             as ticker,
        trim(index_name)                as index_name,
        cast(open as numeric)           as open_price,
        cast(high as numeric)           as high_price,
        cast(low as numeric)            as low_price,
        cast(close as numeric)          as close_price,
        cast(volume as int64)           as volume,
        cast(ingested_at as timestamp)  as ingested_at

    from source

    where
        close is not null
        and close > 0

)

select * from cleaned
