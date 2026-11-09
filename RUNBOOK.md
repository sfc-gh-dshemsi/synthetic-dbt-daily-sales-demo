# Presenter runbook (30 minutes)

A generic demo with fictional data. Verify the lab connection before running anything in `README.md`. Before the session: rerun `build --target dev` once so the workspace shows a fresh run, and confirm the Git workspace opens.

## Open (0-3 min)

"Today I want to show you how dbt works in practice, with a small example. It's fake order data, six rows, so we can follow every number. Stop me anytime."

Ask what the audience most wants to see before you share your screen.

## Models and the DAG (3-9 min)

1. Show `RAW.ORDERS`, then `models/stg_orders.sql` and `models/client_daily_sales.sql`.
2. Point at `source()` and `ref()`. "That's how dbt knows the order. I don't write the dependencies anywhere else."
3. Run **Compile**, open the DAG tab, then **View Compiled SQL** on `client_daily_sales`. "This is the actual SQL Snowflake runs. No magic."

## Build and tests (9-15 min)

1. Run **Build** on `dev`. Show the test summary.
2. Open `tests/expected_daily_sales.sql`. "If a total is wrong or a row goes missing, this fails."
3. Planned failure: run `test --select demo_order_amount_cap --vars '{show_failing_test: true}'`. It fails on two orders over 50. "Good. That's what we want a test to do." Raise `max_order_amount` in `dbt_project.yml`, rerun, it passes.

## Rerun one slice (15-21 min)

1. Run `setup/new_orders.sql`. One new order for CLIENT_B on October 4.
2. Run the incremental model with `--vars '{client_id: CLIENT_B, start_date: 2026-10-04, end_date: 2026-10-04}'`.
3. "dbt deletes just that client and day, then inserts the new numbers. Same idea as a scoped delete and insert, but declared in the model."
4. Mention the limit: a key that disappears inside the slice isn't deleted. A real job needs that decided up front.
5. Show `client_daily_sales_dt` still has the old rows. "Snowflake refreshes this one on its own schedule, not when dbt runs."

## Dev, prod, and scheduling (21-26 min)

1. Open `dbt_projects_profiles.yml`. Same code, two targets, two schemas.
2. Deploy to `PROD`, then open `setup/schedule_tasks.sql`. "dbt says what runs. The task says when. Here it's 9 AM UTC every day, and a second task reruns one slice after it."
3. Tasks stay suspended. Only resume them if you want them to fire.

## Close (26-30 min)

"Which one of your transformations should we try this on? Let's pick one, write down what goes in, what comes out, and what a rerun has to do safely."

Agree on one job, an owner, and a date. Don't imply this example tested any real pipeline.

## Fallback

If the UI or network fails, show the files and the recorded results in `README.md` ("Verified in the lab"), and say they're recorded, not live. The DAG view and workspace OAuth sign-in weren't part of those checks.
