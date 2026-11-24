-- goes to: sales_dbt/models/marts/fct_client_daily_sales_incremental.sql
-- Step 7: the same mart, rebuilt one slice at a time. This is the
-- "delete for a client and date range, recompute, insert" procedure pattern.
--   First run: builds every row.
--   Later runs: only the client/date slice you pass with --vars is deleted and reinserted.
-- The vars are pasted into the SQL as text: use them for trusted operator inputs only.
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='client_day_key'
) }}

select
    client_id || '|' || to_char(order_date, 'YYYY-MM-DD')   as client_day_key,
    client_id,
    region_name,
    order_date,
    sum(completed_order)                     as order_count,
    sum(gross_amount)                        as gross_sales,
    sum(refund_amount)                       as refund_amount,
    sum(gross_amount) - sum(refund_amount)   as net_sales
from {{ ref('int_orders_enriched') }}
{% if is_incremental() %}
where order_date between '{{ var("start_date") }}' and '{{ var("end_date") }}'
  {% if var("client_id") %}
  and client_id = '{{ var("client_id") }}'
  {% endif %}
{% endif %}
group by client_id, region_name, order_date
