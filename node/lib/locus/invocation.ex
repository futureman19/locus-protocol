defmodule Locus.Invocation do
  @moduledoc """
  Ghost invocation handling

  Processes invocation requests, fee distribution, and timeouts.
  """

  use GenServer

  # Fee distribution: 70% dev, 20% executor, 10% protocol
  @dev_share 0.70
  @executor_share 0.20
  @protocol_share 0.10

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{invocations: %{}}}
  end

  @doc """
  Calculate fee distribution
  """
  def distribute_fees(total_fee) do
    dev = trunc(total_fee * @dev_share)
    executor = trunc(total_fee * @executor_share)
    # Protocol gets remainder to handle rounding
    protocol = total_fee - dev - executor

    %{dev: dev, executor: executor, protocol: protocol}
  end

  @doc """
  Generate invocation ID
  """
  def generate_id(ghost_id, timestamp, nonce) do
    data = ghost_id <<< 64 ||| timestamp ||| nonce
    :crypto.hash(:sha256, <<data::little-128>>)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Check if invocation has timed out
  """
  def timed_out?(invocation_time, timeout_seconds) do
    now = DateTime.to_unix(DateTime.utc_now())
    now - invocation_time > timeout_seconds
  end
end
