-- Exact-result test: the mart must match these hand-checked rows for the seed data.
-- It catches a wrong business rule (e.g. counting cancelled orders, double-counting
-- the duplicate load, or forgetting the refund), not just bad keys.
with expected as (
    select column1 as client_id, column2 as region_name, to_date(column3) as order_date,
           column4 as order_count, column5::number(12, 2) as gross_sales,
           column6::number(12, 2) as refund_amount, column7::number(12, 2) as net_sales
    from values
        ('CLIENT_A', 'West', '2026-10-01', 2, 30.00,  0.00, 30.00),  -- A1 + A2 (duplicate load counted once)
        ('CLIENT_A', 'West', '2026-10-02', 1,  7.00,  0.00,  7.00),
        ('CLIENT_A', 'West', '2026-10-03', 1, 99.00,  0.00, 99.00),  -- A5 cancelled, excluded
        ('CLIENT_B', 'East', '2026-10-01', 1, 40.00,  0.00, 40.00),
        ('CLIENT_B', 'East', '2026-10-02', 1, 60.00, 10.00, 50.00)   -- R1 refund subtracted
), actual as (
    select client_id, region_name, order_date, order_count, gross_sales, refund_amount, net_sales
    from {{ ref('fct_client_daily_sales') }}
    -- The fixture covers the original orders; setup/new_orders.sql adds a later date.
    where order_date <= '2026-10-03'
)
select 'unexpected_actual' as mismatch, *
from (select * from actual minus select * from expected)
union all
select 'missing_expected' as mismatch, *
from (select * from expected minus select * from actual)
