# SMI Risk Monitor

An end-to-end analytics engineering project monitoring the **Swiss Market Index (SMI)** — the 20 largest and most liquid companies listed on the SIX Swiss Exchange.

Built to demonstrate production-grade analytics engineering practices: automated data ingestion, layered dbt transformations, data quality testing, and interactive dashboards.

**→ [Browse the interactive data model (dbt docs)](https://ibryam.github.io/smi-risk-monitor)**

---

## Project Purpose

This project analyzes daily equity data for SMI constituents including Nestlé, Roche, Novartis, UBS, ABB, Zurich Insurance, and others. It surfaces risk metrics relevant to Swiss financial institutions — rolling volatility, drawdown analysis, moving average crossover signals, and risk-adjusted return comparisons against the SMI Index and S&P 500.

---

## Architecture

```
Yahoo Finance (free stock data)
          │
          ▼
    Python ingestion script
    (runs every weekday at 09:00 CET via GitHub Actions)
          │
          ▼
   Google BigQuery
   ├── smi_raw          ← prices as downloaded
   ├── smi_staging      ← cleaned and validated
   ├── smi_intermediate ← risk metrics calculated
   └── smi_marts        ← Tableau reads from here
          │
          ▼
   Tableau Public dashboard
```

**→ [Plain-English explanation of the pipeline](docs/architecture.md)**

**Automated daily refresh:** GitHub Actions runs the full pipeline each morning at zero cost — ingestion, dbt transformations, data quality tests, and dbt docs deployment.

---

## Stack

| Layer | Tool |
|-------|------|
| Data source | Yahoo Finance via `yfinance` |
| Storage | Google BigQuery (free tier) |
| Transformation | dbt Core |
| Orchestration | GitHub Actions |
| Visualization | Tableau Public |
| Data model docs | GitHub Pages |

---

## Repository Structure

```
smi-risk-monitor/
├── ingestion/            # Python pipeline: Yahoo Finance → BigQuery
├── dbt/                  # dbt project
│   ├── models/
│   │   ├── staging/      # Data cleaning and validation
│   │   ├── intermediate/ # Risk metrics: returns, volatility, drawdown
│   │   └── marts/        # Business-ready tables for Tableau
│   ├── seeds/            # Static reference data (SMI sectors)
│   └── tests/            # Custom data quality tests
├── docs/                 # Architecture documentation
├── .github/workflows/    # GitHub Actions: daily pipeline + dbt docs
└── DECISIONS.md          # Architecture decisions and trade-offs
```

---

## Data Coverage

- **20 SMI constituents**: ABB, Alcon, Geberit, Givaudan, Holcim, Lonza, Nestlé, Novartis, Partners Group, Richemont, Roche, Sandoz, SGS, Sika, Sonova, Straumann, Swiss Life, Swiss Re, UBS, Zurich Insurance
- **2 benchmarks**: SMI Index (^SSMI), S&P 500 (^GSPC)
- **History**: 2 years of daily data
- **Refresh**: Every weekday morning

---

## Risk Metrics

| Metric | Description |
|--------|-------------|
| Rolling volatility (30/60/90d) | Annualised price volatility — core risk measure |
| Drawdown from 52-week high | How far a stock has fallen from its recent peak |
| CAGR | Compound annual return over the full period |
| Sharpe proxy | Return per unit of risk taken |
| SMA crossover | Golden cross / death cross momentum signals |

---

## Roadmap

- [x] Repository setup
- [x] Python ingestion script (yfinance → BigQuery)
- [x] GitHub Actions daily schedule
- [x] dbt staging models
- [x] dbt intermediate models
- [x] dbt mart models + custom tests
- [x] dbt docs on GitHub Pages
- [ ] Tableau Public dashboard

---

## Setup

See [docs/architecture.md](docs/architecture.md) for a full explanation of how the pipeline works.

To run locally, copy `dbt/profiles.yml.example` to `dbt/profiles.yml` and add your BigQuery service account path.

---

*Built as part of an analytics engineering portfolio targeting Swiss financial and pharmaceutical companies.*
