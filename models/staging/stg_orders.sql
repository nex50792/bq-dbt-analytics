with source as (
  select * from {{ source('thelook', 'orders') }}
)

select
  order_id,
  user_id,
  status,
  cast(created_at as timestamp)            as ordered_at,
  cast(shipped_at as timestamp)            as shipped_at,
  cast(delivered_at as timestamp)          as delivered_at,
  cast(returned_at as timestamp)           as returned_at,
  num_of_item                              as item_count
from source
