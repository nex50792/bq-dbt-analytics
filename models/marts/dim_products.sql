{{ config(materialized='table', cluster_by=['category']) }}

with products as (
  select * from {{ ref('stg_products') }}
)

select
  product_id,
  product_name,
  brand,
  category,
  department,
  sku,
  cost,
  retail_price,
  retail_price - cost                       as margin,
  safe_divide(retail_price - cost, retail_price) as margin_rate
from products
