-- =====================================================================
-- 01_rerun_one_slice.sql
-- Run AFTER step 7 (fct_client_daily_sales_incremental) is built once on dev.
-- New orders land for 2026-10-04. Rerun ONE client and ONE day, not the whole table:
-- the same job as a "delete for client/date, recompute, insert" procedure.
-- =====================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE SALES_DBT_WH;
USE SCHEMA SALES_DBT_DB.RAW;

-- 1. Before: 5 rows, nothing for 2026-10-04 yet.
SELECT * FROM SALES_DBT_DB.DEV.FCT_CLIENT_DAILY_SALES_INCREMENTAL ORDER BY CLIENT_ID, ORDER_DATE;

-- 2. Two new orders arrive for 2026-10-04, one per client.
INSERT INTO ORDERS VALUES
  ('B3', 'CLIENT_B', '2026-10-04', 25.00, 'COMPLETED', '2026-10-05 01:00:00'),
  ('A6', 'CLIENT_A', '2026-10-04', 12.00, 'COMPLETED', '2026-10-05 01:00:00');

-- 3. In the workspace (profile dev), command Run, and in the arguments box (down arrow next to Run):
--      --select fct_client_daily_sales_incremental --vars '{client_id: CLIENT_B, start_date: 2026-10-04, end_date: 2026-10-04}'
--    Then come back here.
SELECT * FROM SALES_DBT_DB.DEV.FCT_CLIENT_DAILY_SALES_INCREMENTAL ORDER BY CLIENT_ID, ORDER_DATE;
-- 6 rows: CLIENT_B 2026-10-04 = 25.00 is in. CLIENT_A 2026-10-04 is NOT, because we only asked for CLIENT_B.

-- 4. Same day, every client: drop client_id from the vars.
--      --select fct_client_daily_sales_incremental --vars '{start_date: 2026-10-04, end_date: 2026-10-04}'
SELECT * FROM SALES_DBT_DB.DEV.FCT_CLIENT_DAILY_SALES_INCREMENTAL ORDER BY CLIENT_ID, ORDER_DATE;
-- 7 rows: CLIENT_A 2026-10-04 = 12.00 is in now.

-- 5. Proof it was a scoped delete + insert, not a full rebuild:
SELECT START_TIME, QUERY_TEXT, ROWS_INSERTED
FROM TABLE(SALES_DBT_DB.INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 500))
WHERE QUERY_TEXT ILIKE '%fct_client_daily_sales_incremental%'
  AND (QUERY_TEXT ILIKE 'delete from%' OR QUERY_TEXT ILIKE 'insert into%')
ORDER BY START_TIME DESC
LIMIT 4;
