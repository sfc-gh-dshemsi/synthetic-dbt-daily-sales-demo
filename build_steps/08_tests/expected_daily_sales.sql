-- goes to: sales_dbt/tests/expected_daily_sales.sql
-- Step 8c: the mart must match these hand-checked numbers for the original orders.
-- This catches a wrong business rule (counting A5, double-counting A2, forgetting R1).
with expected as (
    select column1 as client_id, to_date(column2) as order_date,
           column3::number(12, 2) as net_sales
    from values
        ('CLIENT_A', '2026-10-01', 30.00),   -- A1 + A2, duplicate load counted once
        ('CLIENT_A', '2026-10-02',  7.00),
        ('CLIENT_A', '2026-10-03', 99.00),   -- A5 cancelled, excluded
        ('CLIENT_B', '2026-10-01', 40.00),
        ('CLIENT_B', '2026-10-02', 50.00)    -- 60.00 minus R1 refund 10.00
), actual as (
    select client_id, order_date, net_sales
    from {{ ref('fct_client_daily_sales') }}
    where order_date <= '2026-10-03'         -- step 01 adds a later date on purpose
)
(select 'unexpected' as problem, * from actual minus select 'unexpected', * from expected)
union all
(select 'missing' as problem, * from expected minus select 'missing', * from actual)
