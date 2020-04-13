defmodule ObanDemo do
  alias ObanDemo.{Schedulers, Repo}

  import Ecto.Query

  # test case 1
  def batch_insert(stream) do
    Schedulers.Batches.schedule_jobs(stream)
  end

  # test case 2
  def parallel_multi_batch_insert(stream) do
    Schedulers.ParallelMultiBatches.schedule_jobs(stream)
  end

  # test case 3
  def parallel_batch_insert(stream) do
    Schedulers.ParallelBatches.schedule_jobs(stream)
  end

  def re_schedule_oban_jobs(ids) do
    from(job in Oban.Job, where: job.id in ^ids)
    |> Repo.update_all(set: [state: "available", attempt: 0, discarded_at: nil])
  end

  def mark_jobs_as_completed(queue) do
    str_queue = "#{queue}"

    Oban.Job
    |> where([j], j.queue in [^str_queue])
    |> Repo.update_all(set: [state: "completed", attempted_at: DateTime.utc_now()])
  end
end
