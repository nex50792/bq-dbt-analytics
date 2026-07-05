{{
  config(
    materialized='table',
    partition_by={'field': 'order_date', 'data_type': 'date'}
  )
}}

with items as (
  select * from {{ ref('fct_order_items') }}
  where order_status not in ('Cancelled', 'Returned')
)

select
  order_date,
  product_category,
  count(distinct order_id)                 as orders,
  count(*)                                 as items_sold,
  sum(sale_price)                          as revenue,
  sum(gross_profit)                        as gross_profit,
  safe_divide(sum(gross_profit), sum(sale_price)) as gross_margin_rate
from items
group by order_date, product_category
