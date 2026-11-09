-- Same output as client_daily_sales, built incrementally.
-- On a rerun, delete+insert replaces only the client/day keys in the selected
-- slice, similar to a scoped delete / recompute / insert procedure.
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='client_day_key'
) }}

select
    client_id || '|' || to_char(order_date, 'YYYY-MM-DD') as client_day_key,
    client_id,
    order_date,
    count(*) as order_count,
    sum(amount) as sales_amount
from {{ ref('stg_orders') }}
{% if is_incremental() %}
where order_date between '{{ var("start_date") }}' and '{{ var("end_date") }}'
  {% if var("client_id") %}
  and client_id = '{{ var("client_id") }}'
  {% endif %}
{% endif %}
group by client_id, order_date
