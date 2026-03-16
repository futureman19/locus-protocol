defmodule Locus.Staking do
  @moduledoc """
  Territory-centric staking — CLTV lock scripts and emergency unlock.

  Citizens stake BSV to join cities and claim territories. Stakes are
  locked using OP_CHECKLOCKTIMEVERIFY (CLTV) for 21,600 blocks (~5 months).

  ## Lock Script

      <lock_height> OP_CHECKLOCKTIMEVERIFY OP_DROP <owner_pubkey> OP_CHECKSIG

  ## Emergency Unlock

  Citizens can unlock early by paying a 50% penalty. The penalty amount
  goes to the city treasury.

  ## Progressive Territory Tax

  Each additional territory claimed costs exponentially more:

      1st: base_cost × 2^0 = base_cost
      2nd: base_cost × 2^1 = 2 × base_cost
      3rd: base_cost × 2^2 = 4 × base_cost
      Nth: base_cost × 2^(N-1)
  """

  use GenServer

  require Logger

  alias BSV.Script

  @lock_period_blocks 21_600
  @emergency_penalty 0.50

  defstruct [
    stakes: %{},
    locks: %{}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  # ---------------------------------------------------------------------------
  # CLTV Lock Scripts
  # ---------------------------------------------------------------------------

  @doc """
  Build a CLTV lock script for staking.

  Script format:
      <lock_height> OP_CHECKLOCKTIMEVERIFY OP_DROP <owner_pubkey> OP_CHECKSIG

  ## Parameters

    - `lock_height` — Block height when the stake becomes unlockable
    - `owner_pubkey` — Owner's compressed public key (33 bytes)

  ## Examples

      iex> script = Locus.Staking.build_lock_script(850_000, <<0x02::8, 0::256>>)
      iex> is_binary(script)
      true
  """
  @spec build_lock_script(non_neg_integer(), binary()) :: binary()
  def build_lock_script(lock_height, owner_pubkey) when is_binary(owner_pubkey) do
    Script.new()
    |> Script.push_int(lock_height)
    |> Script.push_op(:OP_CHECKLOCKTIMEVERIFY)
    |> Script.push_op(:OP_DROP)
    |> Script.push_data(owner_pubkey)
    |> Script.push_op(:OP_CHECKSIG)
  end

  @doc """
  Build an emergency unlock script with penalty output.

  The script allows early unlock but requires a penalty payment output
  to the city treasury address.

  Script format:
      OP_IF
        <city_treasury_pubkey> OP_CHECKSIGVERIFY  # Penalty acknowledged
        <owner_pubkey> OP_CHECKSIG                # Owner signs
      OP_ELSE
        <lock_height> OP_CHECKLOCKTIMEVERIFY OP_DROP
        <owner_pubkey> OP_CHECKSIG                # Normal unlock
      OP_ENDIF
  """
  @spec build_emergency_unlock_script(non_neg_integer(), binary(), binary()) :: binary()
  def build_emergency_unlock_script(lock_height, owner_pubkey, treasury_pubkey) do
    Script.new()
    |> Script.push_op(:OP_IF)
    |> Script.push_data(treasury_pubkey)
    |> Script.push_op(:OP_CHECKSIGVERIFY)
    |> Script.push_data(owner_pubkey)
    |> Script.push_op(:OP_CHECKSIG)
    |> Script.push_op(:OP_ELSE)
    |> Script.push_int(lock_height)
    |> Script.push_op(:OP_CHECKLOCKTIMEVERIFY)
    |> Script.push_op(:OP_DROP)
    |> Script.push_data(owner_pubkey)
    |> Script.push_op(:OP_CHECKSIG)
    |> Script.push_op(:OP_ENDIF)
  end

  @doc """
  Create a P2SH address from a redeem script.
  """
  @spec p2sh_address(binary()) :: binary()
  def p2sh_address(redeem_script) do
    Script.Address.from_redeem_script(redeem_script)
  end

  @doc """
  Calculate the lock height for a new stake.

  ## Examples

      iex> Locus.Staking.calculate_lock_height(800_000)
      821_600
  """
  @spec calculate_lock_height(non_neg_integer()) :: non_neg_integer()
  def calculate_lock_height(current_height) do
    lock_period = Application.get_env(:locus_core, :lock_period_blocks, @lock_period_blocks)
    current_height + lock_period
  end

  @doc """
  Validate that a stake amount meets the minimum requirement.
  """
  @spec validate_stake(non_neg_integer(), keyword()) ::
    :ok | {:error, :insufficient_stake}
  def validate_stake(amount, opts \\ []) do
    min = Keyword.get(opts, :min_stake,
      Application.get_env(:locus_core, :min_founding_stake, 1_000_000))

    if amount >= min do
      :ok
    else
      {:error, :insufficient_stake}
    end
  end

  @doc """
  Check if a stake has matured (lock period expired).
  """
  @spec matured?(non_neg_integer(), non_neg_integer()) :: boolean()
  def matured?(lock_height, current_height) do
    current_height >= lock_height
  end

  # ---------------------------------------------------------------------------
  # Emergency Unlock
  # ---------------------------------------------------------------------------

  @doc """
  Calculate the emergency unlock penalty.

  Default penalty is 50% of the staked amount.

  ## Examples

      iex> Locus.Staking.emergency_unlock_penalty(1_000_000)
      500_000
  """
  @spec emergency_unlock_penalty(non_neg_integer()) :: non_neg_integer()
  def emergency_unlock_penalty(stake_amount) do
    penalty_rate = Application.get_env(:locus_core, :emergency_unlock_penalty, @emergency_penalty)
    trunc(stake_amount * penalty_rate)
  end

  @doc """
  Process an emergency unlock request.

  Returns `{:ok, returned_amount, penalty_amount}` where:
  - `returned_amount` goes back to the staker
  - `penalty_amount` goes to the city treasury
  """
  @spec emergency_unlock(non_neg_integer()) ::
    {:ok, non_neg_integer(), non_neg_integer()}
  def emergency_unlock(stake_amount) do
    penalty = emergency_unlock_penalty(stake_amount)
    returned = stake_amount - penalty
    {:ok, returned, penalty}
  end

  # ---------------------------------------------------------------------------
  # Progressive Territory Tax
  # ---------------------------------------------------------------------------

  @doc """
  Calculate the cost for claiming the Nth territory.

  Progressive tax: base_cost × 2^(N-1)

  ## Examples

      iex> Locus.Staking.territory_tax(10_000, 1)
      10_000
      iex> Locus.Staking.territory_tax(10_000, 2)
      20_000
      iex> Locus.Staking.territory_tax(10_000, 3)
      40_000
      iex> Locus.Staking.territory_tax(10_000, 5)
      160_000
  """
  @spec territory_tax(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def territory_tax(base_cost, territory_number) when territory_number >= 1 do
    Locus.Territory.progressive_tax(base_cost, territory_number)
  end

  # ---------------------------------------------------------------------------
  # Stake Tracking (GenServer state)
  # ---------------------------------------------------------------------------

  @doc """
  Record a new stake.
  """
  @spec record_stake(binary(), binary(), non_neg_integer(), non_neg_integer(), binary()) ::
    :ok
  def record_stake(city_id, pubkey, amount, lock_height, txid) do
    GenServer.call(__MODULE__, {:record_stake, city_id, pubkey, amount, lock_height, txid})
  end

  @doc """
  Get stake info for a citizen.
  """
  @spec get_stake(binary(), binary()) :: {:ok, map()} | {:error, :not_found}
  def get_stake(city_id, pubkey) do
    GenServer.call(__MODULE__, {:get_stake, city_id, pubkey})
  end

  @impl true
  def handle_call({:record_stake, city_id, pubkey, amount, lock_height, txid}, _from, state) do
    key = {city_id, pubkey}
    stake = %{
      city_id: city_id,
      pubkey: pubkey,
      amount: amount,
      lock_height: lock_height,
      txid: txid,
      staked_at: System.system_time(:second)
    }
    new_state = %{state | stakes: Map.put(state.stakes, key, stake)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_stake, city_id, pubkey}, _from, state) do
    key = {city_id, pubkey}
    case Map.get(state.stakes, key) do
      nil -> {:reply, {:error, :not_found}, state}
      stake -> {:reply, {:ok, stake}, state}
    end
  end
end
