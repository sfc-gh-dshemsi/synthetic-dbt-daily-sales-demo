# dbt Projects on Snowflake: Synthetic Daily Sales Demo

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=flat&logo=snowflake&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-1.9.4-FF694B?style=flat&logo=dbt&logoColor=white)
![SQL only](https://img.shields.io/badge/SQL-only-informational?style=flat)
![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat)

A small, self-contained dbt project that runs entirely inside Snowflake. It turns six invented orders into daily client sales, and along the way shows the parts of dbt most teams need: layered models, tests, incremental reruns, snapshots, a dynamic table, dev and prod environments, and a scheduled task.

All data is synthetic. No external dbt packages, external access integration, or credentials are needed.

**Contents:** [Architecture](#architecture) · [What you'll learn](#what-youll-learn) · [Repository structure](#repository-structure) · [Prerequisites](#prerequisites) · [Install](#install) · [Scenarios](#scenarios) · [Suggested walkthrough](#suggested-walkthrough) · [Reset the lab](#reset-the-lab) · [Verification](#verification) · [Notes](#notes)

## Architecture

```mermaid
flowchart LR
    subgraph GIT["GitHub"]
        REPO["dbt project<br/>(this repo)"]
    end

    subgraph SF["Snowflake"]
        direction LR
        WS["Git workspace"]
        OBJ["dbt project object"]
        TASK["Task<br/>(daily 09:00 UTC)"]
        RAW[("RAW")]
        STG[("STAGING")]
        MARTS[("MARTS")]
        HIST[("HISTORY")]
    end

    BI["BI / SQL"]

    REPO -->|OAuth| WS
    WS -->|deploy| OBJ
    TASK -->|EXECUTE DBT PROJECT| OBJ
    RAW --> STG --> MARTS --> BI
    RAW --> HIST
    OBJ -.->|builds| STG
    OBJ -.->|builds| MARTS
    OBJ -.->|snapshots| HIST
```

| Component | Role |
| --- | --- |
| GitHub repository | Source of truth for models, tests, and configuration. |
| Git workspace | Browser IDE in Snowsight. Edit, compile, view the DAG, build, and deploy. |
| dbt project object | The deployed copy of the project that Snowflake runs. |
| Task | Schedules the project object. dbt defines **what** runs; the task decides **when**. |
| `RAW` | Synthetic source tables, created by the `setup/` scripts. |
| `STAGING`, `MARTS`, `HISTORY` | Layer schemas dbt builds into (prefixed `DEV_` for the dev target). |

### Model lineage

```mermaid
flowchart LR
    classDef source fill:#E8F1FB,stroke:#29B5E8,color:#11567F
    classDef staging fill:#FFF4E5,stroke:#F2A541,color:#7A4B00
    classDef inter fill:#F3EAFB,stroke:#9B59B6,color:#4A235A
    classDef mart fill:#E9F7EF,stroke:#27AE60,color:#145A32
    classDef hist fill:#FDEDEC,stroke:#E74C3C,color:#78281F

    O[("RAW.ORDERS")]:::source
    C[("RAW.CLIENTS")]:::source
    R["seed: regions"]:::staging
    SO["stg_shop__orders<br/>view"]:::staging
    SC["stg_shop__clients<br/>view"]:::staging
    I["int_orders_enriched<br/>ephemeral"]:::inter
    F1["fct_client_daily_sales<br/>table"]:::mart
    F2["fct_client_daily_sales_incremental<br/>incremental"]:::mart
    F3["fct_client_daily_sales_dt<br/>dynamic table"]:::mart
    D["dim_client<br/>table"]:::mart
    H["hist_clients<br/>snapshot"]:::hist

    O --> SO
    C --> SC
    C --> H
    SO --> I
    SC --> I
    R --> I
    SC --> D
    R --> D
    I --> F1
    I --> F2
    I --> F3
```

The three fact models compute the same result three ways so the materializations can be compared side by side. In a real project you'd choose one.

### Layers and environments

| Layer | Folder | Prefix | Materialization | `--target dev` | `--target prod` |
| --- | --- | --- | --- | --- | --- |
| Staging | `models/staging/shop/` | `stg_` | view | `DEV_STAGING` | `STAGING` |
| Intermediate | `models/intermediate/` | `int_` | ephemeral (inlined, not built) | — | — |
| Marts | `models/marts/sales/` | `fct_`, `dim_` | table | `DEV_MARTS` | `MARTS` |
| Snapshots | `snapshots/` | `hist_` | snapshot | `DEV_HISTORY` | `HISTORY` |
| Seeds | `seeds/` | — | table | `DEV_STAGING` | `STAGING` |

`macros/generate_schema_name.sql` routes each layer to its schema per target, so dev never writes into prod. This project uses one database; a project with separate databases per environment adds a `generate_database_name` macro the same way.

## What you'll learn

| Concept | Where to look |
| --- | --- |
| Sources, `source()`, `ref()`, and the DAG | `models/staging/shop/` → `models/intermediate/` → `models/marts/sales/` |
| Staging, intermediate, and mart layers | `models/` |
| Materializations: view, ephemeral, table, incremental, dynamic table | `dbt_project.yml`, model `config()` blocks |
| Rerun one client and date with delete+insert and `--vars` | `fct_client_daily_sales_incremental.sql` |
| Snapshot (SCD Type 2) history of a changing attribute | `snapshots/hist_clients.sql` |
| Seed: reference data from CSV | `seeds/regions.csv` |
| Macro: per-environment schema names | `macros/generate_schema_name.sql` |
| Tests: built-in, relationships, accepted values, custom generic, exact result | `_shop__models.yml`, `_sales__models.yml`, `tests/` |
| A planned failing test to fix live | `tests/demo_order_amount_cap.sql` |
| Dev and prod targets from one codebase | `dbt_projects_profiles.yml` |
| Scheduling with tasks | `setup/schedule_tasks.sql` |

## Repository structure

```text
.
├── dbt_project.yml               Project config: layers, schemas, vars
├── dbt_projects_profiles.yml     dev and prod targets for dbt Projects on Snowflake
├── models/
│   ├── staging/shop/             stg_  typed views, one per source table
│   ├── intermediate/             int_  shared logic (ephemeral)
│   └── marts/sales/              fct_ / dim_  business-ready tables
├── snapshots/                    hist_ SCD Type 2 history
├── seeds/                        Static reference data
├── macros/                       generate_schema_name (environment routing)
├── tests/
│   ├── generic/                  Custom generic tests
│   └── *.sql                     Singular tests
└── setup/                        Source data, demo changes, task SQL
```

## Prerequisites

| Requirement | Used for |
| --- | --- |
| A Snowflake **lab** account (not production) | Everything. The setup scripts create a database. |
| A role that can create a database, schemas, tables, a dbt project object, and tasks | The sample profile uses `ACCOUNTADMIN` for simplicity; use a narrower role outside a lab. |
| A warehouse named `COMPUTE_WH` | Builds and task runs. |
| Snowflake CLI with a connection (examples use `-c default`) | CLI install. Confirm the connection points to your lab. |
| GitHub account | Git workspace install. |

To use different object names, change them consistently in `dbt_projects_profiles.yml`, `models/staging/shop/_shop__sources.yml`, `models/marts/sales/fct_client_daily_sales_dt.sql`, and the `setup/` scripts.

## Install

### Option A: Git workspace in Snowsight

1. **Create an API integration (one time, admin).** It uses the Snowflake GitHub App for OAuth. Scope the prefix to your copy of the repository:

   ```sql
   CREATE API INTEGRATION DBT_DEMO_GITHUB_APP
     API_PROVIDER = git_https_api
     API_ALLOWED_PREFIXES = ('https://github.com/<owner>/synthetic-dbt-daily-sales-demo')
     API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
     ENABLED = TRUE;
   ```

2. **Create the workspace.** In Snowsight, go to **Projects » Workspaces » From Git repository**. Enter the repository URL, select `DBT_DEMO_GITHUB_APP`, choose OAuth, and sign in with GitHub.

   > Workspaces can't commit and push to a public repository. To commit from a workspace, copy this repository into a private repository of your own and connect the workspace to that.

3. **Create the source data.** Run `setup/synthetic_orders.sql`, then `setup/synthetic_clients.sql`, once.
4. **Build.** From the dbt toolbar, choose profile `dev`, run **Compile** to view the DAG and compiled SQL, then **Build**. `build` also loads the seed, runs the snapshot, and runs every test.
5. **Deploy.** Use **Connect » Deploy dbt project** to deploy to schema `PROD` as `SYNTHETIC_DBT_PROJECT`.

### Option B: Snowflake CLI

```sh
# Confirm you're pointed at the lab
snow sql -c default -q 'select current_account_name(), current_role(), current_warehouse()'

# One-time source data
snow sql -c default -f setup/synthetic_orders.sql
snow sql -c default -f setup/synthetic_clients.sql

# Deploy and build
snow dbt deploy SYNTHETIC_DBT_PROJECT --source . \
  --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD -c default
snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD \
  SYNTHETIC_DBT_PROJECT build --target dev
```

Expected `DEV_MARTS.FCT_CLIENT_DAILY_SALES` after the first build:

| Client | Order date | Orders | Sales amount |
| --- | --- | ---: | ---: |
| CLIENT_A | 2026-10-01 | 2 | 30.00 |
| CLIENT_A | 2026-10-02 | 1 | 7.00 |
| CLIENT_A | 2026-10-03 | 1 | 99.00 |
| CLIENT_B | 2026-10-01 | 1 | 40.00 |
| CLIENT_B | 2026-10-02 | 1 | 60.00 |

## Scenarios

The CLI commands share a long prefix. Define this shell function once (works in bash and zsh):

```sh
demo_dbt() { snow dbt execute -c default --database SYNTHETIC_DBT_DAILY_SALES_DEMO --schema PROD SYNTHETIC_DBT_PROJECT "$@"; }
```

### 1. A test that fails, then passes

`tests/demo_order_amount_cap.sql` is disabled by default so scheduled builds stay green.

```sh
demo_dbt test --select demo_order_amount_cap --target dev --vars '{show_failing_test: true}'
# Fails: orders A4 (99.00) and B2 (60.00) exceed the cap of 50

demo_dbt test --select demo_order_amount_cap --target dev --vars '{show_failing_test: true, max_order_amount: 1000}'
# Passes
```

In a workspace, you can instead raise `max_order_amount` in `dbt_project.yml` and rerun.

### 2. Rerun one client and date (incremental)

```sh
snow sql -c default -f setup/new_orders.sql      # adds order B3: CLIENT_B, 2026-10-04
demo_dbt run --select fct_client_daily_sales_incremental --target dev \
  --vars '{client_id: CLIENT_B, start_date: 2026-10-04, end_date: 2026-10-04}'
```

dbt deletes only the `client_day_key` values in the slice, then inserts the recomputed rows. Only the incremental model changes; `fct_client_daily_sales` catches up on the next `build`, and the dynamic table on its next refresh. A key that disappears from the source inside the slice is not deleted, so decide how a real job should handle that.

> ⚠️ Run `setup/new_orders.sql` only once per lab. A second run inserts a duplicate `order_id`, and the `unique` test fails. [Reset the lab](#reset-the-lab) to run it again.

### 3. Keep history with a snapshot

```sh
snow sql -c default -f setup/client_tier_change.sql   # CLIENT_B: standard -> gold
demo_dbt snapshot --target dev
snow sql -c default -q "select client_id, tier, dbt_valid_from, dbt_valid_to
  from SYNTHETIC_DBT_DAILY_SALES_DEMO.DEV_HISTORY.HIST_CLIENTS order by client_id, dbt_valid_from"
```

| Client | Tier | Valid from | Valid to |
| --- | --- | --- | --- |
| CLIENT_A | standard | 2026-09-01 | — |
| CLIENT_B | standard | 2026-09-01 | 2026-10-15 |
| CLIENT_B | gold | 2026-10-15 | — |

`dim_client` shows only the current tier after its next build; the snapshot keeps the history.

### 4. Dynamic table vs. dbt-run table

`fct_client_daily_sales_dt` is refreshed by Snowflake on its `target_lag` (1 day), not when dbt runs, so right after scenario 2 it still shows the earlier rows. Snowflake's documentation lists dbt-snowflake adapter v1.11.5 or later for omitting `target_lag` so that dbt triggers the refresh instead ([Use dynamic tables in dbt](https://docs.snowflake.com/en/user-guide/dynamic-tables/dbt)). This project runs on dbt 1.9.4, so it sets `target_lag`.

### 5. Build prod and schedule it

```sh
demo_dbt build --target prod
snow sql -c default -f setup/schedule_tasks.sql
```

```mermaid
sequenceDiagram
    autonumber
    participant T1 as DBT_DAILY_BUILD (09:00 UTC)
    participant T2 as DBT_SLICE_RERUN (after root)
    participant P as dbt project object
    participant S as Snowflake schemas

    T1->>P: EXECUTE DBT PROJECT build --target prod
    P->>S: seed, snapshot, models, tests
    T1-->>T2: on success
    T2->>P: EXECUTE DBT PROJECT run --select fct_client_daily_sales_incremental
    P->>S: delete + insert one client/date slice
```

Both tasks are created **suspended**. Tasks must be in the same database and schema as the dbt project object and use a user-managed warehouse. To run the graph once without enabling the schedule:

```sql
ALTER TASK SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.DBT_SLICE_RERUN RESUME;
EXECUTE TASK SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.DBT_DAILY_BUILD;
-- after it finishes
ALTER TASK SYNTHETIC_DBT_DAILY_SALES_DEMO.PROD.DBT_SLICE_RERUN SUSPEND;
```

## Suggested walkthrough

A 30-minute order for presenting the project:

| Time | Segment | Show |
| --- | --- | --- |
| 0–3 | Overview | The architecture diagram and what the six orders become |
| 3–9 | Layers and the DAG | `models/` folders, `source()` / `ref()`, **Compile**, DAG tab, compiled SQL |
| 9–14 | Build and tests | **Build** on dev, test YAML, then scenario 1 |
| 14–19 | Incremental rerun | Scenario 2 |
| 19–23 | Snapshot | Scenario 3 |
| 23–27 | Environments and scheduling | `dbt_projects_profiles.yml`, the schema macro, scenario 5 |
| 27–30 | Close | Pick one real transformation to try next |

Before presenting, [reset the lab](#reset-the-lab) if earlier rehearsals changed the source data.

## Reset the lab

Scenarios 2 and 3 change the source data. To start over, drop the demo database and reinstall. This also removes the dbt project object and tasks.

```sql
DROP DATABASE IF EXISTS SYNTHETIC_DBT_DAILY_SALES_DEMO;
```

Then repeat [Option B](#option-b-snowflake-cli) from the setup scripts onward.

## Verification

Tested end to end on November 9, 2026, from a fresh clone of this repository into an empty lab database, on dbt 1.9.4:

| Step | Result |
| --- | --- |
| Setup scripts, deploy, `build --target dev` | `PASS=34 WARN=0 ERROR=0`; mart matched the expected rows above |
| Scenario 1: failing test | Disabled by default; failed with 2 results at cap 50; passed at cap 1000 |
| Scenario 2: incremental slice | CLIENT_B 2026-10-04 (25.00) added to the incremental model only |
| Scenario 3: snapshot | CLIENT_B `standard` closed at 2026-10-15; current `gold` row added |
| Scenario 5: `build --target prod` | `PASS=34 WARN=0 ERROR=0` |
| Scenario 5: task graph, run once | `DBT_DAILY_BUILD` and `DBT_SLICE_RERUN` both `SUCCEEDED`; left suspended |
| Reconciliation | Prod marts: 7 orders, 261.00, matching `RAW.ORDERS` |

Not covered by these checks: the Snowsight DAG view and the workspace OAuth sign-in.

## Notes

- The sample profile uses `ACCOUNTADMIN` and `COMPUTE_WH` for lab convenience. Use a least-privilege role and your own warehouse outside a lab.
- Incremental `--vars` values are inserted into SQL text. That's fine for trusted operator inputs like these, but don't use the pattern for values end users can type in.
- This is a learning sample, not a supported Snowflake product.

## Owner

Dureti Shemsi ([dureti.shemsi@snowflake.com](mailto:dureti.shemsi@snowflake.com), [@sfc-gh-dshemsi](https://github.com/sfc-gh-dshemsi)). For questions or access requests, email the owner or open an issue.

Licensed under [Apache-2.0](LICENSE).

## References

- [dbt Projects on Snowflake](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake)
- [Getting-started tutorial](https://docs.snowflake.com/en/user-guide/tutorials/dbt-projects-on-snowflake-getting-started-tutorial)
- [Best practices](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-best-practices)
- [Schedule execution of dbt project objects](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-schedule-project-execution)
- [Use dynamic tables in dbt](https://docs.snowflake.com/en/user-guide/dynamic-tables/dbt)
- [Connect to a Git repository](https://docs.snowflake.com/en/developer-guide/git/git-setting-up-public)
