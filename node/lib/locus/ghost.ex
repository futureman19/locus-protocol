defmodule Locus.Ghost do
  @moduledoc """
  Ghost lifecycle management

  Handles ghost registration, activation, retirement, and slashing.
  """

  use GenServer

  # Ghost types
  @type ghost_type :: :greeter | :oracle | :guardian | :merchant | :custom

  # Ghost states
  @type state :: :pending | :active | :inactive | :slashed | :retired

  # Ghost struct
  defstruct [
    :id,
    :name,
    :type,
    :lat,
    :lng,
    :h3_index,
    :stake_amount,
    :lock_height,
    :owner_pubkey,
    :code_hash,
    :base_fee,
    :timeout,
    :state,
    :heartbeat_seq,
    :last_heartbeat,
    :created_at
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    type: ghost_type(),
    lat: float(),
    lng: float(),
    h3_index: non_neg_integer(),
    stake_amount: non_neg_integer(),
    lock_height: non_neg_integer(),
    owner_pubkey: String.t(),
    code_hash: String.t(),
    base_fee: non_neg_integer(),
    timeout: non_neg_integer(),
    state: state(),
    heartbeat_seq: non_neg_integer(),
    last_heartbeat: DateTime.t() | nil,
    created_at: DateTime.t()
  }

  # Staking minimums by type (in satoshis)
  @staking_tiers %{
    greeter: 1_000_000,    # 0.01 BSV
    oracle: 10_000_000,    # 0.1 BSV
    guardian: 50_000_000,  # 0.5 BSV
    merchant: 10_000_000,  # 0.1 BSV
    custom: 100_000_000    # 1 BSV minimum
  }

  # Lock period: 5 months = 21,600 blocks
  @lock_period 21_600

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{ghosts: %{}}}
  end

  @doc """
  Get minimum stake for a ghost type
  """
  def min_stake(type) do
    Map.get(@staking_tiers, type, @staking_tiers.custom)
  end

  @doc """
  Calculate lock height from current height
  """
  def lock_height(current_height) do
    current_height + @lock_period
  end

  @doc """
  Derive ghost ID from stake transaction
  """
  def derive_id(txid, output_index) do
    data = txid <<< 32 ||| output_index
    :crypto.hash(:sha256, <<data::little-64>>)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Validate ghost registration
  """
  def validate_registration(ghost, current_height) do
    min = min_stake(ghost.type)

    cond do
      ghost.stake_amount < min -
        {:error, "Stake below minimum: #{min} sats required"}

      ghost.lock_height < lock_height(current_height) -
        {:error, "Lock period too short: #{@lock_period} blocks minimum"}

      true -
        :ok
    end
  end
end
