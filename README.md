# Synthetic daily sales: a small dbt project

A self-contained, SQL-only demonstration of dbt Projects on Snowflake, laid out the way a real project is: staging, intermediate, and mart layers, plus a snapshot, a seed, a macro, and custom tests. Six invented orders and two clients become daily client totals, built three ways (table, incremental, dynamic table) and checked by tests. All rows and client labels are fictional; no real organization, customer records, customer SQL, personal contact details, or credentials are included. No external dbt packages are needed, so no external access integration is required.

## Project layout

```text
models/
  staging/shop/            stg_  thin typed views, one per raw table
    _shop__sources.yml       RAW.ORDERS and RAW.CLIENTS
    _shop__models.yml        tests and descriptions
    stg_shop__orders.sql
    stg_shop__clients.sql
  intermediate/            int_  shared business logic (ephemeral)
    int_orders_enriched.sql  orders + client + region
  marts/sales/             fct_ / dim_  business-ready tables for BI
    _sales__models.yml
    dim_client.sql
    fct_client_daily_sales.sql
    fct_client_daily_sales_incremental.sql
    fct_client_daily_sales_dt.sql
snapshots/
  hist_clients.sql         hist_  SCD Type 2 history of client tiers
macros/
  generate_schema_name.sql routes layer schemas per target
tests/
  generic/assert_positive_value.sql   custom generic test
  expected_daily_sales.sql            exact-result test
  demo_order_amount_cap.sql           planned failing test (off by default)
seeds/
  regions.csv              static lookup: region_code -> region_name
setup/                     raw data, demo changes, and task SQL
```

## What it teaches

| Concept | Where |
| --- | --- |
| Sources, `source()` and `ref()` (the DAG) | `models/staging/shop/` → `models/intermediate/` → `models/marts/sales/` |
| Layers: staging, intermediate, marts (`stg_`, `int_`, `fct_`, `dim_`) | `models/` folders, `dbt_project.yml` |
| Materializations: view, ephemeral, table, incremental, dynamic table | `dbt_project.yml`, model `config()` blocks |
| Incremental model: rerun one client/date slice with delete+insert | `fct_client_daily_sales_incremental.sql`, `setup/new_orders.sql` |
| Runtime inputs with `--vars` | `client_id`, `start_date`, `end_date` in `dbt_project.yml` |
| Snapshot (SCD Type 2): keep history of changed rows | `snapshots/hist_clients.sql`, `setup/client_tier_change.sql` |
| Seed: small reference CSV loaded as a table | `seeds/regions.csv` |
| Macro: per-environment schema names | `macros/generate_schema_name.sql` |
| Tests: built-in, `relationships`, `accepted_values`, custom generic, exact-result | `_shop__models.yml`, `_sales__models.yml`, `tests/` |
| A planned failing test you fix live | `tests/demo_order_amount_cap.sql` |
| Dev and prod targets | `dbt_projects_profiles.yml` |
| Scheduling with tasks: dbt defines what runs, the task decides when | `setup/schedule_tasks.sql` |

## Data flow

```text
RAW.ORDERS (6 rows, +1 from setup/new_orders.sql)    RAW.CLIENTS (2 rows)    seeds/regions.csv
        |                                                 |       |                  |
  stg_shop__orders                              stg_shop__clients |               regions
        \_________________ int_orders_enriched ______/    |       |__________________|
                         /        |          \             dim_client      hist_clients (snapshot)
  fct_client_daily_sales   ..._incremental   ..._dt
```

## Where objects land

`macros/generate_schema_name.sql` overrides dbt's default schema naming:

| Layer | `--target dev` | `--target prod` |
| --- | --- | --- |
| staging views, seed | `DEV_STAGING` | `STAGING` |
| marts | `DEV_MARTS` | `MARTS` |
| snapshot | `DEV_HISTORY` | `HISTORY` |

This project uses one database, so only schemas are routed. A project with separate databases per environment (for example `DEV_SILVER_DB` and `PROD_SILVER_DB`) adds a `generate_database_name` macro the same way.

Expected `fct_client_daily_sales` rows for the original six orders:

| Client | Order date | Orders | Sales amount |
| --- | --- | ---: | ---: |
| CLIENT_A | 2026-10-01 | 2 | 30.00 |
| CLIENT_A | 2026-10-02 | 1 | 7.00 |
| CLIENT_A | 2026-10-03 | 1 | 99.00 |
| CLIENT_B | 2026-10-01 | 1 | 40.00 |
| CLIENT_B | 2026-10-02 | 1 | 60.00 |

## Lab settings

