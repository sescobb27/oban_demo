defmodule ObanDemo do
  alias ObanDemo.{Schedulers, Repo}

  import Ecto.Query, only: [from: 2]

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
end
