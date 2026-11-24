-- goes to: sales_dbt/tests/assert_amount_positive.sql
-- Step 8b: a singular test is just a query. Any row returned = failure.
-- An order amount is never zero or negative. Corrections belong in refunds.
select order_id, amount
from {{ ref('stg_orders') }}
where amount <= 0
