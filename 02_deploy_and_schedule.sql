-- =====================================================================
-- 02_deploy_and_schedule.sql
-- Run AFTER the whole project builds green on dev (step 8: build).
-- =====================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE SALES_DBT_WH;

-- 1. Check the dev build produced what we expect
SELECT * FROM SALES_DBT_DB.DEV.FCT_CLIENT_DAILY_SALES ORDER BY CLIENT_ID, ORDER_DATE;

-- 2. Deploy: turn the workspace files into a DBT PROJECT object.
--    In the workspace: Connect > Deploy dbt project
--      database SALES_DBT_DB, schema PROD, name SALES_DBT
--    The Output tab shows the exact CREATE DBT PROJECT it ran.
--    To ship a change later: Connect > Redeploy dbt project
--    (this updates the object's live version; it runs ALTER DBT PROJECT ... DEPLOY).
SHOW DBT PROJECTS IN SCHEMA SALES_DBT_DB.PROD;

-- 3. Run the deployed project against prod. Same SQL, different target.
EXECUTE DBT PROJECT SALES_DBT_DB.PROD.SALES_DBT ARGS = 'build --target prod';

SELECT * FROM SALES_DBT_DB.PROD.FCT_CLIENT_DAILY_SALES ORDER BY CLIENT_ID, ORDER_DATE;

-- 4. Schedule it: every day at 6:00 AM Eastern, at a fixed time.
--    Best practice: keep the task in the same database + schema as the dbt project object.
--    It must use a warehouse: serverless tasks can't run a dbt project.
CREATE OR REPLACE TASK SALES_DBT_DB.PROD.DAILY_SALES_BUILD
  WAREHOUSE = SALES_DBT_WH
  SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
AS
  EXECUTE DBT PROJECT SALES_DBT_DB.PROD.SALES_DBT ARGS = 'build --target prod';

-- A new task starts suspended. Run it once now without turning the schedule on:
EXECUTE TASK SALES_DBT_DB.PROD.DAILY_SALES_BUILD;

SELECT NAME, STATE, ERROR_MESSAGE, SCHEDULED_TIME, COMPLETED_TIME
FROM TABLE(SALES_DBT_DB.INFORMATION_SCHEMA.TASK_HISTORY(
  SCHEDULED_TIME_RANGE_START => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())))
ORDER BY SCHEDULED_TIME DESC;

-- To turn the daily schedule on for real:
--   ALTER TASK SALES_DBT_DB.PROD.DAILY_SALES_BUILD RESUME;
-- Run history + logs: Snowsight > Monitoring > dbt Projects (or the task's Run History tab)
