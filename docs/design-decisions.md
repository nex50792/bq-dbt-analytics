# 設計判断ドキュメント

本プロジェクトの技術選定と設計判断の背景を集約する。実装ファイルからは読み取れない「なぜこう作ったか」を残すことで、後から見返す・共有する際の参照点とする。

## 1. データ倉庫: BigQuery Sandbox

### 選定

- BigQuery Sandbox を選定
- クレジットカード登録不要、無料枠(保存容量 10 GB、クエリ 1 TB / 月)の範囲で動作

### 比較検討

| 候補 | 判断 |
|---|---|
| BigQuery (Sandbox) | 選定。カード不要、認知度と実利用実績が高い |
| Snowflake の 30日試用 | 期間終了後にカード必須で、継続公開用途に不向き |
| DuckDB (単独) | 恒久無料だが、クラウド倉庫としての運用イメージを弱める |
| Redshift | カード必須、運用費が高く個人開発では現実的でない |

### Sandbox の制約と対応

- 全テーブル・全パーティションが 60日で自動削除される
- 対応:
  - dim テーブル: `partition_by` を使わない (次元は歴史全体の保持が必要)
  - fct テーブル: `order_date` でパーティションを切る (直近60日運用は本用途で許容)
  - 本番運用では `partition_expiration_days` を明示指定して任意期間に変更可能

## 2. 変換基盤: dbt-core

### 選定

- dbt-core を選定 (dbt Cloud は不採用)

### 理由

- コマンドラインベースで、GitHub Actions などと組み合わせやすい
- Web エディタの座席制限がなく、拡張時の柔軟性が高い

### 版の固定

- dbt-core `1.11.12`
- dbt-bigquery `1.11.3`
- Python `3.13` (Python 3.14 は依存の `mashumaro` と非互換)

## 3. モデル構成: 3層 (staging / intermediate / mart)

### staging (view で実体化)

- 型変換、列名の統一 (`id` → `user_id` 等)、単純な整形のみ
- 実体化: `view` (常に最新、コストが低い)
- 命名: `stg_<source_object>`

### intermediate (ephemeral で実体化)

- ドメインロジック、join、複数の staging を統合する層
- 実体化: `ephemeral` (CTE として展開、物理テーブルを作らない)
- 命名: `int_<domain>_<action>`

### marts (table か incremental で実体化)

- ダッシュボードやアプリから利用する最終層
- 実体化:
  - `dim_*`: `table` (次元は小さいので毎回再構築を許容)
  - `fct_*`: `incremental` (増分更新でコスト削減)
  - `mart_*`: `table` (集約後の分析用マート)
- 命名: `dim_<entity>`, `fct_<event>`, `mart_<usecase>`

## 4. 増分更新方式: insert_overwrite (fct_order_items)

### 比較

BigQuery で dbt の増分更新を実装する4つの方式:

| 方式 | 挙動 | 用途 |
|---|---|---|
| `append` | 新行を追加のみ | ログ追加系 |
| `merge` | MERGE 文で upsert | 汎用、コスト中 |
| `insert_overwrite` | パーティション単位で上書き | 時系列 fact、最安・最速 |
| `microbatch` | dbt 1.9 以降の新機能 | 大規模時系列 |

### 選定

- `insert_overwrite` を選定
- fct_order_items は `order_date` でパーティション済み
- 過去データの変更頻度が低い(注文の返品程度)
- パーティション上書きは MERGE より安い (BigQuery の料金体系上)
- `is_incremental()` の分岐で「直近3日のパーティション」のみ再構築

## 5. パーティションとクラスタリング

BigQuery のコスト・性能最適化機能:

- パーティション: 特定の列 (通常は日付) でテーブルを分割、`WHERE date=...` でスキャン量削減
- クラスタリング: 別の列で物理的にソート、頻出フィルタ列のスキャン量削減

### 使い分け

| モデル | パーティション | クラスタ | 理由 |
|---|---|---|---|
| dim_users | なし | country, traffic_source | 次元は歴史全体を保持、country 別クエリが多い |
| dim_products | なし | category | 次元、category 別クエリが多い |
| fct_order_items | order_date | product_category | 時系列 fact、日付フィルタとカテゴリ集計 |
| mart_daily_revenue | order_date | なし | 集約後、日付フィルタのみ |
| mart_user_cohort_retention | なし | なし | 小テーブル、最適化不要 |

## 6. SCD Type 2 (snapshots/scd_users.sql)

### 目的

- dim_users は現時点のユーザー属性を持つが、過去の値の履歴 (過去の email、age、state) は保持しない
- SCD Type 2 で属性変化を `dbt_valid_from` と `dbt_valid_to` で追跡する

