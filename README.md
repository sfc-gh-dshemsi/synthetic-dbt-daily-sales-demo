# Synthetic daily sales: a small dbt project

A self-contained, SQL-only demonstration of dbt Projects on Snowflake. Six invented orders become daily client totals, built three ways (table, incremental, dynamic table) and checked by tests. All rows and client labels are fictional; no real organization, customer records, customer SQL, personal contact details, or credentials are included. No external dbt packages are needed, so no external access integration is required.

## What it teaches

| Concept | Where |
| --- | --- |
| `source()` and `ref()` dependencies (the DAG) | `models/stg_orders.sql` → `models/client_daily_sales.sql` |
| View vs. table materialization | `dbt_project.yml` |
| Incremental model: rerun one client/date slice with delete+insert | `models/client_daily_sales_incremental.sql`, `setup/new_orders.sql` |
| Runtime inputs with `--vars` | `client_id`, `start_date`, `end_date` in `dbt_project.yml` |
| Dynamic table that Snowflake refreshes on its own | `models/client_daily_sales_dt.sql` |
| Built-in column tests and an exact-result test | `models/sources.yml`, `tests/expected_daily_sales.sql` |
| A planned failing test you fix live | `tests/demo_order_amount_cap.sql` |
| Dev and prod targets | `dbt_projects_profiles.yml` |
| Scheduling with tasks: dbt defines what runs, the task decides when | `setup/schedule_tasks.sql` |

## Data flow

```text
RAW.ORDERS (6 synthetic rows, +1 later order from setup/new_orders.sql)
  -> stg_orders (typed view)
    -> client_daily_sales              (table, full rebuild each run)
    -> client_daily_sales_incremental  (incremental, delete+insert on client_day_key)
    -> client_daily_sales_dt           (dynamic table, target_lag = 1 day)
```

Expected `client_daily_sales` rows for the original six orders:

| Client | Order date | Orders | Sales amount |
| --- | --- | ---: | ---: |
| CLIENT_A | 2026-10-01 | 2 | 30.00 |
| CLIENT_A | 2026-10-02 | 1 | 7.00 |
| CLIENT_A | 2026-10-03 | 1 | 99.00 |
| CLIENT_B | 2026-10-01 | 1 | 40.00 |
| CLIENT_B | 2026-10-02 | 1 | 60.00 |

## Lab settings

The profile targets database `SYNTHETIC_DBT_DAILY_SALES_DEMO` with schemas `DEV` and `PROD`, the `COMPUTE_WH` warehouse, and the `ACCOUNTADMIN` role. These are lab settings, **not** production recommendations. Commands below use a Snowflake CLI connection named `default`; confirm it points to the lab you intend to modify. To use another lab, change the role, warehouse, and database consistently in `dbt_projects_profiles.yml`, `models/sources.yml`, `models/client_daily_sales_dt.sql`, and the `setup/` scripts.

## Option A: Git workspace in Snowsight (recommended for demos)

1. One-time, as an admin, create an API integration that uses the Snowflake GitHub App (OAuth). Scope the prefix to this repository:

   ```sql
   CREATE API INTEGRATION DBT_DEMO_GITHUB_APP
     API_PROVIDER = git_https_api
     API_ALLOWED_PREFIXES = ('https://github.com/<owner>/synthetic-dbt-daily-sales-demo')
     API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
     ENABLED = TRUE;
   ```

2. In Snowsight, go to **Projects » Workspaces » From Git repository**. Enter the repository URL, select `DBT_DEMO_GITHUB_APP`, choose OAuth, and sign in with GitHub. Workspaces can't commit and push to a public repository, so to commit from a workspace, copy this repository into a private repository of your own and point the workspace there.
3. Run `setup/synthetic_orders.sql` once from the workspace.
4. From the dbt toolbar, pick profile `dev`, then run **Compile** (view the DAG and compiled SQL), **Build**, and **Test**.
5. **Connect » Deploy dbt project** to schema `PROD` as `SYNTHETIC_DBT_PROJECT`, then run `setup/schedule_tasks.sql` or create a schedule from the calendar icon.

