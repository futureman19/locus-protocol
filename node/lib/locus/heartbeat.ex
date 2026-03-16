defmodule Locus.Heartbeat do
  @moduledoc """
  Heartbeat protocol for proof-of-liveness

  Ghosts must heartbeat every 24-48 hours to remain active.
  """

  use GenServer

  # Heartbeat requirements
  @min_interval 86_400      # 24 hours in seconds
  @max_interval 172_800     # 48 hours in seconds
  @grace_period 86_400      # 24 hours grace

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{heartbeats: %{}}}
  end

  @doc """
  Validate heartbeat sequence number
  """
  def validate_sequence(current_seq, new_seq) do
    if new_seq > current_seq do
      :ok
    else
      {:error, "Sequence must increase: #{current_seq} -> #{new_seq}"}
    end
  end

  @doc """
  Check if ghost is due for heartbeat
  """
  def due_for_heartbeat?(last_heartbeat) do
    last_time = DateTime.to_unix(last_heartbeat)
    now = DateTime.to_unix(DateTime.utc_now())

    now - last_time > @max_interval
  end

  @doc """
  Check if ghost is in grace period
  """
  def in_grace_period?(last_heartbeat) do
    last_time = DateTime.to_unix(last_heartbeat)
    now = DateTime.to_unix(DateTime.utc_now())

    elapsed = now - last_time
    elapsed > @max_interval and elapsed <= (@max_interval + @grace_period)
  end

  @doc """
  Get heartbeat deadline for a ghost
  """
  def deadline(last_heartbeat) do
    DateTime.add(last_heartbeat, @max_interval + @grace_period, :second)
  end
end
