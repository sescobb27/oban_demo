defmodule ObanDemo.Schedulers.Batches do
  @one_week 604_800

  alias ObanDemo.Workers.Demo
  alias ObanDemo.Repo

  def schedule_jobs(stream) do
    stream
    |> Stream.chunk_every(1000)
    |> Enum.each(&insert_jobs/1)
  end

  defp insert_jobs(job_ids) do
    Enum.reduce(job_ids, Ecto.Multi.new(), fn job_id, multi ->
      job = Demo.new(%{job_id: job_id}, unique: [period: @one_week], queue: :batch_queue)
      Oban.insert(multi, "#{job_id}", job)
    end)
    |> Repo.transaction(timeout: :infinity)
  end
end
