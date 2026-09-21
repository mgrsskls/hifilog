# Background jobs

The application uses **Active Job** with **Solid Queue** as the backend. Solid Queue keeps the jobs in database tables. It does not need Redis.

## Where the jobs are

- The Solid Queue tables (`solid_queue_*`) are in the **primary database**. There is no separate queue database. Migration `CreateSolidQueueTables` creates them. It is a copy of the base schema of the `solid_queue` gem 1.7.
- A job that is enqueued in a transaction is written in the same transaction. Thus the enqueue is atomic: a rollback removes the job, and a worker cannot see the job before the commit. For this reason, `ApplicationJob` sets `enqueue_after_transaction_commit = false`.
- Solid Queue deletes finished jobs after 1 day (the gem default). Thus the tables stay small.

## How the jobs run

| Environment                              | Adapter        | Who runs the jobs                                                |
| ---------------------------------------- | -------------- | ---------------------------------------------------------------- |
| Production (Heroku)                      | `:solid_queue` | The Puma plugin, as threads in the Puma process of the web dyno. |
| Development                              | `:async`       | Puma, in threads of the web process.                             |
| Development with `SOLID_QUEUE_IN_PUMA=1` | `:solid_queue` | The Puma plugin, as in production.                               |
| Test                                     | `:test`        | Nothing. Tests use `perform_enqueued_jobs` or `perform_now`.     |

The Puma plugin runs Solid Queue in **async mode** (`solid_queue_mode :async` in `config/puma.rb`). The supervisor, one **dispatcher** and one **worker** are threads in the Puma process. There are no more processes, no `worker` entry in the `Procfile`, and no extra dyno.

Do not use the default fork mode. Fork mode starts 3 more Ruby processes in the web dyno. After the first deploy with fork mode, the memory increased from approximately 250 MB to more than 590 MB. This is more than the 512 MB quota, and the dyno used swap.

If the supervisor stops, the plugin stops Puma too. Heroku then restarts the dyno. On a deploy, the `release` phase (`rails db:migrate`) runs before the new dynos start. Thus the tables exist before the supervisor starts.

You can also start Solid Queue alone with `bin/jobs`.

## Configuration

`config/queue.yml` sets the processes:

- **Worker:** 2 threads, 1 process, polls every 2 seconds.
- **Dispatcher:** polls every second. It moves scheduled jobs and releases blocked jobs.

### Database connections

The Heroku Postgres plan **Essential-0** accepts a maximum of **20 connections**. The dashboard value "x of 20 connections" shows the connections that are open at that time. Plan for the maximum:

| Consumer                                                     | Connections (max.)      |
| ------------------------------------------------------------ | ----------------------- |
| Puma (`RAILS_MAX_THREADS`, default 5)                        | 5                       |
| Solid Queue worker, dispatcher and supervisor (same process) | about 5                 |
| `release` phase, `heroku run rails c`, PgHero                | 1–2 each, when they run |

All threads of the web process use one pool. In production, `config/database.yml` sets the pool to `RAILS_MAX_THREADS` + 5 (10). Set `DB_POOL` to change it. The total is approximately 10–12. Do not increase the worker threads, `RAILS_MAX_THREADS` or the number of web dynos before you compare the new total with the plan limit. If **preboot** is on, the old and the new dyno run at the same time during a deploy. This doubles the count for a short time and is more than 20.

### Memory

In async mode, Solid Queue adds only threads to the Puma process. The jobs also use the CPU of the web process. A long job can make requests slower.

After a deploy, look for `R14 (Memory quota exceeded)` in the Heroku logs. If this error occurs, move Solid Queue to a separate `worker` dyno:

1. Remove the Solid Queue block from `config/puma.rb`.
2. Add `worker: bin/jobs` to the `Procfile`.
3. Remove the `pool` line from `production` in `config/database.yml`. The worker dyno uses its own pool.
4. Scale the worker dyno to 1.

## Jobs

### `SubCategoryCompletenessJob`

Recalculates `completeness`, `specs_applicable` and `specs_filled` of all products in one sub category (see [Completeness](../README.md#completeness-and-contribution-queues)).

- **Enqueued by:** `CustomAttribute`, when `highlighted` changes, when the sub categories of a highlighted attribute change, or when a highlighted attribute is destroyed. These changes can change the score of all products in a sub category. Use `Product.recalculate_completeness_for_sub_categories_later(ids)`. It enqueues one job for each sub category, in one insert.
- **Not enqueued:** a save of one product. `Product#recalculate_completeness!` stays synchronous for that. It is fast, and the score is correct immediately after the save.
- **Concurrency:** one job for each sub category at a time (`limits_concurrency`). A second job for the same sub category waits until the first job is complete. It is not discarded, because the first job can have read the definitions before the second change.
- **Continuable:** the job includes `ActiveJob::Continuable`. After each product, it records the product id as the cursor. When the dyno stops (deploy, daily restart), the job stops after the current product. Later, it continues after the cursor.

The rake task `completeness:backfill_products` does not use the job. It runs synchronously.

## Add a job

1. Put the class in `app/jobs/` and make it a subclass of `ApplicationJob`.
2. Give only ids as arguments. Do not give records.
3. Make the job safe to run two times. A job can run again after a crash.
4. If the job iterates over many rows, include `ActiveJob::Continuable` and use a cursor.
5. Add a test in `test/jobs/`.
