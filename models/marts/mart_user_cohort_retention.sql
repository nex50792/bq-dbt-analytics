{{ config(materialized='table') }}

with items as (
  select * from {{ ref('fct_order_items') }}
),
users_first as (
  select
    user_id,
    date_trunc(min(order_date), month)     as cohort_month
  from items
  group by user_id
),
activity as (
  select
    i.user_id,
    date_trunc(i.order_date, month)        as active_month,
    u.cohort_month
  from items i
  join users_first u using (user_id)
),
cohort_sizes as (
  select cohort_month, count(distinct user_id) as cohort_size
  from users_first
  group by cohort_month
),
retention as (
  select
    cohort_month,
    active_month,
    date_diff(active_month, cohort_month, month) as month_number,
    count(distinct user_id)                as active_users
  from activity
  group by cohort_month, active_month
)

select
  r.cohort_month,
  r.month_number,
  cs.cohort_size,
  r.active_users,
  safe_divide(r.active_users, cs.cohort_size) as retention_rate
from retention r
join cohort_sizes cs using (cohort_month)
order by r.cohort_month, r.month_number
