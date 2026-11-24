-- goes to: sales_dbt/models/intermediate/int_orders_enriched.sql
-- Step 5: the business rule for "a sale", written once and reused by every mart.
--   completed orders count, cancelled orders don't, refunds subtract.
-- ref() is how models point at each other. It's also how dbt works out the run order.
select
    o.order_id,
    o.client_id,
    c.client_name,
    r.region_name,
    o.order_date,
    o.status,
    iff(o.status = 'completed', 1, 0)           as completed_order,
    iff(o.status = 'completed', o.amount, 0)    as gross_amount,
    iff(o.status = 'refunded',  o.amount, 0)    as refund_amount
from {{ ref('stg_orders') }} o
left join {{ ref('stg_clients') }} c
    on o.client_id = c.client_id
left join {{ ref('regions') }} r
    on c.region_code = r.region_code
where o.status in ('completed', 'refunded')
