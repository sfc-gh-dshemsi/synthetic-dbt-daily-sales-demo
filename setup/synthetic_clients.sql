-- One-time setup, after setup/synthetic_orders.sql: the client table that the
-- staging layer and the hist_clients snapshot read.
create table SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.CLIENTS (
    CLIENT_ID varchar(30) not null,
    CLIENT_NAME varchar(100) not null,
    REGION_CODE varchar(10) not null,
    TIER varchar(20) not null,
    UPDATED_AT timestamp_ntz not null
);
insert into SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.CLIENTS
    (CLIENT_ID, CLIENT_NAME, REGION_CODE, TIER, UPDATED_AT)
values
    ('CLIENT_A', 'Client A', 'WEST', 'standard', '2026-09-01 00:00:00'),
    ('CLIENT_B', 'Client B', 'EAST', 'standard', '2026-09-01 00:00:00');
