{% snapshot scd_users %}

{{
  config(
    target_schema='snapshots',
    unique_key='user_id',
    strategy='check',
    check_cols=['email', 'age', 'traffic_source', 'state', 'city', 'country']
  )
}}

select * from {{ ref('stg_users') }}

{% endsnapshot %}
