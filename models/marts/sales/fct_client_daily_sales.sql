-- Mart: daily net sales per client. The business rule lives in int_orders_enriched;
-- this model only aggregates it to one row per client and day.
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
group by client_id, region_name, order_date
