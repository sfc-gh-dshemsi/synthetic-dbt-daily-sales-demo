with expected as (
    select column1 as client_id, to_date(column2) as order_date,
           column3 as order_count, column4::number(12, 2) as sales_amount
    from values
        ('CLIENT_A', '2026-10-01', 2, 30.00),
        ('CLIENT_A', '2026-10-02', 1, 7.00),
        ('CLIENT_A', '2026-10-03', 1, 99.00),
        ('CLIENT_B', '2026-10-01', 1, 40.00),
        ('CLIENT_B', '2026-10-02', 1, 60.00)
), actual as (
    select client_id, order_date, order_count, sales_amount
    from {{ ref('client_daily_sales') }}
    -- The fixture covers the original six orders; setup/new_orders.sql adds a later date.
    where order_date <= '2026-10-03'
)
select 'unexpected_actual' as mismatch, client_id, order_date, order_count, sales_amount
from (select * from actual minus select * from expected)
union all
select 'missing_expected' as mismatch, client_id, order_date, order_count, sales_amount
from (select * from expected minus select * from actual)