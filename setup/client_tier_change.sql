-- Snapshot demo: CLIENT_B moves from standard to gold. Run `snapshot` once
-- before this change and once after it; hist_clients then holds two rows for
-- CLIENT_B, with dbt_valid_to set on the old one.
update SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.CLIENTS
set TIER = 'gold', UPDATED_AT = '2026-10-15 00:00:00'
where CLIENT_ID = 'CLIENT_B';