### 方式

- `check` 方式を選定
- 対象列: `email`、`age`、`traffic_source`、`state`、`city`、`country`
- 理由: 元データの `updated_at` が信頼できないため、更新時刻に依存する方式が使えない

## 7. テスト: 56件 (4種類の使い分け)

dbt には4種類のテスト機構があり、目的別に併用する。

### 内訳

| 種類 | 実装数 | 対象 | 目的 |
|---|---|---|---|
| 汎用 (組み込み) | 45 | 全ての主キー、外部キー、列挙値の列 | `unique` / `not_null` / `relationships` / `accepted_values` による参照整合性とデータ品質の担保 |
| 汎用 (自作マクロ) | 9 | 金額列 (sale_price、product_cost、revenue、items_sold、orders、retail_price、cost) | `non_negative_value` マクロで負値の混入を検知 |
| 単発 SQL | 2 | stg_orders と mart_daily_revenue | 「将来日付の注文が混入していないか」「集計マートに負値がないか」を単発クエリで検証 |
| モデル単体テスト | 2 | int_order_items_enriched と int_user_first_order | モック入力と期待出力を YAML で書き、intermediate モデルのロジックをメモリ上で単体検証 (dbt 1.8 以降) |

### 型に関する注意 (モデル単体テスト)

- BigQuery は型変換が厳密。モック入力の ID を文字列 (`"p1"`) で書くと、INT64 列との JOIN が型不一致で暗黙のうちに NULL になる。
- 実データに合わせて数値 ID は整数リテラルで指定する必要がある。

### intermediate 用のデータセットについて

- intermediate モデルは `ephemeral` だが、モデル単体テスト実行時は `<database>.<schema>_intermediate` に一時テーブルを作成するため、該当のデータセットが事前に存在している必要がある。
- ローカルまたは CI の初回セットアップ時に `analytics_dev_intermediate` を明示的に作成する。

### CI 上の位置づけ

- プルリクエストで `dbt build` (run + test) を実行
- 失敗時はマージをブロック
- 本番運用では snapshot 更新後にも `dbt test` を実行

## 8. 認証: gcloud (ローカル) と Workload Identity Federation (CI)

### ローカル: gcloud application-default login

- サービスアカウントの鍵ファイルを作らない (漏洩リスクを避ける)
- ブラウザで自分の Google アカウントで認証
- 認証情報は `~/.config/gcloud/application_default_credentials.json` に保存
- profiles.yml で `method: oauth` を指定

### CI: Workload Identity Federation

- GitHub の OIDC トークンを GCP の STS で短時間の access token に交換
- 長期のシークレットを持たない
- 設定手順:
  1. Workload Identity プールを作成
  2. GitHub 用の Workload Identity プロバイダを追加
  3. サービスアカウントを作成し、BigQuery 権限を付与
  4. バインディング: `roles/iam.workloadIdentityUser`
  5. GitHub Actions で `google-github-actions/auth@v2` を使用

## 9. ダッシュボード: Evidence.dev + DuckDB (parquet スナップショット)

### 選定

- Evidence.dev (オープンソース、SQL と Markdown ベース)
- BigQuery のマートテーブルを `.scripts/export_bq_to_parquet.py` で parquet に書き出し
- Evidence は DuckDB 経由で parquet を読み込み、静的サイトを生成
- Vercel で無料公開

### 比較

| 候補 | 判断 |
|---|---|
| Evidence.dev | 選定。コード管理、Vercel の静的公開、認証不要 |
| Looker Studio | 操作が UI ベースで、コードでの管理が困難 |
| Metabase | セルフホストが必要、静的公開に不向き |
| Streamlit | Python 基盤、SQL の可視性が Evidence より劣る |

### 静的スナップショットにした理由

- Vercel デプロイ時に BigQuery の認証情報を渡さずに済む
- 静的サイトは高速で、公開のコストがゼロ
- データ更新は `python .scripts/export_bq_to_parquet.py` → commit → Vercel の自動デプロイで完結

## 10. モデルドキュメント: dbt docs generate --static

- `--static` オプションで単一の HTML ファイルを生成 (`target/static_index.html`)
- `docs/index.html` にコピーして GitHub Pages で公開
- 系統図 (source → staging → mart) と列レベルの説明を自動生成
- ephemeral モデルも系統図に表示される

## 未着手 / 検討中

- Elementary Data: dbt テスト結果を BigQuery に永続化して可観測性を強化
- sqlfluff: SQL の静的検査を CI に組み込む
- dbt project evaluator: コーディング規約の自動チェック
- fct_order_items の履歴延長: 60日制約を超えた履歴保持 (Sandbox 外の運用 or GCS を併用)
