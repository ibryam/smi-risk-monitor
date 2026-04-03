# SMI Risk Monitor

A data project that tracks daily stock prices and risk metrics for all 20 companies in the Swiss Market Index (SMI).

**→ [View the interactive data model](https://ibryam.github.io/smi-risk-monitor)**

---

## What it does

Every weekday morning, the project automatically:
- Downloads the latest prices for all 20 SMI stocks plus the SMI Index and S&P 500
- Saves the data to Google BigQuery
- Calculates risk metrics: volatility, drawdown, moving averages, daily returns
- Updates the Tableau dashboard

No manual work needed. Everything runs on a schedule inside GitHub.

---

## Tools used

| What | Tool |
|------|------|
| Stock data | Yahoo Finance (free) |
| Database | Google BigQuery |
| Data transformations | dbt Core |
| Scheduling | GitHub Actions |
| Dashboard | Tableau Public |
| Documentation | GitHub Pages |

---

## Project structure

```
smi-risk-monitor/
├── ingestion/        # Downloads stock data from Yahoo Finance to BigQuery
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
- [ ] Tableau Public dashboard

---

## How it works

See [docs/architecture.md](docs/architecture.md) for a plain-English explanation of the pipeline.

To run locally, copy `dbt/profiles.yml.example` to `dbt/profiles.yml` and add your BigQuery credentials.

---

*Part of an analytics engineering portfolio. Built to demonstrate data engineering skills for Swiss financial companies.*
