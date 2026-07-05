---
title: TheLook E-Commerce Analytics
description: dbt + BigQuery で構築した EC 分析基盤のダッシュボード
---

## 概要

Google BigQuery public dataset `bigquery-public-data.thelook_ecommerce` を題材に、dbt で staging → intermediate → mart の medallion architecture で構築したデータマートを可視化しています。

---

## 主要指標

```sql kpi
  select
      sum(revenue) as total_revenue,
      sum(items_sold) as total_items,
      sum(orders) as total_orders,
      case when sum(revenue) > 0 then sum(gross_profit) * 1.0 / sum(revenue) else null end as gross_margin
  from thelook.mart_daily_revenue
```

<BigValue
  data={kpi}
  value=total_revenue
  title="売上合計"
  fmt=usd0
/>

<BigValue
  data={kpi}
  value=total_orders
  title="注文数"
  fmt=num0
/>

<BigValue
  data={kpi}
  value=total_items
  title="販売点数"
  fmt=num0
/>

<BigValue
  data={kpi}
  value=gross_margin
  title="平均粗利率"
  fmt=pct1
/>

---

## 日次売上推移(カテゴリ別)

```sql revenue_by_day_cat
  select
      order_date,
      product_category,
      sum(revenue) as revenue
  from thelook.mart_daily_revenue
  group by order_date, product_category
  order by order_date
```

<LineChart
  data={revenue_by_day_cat}
  x=order_date
  y=revenue
  series=product_category
  yFmt=usd0
  title="日次売上(カテゴリ別)"
/>

---

## カテゴリ別売上シェア

```sql revenue_by_category
  select
      product_category,
      sum(revenue) as revenue,
      sum(orders) as orders,
      case when sum(revenue) > 0 then sum(gross_profit) * 1.0 / sum(revenue) else null end as gross_margin
  from thelook.mart_daily_revenue
  group by product_category
  order by revenue desc
```

<BarChart
  data={revenue_by_category}
  x=product_category
  y=revenue
  yFmt=usd0
  title="カテゴリ別売上"
  swapXY=true
/>

<DataTable data={revenue_by_category}>
  <Column id=product_category title="カテゴリ" />
  <Column id=revenue title="売上" fmt=usd0 />
  <Column id=orders title="注文数" fmt=num0 />
  <Column id=gross_margin title="粗利率" fmt=pct1 />
</DataTable>

---

## リテンション(コホート × 経過月)

```sql cohort
  select
      cohort_month,
      month_number,
      retention_rate
  from thelook.mart_user_cohort_retention
  order by cohort_month, month_number
```

<DataTable data={cohort}>
  <Column id=cohort_month title="Cohort" fmt=date />
  <Column id=month_number title="経過月" />
  <Column id=retention_rate title="Retention" fmt=pct1 />
</DataTable>

**Note**: BigQuery Sandbox の 60 日 partition expiration の影響で `fct_order_items` が最新 60 日のみとなっており、cohort 分析はデータが薄くなっています。production 移行時はこの制約は外れます。

---

## ユーザー国別上位 15

```sql users_by_country
  select
      country,
      count(*) as users,
      count(case when has_ordered then 1 end) as active_users,
      count(case when has_ordered then 1 end) * 1.0 / count(*) as activation_rate
  from thelook.dim_users
  group by country
  having count(*) > 100
  order by users desc
  limit 15
```

<BarChart
  data={users_by_country}
  x=country
  y=users
  title="国別ユーザー数"
  swapXY=true
/>

<DataTable data={users_by_country}>
  <Column id=country title="国" />
  <Column id=users title="登録数" fmt=num0 />
  <Column id=active_users title="購入経験あり" fmt=num0 />
  <Column id=activation_rate title="Activation率" fmt=pct1 />
</DataTable>

---

## 商品カテゴリ別 平均粗利率

```sql product_margin
  select
      category,
      count(*) as products,
      avg(retail_price) as avg_price,
      avg(margin_rate) as avg_margin_rate
  from thelook.dim_products
  group by category
  order by avg_margin_rate desc
```

<BarChart
  data={product_margin}
  x=category
  y=avg_margin_rate
  yFmt=pct1
  title="カテゴリ別 平均粗利率"
  swapXY=true
/>

---

## データの新鮮さ

このダッシュボードは BigQuery の dbt モデル (`analytics_dev_marts`) から parquet に export した静的スナップショットを、DuckDB を通して描画しています。

- 更新方法: `python .scripts/export_bq_to_parquet.py` を再実行 → git commit → Vercel 自動 deploy
