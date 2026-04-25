# SMI Risk Monitor

A data project that tracks daily stock prices and risk metrics for all 20 companies in the Swiss Market Index (SMI).

**→ [View the Tableau Dashboard](https://public.tableau.com/app/profile/ibryam/viz/SMIRiskMonitor/Performance)**

**→ [View portfolio](https://ibryam.github.io)**

---

## What it does

Every weekday after market close (17:00 UTC / SIX closing time), the project automatically:
- Downloads the latest prices for all 20 SMI stocks plus the SMI Index and S&P 500
- Saves the data to Google BigQuery
- Calculates risk metrics: volatility, drawdown, moving averages, daily returns
- Updates the Tableau dashboard

No manual work needed. Everything runs on a schedule inside GitHub.

> **Ingestion status:** Yahoo Finance started blocking GitHub Actions IP ranges in April 2026.
> Migrating ingestion to [Twelve Data API](https://twelvedata.com) (free tier, API-key based, not IP-restricted).
> Last successful data load: 2026-04-02. Dashboard data is accurate up to that date.

---

## Tools used

| What | Tool |
|------|------|
| Stock data | Yahoo Finance → migrating to Twelve Data API |
| Database | Google BigQuery |
| Data transformations | dbt Core |
| Scheduling | GitHub Actions |
| Dashboard | Tableau Public (3 interactive tabs) |
| Documentation | GitHub Pages |

---

## Project structure

```
smi-risk-monitor/
├── ingestion/        # Downloads stock data to BigQuery (migrating to Twelve Data API)
├── dbt/              # Transforms and calculates metrics in BigQuery
│   ├── models/
│   │   ├── staging/      # Data cleaning
│   │   ├── intermediate/ # Risk calculations
│   │   └── marts/        # Final tables for the dashboard
│   └── seeds/            # Static data (company sectors)
├── docs/             # How the project works
└── DECISIONS.md      # Why we built it this way
```

---

## Stocks tracked

ABB · Alcon · Geberit · Givaudan · Holcim · Lonza · Nestlé · Novartis · Partners Group · Richemont · Roche · Sandoz · SGS · Sika · Sonova · Straumann · Swiss Life · Swiss Re · UBS · Zurich Insurance

Plus two market benchmarks: SMI Index and S&P 500

---

## Dashboard

Three tabs, each answering a different question:

| Tab | Question it answers |
|-----|-------------------|
| Performance | How did each SMI stock perform over time compared to the market? |
| Risk Monitor | Which stocks carry the most risk, and are they rewarding investors for it? |
| Deep Dive | What happened to a specific stock day by day — price, volume, trends? |

---

## Risk metrics calculated

| Metric | What it tells you |
|--------|------------------|
| Volatility (30/60/90 day) | How much the stock price swings — higher means more risk |
| Drawdown | How far the stock has dropped from its recent high |
| Daily return | Percentage gain or loss each day |
| Moving averages | Short and long-term price trends |
| Golden/Death cross | When trends turn positive or negative |
| CAGR | Annual return over the full period |
| Sharpe ratio | Return earned per unit of risk taken |

---

## Roadmap

- [x] GitHub repository setup
- [x] Automated daily data download
- [x] Data cleaning and validation
- [x] Risk metric calculations
- [x] Dashboard-ready tables
- [x] Interactive data model documentation
- [x] Tableau Public dashboard (3 tabs: Performance, Risk Monitor, Deep Dive)
- [ ] Migrate ingestion from Yahoo Finance to Twelve Data API (unblocks daily refresh)

---

## How it works

See [docs/architecture.md](docs/architecture.md) for a plain-English explanation of the pipeline.

To run locally, copy `dbt/profiles.yml.example` to `dbt/profiles.yml` and add your BigQuery credentials.

---

*Part of an analytics engineering portfolio. Built to demonstrate data engineering skills for Swiss financial companies.*
