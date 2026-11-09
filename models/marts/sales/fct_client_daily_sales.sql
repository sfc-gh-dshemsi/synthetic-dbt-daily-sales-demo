select
    client_id || '|' || to_char(order_date, 'YYYY-MM-DD') as client_day_key,
    client_id,
    order_date,
    count(*) as order_count,
    sum(amount) as sales_amount
from {{ ref('int_orders_enriched') }}
group by client_id, order_date
