defmodule ObanDemo.Schedulers.ParallelBatches do
  @one_week 604_800

  alias ObanDemo.Workers.Demo

  def schedule_jobs(stream) do
    stream
    |> Stream.chunk_every(1000)
    |> Task.async_stream(&insert_jobs/1, timeout: :infinity)
    |> Stream.run()
  end

  defp insert_jobs(job_ids) do
    job_ids
    |> Enum.map(fn job_id ->
      Demo.new(%{job_id: job_id}, unique: [period: @one_week], queue: :parallel_batch_queue)
    end)
    |> Oban.insert_all()
  end
end
