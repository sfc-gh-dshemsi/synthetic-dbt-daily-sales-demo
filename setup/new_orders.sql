-- Incremental demo: one new synthetic order arrives for a later date.
-- Run once, after the first build. Then rerun only that client/date slice:
--   run --select fct_client_daily_sales_incremental --vars '{client_id: CLIENT_B, start_date: 2026-10-04, end_date: 2026-10-04}'
insert into SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.ORDERS
    (ORDER_ID, CLIENT_ID, ORDER_DATE, AMOUNT)
values
    ('B3', 'CLIENT_B', '2026-10-04', 25.00);
