defmodule Locus.Staking do
  @moduledoc """
  Staking and slashing management

  Handles CLTV-locked stakes and slashing for misbehavior.
  """

  use GenServer

  alias BSV.Script

  @slashing_conditions [
    :no_show,       # Ghost didn't respond to invocation
    :fraud,          # Ghost produced fraudulent result
    :malfunction,    # Ghost crashed or errored
    :timeout         # Ghost exceeded timeout
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{stakes: %{}}}
  end

  @doc """
  Build CLTV lock script for staking

  Script format:
    <lock_height> OP_CHECKLOCKTIMEVERIFY OP_DROP
    <owner_pubkey> OP_CHECKSIG
  """
  def build_lock_script(lock_height, owner_pubkey) do
    Script.new()
    |> Script.push_int(lock_height)
    |> Script.push_op(:OP_CHECKLOCKTIMEVERIFY)
    |> Script.push_op(:OP_DROP)
    |> Script.push_data(owner_pubkey)
    |> Script.push_op(:OP_CHECKSIG)
  end

  @doc """
  Create P2SH address from redeem script
  """
  def p2sh_address(redeem_script) do
    Script.Address.from_redeem_script(redeem_script)
  end

  @doc """
  Calculate slash amount (percentage of stake)
  """
  def calculate_slash(stake_amount, condition) do
    percentage = case condition do
      :no_show -> 0.10      # 10%
      :fraud -> 0.50        # 50%
      :malfunction -> 0.25  # 25%
      :timeout -> 0.10      # 10%
      _ -> 0.10
    end

    trunc(stake_amount * percentage)
  end

  @doc """
  Distribute slashed funds
  50% to challenger, 50% to protocol treasury
  """
  def distribute_slash(slash_amount) do
    challenger_reward = trunc(slash_amount * 0.5)
    treasury_amount = slash_amount - challenger_reward

    {challenger_reward, treasury_amount}
  end
end
