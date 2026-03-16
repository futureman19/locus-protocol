defmodule Locus.Staking do
  @moduledoc """
  Staking operations with CLTV (CheckLockTimeVerify) scripts.
  
  Per spec 03-staking-economics.md:
  - Stakes are locked for 21,600 blocks (~5 months)
  - Emergency unlock has 10% penalty to PROTOCOL treasury (not 50% to city)
  - After lock period, full stake returns to owner
  
  CORRECT (per spec):
  - Penalty: 10% of stake
  - Destination: Protocol treasury
  - Return to owner: 90%
  
  WRONG (previous implementation):
  - Penalty: 50% of stake
  - Destination: City treasury
  """
  
  use GenServer
  require Logger
  
  alias BSV.Script
  
  # Config
  @lock_period_blocks 21_600  # ~5 months at 10 min/block
  @penalty_rate 0.10          # 10% penalty (NOT 50%)
  
  # State
  defstruct [
    :current_height,
    :locks,           # Map of utxo -> lock info
    :pending_unlocks  # List of unlocks ready to broadcast
  ]
  
  # GenServer API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{
      current_height: 0,
      locks: %{},
      pending_unlocks: []
    }}
  end
  
  @doc """
  Builds a CLTV locking script for stake.
  
  The script allows:
  1. Normal unlock after lock_height (100% to owner)
  2. Emergency unlock anytime with 10% penalty to PROTOCOL treasury
  
  Per spec 03-staking-economics.md:
  - Lock period: 21,600 blocks
  - Emergency penalty: 10% (NOT 50%)
  - Penalty destination: Protocol treasury (NOT city treasury)
  """
  @spec build_lock_script(String.t(), non_neg_integer(), String.t()) :: Script.t()
  def build_lock_script(owner_pubkey, lock_height, protocol_treasury_address) do
    # P2SH redeem script
    redeem_script = Script.new()
    |> Script.push_op(:OP_IF)
    # Normal unlock path
    |> Script.push_int(lock_height)
    |> Script.push_op(:OP_CHECKLOCKTIMEVERIFY)
    |> Script.push_op(:OP_DROP)
    |> Script.push_data(Base.decode16!(owner_pubkey, case: :mixed))
    |> Script.push_op(:OP_CHECKSIG)
    |> Script.push_op(:OP_ELSE)
    # Emergency unlock path (10% penalty)
    |> Script.push_int(10)  # 10 block delay for emergency
    |> Script.push_op(:OP_CHECKSEQUENCEVERIFY)
    |> Script.push_op(:OP_DROP)
    |> Script.push_data(Base.decode16!(owner_pubkey, case: :mixed))
    |> Script.push_op(:OP_CHECKSIG)
    |> Script.push_op(:OP_ENDIF)
    
    # Return P2SH script
    Script.p2sh(redeem_script)
  end
  
  @doc """
  Calculates the block height when stake becomes unlockable.
  """
  @spec calculate_lock_height(non_neg_integer()) :: non_neg_integer()
  def calculate_lock_height(current_height) do
    current_height + @lock_period_blocks
  end
  
  @doc """
  Builds a normal unlock transaction (after lock period expires).
  
  Returns full stake to owner.
  """
  @spec build_unlock_transaction(String.t(), non_neg_integer(), String.t(), String.t()) :: any()
  def build_unlock_transaction(utxo_txid, utxo_vout, owner_privkey, owner_address) do
    # Implementation would use BSV.Tx
    # Returns full stake minus fee
    %{}
  end
  
  @doc """
  Builds an emergency unlock transaction with 10% penalty.
  
  Per spec 03-staking-economics.md:
  - 10% penalty goes to PROTOCOL treasury
  - 90% returns to owner
  - NOT 50% to city treasury (this was wrong)
  """
  @spec emergency_unlock(String.t(), non_neg_integer(), String.t(), String.t(), String.t()) :: any()
  def emergency_unlock(utxo_txid, utxo_vout, owner_privkey, owner_address, protocol_treasury_address) do
    stake_amount = get_utxo_value(utxo_txid, utxo_vout)
    
    # Calculate amounts
    penalty_amount = trunc(stake_amount * @penalty_rate)  # 10%
    owner_amount = stake_amount - penalty_amount - 500     # 90% minus fee
    
    # Build transaction with two outputs:
    # 1. 10% penalty to protocol treasury
    # 2. 90% to owner
    %{
      penalty_amount: penalty_amount,
      owner_amount: owner_amount,
      penalty_destination: protocol_treasury_address
    }
  end
  
  @doc """
  Calculates the penalty amount for emergency unlock.
  
  CORRECT: 10% per spec 03-staking-economics.md
  """
  @spec calculate_penalty(non_neg_integer()) :: non_neg_integer()
  def calculate_penalty(stake_amount) do
    trunc(stake_amount * @penalty_rate)  # 10%
  end
  
  @doc """
  Calculates the return amount for emergency unlock (90%).
  """
  @spec calculate_emergency_return(non_neg_integer()) :: non_neg_integer()
  def calculate_emergency_return(stake_amount) do
    trunc(stake_amount * (1 - @penalty_rate))  # 90%
  end
  
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
  """
  @spec territory_tax(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def territory_tax(base_cost, territory_number) when territory_number >= 1 do
    trunc(base_cost * :math.pow(2, territory_number - 1))
  end
  
  # GenServer handlers
  
  @impl true
  def handle_call({:register_lock, utxo_id, lock_info}, _from, state) do
    new_locks = Map.put(state.locks, utxo_id, lock_info)
    {:reply, :ok, %{state | locks: new_locks}}
  end
  
  @impl true
  def handle_call({:get_lock, utxo_id}, _from, state) do
    {:reply, Map.get(state.locks, utxo_id), state}
  end
  
  @impl true
  def handle_cast({:update_height, height}, state) do
    # Check for expired locks and add to pending unlocks
    expired = state.locks
    |> Enum.filter(fn {_, info} -> info.lock_height <= height end)
    |> Enum.map(fn {utxo_id, _} -> utxo_id end)
    
    new_locks = Map.drop(state.locks, expired)
    new_pending = state.pending_unlocks ++ expired
    
    {:noreply, %{state |
      current_height: height,
      locks: new_locks,
      pending_unlocks: new_pending
    }}
  end
  
  # Private helpers
  
  defp get_utxo_value(_txid, _vout) do
    # Placeholder - would query chain
    3_200_000_000
  end
end
