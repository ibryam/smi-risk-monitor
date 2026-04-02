# How This Project Works

This page explains the data pipeline behind the SMI Risk Monitor in plain language — no prior data engineering knowledge required.

---

## The Big Picture

Every weekday morning, this system automatically:
1. Downloads fresh stock prices from Yahoo Finance
2. Stores them in a cloud database (Google BigQuery)
3. Calculates risk metrics and performance indicators
4. Makes the results available to the Tableau dashboard

Nobody needs to do anything manually. The whole process runs on a scheduled timer in GitHub.

---

## The Pipeline Step by Step

```
Yahoo Finance (free stock data)
          │
          ▼
    Python Script
    (runs every weekday at 09:00 CET via GitHub Actions)
          │
          ▼
   Google BigQuery
   ┌─────────────────────────────────────┐
   │  RAW LAYER                          │
   │  raw_daily_prices                   │  ← Stock prices exactly as downloaded
   │  raw_benchmark_prices               │  ← SMI Index + S&P 500 levels
   └─────────────────────────────────────┘
          │
          ▼  dbt transforms the data through 3 layers
   ┌─────────────────────────────────────┐
   │  STAGING LAYER                      │
   │  stg_smi__daily_prices              │  ← Prices cleaned and validated
   │  stg_smi__benchmarks                │  ← Benchmarks cleaned and validated
   └─────────────────────────────────────┘
          │
          ▼
   ┌─────────────────────────────────────┐
   │  INTERMEDIATE LAYER                 │
   │  int_smi__daily_returns             │  ← Daily % gains and losses calculated
   │  int_smi__rolling_metrics           │  ← Volatility, moving averages, drawdown
   └─────────────────────────────────────┘
          │
          ▼
   ┌─────────────────────────────────────┐
   │  MARTS LAYER  ← Tableau reads here  │
   │  mart_smi__stock_performance        │  ← Full time-series for all charts
   │  mart_smi__risk_return_summary      │  ← One-row-per-stock risk scorecard
   └─────────────────────────────────────┘
          │
          ▼
   Tableau Public Dashboard
```

---

## Why Three Layers?

Each layer has a specific purpose — this is industry-standard practice at banks and data-driven companies:

| Layer | Purpose | Analogy |
|-------|---------|---------|
| **Raw** | Store data exactly as received, never modified | Original receipts in a filing cabinet |
| **Staging** | Clean, validate, and standardise the data | Checking receipts and correcting errors |
| **Intermediate** | Calculate derived metrics | An accountant running the numbers |
| **Marts** | Business-ready tables optimised for analysis | A polished report ready to present |

This separation means that if something goes wrong at any stage, you can fix it and rerun just that stage — the raw data is always preserved.

---

## Data Sources

| Source | What it provides | Cost |
|--------|-----------------|------|
| Yahoo Finance (`yfinance`) | Daily OHLCV prices for 20 SMI stocks + 2 indices | Free |
| Google BigQuery | Cloud data warehouse storage and compute | Free tier |
| GitHub Actions | Scheduled pipeline execution | Free (public repo) |

---

## Data Coverage

- **20 SMI constituent stocks**: ABB, Alcon, Geberit, Givaudan, Holcim, Lonza, Nestlé, Novartis, Partners Group, Richemont, Roche, Sandoz, SGS, Sika, Sonova, Straumann, Swiss Life, Swiss Re, UBS, Zurich Insurance
- **2 benchmark indices**: SMI Index (^SSMI), S&P 500 (^GSPC)
- **History**: 2 years of daily data
- **Refresh**: Every weekday morning

---

## How to Read the dbt DAG

When you open the interactive data lineage graph, you will see:

- **Green nodes** = source tables (raw data from Yahoo Finance)
- **Blue nodes** = transformed models (the work dbt does)
- **Arrows** = data flows from left to right
- **Click any node** to read a plain-English description of what that model does

The two rightmost nodes (`mart_smi__stock_performance` and `mart_smi__risk_return_summary`) are what the Tableau dashboard reads from.
