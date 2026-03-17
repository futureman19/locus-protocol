defmodule Locus.RuntimeReporter do
  @moduledoc """
  Periodically writes node health and genesis status to a JSON file.
  """

  use GenServer

  @default_interval_ms 5_000

  defstruct [:output_path, :interval_ms]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      output_path: Keyword.fetch!(opts, :output_path),
      interval_ms: Keyword.get(opts, :interval_ms, @default_interval_ms)
    }

    send(self(), :write_snapshot)
    {:ok, state}
  end

  @impl true
  def handle_info(:write_snapshot, state) do
    snapshot = %{
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      node_name: Application.get_env(:locus, :node_name, "locus"),
      status: Locus.status()
    }

    state.output_path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(state.output_path, Jason.encode_to_iodata!(snapshot, pretty: true))
    Process.send_after(self(), :write_snapshot, state.interval_ms)

    {:noreply, state}
  end
end
