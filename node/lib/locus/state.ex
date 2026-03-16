defmodule Locus.State do
  @moduledoc """
  Protocol state machine

  Manages state transitions for ghosts based on blockchain events.
  """

  use GenServer

  require Logger

  alias Locus.{Ghost, Heartbeat, Challenge}

  @valid_transitions %{
    pending: [:active],
    active: [:inactive, :slashed, :retired],
    inactive: [:active, :slashed, :retired],
    slashed: [],
    retired: []
  }

  defstruct [
    :ghosts,
    :pending_txs,
    :active_challenges
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      ghosts: %{},
      pending_txs: %{},
      active_challenges: %{}
    }

    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Process a blockchain event and update ghost state
  """
  def process_event(event) do
    GenServer.call(__MODULE__, {:process_event, event})
  end

  @doc """
  Get ghost by ID
  """
  def get_ghost(ghost_id) do
    GenServer.call(__MODULE__, {:get_ghost, ghost_id})
  end

  @doc """
  List all ghosts
  """
  def list_ghosts do
    GenServer.call(__MODULE__, :list_ghosts)
  end

  @doc """
  List ghosts by state
  """
  def list_by_state(state) do
    GenServer.call(__MODULE__, {:list_by_state, state})
  end

  @doc """
  Get active challenges for a ghost
  """
  def get_challenges(ghost_id) do
    GenServer.call(__MODULE__, {:get_challenges, ghost_id})
  end

  # ----------------------------------------------------------------------------
  # GenServer Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def handle_call({:process_event, %{type: :ghost_register, data: data}}, _from, state) do
    ghost = %Ghost{
      id: data.ghost_id,
      name: data.name,
      type: int_to_type(data.type),
      lat: data.lat / 1_000_000,
      lng: data.lng / 1_000_000,
      h3_index: data.h3,
      stake_amount: data.stake_amt,
      lock_height: data.unlock_h,
      owner_pubkey: data.owner_pk,
      code_hash: data.code_hash,
      base_fee: data.base_fee,
      timeout: data.timeout,
      state: :pending,
      heartbeat_seq: 0,
      last_heartbeat: nil,
      created_at: DateTime.utc_now()
    }

    new_ghosts = Map.put(state.ghosts, ghost.id, ghost)
    new_state = %{state | ghosts: new_ghosts}

    Logger.info("Ghost registered: #{ghost.id} (#{ghost.name})")
    {:reply, {:ok, ghost}, new_state}
  end

  @impl true
  def handle_call({:process_event, %{type: :heartbeat, data: data}}, _from, state) do
    ghost_id = data.ghost_id

    case Map.get(state.ghosts, ghost_id) do
      nil ->
        {:reply, {:error, :ghost_not_found}, state}

      ghost ->
        # Validate sequence
        case Heartbeat.validate_sequence(ghost.heartbeat_seq, data.seq) do
          :ok ->
            new_ghost = %{ghost |
              heartbeat_seq: data.seq,
              last_heartbeat: DateTime.utc_now(),
              state: transition_state(ghost.state, :active)
            }

            new_ghosts = Map.put(state.ghosts, ghost_id, new_ghost)
            new_state = %{state | ghosts: new_ghosts}

            Logger.debug("Heartbeat received: #{ghost_id} seq=#{data.seq}")
            {:reply, {:ok, new_ghost}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:process_event, %{type: :challenge, data: data}}, _from, state) do
    ghost_id = data.ghost_id
    challenge_id = generate_challenge_id(ghost_id, data)

    challenge = %{
      id: challenge_id,
      ghost_id: ghost_id,
      type: int_to_challenge_type(data.type),
      evidence: data.evidence,
      challenger: data.challenger,
      created_at: DateTime.utc_now(),
      status: :pending
    }

    # Add to active challenges
    ghost_challenges = Map.get(state.active_challenges, ghost_id, [])
    new_challenges = Map.put(state.active_challenges, ghost_id, [challenge | ghost_challenges])

    # Update ghost state
    case Map.get(state.ghosts, ghost_id) do
      nil ->
        {:reply, {:error, :ghost_not_found}, state}

      ghost ->
        new_ghost = %{ghost | state: :inactive}
        new_ghosts = Map.put(state.ghosts, ghost_id, new_ghost)

        new_state = %{state |
          ghosts: new_ghosts,
          active_challenges: new_challenges
        }

        Logger.info("Challenge filed: #{challenge_id} against #{ghost_id}")
        {:reply, {:ok, challenge}, new_state}
    end
  end

  @impl true
  def handle_call({:process_event, %{type: :challenge_response, data: data}}, _from, state) do
    challenge_id = data.challenge_id

    # Find and update challenge
    {found, new_challenges} = find_and_update_challenge(
      state.active_challenges,
      challenge_id,
      data
    )

    if found do
      new_state = %{state | active_challenges: new_challenges}
      {:reply, {:ok, :responded}, new_state}
    else
      {:reply, {:error, :challenge_not_found}, state}
    end
  end

  @impl true
  def handle_call({:process_event, %{type: :ghost_retire, data: data}}, _from, state) do
    ghost_id = data.ghost_id

    case Map.get(state.ghosts, ghost_id) do
      nil ->
        {:reply, {:error, :ghost_not_found}, state}

      ghost ->
        new_ghost = %{ghost | state: :retired}
        new_ghosts = Map.put(state.ghosts, ghost_id, new_ghost)
        new_state = %{state | ghosts: new_ghosts}

        Logger.info("Ghost retired: #{ghost_id}")
        {:reply, {:ok, new_ghost}, new_state}
    end
  end

  @impl true
  def handle_call({:get_ghost, ghost_id}, _from, state) do
    {:reply, Map.get(state.ghosts, ghost_id), state}
  end

  @impl true
  def handle_call(:list_ghosts, _from, state) do
    {:reply, Map.values(state.ghosts), state}
  end

  @impl true
  def handle_call({:list_by_state, target_state}, _from, state) do
    ghosts = state.ghosts
    |> Map.values()
    |> Enum.filter(fn g -> g.state == target_state end)

    {:reply, ghosts, state}
  end

  @impl true
  def handle_call({:get_challenges, ghost_id}, _from, state) do
    challenges = Map.get(state.active_challenges, ghost_id, [])
    {:reply, challenges, state}
  end

  # ----------------------------------------------------------------------------
  # Private Functions
  # ----------------------------------------------------------------------------

  defp transition_state(current, target) do
    allowed = Map.get(@valid_transitions, current, [])

    if target in allowed do
      target
    else
      current
    end
  end

  defp int_to_type(1), do: :greeter
  defp int_to_type(2), do: :oracle
  defp int_to_type(3), do: :guardian
  defp int_to_type(4), do: :merchant
  defp int_to_type(5), do: :custom
  defp int_to_type(_), do: :custom

  defp int_to_challenge_type(1), do: :no_show
  defp int_to_challenge_type(2), do: :fraud
  defp int_to_challenge_type(3), do: :malfunction
  defp int_to_challenge_type(4), do: :timeout
  defp int_to_challenge_type(_), do: :unknown

  defp generate_challenge_id(ghost_id, data) do
    input = "#{ghost_id}:#{data.challenger}:#{data.ts}"
    :crypto.hash(:sha256, input) |> Base.encode16(case: :lower)
  end

  defp find_and_update_challenge(challenges_map, challenge_id, response_data) do
    found = refute false

    new_map = Enum.map(challenges_map, fn {ghost_id, challenges} ->
      new_challenges = Enum.map(challenges, fn c ->
        if c.id == challenge_id do
          found = true
          %{c |
            status: :responded,
            response: response_data,
            responded_at: DateTime.utc_now()
          }
        else
          c
        end
      end)

      {ghost_id, new_challenges}
    end)
    |> Enum.into(%{})

    {found, new_map}
  end
end
