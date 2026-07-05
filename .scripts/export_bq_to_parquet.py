"""BigQuery の analytics_dev_marts.* を parquet として export する。
Evidence.dev + DuckDB で読ませる用。実行: python .scripts/export_bq_to_parquet.py
"""

from pathlib import Path

from google.cloud import bigquery

PROJECT = "coral-hull-501505-n8"
DATASET = "analytics_dev_marts"
TABLES = [
    "dim_users",
    "dim_products",
    "fct_order_items",
    "mart_daily_revenue",
    "mart_user_cohort_retention",
]
OUT_DIR = Path("evidence-app/sources/thelook/data")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    client = bigquery.Client(project=PROJECT)
    for t in TABLES:
        print(f"Exporting {t}...")
        df = client.query(f"SELECT * FROM `{PROJECT}.{DATASET}.{t}`").to_dataframe()
        out = OUT_DIR / f"{t}.parquet"
        df.to_parquet(out, index=False)
        print(f"  {len(df):,} rows -> {out} ({out.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
