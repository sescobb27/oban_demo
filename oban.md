---
marp: true
theme: uncover
---

# Oban at Titan

## by: Simon Escobar Benitez

---

# Why Oban?

At tubi we are using a handcrafted solution for processing background jobs, but that solution had a couple of problems like durability and zombie jobs.

---

our current solution for background jobs has the following flow:

- from controller we enqueue some jobs to run in a different service
- each service is polling enqueued jobs from controller and starts running them
- once the job is finished it will trigger a sync notification to controller (via GRPC) so controller mark the job as completed/failed

---

Then problem now is that sometimes because reasons (timeouts, service is being re-deployed, etc), the notification wasn't delivered so that job becames in a zombie job.

for this reason we created a job process checker that is in charge of querying zombie jobs in controller (jobs that their statuses haven't changed in a period of time) and ask for their status in the corresponding service

---

This works but is not ideal, so i start researching about asyncrhonous jobs processing tools already implemented in elixir and found [Oban](https://github.com/sorentwo/oban)

---

# what is oban?

[Oban](https://github.com/sorentwo/oban) is a robust job processing library which uses PostgreSQL for storage and coordination.

---

Oban's primary goals are reliability, consistency and observability.

It is fundamentally different from other background job processing tools because it retains job data for historic metrics and inspection. You can leave your application running indefinitely without worrying about jobs being lost or orphaned due to crashes.

---

# Advantages Over Other Tools

**Fewer Dependencies** — If you are running a web app there is a very good chance that you're running on top of a RDBMS. Running your job queue within PostgreSQL minimizes system dependencies and simplifies data backups.

---

**Transactional Control** — Enqueue a job along with other database changes, ensuring that everything is committed or rolled back atomically.

**Database Backups** — Jobs are stored inside of your primary database, which means they are backed up together with the data that they relate to.

---

# Advanced Features

**Isolated Queues** — Jobs are stored in a single table but are executed in distinct queues. Each queue runs in isolation, ensuring that a job in a single slow queue can't back up other faster queues (GenServers).

**Queue Control** — Queues can be started, stopped, paused, resumed and scaled independently at runtime across all running nodes (even in environments like Heroku, without distributed Erlang).

---

**Resilient Queues** — Failing queries won't crash the entire supervision tree, instead they trip a circuit breaker and will be retried again in the future.

**Job Killing** — Jobs can be killed in the middle of execution regardless of which node they are running on. This stops the job at once and flags it as discarded.

---

**Triggered Execution** — Database triggers ensure that jobs are dispatched as soon as they are inserted into the database.

**Unique Jobs** — Duplicate work can be avoided through unique job controls. Uniqueness can be enforced at the argument, queue and worker level for any period of time [GOTCHA 1.].

---

**Scheduled Jobs** — Jobs can be scheduled at any time in the future, down to the second.

**Periodic (CRON) Jobs** — Automatically enqueue jobs on a cron-like schedule. Duplicate jobs are never enqueued, no matter how many nodes you're running.

---

**Job Priority** — Prioritize jobs within a queue to run ahead of others.

**Job Safety** — When a process crashes or the BEAM is terminated executing jobs aren't lost—they are quickly recovered by other running nodes or immediately when the node is restarted.

---

**Historic Metrics** — After a job is processed the row is not deleted. Instead, the job is retained in the database to provide metrics. This allows users to inspect historic jobs and to see aggregate data at the job, queue or argument level.

**Node Metrics** — Every queue records metrics to the database during runtime. These are used to monitor queue health across nodes and may be used for analytics.

---

**Queue Draining** — Queue shutdown is delayed so that slow jobs can finish executing before shutdown. When shutdown starts queues are paused and stop executing new jobs. Any jobs left running after the shutdown grace period may be rescued later.

**Telemetry Integration** — Job life-cycle events are emitted via Telemetry integration. This enables simple logging, error reporting and health checkups without plug-ins.

---

# Usage

[Oban Usage, Configuration and Workers](https://hexdocs.pm/oban/readme.html#usage)

---

# Unique Jobs

There are a couple of ways for inserting a large number of unique Jobs, taking advantage of Oban unique options or using DB unique indexes lets discuss each approach

---

# Oban Unique Options

## Option 1

We can insert each job one by one in a loop, this works well in a simple case but at titan we sometimes need to enqueue more than 300k jobs so this is not suitable as can take days

```elixir
job = Worker.new(args, unique: [period: @one_week], queue: :myqueue)
Oban.insert(job)
```

---

## Option 2

We can batch insert records in batches inside a loop, this works well in more complex cases but not when enqueueing more than 100k jobs as this can take hours [GOTCHA 2.][gotcha 3.]

---

```elixir
defmodule TestScheduler do
  @one_week 604_800

  def schedule_jobs(stream) do
    stream
    |> Stream.chunk_every(1000)
    |> Enum.each(&insert_jobs/1)
  end

  defp insert_jobs(job_ids) do
    Enum.reduce(job_ids, Ecto.Multi.new(), fn job_id, multi ->
      job =
        Worker.new(%{job_id: job_id},
          unique: [period: @one_week],
          queue: :test
        )
      Oban.insert(multi, "#{job_id}", job)
    end)
    |> Models.Repo.transaction(timeout: :infinity)
  end
end
```

---

## Option 3

We can use Elixir concurrency and a big pool of connections to insert jobs in parallel to improve performance.

---

```elixir
defmodule TestScheduler do
  @one_week 604_800

  def schedule_jobs(stream) do
    stream
    |> Stream.chunk_every(1000)
    # introduce async_stream to batch insert in parallel
    |> Task.async_stream(&insert_jobs/1, timeout: :infinity)
    |> Stream.run()
  end

  # same as before
end
```

---

It works but still is taking a couple of hours to insert all the jobs, so, if we want to process 300k jobs as fast as possible and have unique jobs we still need to do something else

---

## Option 4 and Final

For this option we will need to introduce unique indexes at the DB level because we are going to use `insert_all` which is a postgres feature for batch inserting records into the database, but as we need unique jobs, we need to guarantee that each inserted job is unique by the queue and its arguments.

---

## Partial indexes

We can use partial indexes if we only need unique jobs in some queues

```elixir
create(
  index("oban_jobs", [:queue, :args],
    unique: true,
    where: "queue = 'myqueue'"
  )
)
```

---

## Full indexes

We can use full indexes if we need unique jobs across all queues

```elixir
create index("oban_jobs", [:queue, :args], unique: true)
```

---

This will let us use `insert_all` and `on_conflict: :nothing` which will omit already inserted jobs

---

```elixir
defmodule TestScheduler do
  @one_week 604_800

  def schedule_jobs(stream) do
    stream
    |> Stream.chunk_every(1000)
    |> Task.async_stream(&insert_jobs/1, timeout: :infinity)
    |> Stream.run()
  end

  defp insert_jobs(job_ids) do
    job_ids
    |> Enum.map(fn job_id ->
      Worker.new(%{job_id: job_id},
        unique: [period: @one_week],
        queue: :test
      )
    end)
    |> Oban.insert_all()
  end
end
```

---

With this tunning we can insert 300k jobs in ~7sec

```
iex(18)> prev = System.monotonic_time(:millisecond)
-576460423564
iex(19)> 1..300000 |> TestScheduler.schedule_jobs()
:ok
iex(20)> next = System.monotonic_time(:millisecond)
-576460416232
iex(21)> diff = next - prev
7332
iex(22)>
```

---

# Custom Pruner

Oban has a out of the box pruner which is in charge of deleting old jobs that are not longer needed (finished/discarded) and this can be by `maxlength` or `maxage`

---

Pruning by `maxlength` means that we will prune jobs after we reach a given amount of enqueued jobs (we are only going to prune finished/discarded jobs) this is the default setting with a value of 1000

---

Pruning by `maxage` means that we will prune jobs after a given period of time, old jobs that are older than the given period of time are going to be deleted

---

The problem now is that some jobs need to live longer than other jobs, we need to delete some scheduled jobs every day but still keep some other jobs for a couple of weeks, so we end up building our own custom pruner with the same logic as Oban's default pruner

---

- [CustomPruner](https://gist.github.com/sescobb27/5e066ee06174473602bb08361f7a8bea#file-custom_pruner-ex)

- [Upcoming Enhancement - Pruner Behaviour](https://github.com/sorentwo/oban/issues/209)

---

[DEMO](https://github.com/sescobb27/oban_demo)

---

# Gotchas

**GOTCHA 1.** - Jobs are unique in a given period of time (60s by default), that means that after that period of time, the job can be enqueued again so we need to be really careful about this and think if we need unique jobs or we can run indempotent operations for each job.

---

**GOTCHA 2.** - We can't insert infinity records to PostgreSQL at once, so we need to insert sane default number of records, in this case 1000 records.

**GOTCHA 3.** - As we are inserting a big amount of records to the DB we need to increase repo's timeouts as the transaction is going to take more than 15s (the default timeout)
