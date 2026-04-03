# Key Decisions

Why did we build it this way? This file explains the main choices made in this project.

---

## Why Yahoo Finance and not a paid data provider?

Yahoo Finance is free and has over 20 years of history for Swiss stocks. Paid providers like Bloomberg or Polygon cost money and add complexity. For this project the data quality is more than good enough.

The downside: Yahoo Finance can change their API without warning, which would break the ingestion script. That is a known risk and acceptable here. A real production system at a bank would use a paid provider with a contract and guaranteed uptime.

---

## Why GitHub Actions and not Airflow?

Airflow on Google Cloud costs around $300 per month. That is too expensive for a personal project. GitHub Actions is free for public repositories and runs the pipeline on a daily schedule with no infrastructure to manage.

The downside: GitHub Actions does not have the advanced monitoring and retry features that Airflow has. For one simple daily job, that is not a problem.

---

## Why save raw data before transforming it?

The raw data from Yahoo Finance is saved into BigQuery exactly as it arrives, before any changes are made. This means if something goes wrong during transformation, the original data is still safe. We can fix the transformation and run it again without downloading data a second time.

This is called the ELT pattern (Extract, Load, Transform) and is standard practice in modern data engineering.

---

## Why are stock prices and index prices in separate tables?

Stock prices and index prices are stored in two different tables (`raw_daily_prices` and `raw_benchmark_prices`). They could have been combined into one table with a column to tell them apart, but that would cause confusion.

A stock's trading volume is meaningful — it tells you how actively it was bought and sold. An index like the SMI does not actually trade, so its volume number means nothing. Keeping them separate makes the data cleaner and easier to work with.

---

*This file is updated when new decisions are made.*
