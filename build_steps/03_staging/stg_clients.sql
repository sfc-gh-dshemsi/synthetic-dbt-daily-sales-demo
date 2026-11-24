-- goes to: sales_dbt/models/staging/stg_clients.sql
-- Step 3b: tier arrives as 'Standard', 'GOLD'
select
    client_id,
    client_name,
    region_code,
    lower(trim(tier))        as tier
from {{ source('raw', 'clients') }}
