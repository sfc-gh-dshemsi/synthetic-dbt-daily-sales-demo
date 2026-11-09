-- Planned failing test for a live demo. Disabled unless show_failing_test is true.
-- With max_order_amount = 50, orders A4 (99.00) and B2 (60.00) fail. Fix it live by
-- passing a higher max_order_amount with --vars (or edit dbt_project.yml and redeploy),
-- then rerun the test.
{{ config(enabled=var('show_failing_test')) }}

select order_id, client_id, amount
from {{ ref('stg_orders') }}
where amount > {{ var('max_order_amount') }}
