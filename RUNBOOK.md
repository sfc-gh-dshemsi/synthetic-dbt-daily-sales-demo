# Presenter runbook (30 minutes)

A generic demo with fictional data. Verify the lab connection before running anything in `README.md`. Before the session: rerun `build --target dev` once so the workspace shows a fresh run, and confirm the Git workspace opens. If you've already run `setup/client_tier_change.sql` in this lab, the snapshot already shows the change; walk through the result instead of rerunning it.

## Open (0-3 min)

"Today I want to show you how dbt works in practice, with a small example. It's fake order data, six orders and two clients, so we can follow every number. Stop me anytime."

Ask what the audience most wants to see before you share your screen.

## Layers and the DAG (3-9 min)

1. Open the `models/` folders top to bottom: `staging/`, `intermediate/`, `marts/`. "Raw data comes in at the top. Each layer does one job. What your BI tool reads is at the bottom."
2. Open `stg_shop__orders.sql`, then `int_orders_enriched.sql`, then `fct_client_daily_sales.sql`. Point at `source()` and `ref()`. "That's how dbt knows the order. I don't write the dependencies anywhere else."
3. Run **Compile**, open the DAG tab, then **View Compiled SQL** on `fct_client_daily_sales`. "The intermediate model is ephemeral, so dbt pastes it in as a CTE. This is the actual SQL Snowflake runs."

## Build and tests (9-14 min)

1. Run **Build** on `dev`. Show the summary: the seed loads, the snapshot runs, models build, tests pass.
2. Open `_shop__models.yml`. "`unique`, `not_null`, a relationship check, and our own test that amounts are positive. Each one is just a query that should return nothing."
3. Planned failure: run `test --select demo_order_amount_cap --vars '{show_failing_test: true}'`. It fails on two orders over 50. "Good. That's what we want a test to do." Raise `max_order_amount` in `dbt_project.yml`, rerun, it passes.

## Rerun one slice (14-19 min)

1. Run `setup/new_orders.sql`. One new order for CLIENT_B on October 4.
2. Run `fct_client_daily_sales_incremental` with `--vars '{client_id: CLIENT_B, start_date: 2026-10-04, end_date: 2026-10-04}'`.
3. "dbt deletes just that client and day, then inserts the new numbers. Same idea as a scoped delete and insert, but declared in the model."
4. Mention the limit: a key that disappears inside the slice isn't deleted. A real job needs that decided up front.

## Keep history with a snapshot (19-23 min)

1. Open `snapshots/hist_clients.sql`. "When a client's tier changes, the raw table just overwrites it. The snapshot remembers what it used to be."
2. Run `setup/client_tier_change.sql`, then `snapshot`. Query `DEV_HISTORY.HIST_CLIENTS`.
3. Point at CLIENT_B's two rows. "Standard until October 15, gold since. You get that without writing the history logic yourself."

## Dev, prod, and scheduling (23-27 min)

1. Open `dbt_projects_profiles.yml` and `macros/generate_schema_name.sql`. "Same code, two targets. Dev lands in DEV_MARTS, prod in MARTS."
2. Open `setup/schedule_tasks.sql`. "dbt says what runs. The task says when. Here it's 9 AM UTC every day, and a second task reruns one slice after it."
3. Tasks stay suspended. Only resume them if you want them to fire.

## Close (27-30 min)

"Which one of your transformations should we try this on? Let's pick one, write down what goes in, what comes out, and what a rerun has to do safely."

Agree on one job, an owner, and a date. Don't imply this example tested any real pipeline.

## Fallback

If the UI or network fails, show the files and the recorded results in `README.md` ("Verified in the lab"), and say they're recorded, not live. The DAG view and workspace OAuth sign-in weren't part of those checks.
