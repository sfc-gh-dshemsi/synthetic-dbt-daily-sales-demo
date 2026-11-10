-- Run only after verifying the intended lab connection and an unused database name.
-- This script is for one-time setup; it does not replace or remove existing objects.
--
-- The raw orders are deliberately messy, the way real source extracts often are:
--   A2  loaded twice (same order_id, two LOADED_AT times)       -> staging keeps one
--   A2  client id as ' client_a ' and status 'Completed'          -> staging trims and normalizes
--   A5  CANCELLED                                                  -> excluded from sales
--   R1  REFUNDED 10.00 against CLIENT_B on 2026-10-02              -> subtracted from sales
create database SYNTHETIC_DBT_DAILY_SALES_DEMO;
create schema SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW;
create schema SYNTHETIC_DBT_DAILY_SALES_DEMO.DEV;
create schema SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD;
create table SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.ORDERS (
    ORDER_ID varchar(20) not null,
    CLIENT_ID varchar(30) not null,
    ORDER_DATE date not null,
    AMOUNT number(12, 2) not null,
    STATUS varchar(20) not null,
    LOADED_AT timestamp_ntz not null
);
insert into SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.ORDERS
    (ORDER_ID, CLIENT_ID, ORDER_DATE, AMOUNT, STATUS, LOADED_AT)
values
    ('A1', 'CLIENT_A',   '2026-10-01', 10.00, 'COMPLETED', '2026-10-02 01:00:00'),
    ('A2', ' client_a ', '2026-10-01', 20.00, 'Completed', '2026-10-02 01:00:00'),
    ('A2', ' client_a ', '2026-10-01', 20.00, 'Completed', '2026-10-02 05:00:00'),
    ('A3', 'CLIENT_A',   '2026-10-02',  7.00, 'completed', '2026-10-03 01:00:00'),
    ('A4', 'CLIENT_A',   '2026-10-03', 99.00, 'COMPLETED', '2026-10-04 01:00:00'),
    ('A5', 'CLIENT_A',   '2026-10-03', 15.00, 'CANCELLED', '2026-10-04 01:00:00'),
    ('B1', 'CLIENT_B',   '2026-10-01', 40.00, 'COMPLETED', '2026-10-02 01:00:00'),
    ('B2', 'CLIENT_B',   '2026-10-02', 60.00, 'COMPLETED', '2026-10-03 01:00:00'),
    ('R1', 'CLIENT_B',   '2026-10-02', 10.00, 'REFUNDED',  '2026-10-03 01:00:00');
