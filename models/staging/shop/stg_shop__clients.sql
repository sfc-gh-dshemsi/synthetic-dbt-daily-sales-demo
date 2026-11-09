select
    cast(client_id as varchar) as client_id,
    cast(client_name as varchar) as client_name,
    cast(region_code as varchar) as region_code,
    lower(tier) as tier,
    cast(updated_at as timestamp_ntz) as updated_at
from {{ source('shop', 'clients') }}
