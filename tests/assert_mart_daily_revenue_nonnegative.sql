-- mart_daily_revenue は Cancelled/Returned を除外している集計マート。
-- revenue / items_sold / orders / gross_profit いずれも負にはならない前提。
-- 返品などで負になる場合は上流モデルの除外条件を見直す必要がある。
select
    order_date,
    product_category,
    revenue,
    items_sold,
    orders,
    gross_profit
from {{ ref('mart_daily_revenue') }}
where revenue < 0
   or items_sold < 0
   or orders < 0
   or gross_profit < -revenue