The profile targets database `SYNTHETIC_DBT_DAILY_SALES_DEMO` with target schemas `DEV` and `PROD` (layer schemas are derived from these), the `COMPUTE_WH` warehouse, and the `ACCOUNTADMIN` role. These are lab settings, **not** production recommendations. Commands below use a Snowflake CLI connection named `default`; confirm it points to the lab you intend to modify. To use another lab, change the role, warehouse, and database consistently in `dbt_projects_profiles.yml`, `models/staging/shop/_shop__sources.yml`, `models/marts/sales/fct_client_daily_sales_dt.sql`, and the `setup/` scripts.

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
3. Run `setup/synthetic_orders.sql`, then `setup/synthetic_clients.sql`, once from the workspace.
4. From the dbt toolbar, pick profile `dev`, then run **Compile** (view the DAG and compiled SQL), **Build**, and **Test**. `build` also loads the seed and runs the snapshot.
5. **Connect » Deploy dbt project** to schema `PROD` as `SYNTHETIC_DBT_PROJECT`, then run `setup/schedule_tasks.sql` or create a schedule from the calendar icon.

## Option B: Snowflake CLI

```sh
snow sql -c default -q 'select current_account_name(), current_role(), current_warehouse()'
snow sql -c default -f setup/synthetic_orders.sql          # one time only
snow sql -c default -f setup/synthetic_clients.sql         # one time only
snow dbt deploy SYNTHETIC_DBT_PROJECT --source . --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD -c default
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT build --target dev
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT build --target prod
```

## Demo scenarios

**Incremental slice.** After the first build, add one order and rerun only that client and date:

```sh
snow sql -c default -f setup/new_orders.sql
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT \
  run --select fct_client_daily_sales_incremental --target dev \
  --vars '{client_id: CLIENT_B, start_date: 2026-10-04, end_date: 2026-10-04}'
```

dbt deletes only the `client_day_key` values in the slice, then inserts the recomputed rows. The slice run updates only the incremental model; `fct_client_daily_sales` catches up on the next `build`, and the dynamic table on its next refresh. A key that disappears from the source inside the slice is not deleted; handle that case explicitly if a job needs it.

**Planned failing test.** The test is disabled by default so scheduled builds stay green.

```sh
# Fails: orders A4 (99.00) and B2 (60.00) exceed the cap of 50
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT test --select demo_order_amount_cap --target dev --vars '{show_failing_test: true}'
# Fix: pass a higher cap, or raise max_order_amount in dbt_project.yml and redeploy, then rerun
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT test --select demo_order_amount_cap --target dev --vars '{show_failing_test: true, max_order_amount: 1000}'
```

**Snapshot.** `build` (or `snapshot`) records each client's current tier in `hist_clients`. Change CLIENT_B's tier, then run the snapshot again:

```sh
snow sql -c default -f setup/client_tier_change.sql
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT snapshot --target dev
snow sql -c default -q 'select client_id, tier, dbt_valid_from, dbt_valid_to from SYNTHETIC_DBT_DAILY_SALES_DEMO.DEV_HISTORY.HIST_CLIENTS order by client_id, dbt_valid_from'
```

CLIENT_B now has two rows: `standard` closed on 2026-10-15 (`dbt_valid_to`) and a current `gold` row. `dim_client` shows only the current tier after its next build; the snapshot keeps the history.

**Dynamic table.** `fct_client_daily_sales_dt` refreshes on Snowflake's schedule (`target_lag = '1 day'`), not when dbt runs. Right after `setup/new_orders.sql`, it still shows the earlier rows until it refreshes. Snowflake's docs list dbt-snowflake adapter v1.11.5 or later for the option to omit `target_lag`, so that dbt triggers the refresh on each run ([Use dynamic tables in dbt](https://docs.snowflake.com/en/user-guide/dynamic-tables/dbt)). This project runs on dbt 1.9.4, so it sets `target_lag`.

**Scheduling.** `setup/schedule_tasks.sql` creates a daily 09:00 UTC `build --target prod` task and a child task that reruns one slice. Both are created suspended. Tasks must be in the same schema as the dbt project object and need a warehouse.

## Verified in the lab

On November 9, 2026, in a separate lab account, on dbt 1.9.4:

- `build --target dev` and `build --target prod` with the layered layout (seed, snapshot, models, and tests), with `--full-refresh`: `PASS=34 WARN=0 ERROR=0 SKIP=0 TOTAL=34` each; objects landed in `DEV_STAGING`/`DEV_MARTS`/`DEV_HISTORY` and `STAGING`/`MARTS`/`HISTORY`.
- Snapshot after `setup/client_tier_change.sql`: `SUCCESS 2`; CLIENT_B had a closed `standard` row (`dbt_valid_to` 2026-10-15) and a current `gold` row.
- Earlier, with the flat layout (before the folders were added):
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
