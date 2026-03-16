defmodule Locus.Territory do
  @moduledoc """
  Territory management — claim, release, transfer at all hierarchy levels.

  Per spec 01-territory-hierarchy.md:

      /128 Continent     (no stake, geographic only)
      /64  Country       (no stake, jurisdiction boundary)
      /32  City          (32 BSV stake)
      /16  Public Block  (auctioned by city treasury, Fibonacci unlock)
      /16  Private Block (8 BSV stake)
      /8   Building      (8 BSV stake)
      /4   Home          (4 BSV stake)
      /2   Aura          (automatic with presence)
      /1   Object        (0.1-64 BSV depending on type)

  ## Progressive Property Tax

      1st property: base_cost
      2nd property: base_cost × 2
      3rd property: base_cost × 4
      Nth property: base_cost × 2^(N-1)

  ## H3 Addressing

  Territory IDs use H3 hexagonal grid indexes at appropriate resolutions:
      /32 City:     H3 Resolution 7  (~5.1 km²)
      /8 Building:  H3 Resolution 9  (~0.1 km²)
      /4 Home:      H3 Resolution 10 (~0.015 km²)
      /1 Object:    H3 Resolution 12 (~0.003 km²)
  """

  alias Locus.Schemas.Territory, as: TerritorySchema

  @doc """
  Claim a territory at a given level.

  Per spec 01-territory-hierarchy.md:
  - Stake must meet level minimum
  - First-claimer wins (earlier tx timestamp)
  - CLTV lock for 21,600 blocks

  Returns `{:ok, territory}` or `{:error, reason}`.
  """
  @spec claim(map()) :: {:ok, TerritorySchema.t()} | {:error, atom()}
  def claim(params) do
    level = Map.fetch!(params, :level)
    h3_index = Map.fetch!(params, :h3_index)
    owner_pubkey = Map.fetch!(params, :owner_pubkey)
    stake_amount = Map.fetch!(params, :stake_amount)
    block_height = Map.fetch!(params, :block_height)
    city_id = Map.get(params, :city_id)

    min_stake = TerritorySchema.stake_for_level(level)

    cond do
      min_stake > 0 and stake_amount < min_stake ->
        {:error, :insufficient_stake}

      true ->
        territory_id = derive_territory_id(h3_index, level)

        territory = %TerritorySchema{
          id: territory_id,
          h3_index: h3_index,
          level: level,
          parent_id: Map.get(params, :parent_id),
          owner_pubkey: owner_pubkey,
          city_id: city_id,
          claimed_at: block_height,
          stake_amount: stake_amount,
          lock_height: block_height + 21_600,
          status: :claimed
        }

        {:ok, territory}
    end
  end

  @doc """
  Release a claimed territory back to unclaimed.
  """
  @spec release(TerritorySchema.t(), binary()) ::
    {:ok, TerritorySchema.t()} | {:error, atom()}
  def release(%TerritorySchema{} = territory, owner_pubkey) do
    cond do
      territory.status != :claimed ->
        {:error, :not_claimed}

      territory.owner_pubkey != owner_pubkey ->
        {:error, :not_owner}

      true ->
        released = %{territory |
          owner_pubkey: nil,
          city_id: nil,
          status: :unclaimed,
          claimed_at: nil,
          stake_amount: 0,
          lock_height: 0
        }
        {:ok, released}
    end
  end

  @doc """
  Transfer territory to a new owner.

  Per spec 07-transaction-formats.md TERRITORY_TRANSFER (0x12):
  - Requires signature from current owner
  - Optionally includes price (0 for gift)
  """
  @spec transfer(TerritorySchema.t(), binary(), binary(), keyword()) ::
    {:ok, TerritorySchema.t()} | {:error, atom()}
  def transfer(%TerritorySchema{} = territory, from_pubkey, to_pubkey, _opts \\ []) do
    cond do
      territory.status != :claimed ->
        {:error, :not_claimed}

      territory.owner_pubkey != from_pubkey ->
        {:error, :not_owner}

      true ->
        {:ok, %{territory | owner_pubkey: to_pubkey}}
    end
  end

  @doc """
  Calculate progressive property tax for the Nth property.

  Per spec 03-staking-economics.md:
  Cost(n) = base_cost × 2^(n-1)

  ## Examples

      iex> Locus.Territory.progressive_tax(800_000_000, 1)
      800_000_000
      iex> Locus.Territory.progressive_tax(800_000_000, 3)
      3_200_000_000
  """
  @spec progressive_tax(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def progressive_tax(base_cost, property_number) when property_number >= 1 do
    trunc(base_cost * :math.pow(2, property_number - 1))
  end

  @doc """
  Calculate total cost for N properties at a given base.

  Per spec: Total = base_cost × (2^N - 1)
  """
  @spec total_cost(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def total_cost(base_cost, count) when count >= 1 do
    trunc(base_cost * (:math.pow(2, count) - 1))
  end

  @doc """
  Fee distribution for an interaction on a /1 object.

  Per spec 03-staking-economics.md:
      50% → Application/Ghost developer
      40% → Territory owner(s):
          50% of 40% → Building owner (/8)
          30% of 40% → City treasury (/32)
          20% of 40% → Block owner (/16)
      10% → Protocol treasury

  Returns map of allocations in satoshis.
  """
  @spec distribute_fees(non_neg_integer()) :: map()
  def distribute_fees(total_fee) do
    developer = div(total_fee * 50, 100)
    territory = div(total_fee * 40, 100)
    protocol = total_fee - developer - territory

    building_owner = div(territory * 50, 100)
    city_treasury = div(territory * 30, 100)
    block_owner = territory - building_owner - city_treasury

    %{
      developer: developer,
      territory_total: territory,
      building_owner: building_owner,
      city_treasury: city_treasury,
      block_owner: block_owner,
      protocol: protocol
    }
  end

  defp derive_territory_id(h3_index, level) do
    data = "#{h3_index}:#{level}"
    :crypto.hash(:sha256, data)
  end
end
