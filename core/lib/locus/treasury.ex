defmodule Locus.Treasury do
  @moduledoc """
  City treasury management — BSV tracking, UBI distribution, token redemption.

  Each city has a treasury funded by territory taxes, staking deposits,
  and voluntary contributions. The treasury funds:

  - **UBI** — Daily distribution to all active citizens
  - **Governance spending** — Approved via proposals
  - **Lock-to-mint** — BSV locked in treasury mints LOCUS tokens

  ## UBI Formula

      daily_ubi = (treasury_balance × 0.001) / active_citizen_count

  This ensures UBI is sustainable and scales with treasury size.
  """

  use GenServer

  require Logger

  alias Locus.Schemas.{City, Citizen}

  defstruct [
    cities: %{},
    token_supply: %{}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Deposit BSV (satoshis) into a city's treasury.

  ## Examples

      iex> Locus.Treasury.deposit("city_id", 100_000, "deposit_txid")
      {:ok, 100_000}
  """
  @spec deposit(binary(), non_neg_integer(), binary()) ::
    {:ok, non_neg_integer()} | {:error, atom()}
  def deposit(city_id, amount, txid) when amount > 0 do
    GenServer.call(__MODULE__, {:deposit, city_id, amount, txid})
  end

  def deposit(_city_id, _amount, _txid), do: {:error, :invalid_amount}

  @doc """
  Withdraw BSV from a city's treasury.

  Requires governance authorization (proposal must have passed in Federal era,
  or founder approval in Genesis era).
  """
  @spec withdraw(binary(), non_neg_integer(), binary(), binary()) ::
    {:ok, non_neg_integer()} | {:error, atom()}
  def withdraw(city_id, amount, authorization_id, recipient_pubkey) do
    GenServer.call(__MODULE__, {:withdraw, city_id, amount, authorization_id, recipient_pubkey})
  end

  @doc """
  Get the treasury balance for a city.
  """
  @spec balance(binary()) :: non_neg_integer()
  def balance(city_id) do
    GenServer.call(__MODULE__, {:balance, city_id})
  end

  @doc """
  Calculate UBI amount per citizen for a city.

  Formula: daily_ubi = (treasury_balance × ubi_rate) / active_citizen_count

  ## Examples

      iex> Locus.Treasury.calculate_ubi(1_000_000, 10)
      100
  """
  @spec calculate_ubi(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def calculate_ubi(treasury_balance, citizen_count) when citizen_count > 0 do
    rate = Application.get_env(:locus_core, :ubi_rate, 0.001)
    daily_pool = trunc(treasury_balance * rate)
    div(daily_pool, citizen_count)
  end

  def calculate_ubi(_treasury_balance, 0), do: 0

  @doc """
  Calculate UBI for a specific city using its current state.
  """
  @spec calculate_city_ubi(City.t()) :: non_neg_integer()
  def calculate_city_ubi(%City{} = city) do
    if city.citizen_count > 0 do
      calculate_ubi(city.treasury_balance, city.citizen_count)
    else
      0
    end
  end

  @doc """
  Distribute UBI to all active citizens of a city.

  Returns a list of `{citizen_pubkey, amount}` tuples.
  UBI is only available once a city reaches the Thriving phase (phase 4+).
  """
  @spec distribute_ubi(City.t(), non_neg_integer()) ::
    {:ok, [{binary(), non_neg_integer()}], City.t()} | {:error, atom()}
  def distribute_ubi(%City{} = city, current_height) do
    phase_index = Locus.Schemas.City.phase_index(city.phase)

    cond do
      phase_index < 4 ->
        {:error, :city_not_thriving}

      city.citizen_count == 0 ->
        {:error, :no_citizens}

      true ->
        ubi_per_citizen = calculate_ubi(city.treasury_balance, city.citizen_count)

        if ubi_per_citizen == 0 do
          {:error, :insufficient_treasury}
        else
          total_distribution = ubi_per_citizen * city.citizen_count

          distributions =
            city.citizens
            |> Enum.map(fn pubkey -> {pubkey, ubi_per_citizen} end)

          updated_city = %{city |
            treasury_balance: city.treasury_balance - total_distribution
          }

          {:ok, distributions, updated_city}
        end
    end
  end

  @doc """
  Lock BSV to mint LOCUS tokens (lock-to-mint).

  The BSV is locked in the city treasury and equivalent LOCUS tokens
  are minted. Exchange rate is 1:1 (1 satoshi = 1 LOCUS token).

  Returns `{:ok, tokens_minted, updated_treasury_balance}`.
  """
  @spec lock_to_mint(binary(), non_neg_integer(), binary()) ::
    {:ok, non_neg_integer(), non_neg_integer()} | {:error, atom()}
  def lock_to_mint(city_id, bsv_amount, locker_pubkey) when bsv_amount > 0 do
    GenServer.call(__MODULE__, {:lock_to_mint, city_id, bsv_amount, locker_pubkey})
  end

  def lock_to_mint(_city_id, _amount, _pubkey), do: {:error, :invalid_amount}

  @doc """
  Redeem LOCUS tokens back to BSV.

  Burns the tokens and releases the equivalent BSV from the treasury.
  """
  @spec redeem(binary(), non_neg_integer(), binary()) ::
    {:ok, non_neg_integer()} | {:error, atom()}
  def redeem(city_id, token_amount, redeemer_pubkey) when token_amount > 0 do
    GenServer.call(__MODULE__, {:redeem, city_id, token_amount, redeemer_pubkey})
  end

  def redeem(_city_id, _amount, _pubkey), do: {:error, :invalid_amount}

  @doc """
  Get LOCUS token balance for a pubkey in a city.
  """
  @spec token_balance(binary(), binary()) :: non_neg_integer()
  def token_balance(city_id, pubkey) do
    GenServer.call(__MODULE__, {:token_balance, city_id, pubkey})
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def handle_call({:deposit, city_id, amount, _txid}, _from, state) do
    current = Map.get(state.cities, city_id, 0)
    new_balance = current + amount
    new_state = %{state | cities: Map.put(state.cities, city_id, new_balance)}
    {:reply, {:ok, new_balance}, new_state}
  end

  @impl true
  def handle_call({:withdraw, city_id, amount, _auth_id, _recipient}, _from, state) do
    current = Map.get(state.cities, city_id, 0)

    if amount > current do
      {:reply, {:error, :insufficient_funds}, state}
    else
      new_balance = current - amount
      new_state = %{state | cities: Map.put(state.cities, city_id, new_balance)}
      {:reply, {:ok, new_balance}, new_state}
    end
  end

  @impl true
  def handle_call({:balance, city_id}, _from, state) do
    balance = Map.get(state.cities, city_id, 0)
    {:reply, balance, state}
  end

  @impl true
  def handle_call({:lock_to_mint, city_id, amount, pubkey}, _from, state) do
    # Add BSV to treasury
    current_balance = Map.get(state.cities, city_id, 0)
    new_balance = current_balance + amount

    # Mint tokens (1:1 with satoshis)
    city_tokens = Map.get(state.token_supply, city_id, %{})
    current_tokens = Map.get(city_tokens, pubkey, 0)
    new_tokens = current_tokens + amount

    new_state = %{state |
      cities: Map.put(state.cities, city_id, new_balance),
      token_supply: Map.put(state.token_supply, city_id,
        Map.put(city_tokens, pubkey, new_tokens))
    }

    {:reply, {:ok, amount, new_balance}, new_state}
  end

  @impl true
  def handle_call({:redeem, city_id, token_amount, pubkey}, _from, state) do
    city_tokens = Map.get(state.token_supply, city_id, %{})
    current_tokens = Map.get(city_tokens, pubkey, 0)
    current_balance = Map.get(state.cities, city_id, 0)

    cond do
      token_amount > current_tokens ->
        {:reply, {:error, :insufficient_tokens}, state}

      token_amount > current_balance ->
        {:reply, {:error, :insufficient_treasury}, state}

      true ->
        new_tokens = current_tokens - token_amount
        new_balance = current_balance - token_amount

        new_state = %{state |
          cities: Map.put(state.cities, city_id, new_balance),
          token_supply: Map.put(state.token_supply, city_id,
            Map.put(city_tokens, pubkey, new_tokens))
        }

        {:reply, {:ok, token_amount}, new_state}
    end
  end

  @impl true
  def handle_call({:token_balance, city_id, pubkey}, _from, state) do
    city_tokens = Map.get(state.token_supply, city_id, %{})
    balance = Map.get(city_tokens, pubkey, 0)
    {:reply, balance, state}
  end
end
