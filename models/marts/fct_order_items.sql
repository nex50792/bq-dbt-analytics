{{
  config(
    materialized='incremental',
    partition_by={'field': 'order_date', 'data_type': 'date'},
    cluster_by=['product_category'],
    incremental_strategy='insert_overwrite'
  )
}}

with items as (
  select * from {{ ref('int_order_items_enriched') }}
  {% if is_incremental() %}
    where date(ordered_at) >= date_sub(current_date(), interval 3 day)
  {% endif %}
)

select
  order_item_id,
  order_id,
  user_id,
  product_id,
  order_status,
  status                                   as item_status,
  sale_price,
  product_cost,
  gross_profit,
  gross_margin,
  product_category,
  product_brand,
  product_department,
  ordered_at,
  order_date
from items
