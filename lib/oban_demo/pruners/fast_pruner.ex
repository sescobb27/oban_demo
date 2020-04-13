defmodule ObanDemo.Pruners.FastPruner do
  @moduledoc false

  use GenServer

  import Ecto.Query
  import Oban.Breaker, only: [open_circuit: 1, trip_errors: 0, trip_circuit: 3]

  alias Oban.{Query, Config}
  alias ObanDemo.Repo

  @lock_key 1_159_969_450_252_858_340

  defmodule State do
    defstruct [:config, :queues, circuit: :enabled]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    {queues, oban_opts} = Keyword.pop(opts, :queues, [])
    config = Config.new([{:repo, Repo} | oban_opts])
    send(self(), :prune)
    {:ok, %State{config: config, queues: Enum.map(queues, &to_string/1)}}
  end

  @impl GenServer
  def handle_info(:prune, state) do
    IO.puts("start pruning")
    state = prune(state)
    IO.puts("finished pruning")
    Process.send_after(self(), :prune, :timer.minutes(1))
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:reset_circuit, state) do
    {:noreply, open_circuit(state)}
  end

  @impl GenServer
  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp prune(%State{circuit: :disabled} = state), do: state

  defp prune(%State{config: config, queues: queues} = state) do
    Repo.transaction(fn ->
      if Query.acquire_lock?(config, @lock_key) do
        prune_jobs(config, queues)
      end
    end)

    state
  rescue
    exception in trip_errors() -> trip_circuit(exception, __STACKTRACE__, state)
  end

  defp prune_jobs(config, queues) do
    %{prune: prune} = config

    case prune do
      {:maxage, seconds} ->
        delete_outdated_jobs(queues, seconds)
    end
  end

  def delete_outdated_jobs(queues, seconds) do
    outdated_at = DateTime.utc_now() |> DateTime.add(-seconds)

    Oban.Job
    |> where([j], j.state in ["completed", "discarded"])
    |> where([j], j.attempted_at < ^outdated_at)
    |> where([j], j.queue in ^queues)
    |> Repo.delete_all()
  end
end
