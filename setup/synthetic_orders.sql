-- Run only after verifying the intended lab connection and an unused database name.
-- This script is for one-time setup; it does not replace or remove existing objects.
create database SYNTHETIC_DBT_DAILY_SALES_DEMO;
create schema SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW;
create schema SYNTHETIC_DBT_DAILY_SALES_DEMO.DEV;
create schema SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD;
create table SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.ORDERS (
    ORDER_ID varchar(20) not null,
    CLIENT_ID varchar(30) not null,
    ORDER_DATE date not null,
    AMOUNT number(12, 2) not null
);
insert into SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.ORDERS
    (ORDER_ID, CLIENT_ID, ORDER_DATE, AMOUNT)
values
    ('A1', 'CLIENT_A', '2026-10-01', 10.00),
    ('A2', 'CLIENT_A', '2026-10-01', 20.00),
    ('A3', 'CLIENT_A', '2026-10-02', 7.00),
    ('A4', 'CLIENT_A', '2026-10-03', 99.00),
    ('B1', 'CLIENT_B', '2026-10-01', 40.00),
    ('B2', 'CLIENT_B', '2026-10-02', 60.00);
