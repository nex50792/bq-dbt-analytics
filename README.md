# bq-dbt-analytics

BigQuery + dbt + Evidence.dev で構築した EC 分析基盤。

Google の合成 EC データ (`bigquery-public-data.thelook_ecommerce`) を題材に、staging → intermediate → mart の3層構成、SCD Type 2、増分更新、パーティション + クラスタリング、56件のテスト、コード管理型の BI ダッシュボードを実装。

## 公開 URL

- ダッシュボード (Evidence.dev): https://bq-dbt-analytics.vercel.app/
- 系統図 (dbt docs): https://nex50792.github.io/bq-dbt-analytics/
- ソースコード: https://github.com/nex50792/bq-dbt-analytics

## 使用技術

| 項目 | 選定 | 選定理由 |
|---|---|---|
| データ倉庫 | BigQuery (Sandbox) | クラウド倉庫の代表格、無料枠内で継続運用が可能 |
| ELT 変換 | dbt-core 1.11 + dbt-bigquery | 全てコードで管理、SCD・増分更新・テストが揃う |
| 認証(ローカル) | gcloud application-default (OAuth) | サービスアカウントの鍵ファイルを作らず漏洩リスクを低減 |
| 認証(CI) | Workload Identity Federation (GitHub OIDC) | 長期シークレット不要、公式が推奨する方式 |
| モデルドキュメント | dbt docs generate --static → GitHub Pages | 系統図を自動生成 |
| ダッシュボード | Evidence.dev + DuckDB (parquet) | SQL と Markdown で記述、Vercel の無料枠で公開可能 |
| CI | GitHub Actions | 依存関係の検証と、ドキュメント自動配信 |

## 構成

```
bigquery-public-data.thelook_ecommerce
        │
        ▼
┌──────────────────┐
│ staging (view)   │  型変換 + 列名統一、テスト付き
│  stg_users       │
│  stg_products    │
│  stg_orders      │
│  stg_order_items │
└──────────────────┘
        │
        ▼
┌──────────────────────────┐
│ intermediate (ephemeral) │  ドメインロジック
│  int_order_items_enriched│
│  int_user_first_order    │
└──────────────────────────┘
        │
        ▼
┌────────────────────────────┐
│ marts (table / incremental)│
│  dim_users                 │ (クラスタ: country, traffic_source)
│  dim_products              │ (クラスタ: category)
│  fct_order_items           │ (増分更新、パーティション: order_date)
│  mart_daily_revenue        │ (パーティション: order_date)
│  mart_user_cohort_retention│
└────────────────────────────┘

snapshots/
  scd_users (SCD Type 2、check 方式)

.scripts/export_bq_to_parquet.py
  mart_* → parquet に書き出し (Evidence.dev 用のスナップショット)

evidence-app/
  ├─ pages/index.md            (SQL と Markdown でダッシュボードを記述)
  ├─ sources/thelook/          (DuckDB 経由で parquet を読む)
  │  ├─ connection.yaml
  │  ├─ *.sql                  (read_parquet('...') 経由で参照)
  │  └─ data/*.parquet         (BigQuery からの書き出しスナップショット)
  └─ package.json              (Vercel デプロイ用の Evidence アプリ)
```

## 系統図

自動生成の系統図 + 列レベルのドキュメント:

- 公開 URL: https://nex50792.github.io/bq-dbt-analytics/

## 設計判断の要点

詳細は [設計判断ドキュメント](./docs/design-decisions.md) を参照。

- **3層構成 (staging / intermediate / mart)**: dbt 公式が推奨する構成、可読性・再利用性・テスト容易性のバランスが良い
- **実体化方式の使い分け**: staging は view (常に最新)、intermediate は ephemeral (SQL にインライン展開)、mart は table か incremental
- **fct_order_items の incremental_strategy: insert_overwrite**: BigQuery のパーティション上書きが最も安価かつ高速
- **Sandbox 制約への対応**: 60日でパーティションが自動失効するため、dim テーブルは非パーティション、fct テーブルは order_date パーティションで直近60日を運用
- **テスト56件の内訳**: 汎用(組み込み: unique / not_null / relationships / accepted_values) + 汎用(自作: `non_negative_value` を金額列に適用) + 単発 SQL (将来日付の混入検知、集計マートの負値検知) + モデル単体テスト (intermediate モデルの粗利計算と初回注文集計を、モック入力と期待出力の比較で検証)
- **SCD Type 2 (check 方式)**: dim_users の email / age / traffic_source / state / city / country の変化を履歴として追跡

## 開発環境構築

```bash
# 1. venv を作成して dbt-bigquery を導入
python3.13 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install dbt-bigquery

# 2. gcloud で認証 (初回のみ)
gcloud auth application-default login
gcloud config set project coral-hull-501505-n8
gcloud auth application-default set-quota-project coral-hull-501505-n8

# 3. dbt debug で接続確認
DBT_PROFILES_DIR=. .venv/bin/dbt debug

# 4. モデル実行と検証
DBT_PROFILES_DIR=. .venv/bin/dbt build   # run + test を一括
DBT_PROFILES_DIR=. .venv/bin/dbt snapshot
DBT_PROFILES_DIR=. .venv/bin/dbt docs generate --static

# 5. 系統図をローカルで確認
open target/static_index.html

# 6. Evidence.dev のダッシュボードをローカルで確認
cd evidence-app
npm install
npm run sources    # parquet を DuckDB に取り込む
npm run dev        # http://localhost:3210 が開く (port は package.json で固定)
```
