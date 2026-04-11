"""
SMI daily equity ingestion: Yahoo Finance -> BigQuery (raw layer)

Pulls OHLCV data for all SMI constituents and benchmark indices, loading into
separate BigQuery tables:
  - smi_raw.raw_daily_prices      — SMI constituent stocks
  - smi_raw.raw_benchmark_prices  — SMI index and S&P 500

Run manually:   python ingestion/ingest_smi.py
Run via CI:     GitHub Actions calls this daily on market days
"""

import os
import time
import logging
from datetime import datetime, timedelta, timezone

import yfinance as yf
import pandas as pd
from google.cloud import bigquery

# ── Config ────────────────────────────────────────────────────────────────────

PROJECT_ID        = "smi-risk-monitor"
DATASET_ID        = "smi_raw"
PRICES_TABLE      = "raw_daily_prices"
BENCHMARKS_TABLE  = "raw_benchmark_prices"

# Local: path to service account JSON. CI: set GOOGLE_APPLICATION_CREDENTIALS env var instead.
CREDENTIALS = os.environ.get(
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

BENCHMARK_TICKERS = {
    "^SSMI":  "SMI Index",
    "^GSPC":  "S&P 500",
}

PRICES_SCHEMA = [
    bigquery.SchemaField("date",         "DATE"),
    bigquery.SchemaField("ticker",        "STRING"),
    bigquery.SchemaField("company_name",  "STRING"),
    bigquery.SchemaField("open",          "FLOAT64"),
    bigquery.SchemaField("high",          "FLOAT64"),
    bigquery.SchemaField("low",           "FLOAT64"),
    bigquery.SchemaField("close",         "FLOAT64"),
    bigquery.SchemaField("volume",        "INT64"),
    bigquery.SchemaField("ingested_at",   "TIMESTAMP"),
]

BENCHMARKS_SCHEMA = [
    bigquery.SchemaField("date",          "DATE"),
    bigquery.SchemaField("ticker",        "STRING"),
    bigquery.SchemaField("index_name",    "STRING"),
    bigquery.SchemaField("open",          "FLOAT64"),
    bigquery.SchemaField("high",          "FLOAT64"),
    bigquery.SchemaField("low",           "FLOAT64"),
    bigquery.SchemaField("close",         "FLOAT64"),
    bigquery.SchemaField("volume",        "INT64"),
    bigquery.SchemaField("ingested_at",   "TIMESTAMP"),
]

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


def get_last_loaded_date(client: bigquery.Client, table_id: str) -> str | None:
    """Return the most recent date already in a given BigQuery table."""
    query = f"""
        SELECT MAX(date) AS max_date
        FROM `{PROJECT_ID}.{DATASET_ID}.{table_id}`
    """
    try:
        result = client.query(query).result()
        row = next(iter(result))
        return str(row.max_date) if row.max_date else None
    except Exception:
        return None  # Table doesn't exist yet — first run


def fetch_ohlcv(tickers: dict, start_date: str, end_date: str, name_field: str) -> pd.DataFrame:
    """Pull OHLCV from Yahoo Finance one ticker at a time to avoid rate limits."""
    log.info(f"Fetching {len(tickers)} tickers from {start_date} to {end_date}")

    rows = []
    for ticker, name in tickers.items():
        for attempt in range(1, 4):
            try:
                df = yf.Ticker(ticker).history(
                    start=start_date,
                    end=end_date,
                    auto_adjust=True,
                ).reset_index()

                if df.empty:
                    log.info(f"  {ticker}: no data in range")
                    break

                df["ticker"]   = ticker
                df[name_field] = name
                df = df.rename(columns={
                    "Date":   "date",
                    "Open":   "open",
                    "High":   "high",
                    "Low":    "low",
                    "Close":  "close",
                    "Volume": "volume",
                })
                df["ingested_at"] = datetime.now(timezone.utc)
                rows.append(df[["date", "ticker", name_field, "open", "high", "low", "close", "volume", "ingested_at"]])
                log.info(f"  {ticker}: {len(df)} rows")
                break
            except Exception as e:
                log.warning(f"  {ticker} attempt {attempt}/3 failed: {e}")
                if attempt < 3:
                    time.sleep(10 * attempt)

        time.sleep(3)  # pause between tickers to avoid rate limiting

    if not rows:
        log.warning("No data fetched")
        return pd.DataFrame()

    combined = pd.concat(rows, ignore_index=True)
    combined["date"] = pd.to_datetime(combined["date"]).dt.date
    log.info(f"Fetched {len(combined)} rows across {combined['ticker'].nunique()} tickers")
    return combined


def load_to_bigquery(client: bigquery.Client, df: pd.DataFrame, table_id: str, schema: list):
    """Append new rows to a BigQuery table, creating it if it doesn't exist."""
    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{table_id}"
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=schema,
    )
    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()
    log.info(f"Loaded {len(df)} rows into {table_ref}")


def run_pipeline(client, table_id: str, tickers: dict, schema: list, name_field: str):
    """Full incremental pipeline for a single table."""
    last_date = get_last_loaded_date(client, table_id)

    if last_date:
        start_date = (datetime.strptime(last_date, "%Y-%m-%d") + timedelta(days=1)).strftime("%Y-%m-%d")
        log.info(f"[{table_id}] Incremental run — loading from {start_date}")
    else:
        start_date = (datetime.now(timezone.utc) - timedelta(days=730)).strftime("%Y-%m-%d")
        log.info(f"[{table_id}] First run — loading full history from {start_date}")

    # yfinance end is exclusive — add 1 day so today's close is included
    end_date = (datetime.now(timezone.utc) + timedelta(days=1)).strftime("%Y-%m-%d")

    if start_date >= end_date:
        log.info(f"[{table_id}] Already up to date — nothing to load")
        return

    df = fetch_ohlcv(tickers, start_date, end_date, name_field)

    if df.empty:
        log.info(f"[{table_id}] No new data to load")
        return

    load_to_bigquery(client, df, table_id, schema)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    client = get_bq_client()

    log.info("── SMI constituents ──────────────────────────────")
    run_pipeline(client, PRICES_TABLE,     SMI_TICKERS,       PRICES_SCHEMA,     "company_name")

    log.info("Waiting 60s before benchmark pull to avoid Yahoo rate limits")
    time.sleep(60)

    log.info("── Benchmarks ────────────────────────────────────")
    run_pipeline(client, BENCHMARKS_TABLE, BENCHMARK_TICKERS, BENCHMARKS_SCHEMA, "index_name")

    log.info("Ingestion complete")


if __name__ == "__main__":
    main()
