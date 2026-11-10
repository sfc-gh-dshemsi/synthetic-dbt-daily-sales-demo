-- Optional alternative: same output as fct_client_daily_sales, built incrementally.
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
    region_name,
    order_date,
    sum(completed_order) as order_count,
    sum(gross_amount) as gross_sales,
    sum(refund_amount) as refund_amount,
    sum(gross_amount) - sum(refund_amount) as net_sales
from {{ ref('int_orders_enriched') }}
{% if is_incremental() %}
-- The vars are pasted into the SQL as text. That's fine for trusted operator
-- inputs like these; don't use this pattern for values a user can type in.
where order_date between '{{ var("start_date") }}' and '{{ var("end_date") }}'
  {% if var("client_id") %}
  and client_id = '{{ var("client_id") }}'
  {% endif %}
{% endif %}
group by client_id, region_name, order_date
