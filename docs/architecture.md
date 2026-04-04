# How This Project Works

A simple explanation of the data pipeline behind the SMI Risk Monitor.

---

## What happens every morning

Every weekday at 09:00 Swiss time, this project runs automatically:

1. Downloads the latest stock prices from Yahoo Finance
2. Saves them to a cloud database (Google BigQuery)
3. Calculates risk and performance numbers
4. Updates the Tableau dashboard

No manual work needed. Everything runs on a timer inside GitHub.

---

## The pipeline

```
Yahoo Finance
(free stock price data)
        │
        ▼
Python script runs every weekday morning
        │
        ▼
Google BigQuery — 4 layers of data:

  smi_raw          ← prices saved exactly as downloaded
        │
  smi_staging      ← prices checked and cleaned
        │
  smi_intermediate ← performance and risk numbers calculated
        │
  smi_marts        ← final tables, ready for the dashboard
        │
        ▼
Tableau dashboard
```

---

## Why four layers?

Each layer has one job. This makes the system easier to fix when something goes wrong.

| Layer | Job |
|-------|-----|
| Raw | Save the original data, never change it |
| Staging | Check for errors, fix column names and types |
| Intermediate | Calculate daily returns, volatility, drawdowns |
| Marts | Combine everything into clean tables for the dashboard |

If the calculation logic changes, only the intermediate and mart layers need to be updated. The raw data stays untouched.

---

## What stocks are tracked

**20 SMI companies:** ABB, Alcon, Geberit, Givaudan, Holcim, Lonza, Nestlé, Novartis, Partners Group, Richemont, Roche, Sandoz, SGS, Sika, Sonova, Straumann, Swiss Life, Swiss Re, UBS, Zurich Insurance

**2 market benchmarks:** SMI Index, S&P 500

**History:** 2 years of daily data, updated every weekday

---

## The dashboard

The Tableau dashboard has three tabs, each built from the mart tables:

| Tab | Main chart | Data source |
|-----|-----------|-------------|
| Performance | Normalized price line chart — all stocks rebased to 100 for direct comparison | `mart_smi__stock_performance` |
| Risk Monitor | Volatility heatmap, risk/return scatter, max drawdown bar chart | `mart_smi__risk_return_summary` |
| Deep Dive | OHLC candlestick chart + volume bars for a single selected stock | `mart_smi__stock_performance` |

The normalized price makes it possible to compare stocks with very different price levels on the same chart. For example, Givaudan trades around 3,500 CHF while Sandoz trades around 30 CHF. By starting both at 100 on the same date, you can directly compare their performance.

---

## How to read the data model diagram

The interactive diagram at [ibryam.github.io/smi-risk-monitor](https://ibryam.github.io/smi-risk-monitor) shows how data moves through the project.

- Each box is a table or view in the database
- Arrows show where the data comes from
- Data flows left to right — raw data on the left, dashboard tables on the right
- Click any box to read what it contains
