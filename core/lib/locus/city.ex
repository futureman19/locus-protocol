defmodule Locus.City do
  @moduledoc """
  City lifecycle management — the primary primitive of Locus Protocol.

  Per spec 02-city-lifecycle.md:
  - Cities progress through 6 phases driven by CITIZEN COUNT
  - Phases: genesis → settlement → village → town → city → metropolis
  - Fibonacci sequence governs /16 block unlocking
  - UBI activates at Phase 4 (city, 21+ citizens)
  - Founding stake: 32 BSV (CLTV locked 21,600 blocks)
  - Token supply: 3.2M per city

  Phase transitions happen automatically when citizen count crosses
  thresholds. Governance type evolves with each phase.
  """

  alias Locus.Schemas.{City, Citizen}
  alias Locus.Fibonacci

  @founding_stake 3_200_000_000  # 32 BSV in satoshis
  @lock_period 21_600            # blocks (~5 months)

  @doc """
  Found a new city.

  Per spec 02-city-lifecycle.md:
  1. Stake 32 BSV with 21,600-block CLTV lock
  2. Specify city name, description, location
  3. Founder receives 20% tokens (640,000) on 12-month vest
  4. City treasury receives 50% tokens (1,600,000)

  Returns `{:ok, city, founder_citizen}`.
  """
  @spec found(String.t(), map(), binary(), non_neg_integer(), keyword()) ::
    {:ok, City.t(), Citizen.t()} | {:error, atom()}
  def found(name, location, founder_pubkey, block_height, opts \\ []) do
    stake_amount = Keyword.get(opts, :stake_amount, @founding_stake)
    stake_txid = Keyword.get(opts, :stake_txid)
    description = Keyword.get(opts, :description, "")
    policies = Keyword.get(opts, :policies, %{})

    cond do
      stake_amount < @founding_stake ->
        {:error, :insufficient_stake}

      byte_size(name) > 50 ->
        {:error, :name_too_long}

      true ->
        territory_id = derive_territory_id(location, founder_pubkey)
        city_id = derive_city_id(territory_id, founder_pubkey, block_height)

        city = %City{
          id: city_id,
          name: name,
          description: description,
          territory_id: territory_id,
          founder_pubkey: founder_pubkey,
          founded_at: block_height,
          founding_txid: stake_txid,
          phase: :genesis,
          citizens: [founder_pubkey],
          citizen_count: 1,
          treasury_bsv: stake_amount,
          treasury_tokens: City.treasury_token_allocation(),
          token_supply: City.total_token_supply(),
          founder_tokens_total: City.founder_token_allocation(),
          founder_tokens_vested: 0,
          territories: [territory_id],
          blocks_unlocked: Fibonacci.blocks_for_citizens(1),
          location: location,
          policies: policies
        }

        founder = %Citizen{
          pubkey: founder_pubkey,
          city_id: city_id,
          joined_at: block_height,
          stake_amount: stake_amount,
          stake_txid: stake_txid,
          lock_height: block_height + @lock_period,
          token_balance: 0,
          status: :active
        }

        {:ok, city, founder}
    end
  end

  @doc """
  Add a citizen to a city.

  Per spec 02-city-lifecycle.md:
  - Anyone can join (if immigration_policy = "open")
  - Joining may trigger phase transition based on new citizen count
  - New blocks may unlock via Fibonacci

  Returns `{:ok, updated_city, citizen}`.
  """
  @spec add_citizen(City.t(), binary(), non_neg_integer(), keyword()) ::
    {:ok, City.t(), Citizen.t()} | {:error, atom()}
  def add_citizen(%City{} = city, citizen_pubkey, block_height, opts \\ []) do
    stake_amount = Keyword.get(opts, :stake_amount, 0)
    stake_txid = Keyword.get(opts, :stake_txid)

    cond do
      citizen_pubkey in city.citizens ->
        {:error, :already_citizen}

      true ->
        new_count = city.citizen_count + 1

        citizen = %Citizen{
          pubkey: citizen_pubkey,
          city_id: city.id,
          joined_at: block_height,
          stake_amount: stake_amount,
          stake_txid: stake_txid,
          lock_height: block_height + @lock_period,
          status: :active
        }

        updated_city = %{city |
          citizens: [citizen_pubkey | city.citizens],
          citizen_count: new_count,
          phase: Fibonacci.phase_for_citizens(new_count),
          blocks_unlocked: Fibonacci.blocks_for_citizens(new_count)
        }

        {:ok, updated_city, citizen}
    end
  end

  @doc """
  Remove a citizen from a city. Cannot remove the founder.

  Per spec 02-city-lifecycle.md:
  - City dies if citizen count drops to 0
  - Phase may revert if citizen count drops below threshold
  """
  @spec remove_citizen(City.t(), binary(), binary()) ::
    {:ok, City.t()} | {:error, atom()}
  def remove_citizen(%City{} = city, citizen_pubkey, requester_pubkey) do
    governance = Fibonacci.governance_for_phase(city.phase)

    cond do
      citizen_pubkey == city.founder_pubkey ->
        {:error, :cannot_remove_founder}

      citizen_pubkey not in city.citizens ->
        {:error, :not_citizen}

      requester_pubkey != citizen_pubkey and
        governance == :founder and
        requester_pubkey != city.founder_pubkey ->
        {:error, :unauthorized}

      true ->
        new_count = city.citizen_count - 1

        # Per spec: once unlocked, blocks stay unlocked (no reverse)
        # But phase CAN drop based on current citizen count
        new_phase = Fibonacci.phase_for_citizens(new_count)

        updated_city = %{city |
          citizens: List.delete(city.citizens, citizen_pubkey),
          citizen_count: new_count,
          phase: new_phase
          # blocks_unlocked stays the same (no reverse per spec)
        }
        {:ok, updated_city}
    end
  end

  @doc """
  Calculate vested founder tokens.

  Per spec 02-city-lifecycle.md:
  - 640,000 tokens (20%) vest linearly over 12 months
  - 1/12th unlocks each month (~4,320 blocks per month at 144/day)

  Returns number of tokens vested so far.
  """
  @spec founder_vested_tokens(City.t(), non_neg_integer()) :: non_neg_integer()
  def founder_vested_tokens(%City{} = city, current_height) do
    blocks_per_month = 144 * 30  # ~4,320 blocks
    blocks_elapsed = max(0, current_height - city.founded_at)
    months_elapsed = min(12, div(blocks_elapsed, blocks_per_month))
    div(city.founder_tokens_total * months_elapsed, 12)
  end

  @doc """
  Check if UBI is active for this city.

  Per spec 02-city-lifecycle.md:
  UBI activates at Phase 4 (:city) with 21+ citizens.
  """
  @spec ubi_active?(City.t()) :: boolean()
  def ubi_active?(%City{} = city) do
    city.phase in [:city, :metropolis]
  end

  @doc """
  Get the governance type for this city's current phase.
  """
  @spec governance_type(City.t()) :: atom()
  def governance_type(%City{} = city) do
    Fibonacci.governance_for_phase(city.phase)
  end

  @doc """
  Claim a territory for the city.
  """
  @spec claim_territory(City.t(), binary(), binary()) ::
    {:ok, City.t()} | {:error, atom()}
  def claim_territory(%City{} = city, territory_id, claimer_pubkey) do
    cond do
      claimer_pubkey not in city.citizens ->
        {:error, :not_citizen}

      territory_id in city.territories ->
        {:error, :already_claimed}

      true ->
        {:ok, %{city | territories: [territory_id | city.territories]}}
    end
  end

  @doc """
  Check city death conditions.

  Per spec 02-city-lifecycle.md, a city dies if:
  1. Citizen count drops to 0
  2. Founder heartbeat expires (12 months)
  3. Unanimous dissolution vote
  """
  @spec dead?(City.t()) :: boolean()
  def dead?(%City{citizen_count: 0}), do: true
  def dead?(_city), do: false

  @doc "Derive a unique city ID from founding parameters."
  @spec derive_city_id(binary(), binary(), non_neg_integer()) :: binary()
  def derive_city_id(territory_id, founder_pubkey, block_height) do
    data = territory_id <> founder_pubkey <> <<block_height::64>>
    :crypto.hash(:sha256, data)
  end

  defp derive_territory_id(location, founder_pubkey) do
    h3 = Map.get(location, :h3_res7) || Map.get(location, "h3_res7", "")
    lat = Map.get(location, :lat) || Map.get(location, "lat", 0)
    lng = Map.get(location, :lng) || Map.get(location, "lng", 0)
    data = "#{h3}:#{lat}:#{lng}" <> founder_pubkey
    :crypto.hash(:sha256, data)
  end
end
