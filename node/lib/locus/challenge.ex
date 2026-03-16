defmodule Locus.Challenge do
  @moduledoc """
  Challenge system for dispute resolution

  Anyone can challenge a ghost for misbehavior.
  """

  use GenServer

  # Challenge types
  @challenge_types [:no_show, :fraud, :malfunction, :timeout]

  # Challenge period: 72 hours
  @response_window 259_200  # 72 hours in seconds

  # Challenger stake
  @challenger_stake 10_000  # 10K sats

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{challenges: %{}}}
  end

  @doc """
  Get required challenger stake
  """
  def challenger_stake, do: @challenger_stake

  @doc """
  Get response window in seconds
  """
  def response_window, do: @response_window

  @doc """
  Validate challenge type
  """
  def valid_type?(type) do
    type in @challenge_types
  end

  @doc """
  Check if challenge response is within window
  """
  def within_window?(challenge_time) do
    now = DateTime.to_unix(DateTime.utc_now())
    now - challenge_time <= @response_window
  end

  @doc """
  Generate challenge ID
  """
  def generate_id(ghost_id, challenger_pk, timestamp) do
    data = ghost_id <<< 256 ||| challenger_pk ||| timestamp
    :crypto.hash(:sha256, <<data::little-320>>)
    |> Base.encode16(case: :lower)
  end
end
