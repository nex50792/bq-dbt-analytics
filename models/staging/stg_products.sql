with source as (
  select * from {{ source('thelook', 'products') }}
)

select
  id                                       as product_id,
  cast(cost as numeric)                    as cost,
  category,
  name                                     as product_name,
  brand,
  cast(retail_price as numeric)            as retail_price,
  department,
  sku,
  distribution_center_id
from source
