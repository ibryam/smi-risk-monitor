# Architecture Decisions

This document explains the key design choices made in this project and the reasoning behind them.

---

## Data Source: Yahoo Finance (yfinance)

**Decision:** Use `yfinance` over paid providers (Alpha Vantage, Polygon, Bloomberg).

**Reason:** For a daily OHLCV portfolio project, Yahoo Finance provides sufficient data quality and history (20+ years). Paid APIs add cost and complexity without meaningful benefit at this scale. The trade-off is that Yahoo Finance has no SLA — if the API changes, the ingestion script needs updating. Acceptable for a portfolio project; in production, a paid provider with a stable API contract would be preferable.

---

## Orchestration: GitHub Actions over Airflow/Prefect

**Decision:** Use GitHub Actions cron schedule instead of a managed orchestration platform.

**Reason:** Airflow (Cloud Composer) costs ~$300/month on GCP. Prefect Cloud free tier has run limits. For a single daily pipeline with one task, GitHub Actions cron (`0 8 * * 1-5`) is free, version-controlled alongside the code, and requires zero infrastructure. The trade-off is limited observability — no native retry UI or dependency graph. Acceptable at this scale; noted as a production upgrade path.

---

## Storage: BigQuery Raw Layer

**Decision:** Land raw yfinance data in BigQuery as-is before any transformation.

**Reason:** Separating ingestion from transformation means a failed dbt run never corrupts source data, and we can re-run transformations without re-pulling from Yahoo Finance. This follows the ELT (not ETL) pattern standard in modern data stacks.

---

## dbt Incremental Models for Price Data

**Decision:** Use `incremental` materialization for staging price models, not `table`.

**Reason:** Daily OHLCV data grows by ~20 rows/day (one per SMI stock). Rebuilding the full history on every dbt run is wasteful. Incremental models append only new dates, making runs faster and reducing BigQuery query costs over time.

---

---

## Benchmarks in a Separate Table

**Decision:** Store benchmark indices (`^SSMI`, `^GSPC`) in `raw_benchmark_prices`, separate from `raw_daily_prices` which holds SMI constituent stocks.

**Reason:** Benchmarks are reference data; stocks are entity data. They serve different analytical purposes and have different semantics — volume for an index is meaningless, while volume for a stock is a key signal. Mixing them into one table with a `type` column saves a few lines of code but creates ambiguity in every downstream query. In a production data warehouse at a bank or asset manager, this separation would be non-negotiable. The explicit join in the mart layer makes the relationship intentional and readable.

---

*This document is updated as new decisions are made.*
