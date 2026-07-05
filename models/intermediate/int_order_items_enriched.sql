{{ config(materialized='ephemeral') }}

with items as (
  select * from {{ ref('stg_order_items') }}
),
products as (
  select * from {{ ref('stg_products') }}
),
orders as (
  select * from {{ ref('stg_orders') }}
)

select
  items.order_item_id,
  items.order_id,
  items.user_id,
  items.product_id,
  items.status,
  items.sale_price,
  products.cost                                    as product_cost,
  products.category                                as product_category,
  products.brand                                   as product_brand,
  products.department                              as product_department,
  items.sale_price - products.cost                 as gross_profit,
  safe_divide(items.sale_price - products.cost, items.sale_price) as gross_margin,
  items.ordered_at,
  orders.status                                    as order_status,
  date(items.ordered_at)                           as order_date
from items
left join products on items.product_id = products.product_id
left join orders   on items.order_id   = orders.order_id
