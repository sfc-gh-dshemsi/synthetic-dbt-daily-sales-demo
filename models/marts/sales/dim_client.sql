select
    c.client_id,
    c.client_name,
    c.region_code,
    r.region_name,
    c.tier
from {{ ref('stg_shop__clients') }} as c
left join {{ ref('regions') }} as r
    on c.region_code = r.region_code