## Option B: Snowflake CLI

```sh
snow sql -c default -q 'select current_account_name(), current_role(), current_warehouse()'
snow sql -c default -f setup/synthetic_orders.sql          # one time only
snow dbt deploy SYNTHETIC_DBT_PROJECT --source . --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD -c default
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT build --target dev
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT build --target prod
```

## Demo scenarios

**Incremental slice.** After the first build, add one order and rerun only that client and date:

```sh
snow sql -c default -f setup/new_orders.sql
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT \
  run --select client_daily_sales_incremental --target dev \
  --vars '{client_id: CLIENT_B, start_date: 2026-10-04, end_date: 2026-10-04}'
```

dbt deletes only the `client_day_key` values in the slice, then inserts the recomputed rows. The slice run updates only the incremental model; `client_daily_sales` catches up on the next `build`, and the dynamic table on its next refresh. A key that disappears from the source inside the slice is not deleted; handle that case explicitly if a job needs it.

**Planned failing test.** The test is disabled by default so scheduled builds stay green.

```sh
# Fails: orders A4 (99.00) and B2 (60.00) exceed the cap of 50
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT test --select demo_order_amount_cap --target dev --vars '{show_failing_test: true}'
# Fix: pass a higher cap, or raise max_order_amount in dbt_project.yml and redeploy, then rerun
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT test --select demo_order_amount_cap --target dev --vars '{show_failing_test: true, max_order_amount: 1000}'
```

**Dynamic table.** `client_daily_sales_dt` refreshes on Snowflake's schedule (`target_lag = '1 day'`), not when dbt runs. Right after `setup/new_orders.sql`, it still shows the earlier rows until it refreshes. dbt 1.9.4 and 1.10.15 require `target_lag`; on 1.11.11 and later you can omit it so the table refreshes only when dbt runs.

**Scheduling.** `setup/schedule_tasks.sql` creates a daily 09:00 UTC `build --target prod` task and a child task that reruns one slice. Both are created suspended. Tasks must be in the same schema as the dbt project object and need a warehouse.

## Verified in the lab

On November 9, 2026, in a separate lab account, on dbt 1.9.4:

- `build --target dev` and `build --target prod`: `PASS=19 WARN=0 ERROR=0 SKIP=0 TOTAL=19` each.
- Incremental slice rerun: `PASS=1`; the CLIENT_B 2026-10-04 row (25.00) was added; the generated `DELETE` filtered on keys from the slice.
- Planned failing test: disabled by default ("does not match any enabled nodes"); enabled with cap 50 it failed with 2 results; with cap 1000 it passed.
- Task graph run once with `EXECUTE TASK`: `DBT_DAILY_BUILD` and `DBT_SLICE_RERUN` both `SUCCEEDED`; both left suspended.

The Snowsight DAG view, the workspace OAuth sign-in, and workspace deploy were not exercised by these checks. `RUNBOOK.md` has a 30-minute presenter walkthrough.

## Repository owner

- **Owner:** Dureti Shemsi (dureti.shemsi@snowflake.com / [@sfc-gh-dshemsi](https://github.com/sfc-gh-dshemsi))
- **Access requests and questions:** email the owner or open an issue
- **License:** Apache-2.0 (see `LICENSE`)

This is a sample for learning, not a supported Snowflake product.

## References

- [dbt Projects on Snowflake overview](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake)
- [Getting-started tutorial](https://docs.snowflake.com/en/user-guide/tutorials/dbt-projects-on-snowflake-getting-started-tutorial)
- [Connect to a Git repository (OAuth with the Snowflake GitHub App)](https://docs.snowflake.com/en/developer-guide/git/git-setting-up-public)
- [Schedule execution of dbt project objects](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-schedule-project-execution)
- [Understand orchestration](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-orchestration)
- [Best practices](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-best-practices)
