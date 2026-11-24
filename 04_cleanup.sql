-- 04_cleanup.sql
USE ROLE SYSADMIN;
ALTER TASK IF EXISTS SALES_DBT_DB.PROD.DAILY_SALES_BUILD SUSPEND;
DROP DATABASE IF EXISTS SALES_DBT_DB;          -- also drops the DBT PROJECT object and the task
DROP WAREHOUSE IF EXISTS SALES_DBT_WH;
-- The workspace itself stays in Projects > Workspaces. Delete it there if you want.
