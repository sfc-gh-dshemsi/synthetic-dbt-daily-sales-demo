# build_steps: grow the dbt project one file at a time

You start with an **empty** `sales_dbt/` folder in your workspace and copy each file below into it,
in this order. After each step there's something to run, so you see the project grow.

| Step | Copy | Into | Then run |
|---|---|---|---|
| 01 | `01_project/dbt_project.yml`, `dbt_projects_profiles.yml` | `sales_dbt/` | `compile` (the project is valid, it just has nothing in it yet) |
| 02 | `02_sources/_sources.yml` | `sales_dbt/models/staging/` | nothing yet, sources are just pointers |
| 03 | `03_staging/stg_*.sql` (2 files) | `sales_dbt/models/staging/` | `run`: two views appear in `SALES_DBT_DB.DEV`; 9 raw orders become 8 |
| 04 | `04_seed/regions.csv` | `sales_dbt/seeds/` | `seed`: a table from a CSV |
| 05 | `05_intermediate/int_orders_enriched.sql` | `sales_dbt/models/intermediate/` | `run`, then open the lineage (DAG) view |
| 06 | `06_mart/fct_client_daily_sales.sql` | `sales_dbt/models/marts/` | `run`: the table the dashboard reads |
| 07 | `07_incremental/fct_client_daily_sales_incremental.sql` | `sales_dbt/models/marts/` | `run`, then `../01_rerun_one_slice.sql` |
| 08 | `08_tests/_staging.yml` → `models/staging/`; `_marts.yml` → `models/marts/`; `assert_amount_positive.sql`, `expected_daily_sales.sql` → `sales_dbt/tests/` | | `build`: every model and every test, in order |

Each `.sql` and `.yml` file starts with a `goes to:` line, so you always know where it belongs.

Want to skip ahead? `../finished/sales_dbt/` has every file already in place.
