defmodule ObanDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {ObanDemo.Repo, []},
      {Oban, oban_config()},
      {ObanDemo.Pruners.FastPruner, fast_pruner_config()}
    ]

    opts = [strategy: :one_for_one, name: ObanDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp oban_config do
    opts = Application.get_env(:oban_demo, Oban)

    # Prevent running queues or scheduling jobs from an iex console.
    if Code.ensure_loaded?(IEx) and IEx.started?() do
      opts
      |> Keyword.put(:crontab, false)
      |> Keyword.put(:queues, false)
    else
      opts
    end
  end

  defp fast_pruner_config() do
    [
      prune: {:maxage, :timer.seconds(20)},
      queues: [
        :batch_queue,
        :parallel_multi_batch_queue,
        :parallel_batch_queue
      ]
    ]
  end
end
