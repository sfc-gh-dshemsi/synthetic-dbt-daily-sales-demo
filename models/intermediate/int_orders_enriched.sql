-- Business logic shared by the sales marts: each order with its client and region.
-- Ephemeral: dbt inlines this as a CTE in the models that ref() it; nothing is built.
-- Left joins keep every order even if its client or region is missing, so the
-- marts always reconcile to RAW.ORDERS; the relationships test flags orphans.
{{ config(materialized='ephemeral') }}

select
    o.order_id,
    o.client_id,
    c.client_name,
    c.region_code,
    r.region_name,
    o.order_date,
    o.amount
from {{ ref('stg_shop__orders') }} as o
left join {{ ref('stg_shop__clients') }} as c
    on o.client_id = c.client_id
left join {{ ref('regions') }} as r
    on c.region_code = r.region_code
