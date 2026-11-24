# dbt Projects on Snowflake: Daily Sales Demo

A small, SQL-only dbt project that runs entirely in Snowflake. It turns a messy raw order
extract into clean daily net sales per client, tests it, reruns one client/day slice on
demand, and schedules it with a task.

All data is synthetic. No packages, external access, or credentials are required.

## What's in here

| File | What it's for |
|---|---|
| `00_setup.sql` | Warehouse, database, and two messy raw tables. Rerun any time to reset RAW. |
| `build_steps/` | The dbt project, one file per step. Copy them into an empty workspace folder in order. |
| `finished/sales_dbt/` | The complete project, if you want to skip ahead. |
| `01_rerun_one_slice.sql` | New orders arrive; rerun one client and one day with `--vars`. |
| `02_deploy_and_schedule.sql` | Deploy to prod, run it, schedule it at a fixed time. |
| `03_bad_data_run_vs_build.sql` | Why `build` beats `run` then `test`: bad data never reaches the dashboard. |
| `04_cleanup.sql` | Drops everything this demo created. |

## The data, and what each layer does

| Layer | Object | Job | Visible change |
|---|---|---|---|
| Raw | `RAW.ORDERS` | as received | 9 rows: A2 loaded twice, mixed casing, a cancelled order, a refund. Naive total 281.00 |
| Staging | `stg_orders`, `stg_clients` (views) | trim, normalize case, keep latest load | 8 rows |
| Intermediate | `int_orders_enriched` (view) | the business rule: completed counts, cancelled doesn't, refunds subtract | one definition of "a sale" |
| Mart | `fct_client_daily_sales` (table) | one row per client per day | net total 226.00 |
| Mart | `fct_client_daily_sales_incremental` | same numbers, rebuilt one client/date slice at a time | delete + insert, like a parameterized procedure |

## Run it

Prerequisites: a lab account where you can use `ACCOUNTADMIN` once (to grant EXECUTE TASK to `SYSADMIN`)
and `SYSADMIN` for everything else.

1. Run `00_setup.sql` in a Snowsight worksheet.
2. **Projects » Workspaces » From Git repository**, then create an empty `sales_dbt/` folder.
3. Follow `build_steps/README.md`, steps 01 to 08, with profile `dev`.
   Step 8 `build` should end with `PASS=20 WARN=0 ERROR=0`.
4. Run `01_rerun_one_slice.sql`, `02_deploy_and_schedule.sql`, then `03_bad_data_run_vs_build.sql`.
5. `04_cleanup.sql` when you're done.

dbt commands are picked in the workspace toolbar (Compile, Run, Test, Seed, Build). Flags such as
`--select` and `--vars` go in the box behind the down arrow next to the run button.

## Notes

- Tested end to end on November 24, 2026, including the scheduled task.
- `--vars` values are inserted into SQL text; use them only for trusted operator inputs.
- Tasks that run a dbt project need a user-managed warehouse. Keeping the task in the same schema as
  the project object is a best practice.
- This is a learning sample, not a supported Snowflake product.

Owner: Dureti Shemsi ([dureti.shemsi@snowflake.com](mailto:dureti.shemsi@snowflake.com), [@sfc-gh-dshemsi](https://github.com/sfc-gh-dshemsi)). Licensed under Apache-2.0.

References: [dbt Projects on Snowflake](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake) · [Getting-started tutorial](https://docs.snowflake.com/en/user-guide/tutorials/dbt-projects-on-snowflake-getting-started-tutorial) · [Schedule dbt project runs](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-schedule-project-execution)
