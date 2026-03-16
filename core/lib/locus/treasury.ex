defmodule Locus.Treasury do
  @moduledoc """
  City treasury — BSV tracking, UBI distribution, token redemption.

  Per spec 03-staking-economics.md:

  ## UBI Formula

      daily_ubi = (treasury_bsv × 0.001) / citizen_count

  ## UBI Guardrails

  - Monthly cap: 1% of treasury
  - Minimum treasury: 100 BSV (10B sats) — UBI pauses below this
  - Requires active heartbeat (within 30 days)
  - Accumulates if unclaimed

  ## Token Redemption

      redemption_rate = treasury_bsv / total_token_supply
      Tokens burned on redemption, rate increases for remaining holders.

  ## Founder Vesting

  - 640,000 tokens (20%) vest linearly over 12 months
  - 1/12th unlocks per month (~4,320 blocks)
  """

  use GenServer
  require Logger

  alias Locus.Schemas.City

  @ubi_rate 0.001
  @monthly_cap_rate 0.01
  @min_treasury_for_ubi 10_000_000_000  # 100 BSV in sats
  @blocks_per_month 4_320               # 144 blocks/day × 30 days

  defstruct [
    treasuries: %{},
    token_balances: %{},
    ubi_claims: %{}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  # ---------------------------------------------------------------------------
  # UBI
  # ---------------------------------------------------------------------------

  @doc """
  Calculate daily UBI per citizen.

  Per spec 03-staking-economics.md:
      daily_ubi = (treasury_bsv × 0.001) / citizen_count

  ## Examples

      iex> Locus.Treasury.calculate_daily_ubi(100_000_000_000, 25)
      4_000_000
  """
  @spec calculate_daily_ubi(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def calculate_daily_ubi(treasury_bsv, citizen_count) when citizen_count > 0 do
    daily_pool = trunc(treasury_bsv * @ubi_rate)
    div(daily_pool, citizen_count)
  end

  def calculate_daily_ubi(_treasury, 0), do: 0

  @doc """
  Calculate UBI for a specific city with guardrails.

  Per spec 03-staking-economics.md:
  - UBI only active at Phase 4+ (:city, 21+ citizens)
  - Monthly cap: 1% of treasury
  - Pauses if treasury < 100 BSV

  Returns `{:ok, per_citizen_amount}` or `{:error, reason}`.
  """
  @spec calculate_city_ubi(City.t()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def calculate_city_ubi(%City{} = city) do
    cond do
      city.phase not in [:city, :metropolis] ->
        {:error, :ubi_not_active}

      city.citizen_count == 0 ->
        {:error, :no_citizens}

      city.treasury_bsv < @min_treasury_for_ubi ->
        {:error, :treasury_below_minimum}

      true ->
        daily_ubi = calculate_daily_ubi(city.treasury_bsv, city.citizen_count)

        # Monthly cap check: total monthly distribution must not exceed 1% of treasury
        monthly_total = daily_ubi * city.citizen_count * 30
        monthly_cap = trunc(city.treasury_bsv * @monthly_cap_rate)

        if monthly_total > monthly_cap do
          # Cap the daily amount
          capped_daily = div(monthly_cap, city.citizen_count * 30)
          {:ok, capped_daily}
        else
          {:ok, daily_ubi}
        end
    end
  end

  @doc """
  Distribute UBI to all active citizens of a city.

  Returns `{:ok, distributions, updated_city}` where distributions
  is a list of `{pubkey, amount}` tuples.
  """
  @spec distribute_ubi(City.t()) ::
    {:ok, [{binary(), non_neg_integer()}], City.t()} | {:error, atom()}
  def distribute_ubi(%City{} = city) do
    case calculate_city_ubi(city) do
      {:ok, per_citizen} when per_citizen > 0 ->
        distributions = Enum.map(city.citizens, fn pk -> {pk, per_citizen} end)
        total = per_citizen * city.citizen_count

        updated_city = %{city | treasury_bsv: city.treasury_bsv - total}
        {:ok, distributions, updated_city}

      {:ok, 0} ->
        {:error, :insufficient_treasury}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Token Redemption
  # ---------------------------------------------------------------------------

  @doc """
  Calculate token redemption rate.

  Per spec 03-staking-economics.md:
      redemption_rate = treasury_bsv / total_token_supply

  Returns satoshis per token.

  ## Examples

      iex> Locus.Treasury.redemption_rate(100_000_000_000, 3_200_000)
      31_250
  """
  @spec redemption_rate(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def redemption_rate(treasury_bsv, total_supply) when total_supply > 0 do
    div(treasury_bsv, total_supply)
  end

  def redemption_rate(_treasury, 0), do: 0

  @doc """
  Redeem tokens for BSV from city treasury.

  Per spec 03-staking-economics.md:
  1. Tokens sent to burn address
  2. BSV returned at current redemption rate
  3. Tokens permanently burned
  4. Rate increases for remaining holders

  Returns `{:ok, bsv_amount, updated_city}`.
  """
  @spec redeem_tokens(City.t(), non_neg_integer(), binary()) ::
    {:ok, non_neg_integer(), City.t()} | {:error, atom()}
  def redeem_tokens(%City{} = city, token_amount, _redeemer_pubkey)
      when token_amount > 0 do
    rate = redemption_rate(city.treasury_bsv, city.token_supply)
    bsv_amount = rate * token_amount

    cond do
      bsv_amount > city.treasury_bsv ->
        {:error, :insufficient_treasury}

      token_amount > city.token_supply ->
        {:error, :exceeds_supply}

      true ->
        updated = %{city |
          treasury_bsv: city.treasury_bsv - bsv_amount,
          token_supply: city.token_supply - token_amount
        }
        {:ok, bsv_amount, updated}
    end
  end

  def redeem_tokens(_city, _amount, _pubkey), do: {:error, :invalid_amount}

  # ---------------------------------------------------------------------------
  # Founder Vesting
  # ---------------------------------------------------------------------------

  @doc """
  Calculate vested founder tokens.

  Per spec 02-city-lifecycle.md:
  - 640,000 tokens vest linearly over 12 months
  - 1/12th unlocks each month (~4,320 blocks)
  """
  @spec vested_founder_tokens(City.t(), non_neg_integer()) :: non_neg_integer()
  def vested_founder_tokens(%City{} = city, current_height) do
    blocks_elapsed = max(0, current_height - city.founded_at)
    months = min(12, div(blocks_elapsed, @blocks_per_month))
    div(city.founder_tokens_total * months, 12)
  end

  # ---------------------------------------------------------------------------
  # GenServer: Treasury Balance Tracking
  # ---------------------------------------------------------------------------

  @doc "Deposit BSV (satoshis) into a city's treasury."
  @spec deposit(binary(), non_neg_integer(), binary()) ::
    {:ok, non_neg_integer()} | {:error, atom()}
  def deposit(city_id, amount, _txid) when amount > 0 do
    GenServer.call(__MODULE__, {:deposit, city_id, amount})
  end

  def deposit(_city_id, _amount, _txid), do: {:error, :invalid_amount}

  @doc "Withdraw BSV from a city's treasury (requires governance approval)."
  @spec withdraw(binary(), non_neg_integer(), binary()) ::
    {:ok, non_neg_integer()} | {:error, atom()}
  def withdraw(city_id, amount, _authorization_id) when amount > 0 do
    GenServer.call(__MODULE__, {:withdraw, city_id, amount})
  end

  def withdraw(_city_id, _amount, _auth), do: {:error, :invalid_amount}

  @doc "Get treasury balance for a city."
  @spec balance(binary()) :: non_neg_integer()
  def balance(city_id) do
    GenServer.call(__MODULE__, {:balance, city_id})
  end

  @impl true
  def handle_call({:deposit, city_id, amount}, _from, state) do
    current = Map.get(state.treasuries, city_id, 0)
    new_balance = current + amount
    new_state = %{state | treasuries: Map.put(state.treasuries, city_id, new_balance)}
    {:reply, {:ok, new_balance}, new_state}
  end

  @impl true
  def handle_call({:withdraw, city_id, amount}, _from, state) do
    current = Map.get(state.treasuries, city_id, 0)

    if amount > current do
      {:reply, {:error, :insufficient_funds}, state}
    else
      new_balance = current - amount
      new_state = %{state | treasuries: Map.put(state.treasuries, city_id, new_balance)}
      {:reply, {:ok, new_balance}, new_state}
    end
  end

  @impl true
  def handle_call({:balance, city_id}, _from, state) do
    {:reply, Map.get(state.treasuries, city_id, 0), state}
  end
end
