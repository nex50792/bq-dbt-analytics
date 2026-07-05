with source as (
  select * from {{ source('thelook', 'order_items') }}
)

select
  id                                       as order_item_id,
  order_id,
  user_id,
  product_id,
  inventory_item_id,
  status,
  cast(sale_price as numeric)              as sale_price,
  cast(created_at as timestamp)            as ordered_at,
  cast(shipped_at as timestamp)            as shipped_at,
  cast(delivered_at as timestamp)          as delivered_at,
  cast(returned_at as timestamp)           as returned_at
from source
