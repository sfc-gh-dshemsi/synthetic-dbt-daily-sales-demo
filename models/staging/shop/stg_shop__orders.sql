-- Staging: clean the raw extract, one row per order. No business rules here.
--   * trim and uppercase client ids (' client_a ' -> 'CLIENT_A')
--   * lowercase status ('Completed', 'COMPLETED' -> 'completed')
--   * keep only the latest load of each order_id (removes the duplicate A2)
select
    cast(order_id as varchar) as order_id,
    upper(trim(client_id)) as client_id,
    cast(order_date as date) as order_date,
    cast(amount as number(12, 2)) as amount,
    lower(trim(status)) as status,
    cast(loaded_at as timestamp_ntz) as loaded_at
from {{ source('shop', 'orders') }}
qualify row_number() over (partition by order_id order by loaded_at desc) = 1
