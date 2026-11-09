-- Same output as client_daily_sales, as a dynamic table that Snowflake keeps
-- fresh on its own. target_lag is required on dbt 1.9.4 and 1.10.15.
{{ config(
    materialized='dynamic_table',
    snowflake_warehouse='COMPUTE_WH',
    target_lag='1 day'
) }}

select
    client_id || '|' || to_char(order_date, 'YYYY-MM-DD') as client_day_key,
    client_id,
    order_date,
    count(*) as order_count,
    sum(amount) as sales_amount
from {{ ref('stg_orders') }}
group by client_id, order_date
