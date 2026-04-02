# SMI Risk Monitor

An end-to-end analytics engineering project monitoring the **Swiss Market Index (SMI)** — the 20 largest and most liquid companies listed on the SIX Swiss Exchange.

Built to demonstrate production-grade analytics engineering practices: automated data ingestion, layered dbt transformations, data quality testing, and interactive dashboards.

---

## Project Purpose

This project analyzes daily equity data for SMI constituents including Nestlé, Roche, Novartis, UBS, ABB, Zurich Insurance, and others. It surfaces risk metrics relevant to Swiss financial institutions — rolling volatility, drawdown analysis, inter-stock correlations, and sector exposure.

---

## Architecture

```
yfinance (Yahoo Finance)
        ↓
   Python ingestion
        ↓
  BigQuery (raw layer)
        ↓
  dbt Core (staging → intermediate → marts)
        ↓
  Tableau Public dashboard
```

**Automated daily refresh:** GitHub Actions runs the ingestion pipeline each morning, keeping data current at zero cost.

---

## Stack

| Layer | Tool |
|-------|------|
| Data source | Yahoo Finance via `yfinance` |
| Storage | Google BigQuery (free tier) |
| Transformation | dbt Core |
| Orchestration | GitHub Actions |
| Visualization | Tableau Public |
| Docs | GitHub Pages (dbt docs) |

---

## Repository Structure

```
smi-risk-monitor/
├── ingestion/            # Python scripts to pull yfinance data → BigQuery
├── dbt/                  # dbt project
│   ├── models/
│   │   ├── staging/      # Raw data cleaned and typed
│   │   ├── intermediate/ # Joined and enriched models
│   │   └── marts/        # Business-ready tables for Tableau
│   ├── tests/            # Custom generic tests
│   └── macros/           # Reusable macros
├── .github/workflows/    # GitHub Actions — daily ingestion schedule
└── DECISIONS.md          # Architecture decisions and trade-offs
```

---

## SMI Constituents Tracked

ABB, Alcon, Geberit, Givaudan, Holcim, Lonza, Nestlé, Novartis, Partners Group, Richemont, Roche, Sandoz, SGS, Sika, Sonova, Straumann, Swiss Life, Swiss Re, UBS, Zurich Insurance

---

## Roadmap

- [x] Repository setup
- [ ] Python ingestion script (yfinance → BigQuery)
- [ ] GitHub Actions daily schedule
- [ ] dbt staging models
- [ ] dbt intermediate models
- [ ] dbt mart models + custom tests
- [ ] Tableau Public dashboard
- [ ] dbt docs on GitHub Pages

---

## Setup

> Detailed setup instructions will be added as each component is built.

---

*Built as part of an analytics engineering portfolio targeting Swiss financial and pharmaceutical companies.*
