defmodule Locus.City do
  @moduledoc """
  City lifecycle management — the primary primitive of Locus Protocol.

  Cities are founded on territories, progress through 6 Fibonacci-gated
  phases, and manage citizens who stake BSV to participate.

  ## Founding

  A city is founded by locking BSV to a territory via a CLTV-locked
  stake transaction. The founder becomes the first citizen and the
  city enters the Genesis governance era.

  ## Phase Progression

  Phase transitions are checked against block height using Fibonacci
  unlock calculations. Each phase enables new capabilities:

      Founded      → City exists, founder can claim territories
      Settled      → Citizens can join
      Established  → Basic governance
      Thriving     → Treasury active, UBI distribution begins
      Metropolitan → Multi-district expansion enabled
      Sovereign    → Full Federal governance, self-sovereignty
  """

  alias Locus.Schemas.{City, Citizen}
  alias Locus.{Fibonacci, Territory}

  @doc """
  Found a new city on a territory.

  Returns `{:ok, city, citizen}` with the founder as the first citizen.

  ## Parameters

    - `name` — City name
    - `territory_id` — Geo-IPv6 address of founding territory
    - `founder_pubkey` — Founder's public key
    - `block_height` — Current block height
    - `opts` — Optional: `:stake_amount`, `:stake_txid`, `:metadata`
  """
  @spec found(String.t(), binary(), binary(), non_neg_integer(), keyword()) ::
    {:ok, City.t(), Citizen.t()} | {:error, atom()}
  def found(name, territory_id, founder_pubkey, block_height, opts \\ []) do
    stake_amount = Keyword.get(opts, :stake_amount, 0)
    stake_txid = Keyword.get(opts, :stake_txid)
    metadata = Keyword.get(opts, :metadata, %{})

    min_stake = Application.get_env(:locus_core, :min_founding_stake, 1_000_000)

    if stake_amount < min_stake do
      {:error, :insufficient_stake}
    else
      city_id = derive_city_id(territory_id, founder_pubkey, block_height)

      city = %City{
        id: city_id,
        name: name,
        territory_id: territory_id,
        founder_pubkey: founder_pubkey,
        founded_at: block_height,
        founding_txid: stake_txid,
        phase: :founded,
        phase_changed_at: block_height,
        citizens: [founder_pubkey],
        citizen_count: 1,
        treasury_balance: 0,
        territories: [territory_id],
        governance_era: :genesis,
        metadata: metadata
      }

      founder = %Citizen{
        pubkey: founder_pubkey,
        city_id: city_id,
        joined_at: block_height,
        stake_amount: stake_amount,
        stake_txid: stake_txid,
        lock_height: block_height + lock_period(),
        status: :active
      }

      {:ok, city, founder}
    end
  end

  @doc """
  Add a citizen to a city.

  The city must be at least in the Settled phase (phase 2+).
  Returns `{:ok, updated_city, citizen}` or `{:error, reason}`.
  """
  @spec add_citizen(City.t(), binary(), non_neg_integer(), keyword()) ::
    {:ok, City.t(), Citizen.t()} | {:error, atom()}
  def add_citizen(%City{} = city, citizen_pubkey, block_height, opts \\ []) do
    stake_amount = Keyword.get(opts, :stake_amount, 0)
    stake_txid = Keyword.get(opts, :stake_txid)

    cond do
      City.phase_index(city.phase) < 2 ->
        {:error, :city_not_settled}

      citizen_pubkey in city.citizens ->
        {:error, :already_citizen}

      true ->
        citizen = %Citizen{
          pubkey: citizen_pubkey,
          city_id: city.id,
          joined_at: block_height,
          stake_amount: stake_amount,
          stake_txid: stake_txid,
          lock_height: block_height + lock_period(),
          status: :active
        }

        updated_city = %{city |
          citizens: [citizen_pubkey | city.citizens],
          citizen_count: city.citizen_count + 1
        }

        {:ok, updated_city, citizen}
    end
  end

  @doc """
  Remove a citizen from a city. Cannot remove the founder.
  """
  @spec remove_citizen(City.t(), binary(), binary()) ::
    {:ok, City.t()} | {:error, atom()}
  def remove_citizen(%City{} = city, citizen_pubkey, requester_pubkey) do
    cond do
      citizen_pubkey == city.founder_pubkey ->
        {:error, :cannot_remove_founder}

      citizen_pubkey not in city.citizens ->
        {:error, :not_citizen}

      requester_pubkey != citizen_pubkey and
        requester_pubkey != city.founder_pubkey and
        city.governance_era == :genesis ->
        {:error, :unauthorized}

      true ->
        updated_city = %{city |
          citizens: List.delete(city.citizens, citizen_pubkey),
          citizen_count: city.citizen_count - 1
        }
        {:ok, updated_city}
    end
  end

  @doc """
  Check if a city is eligible for the next phase transition.

  Returns `{:ok, next_phase}` or `{:error, reason}`.
  """
  @spec check_phase_transition(City.t(), non_neg_integer()) ::
    {:ok, atom()} | {:error, atom()}
  def check_phase_transition(%City{} = city, current_height) do
    next = City.next_phase(city.phase)

    cond do
      next == nil ->
        {:error, :already_sovereign}

      true ->
        blocks_elapsed = current_height - city.founded_at
        next_index = City.phase_index(next)
        required = Fibonacci.phase_threshold(next_index)

        if blocks_elapsed >= required do
          {:ok, next}
        else
          {:error, :not_enough_blocks}
        end
    end
  end

  @doc """
  Advance a city to the next phase if eligible.

  Returns `{:ok, updated_city}` or `{:error, reason}`.
  """
  @spec advance_phase(City.t(), non_neg_integer()) ::
    {:ok, City.t()} | {:error, atom()}
  def advance_phase(%City{} = city, current_height) do
    case check_phase_transition(city, current_height) do
      {:ok, next_phase} ->
        updated = %{city |
          phase: next_phase,
          phase_changed_at: current_height
        }
        {:ok, updated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Advance a city through all eligible phases at once.

  Useful when catching up after many blocks have passed.
  """
  @spec advance_all_phases(City.t(), non_neg_integer()) :: City.t()
  def advance_all_phases(%City{} = city, current_height) do
    case advance_phase(city, current_height) do
      {:ok, updated} -> advance_all_phases(updated, current_height)
      {:error, _} -> city
    end
  end

  @doc """
  Claim a new territory for the city.

  The claiming citizen pays progressive tax based on how many
  territories they already hold.
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
        updated = %{city |
          territories: [territory_id | city.territories]
        }
        {:ok, updated}
    end
  end

  @doc """
  Get the block height at which a specific phase unlocks for this city.
  """
  @spec phase_unlock_height(City.t(), City.phase()) :: non_neg_integer()
  def phase_unlock_height(%City{} = city, phase) do
    phase_index = City.phase_index(phase)
    Fibonacci.unlock_height(city.founded_at, phase_index)
  end

  @doc """
  Check if city should transition from Genesis to Federal governance era.

  Transition happens when citizen_count >= federal_transition_citizens (default 21).
  """
  @spec check_federal_transition(City.t()) :: {:ok, City.t()} | {:error, atom()}
  def check_federal_transition(%City{governance_era: :federal} = city) do
    {:error, :already_federal}
  end

  def check_federal_transition(%City{} = city) do
    threshold = Application.get_env(:locus_core, :federal_transition_citizens, 21)

    if city.citizen_count >= threshold do
      {:ok, %{city | governance_era: :federal}}
    else
      {:error, :insufficient_citizens}
    end
  end

  @doc "Derive a unique city ID from founding parameters."
  @spec derive_city_id(binary(), binary(), non_neg_integer()) :: binary()
  def derive_city_id(territory_id, founder_pubkey, block_height) do
    data = territory_id <> founder_pubkey <> <<block_height::64>>
    :crypto.hash(:sha256, data)
  end

  defp lock_period do
    Application.get_env(:locus_core, :lock_period_blocks, 21_600)
  end
end
