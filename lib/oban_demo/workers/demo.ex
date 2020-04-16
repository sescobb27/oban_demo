defmodule ObanDemo.Workers.Demo do
  use Oban.Worker, max_attempts: 5, queue: :parallel_batch_queue

  require Logger

  @impl Oban.Worker
  def perform(%{"job_id" => job_id}, _job) do
    Logger.info("performing job_id:#{job_id}")
    20 |> :timer.seconds() |> :timer.sleep()
    Logger.info("done performing job_id:#{job_id}")
    :ok
  end
end
