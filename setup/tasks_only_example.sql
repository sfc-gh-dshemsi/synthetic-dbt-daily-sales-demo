-- The SAME pipeline as the dbt project, built with tasks only (no dbt).
-- Use it to compare the two approaches side by side. It writes to its own schema,
-- TASKS_ONLY, so it never touches the dbt-built objects.
--
-- Notice what you write by hand here that dbt writes for you:
--   * every CREATE OR REPLACE TABLE ... AS           (dbt: materializations)
--   * the run order, via AFTER                        (dbt: inferred from ref())
--   * the data check, as procedural code              (dbt: tests declared in YAML)
--   * a second copy of all of this for dev vs. prod   (dbt: --target dev / prod)
--
-- Tasks are created suspended. Run the graph once with:
--   ALTER TASK SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.T_DAILY_SALES RESUME;
--   ALTER TASK SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.T_CHECK_DAILY_SALES RESUME;
--   EXECUTE TASK SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.T_STG_ORDERS;
-- then suspend the two child tasks again.

create schema if not exists SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY;

-- Step 1 (root): clean and deduplicate the raw orders.
create or alter task SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.T_STG_ORDERS
  warehouse = COMPUTE_WH
  schedule = 'USING CRON 0 9 * * * UTC'
as
  create or replace table SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.STG_ORDERS as
  select
      order_id,
      upper(trim(client_id)) as client_id,
      order_date,
      amount,
      lower(trim(status)) as status
  from SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.ORDERS
  qualify row_number() over (partition by order_id order by loaded_at desc) = 1;

-- Step 2: apply the business rule and aggregate. The order is wired by hand.
create or alter task SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.T_DAILY_SALES
  warehouse = COMPUTE_WH
  after SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.T_STG_ORDERS
as
  create or replace table SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.CLIENT_DAILY_SALES as
  select
      o.client_id,
      case c.region_code when 'WEST' then 'West' when 'EAST' then 'East' end as region_name,
      o.order_date,
      sum(iff(o.status = 'completed', 1, 0)) as order_count,
      sum(iff(o.status = 'completed', o.amount, 0)) as gross_sales,
      sum(iff(o.status = 'refunded', o.amount, 0)) as refund_amount,
      sum(iff(o.status = 'completed', o.amount, 0)) - sum(iff(o.status = 'refunded', o.amount, 0)) as net_sales
  from SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.STG_ORDERS o
  left join SYNTHETIC_DBT_DAILY_SALES_DEMO.RAW.CLIENTS c
      on o.client_id = c.client_id
  where o.status in ('completed', 'refunded')
  group by o.client_id, region_name, o.order_date;

-- Step 3: a data check, written as procedural code. Fails the task if any
-- client/day appears twice. The block is wrapped in EXECUTE IMMEDIATE $$ ... $$
-- so it also runs from the Snowflake CLI, which doesn't parse scripting blocks.
create or alter task SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.T_CHECK_DAILY_SALES
  warehouse = COMPUTE_WH
  after SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.T_DAILY_SALES
as
  execute immediate $$
  declare
    duplicate_keys exception (-20001, 'CLIENT_DAILY_SALES has duplicate client/day rows');
    dupes integer;
  begin
    dupes := (select count(*) from (
                select client_id, order_date
                from SYNTHETIC_DBT_DAILY_SALES_DEMO.TASKS_ONLY.CLIENT_DAILY_SALES
                group by client_id, order_date
                having count(*) > 1));
    if (dupes > 0) then
      raise duplicate_keys;
    end if;
  end;
  $$;
