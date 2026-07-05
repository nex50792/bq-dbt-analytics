{{ config(materialized='ephemeral') }}

with orders as (
  select * from {{ ref('stg_orders') }}
)

select
  user_id,
  min(ordered_at)                          as first_ordered_at,
  date(min(ordered_at))                    as first_order_date
from orders
group by user_id
