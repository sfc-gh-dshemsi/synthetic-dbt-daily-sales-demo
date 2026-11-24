-- goes to: sales_dbt/models/staging/stg_orders.sql
-- Step 3a: one row per order, cleaned. No business rules here.
--   ' client_a ' -> 'CLIENT_A'      'Completed' -> 'completed'
--   A2 was loaded twice: keep only the latest load.
select
    order_id,
    upper(trim(client_id))   as client_id,
    order_date,
    amount,
    lower(trim(status))      as status,
    loaded_at
from {{ source('raw', 'orders') }}
qualify row_number() over (partition by order_id order by loaded_at desc) = 1
