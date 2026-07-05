-- 将来日付の注文はデータエラーとみなして fail させる。
-- Sandbox の日次バッチ運用上、ordered_at > now() は起こり得ない前提。
select
    order_id,
    ordered_at
from {{ ref('stg_orders') }}
where ordered_at > current_timestamp()
