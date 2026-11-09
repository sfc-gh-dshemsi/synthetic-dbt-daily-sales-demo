{% snapshot hist_clients %}

-- SCD Type 2 history of client tiers. Each run compares RAW.CLIENTS with the
-- snapshot; when updated_at moves, the old row is closed (dbt_valid_to) and a
-- new current row is added.
{{ config(
    schema='history',
    unique_key='client_id',
    strategy='timestamp',
    updated_at='updated_at'
) }}

select client_id, client_name, region_code, lower(tier) as tier, updated_at
from {{ source('shop', 'clients') }}

{% endsnapshot %}
