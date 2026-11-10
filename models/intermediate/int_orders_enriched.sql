-- Intermediate: the business rule for "a sale", defined once and shared by every mart.
--   * cancelled orders don't count
--   * completed orders count toward gross sales
--   * refunds are subtracted from the client's sales on the refund date
--   * each order gets its client's region
-- Ephemeral: dbt inlines this as a CTE in the models that ref() it; nothing is built.
-- Left joins keep every order even if its client or region is missing, so the
-- marts always reconcile to the cleaned orders; the relationships test flags orphans.
{{ config(materialized='ephemeral') }}

select
    o.order_id,
    o.client_id,
    c.client_name,
    r.region_name,
    o.order_date,
    o.status,
    case when o.status = 'completed' then 1 else 0 end as completed_order,
    case when o.status = 'completed' then o.amount else 0 end as gross_amount,
    case when o.status = 'refunded' then o.amount else 0 end as refund_amount
from {{ ref('stg_shop__orders') }} as o
left join {{ ref('stg_shop__clients') }} as c
    on o.client_id = c.client_id
left join {{ ref('regions') }} as r
    on c.region_code = r.region_code
where o.status in ('completed', 'refunded')
