"""
SMI daily equity ingestion: Yahoo Finance -> BigQuery (raw layer)

Pulls OHLCV data for all SMI constituents and loads it into
BigQuery table: smi_raw.raw_daily_prices

Run manually:   python ingestion/ingest_smi.py
Run via CI:     GitHub Actions calls this daily on market days
"""

import os
import logging
from datetime import datetime, timedelta, timezone

import yfinance as yf
import pandas as pd
from google.cloud import bigquery

# ── Config ────────────────────────────────────────────────────────────────────

PROJECT_ID   = "smi-risk-monitor"
DATASET_ID   = "smi_raw"
TABLE_ID     = "raw_daily_prices"
# Local: path to service account JSON. CI: set GOOGLE_APPLICATION_CREDENTIALS env var instead.
CREDENTIALS  = os.environ.get(
    "GOOGLE_APPLICATION_CREDENTIALS",
    os.path.join(os.path.dirname(__file__), "..", "smi-risk-monitor-9a782e9e17af.json"),
)

SMI_TICKERS = {
    "ABBN.SW":  "ABB",
    "ALC.SW":   "Alcon",
    "GEBN.SW":  "Geberit",
    "GIVN.SW":  "Givaudan",
    "HOLN.SW":  "Holcim",
    "LONN.SW":  "Lonza",
    "NESN.SW":  "Nestle",
    "NOVN.SW":  "Novartis",
    "PGHN.SW":  "Partners Group",
    "CFR.SW":   "Richemont",
    "ROG.SW":   "Roche",
    "SDZ.SW":   "Sandoz",
    "SGSN.SW":  "SGS",
    "SIKA.SW":  "Sika",
    "SOON.SW":  "Sonova",
    "STMN.SW":  "Straumann",
    "SLHN.SW":  "Swiss Life",
    "SREN.SW":  "Swiss Re",
    "UBSG.SW":  "UBS",
    "ZURN.SW":  "Zurich Insurance",
}

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ── Helpers ───────────────────────────────────────────────────────────────────

def get_bq_client():
    from google.oauth2 import service_account
    creds = service_account.Credentials.from_service_account_file(CREDENTIALS)
    return bigquery.Client(project=PROJECT_ID, credentials=creds)


def get_last_loaded_date(client: bigquery.Client) -> str | None:
    """Return the most recent date already in BigQuery, or None if table is empty."""
    query = f"""
        SELECT MAX(date) AS max_date
        FROM `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`
    """
    try:
        result = client.query(query).result()
        row = next(iter(result))
        return str(row.max_date) if row.max_date else None
    except Exception:
        return None  # Table doesn't exist yet — first run


def fetch_prices(start_date: str, end_date: str) -> pd.DataFrame:
    """Pull OHLCV from Yahoo Finance for all SMI tickers."""
    tickers = list(SMI_TICKERS.keys())
    log.info(f"Fetching {len(tickers)} tickers from {start_date} to {end_date}")

    raw = yf.download(
        tickers=tickers,
        start=start_date,
        end=end_date,
        auto_adjust=True,
        progress=False,
        group_by="ticker",
    )

    rows = []
    for ticker in tickers:
        try:
            df = raw[ticker].dropna(how="all").reset_index()
            df["ticker"]      = ticker
            df["company_name"] = SMI_TICKERS[ticker]
            df = df.rename(columns={
                "Date":   "date",
                "Open":   "open",
                "High":   "high",
                "Low":    "low",
                "Close":  "close",
                "Volume": "volume",
            })
            df["ingested_at"] = datetime.now(timezone.utc)
            rows.append(df[["date", "ticker", "company_name", "open", "high", "low", "close", "volume", "ingested_at"]])
        except Exception as e:
            log.warning(f"Skipping {ticker}: {e}")

    if not rows:
        log.warning("No data fetched — market may be closed or all tickers failed")
        return pd.DataFrame()

    combined = pd.concat(rows, ignore_index=True)
    combined["date"] = pd.to_datetime(combined["date"]).dt.date
    log.info(f"Fetched {len(combined)} rows across {combined['ticker'].nunique()} tickers")
    return combined


def load_to_bigquery(client: bigquery.Client, df: pd.DataFrame):
    """Append new rows to BigQuery table, creating it if it doesn't exist."""
    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=[
            bigquery.SchemaField("date",         "DATE"),
            bigquery.SchemaField("ticker",        "STRING"),
            bigquery.SchemaField("company_name",  "STRING"),
            bigquery.SchemaField("open",          "FLOAT64"),
            bigquery.SchemaField("high",          "FLOAT64"),
            bigquery.SchemaField("low",           "FLOAT64"),
            bigquery.SchemaField("close",         "FLOAT64"),
            bigquery.SchemaField("volume",        "INT64"),
            bigquery.SchemaField("ingested_at",   "TIMESTAMP"),
        ],
    )

    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()
    log.info(f"Loaded {len(df)} rows into {table_ref}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    client = get_bq_client()

    last_date = get_last_loaded_date(client)

    if last_date:
        # Incremental: start from day after last loaded date
        start_date = (datetime.strptime(last_date, "%Y-%m-%d") + timedelta(days=1)).strftime("%Y-%m-%d")
        log.info(f"Incremental run — loading from {start_date}")
    else:
        # First run: load 2 years of history
        start_date = (datetime.now(timezone.utc) - timedelta(days=730)).strftime("%Y-%m-%d")
        log.info(f"First run — loading full history from {start_date}")

    end_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    if start_date >= end_date:
        log.info("Already up to date — nothing to load")
        return

    df = fetch_prices(start_date, end_date)

    if df.empty:
        log.info("No new data to load")
        return

    load_to_bigquery(client, df)
    log.info("Ingestion complete")


if __name__ == "__main__":
    main()
