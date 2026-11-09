select
    cast(order_id as varchar) as order_id,
    cast(client_id as varchar) as client_id,
    cast(order_date as date) as order_date,
    cast(amount as number(12, 2)) as amount
from {{ source('shop', 'orders') }}
