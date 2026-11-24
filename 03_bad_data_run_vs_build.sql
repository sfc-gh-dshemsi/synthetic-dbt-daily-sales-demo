-- =====================================================================
-- 03_bad_data_run_vs_build.sql
-- `run` then `test`   vs   `build`
-- Why dbt instead of a task that just runs SQL: tests can stop bad numbers
-- before the dashboard sees them.
-- =====================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE SALES_DBT_WH;

-- 0. CLIENT_A's net sales on 2026-10-03 right now (note the number: 99.00)
SELECT CLIENT_ID, ORDER_DATE, NET_SALES
FROM SALES_DBT_DB.DEV.FCT_CLIENT_DAILY_SALES
WHERE CLIENT_ID = 'CLIENT_A' AND ORDER_DATE = '2026-10-03';

-- 1. The extract ships a bug: a correction written as a negative order.
INSERT INTO SALES_DBT_DB.RAW.ORDERS VALUES
  ('A9', 'CLIENT_A', '2026-10-03', -40.00, 'COMPLETED', '2026-10-04 06:00:00');

-- 2. In the workspace (profile dev), command:   Run      <- models only, no tests
--    Everything succeeds. Now look at the dashboard table:
SELECT CLIENT_ID, ORDER_DATE, NET_SALES
FROM SALES_DBT_DB.DEV.FCT_CLIENT_DAILY_SALES
WHERE CLIENT_ID = 'CLIENT_A' AND ORDER_DATE = '2026-10-03';
-- 59.00. Sales went DOWN by an order that never happened. Metabase already shows it.
--    Then command:   Test
--    assert_amount_positive FAILS and expected_daily_sales FAILS.
--    Correct tests... that ran AFTER the bad number was published.

-- 3. The same day with `build`.
--    Reset first, so the mart holds good data again:
DELETE FROM SALES_DBT_DB.RAW.ORDERS WHERE ORDER_ID = 'A9';
--    workspace: Build     (all green, 99.00 is back)

INSERT INTO SALES_DBT_DB.RAW.ORDERS VALUES
  ('A9', 'CLIENT_A', '2026-10-03', -40.00, 'COMPLETED', '2026-10-04 06:00:00');
--    workspace: Build
--    stg_orders builds (it's a view), its tests run straight after it, they FAIL,
--    and dbt SKIPS everything downstream, including fct_client_daily_sales.
SELECT CLIENT_ID, ORDER_DATE, NET_SALES
FROM SALES_DBT_DB.DEV.FCT_CLIENT_DAILY_SALES
WHERE CLIENT_ID = 'CLIENT_A' AND ORDER_DATE = '2026-10-03';
-- Still 99.00. The dashboard keeps yesterday's good numbers.

-- 4. Fix at the source, build again, all green.
DELETE FROM SALES_DBT_DB.RAW.ORDERS WHERE ORDER_ID = 'A9';   -- corrections belong in refunds
--    workspace: Build
