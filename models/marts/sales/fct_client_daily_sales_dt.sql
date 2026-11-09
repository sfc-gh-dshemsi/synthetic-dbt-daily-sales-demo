-- Same output as fct_client_daily_sales, as a dynamic table that Snowflake keeps
-- fresh on its own (target_lag). Omitting target_lag so dbt triggers the refresh
-- needs dbt-snowflake 1.11.5 or later; this project runs on dbt 1.9.4.
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
from {{ ref('int_orders_enriched') }}
group by client_id, order_date
