{{
  config(
    materialized='table',
    cluster_by=['country', 'traffic_source']
  )
}}

with users as (
  select * from {{ ref('stg_users') }}
),
first_order as (
  select * from {{ ref('int_user_first_order') }}
)

select
  u.user_id,
  u.first_name,
  u.last_name,
  u.email,
  u.age,
  u.gender,
  u.country,
  u.state,
  u.city,
  u.traffic_source,
  u.signed_up_at,
  date(u.signed_up_at)                     as signed_up_date,
  fo.first_ordered_at,
  fo.first_order_date,
  date_diff(fo.first_order_date, date(u.signed_up_at), day) as days_to_first_order,
  case when fo.user_id is not null then true else false end as has_ordered
from users u
left join first_order fo using (user_id)
