-- =====================================================================
-- 00_setup.sql
-- One-time setup: a warehouse, a database, and two messy raw tables.
-- Safe to rerun: it resets RAW back to the original 9 orders.
-- =====================================================================
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN;   -- needed for step 02 (schedule)

USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SALES_DBT_WH
  WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
CREATE DATABASE IF NOT EXISTS SALES_DBT_DB;
CREATE SCHEMA IF NOT EXISTS SALES_DBT_DB.RAW;    -- what the marketplace extract lands in
CREATE SCHEMA IF NOT EXISTS SALES_DBT_DB.DEV;    -- dbt target: dev
CREATE SCHEMA IF NOT EXISTS SALES_DBT_DB.PROD;   -- dbt target: prod

USE WAREHOUSE SALES_DBT_WH;
USE SCHEMA SALES_DBT_DB.RAW;

-- ---------------------------------------------------------------------
-- 1. Clients (fictional)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE CLIENTS (
  CLIENT_ID   STRING,
  CLIENT_NAME STRING,
  REGION_CODE STRING,
  TIER        STRING
);
INSERT INTO CLIENTS VALUES
  ('CLIENT_A', 'Client A', 'WEST', 'Standard'),
  ('CLIENT_B', 'Client B', 'EAST', 'GOLD');

-- ---------------------------------------------------------------------
-- 2. Orders: deliberately messy, the way real extracts arrive.
--    A2  loaded twice (same ORDER_ID, two LOADED_AT times)
--    A2  client id ' client_a ' and status 'Completed'  (spaces, casing)
--    A5  CANCELLED                                      (not a sale)
--    R1  REFUNDED 10.00 against CLIENT_B on 2026-10-02  (subtract it)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE ORDERS (
  ORDER_ID   STRING,
  CLIENT_ID  STRING,
  ORDER_DATE DATE,
  AMOUNT     NUMBER(12, 2),
  STATUS     STRING,
  LOADED_AT  TIMESTAMP_NTZ
);
INSERT INTO ORDERS VALUES
  ('A1', 'CLIENT_A',   '2026-10-01', 10.00, 'COMPLETED', '2026-10-02 01:00:00'),
  ('A2', ' client_a ', '2026-10-01', 20.00, 'Completed', '2026-10-02 01:00:00'),
  ('A2', ' client_a ', '2026-10-01', 20.00, 'Completed', '2026-10-02 05:00:00'),
  ('A3', 'CLIENT_A',   '2026-10-02',  7.00, 'completed', '2026-10-03 01:00:00'),
  ('A4', 'CLIENT_A',   '2026-10-03', 99.00, 'COMPLETED', '2026-10-04 01:00:00'),
  ('A5', 'CLIENT_A',   '2026-10-03', 15.00, 'CANCELLED', '2026-10-04 01:00:00'),
  ('B1', 'CLIENT_B',   '2026-10-01', 40.00, 'COMPLETED', '2026-10-02 01:00:00'),
  ('B2', 'CLIENT_B',   '2026-10-02', 60.00, 'COMPLETED', '2026-10-03 01:00:00'),
  ('R1', 'CLIENT_B',   '2026-10-02', 10.00, 'REFUNDED',  '2026-10-03 01:00:00');

-- ---------------------------------------------------------------------
-- 3. The problem, in one query: a naive total is wrong.
-- ---------------------------------------------------------------------
SELECT * FROM ORDERS ORDER BY ORDER_ID, LOADED_AT;              -- 9 rows
SELECT SUM(AMOUNT) AS NAIVE_TOTAL FROM ORDERS;                  -- 281.00
-- The right answer is 226.00: count A2 once, drop A5, subtract R1.
