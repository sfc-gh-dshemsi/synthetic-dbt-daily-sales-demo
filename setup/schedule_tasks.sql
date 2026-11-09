-- Schedule the deployed project with tasks: dbt defines what runs, the task decides when.
-- Tasks must live in the same database and schema as the dbt project object,
-- and need a user-managed warehouse (serverless tasks can't run EXECUTE DBT PROJECT).
-- Tasks are created suspended. Resume them only when you want them to fire.

-- Daily build of the prod target at 09:00 UTC.
create or alter task SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.DBT_DAILY_BUILD
  warehouse = COMPUTE_WH
  schedule = 'USING CRON 0 9 * * * UTC'
as
  execute dbt project SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.SYNTHETIC_DBT_PROJECT
    args = 'build --target prod';

-- Child task: rerun one client/date slice of the incremental model after the build.
create or alter task SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.DBT_SLICE_RERUN
  warehouse = COMPUTE_WH
  after SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.DBT_DAILY_BUILD
as
  execute dbt project SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.SYNTHETIC_DBT_PROJECT
    args = 'run --select client_daily_sales_incremental --target prod --vars "{client_id: CLIENT_B, start_date: 2026-10-04, end_date: 2026-10-04}"';

-- Run the graph once on demand, without resuming the schedule:
--   alter task SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.DBT_SLICE_RERUN resume;
--   execute task SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.DBT_DAILY_BUILD;
-- Resume order for a live schedule is child first, then root.
