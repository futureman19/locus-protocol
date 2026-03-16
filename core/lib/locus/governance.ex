defmodule Locus.Governance do
  @moduledoc """
  City governance — proposals, voting, and execution.

  ## Governance Eras

  **Genesis Era** — Founder has unilateral decision-making power.
  All proposals are auto-approved by the founder. This era exists
  to bootstrap cities before they have enough citizens for democracy.

  **Federal Era** — Triggered when citizen count reaches the threshold
  (default: 21 citizens). Proposals require majority vote with quorum.

  ## Proposal Lifecycle

      pending → active → passed/rejected → executed/expired

  In Genesis era: pending → executed (founder approval only)
  In Federal era: pending → active → (voting period) → passed/rejected → executed
  """

  use GenServer

  require Logger

  alias Locus.Schemas.{City, Proposal}

  defstruct [
    proposals: %{},
    votes: %{}
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
  Create a new proposal for a city.

  In Genesis era, only the founder can propose.
  In Federal era, any citizen can propose.
  """
  @spec create_proposal(City.t(), binary(), map()) ::
    {:ok, Proposal.t()} | {:error, atom()}
  def create_proposal(%City{} = city, proposer_pubkey, params) do
    cond do
      not can_propose?(city, proposer_pubkey) ->
        {:error, :unauthorized}

      not valid_proposal_type?(params[:proposal_type]) ->
        {:error, :invalid_proposal_type}

      true ->
        proposal = build_proposal(city, proposer_pubkey, params)

        case city.governance_era do
          :genesis ->
            # In Genesis era, founder proposals are auto-passed
            proposal = %{proposal | status: :passed}
            GenServer.call(__MODULE__, {:store_proposal, proposal})
            {:ok, proposal}

          :federal ->
            proposal = %{proposal | status: :active}
            GenServer.call(__MODULE__, {:store_proposal, proposal})
            {:ok, proposal}
        end
    end
  end

  @doc """
  Cast a vote on an active proposal.

  Only citizens of the proposal's city can vote. Each citizen gets one vote.
  """
  @spec vote(binary(), binary(), City.t(), boolean()) ::
    {:ok, Proposal.t()} | {:error, atom()}
  def vote(proposal_id, voter_pubkey, %City{} = city, approve?) do
    cond do
      city.governance_era != :federal ->
        {:error, :not_federal_era}

      voter_pubkey not in city.citizens ->
        {:error, :not_citizen}

      true ->
        GenServer.call(__MODULE__, {:vote, proposal_id, voter_pubkey, approve?})
    end
  end

  @doc """
  Tally votes and determine if a proposal has passed.

  A proposal passes if:
  - votes_for > votes_against (simple majority)
  - total votes >= quorum (default 51% of citizens)
  """
  @spec tally(Proposal.t(), City.t()) :: :passed | :rejected | :pending
  def tally(%Proposal{} = proposal, %City{} = city) do
    quorum = Application.get_env(:locus_core, :quorum_percentage, 0.51)
    total_votes = proposal.votes_for + proposal.votes_against
    quorum_needed = ceil(city.citizen_count * quorum)

    cond do
      total_votes < quorum_needed -> :pending
      proposal.votes_for > proposal.votes_against -> :passed
      true -> :rejected
    end
  end

  @doc """
  Execute a passed proposal.

  Returns `{:ok, updated_proposal}` with execution details.
  """
  @spec execute(Proposal.t(), non_neg_integer(), keyword()) ::
    {:ok, Proposal.t()} | {:error, atom()}
  def execute(%Proposal{} = proposal, current_height, opts \\ []) do
    execution_txid = Keyword.get(opts, :txid)

    cond do
      proposal.status != :passed ->
        {:error, :not_passed}

      true ->
        executed = %{proposal |
          status: :executed,
          executed_at: current_height,
          execution_txid: execution_txid
        }
        GenServer.call(__MODULE__, {:store_proposal, executed})
        {:ok, executed}
    end
  end

  @doc """
  Check and expire proposals that have exceeded their voting period.
  """
  @spec expire_proposals(binary(), non_neg_integer()) :: [Proposal.t()]
  def expire_proposals(city_id, current_height) do
    GenServer.call(__MODULE__, {:expire_proposals, city_id, current_height})
  end

  @doc """
  Check if a pubkey can propose in the given city.
  """
  @spec can_propose?(City.t(), binary()) :: boolean()
  def can_propose?(%City{governance_era: :genesis} = city, pubkey) do
    pubkey == city.founder_pubkey
  end

  def can_propose?(%City{governance_era: :federal} = city, pubkey) do
    pubkey in city.citizens
  end

  @doc """
  Check if a pubkey can vote in the given city.
  """
  @spec can_vote?(City.t(), binary()) :: boolean()
  def can_vote?(%City{governance_era: :federal} = city, pubkey) do
    pubkey in city.citizens
  end

  def can_vote?(%City{governance_era: :genesis}, _pubkey), do: false

  @doc """
  Get a proposal by ID.
  """
  @spec get_proposal(binary()) :: {:ok, Proposal.t()} | {:error, :not_found}
  def get_proposal(proposal_id) do
    GenServer.call(__MODULE__, {:get_proposal, proposal_id})
  end

  @doc """
  List all proposals for a city.
  """
  @spec list_proposals(binary()) :: [Proposal.t()]
  def list_proposals(city_id) do
    GenServer.call(__MODULE__, {:list_proposals, city_id})
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def handle_call({:store_proposal, proposal}, _from, state) do
    new_state = %{state |
      proposals: Map.put(state.proposals, proposal.id, proposal)
    }
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:vote, proposal_id, voter_pubkey, approve?}, _from, state) do
    case Map.get(state.proposals, proposal_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %Proposal{status: :active} = proposal ->
        if voter_pubkey in proposal.voters do
          {:reply, {:error, :already_voted}, state}
        else
          updated = if approve? do
            %{proposal |
              votes_for: proposal.votes_for + 1,
              voters: [voter_pubkey | proposal.voters]
            }
          else
            %{proposal |
              votes_against: proposal.votes_against + 1,
              voters: [voter_pubkey | proposal.voters]
            }
          end

          new_state = %{state |
            proposals: Map.put(state.proposals, proposal_id, updated)
          }
          {:reply, {:ok, updated}, new_state}
        end

      %Proposal{} ->
        {:reply, {:error, :not_active}, state}
    end
  end

  @impl true
  def handle_call({:expire_proposals, city_id, current_height}, _from, state) do
    {expired, updated_proposals} =
      state.proposals
      |> Enum.reduce({[], state.proposals}, fn {id, proposal}, {expired_list, proposals} ->
        if proposal.city_id == city_id and
           proposal.status == :active and
           current_height >= proposal.expires_at do
          expired_proposal = %{proposal | status: :expired}
          {[expired_proposal | expired_list], Map.put(proposals, id, expired_proposal)}
        else
          {expired_list, proposals}
        end
      end)

    new_state = %{state | proposals: updated_proposals}
    {:reply, expired, new_state}
  end

  @impl true
  def handle_call({:get_proposal, proposal_id}, _from, state) do
    case Map.get(state.proposals, proposal_id) do
      nil -> {:reply, {:error, :not_found}, state}
      proposal -> {:reply, {:ok, proposal}, state}
    end
  end

  @impl true
  def handle_call({:list_proposals, city_id}, _from, state) do
    proposals =
      state.proposals
      |> Map.values()
      |> Enum.filter(fn p -> p.city_id == city_id end)
      |> Enum.sort_by(fn p -> p.created_at end, :desc)

    {:reply, proposals, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp build_proposal(%City{} = city, proposer_pubkey, params) do
    duration = Application.get_env(:locus_core, :proposal_duration_blocks, 4_320)
    created_at = Map.get(params, :current_height, 0)

    %Proposal{
      id: derive_proposal_id(city.id, proposer_pubkey, created_at),
      city_id: city.id,
      proposer_pubkey: proposer_pubkey,
      proposal_type: params[:proposal_type],
      title: params[:title] || "",
      description: params[:description] || "",
      params: Map.get(params, :params, %{}),
      created_at: created_at,
      expires_at: created_at + duration
    }
  end

  defp derive_proposal_id(city_id, proposer_pubkey, created_at) do
    data = city_id <> proposer_pubkey <> <<created_at::64>>
    :crypto.hash(:sha256, data)
  end

  defp valid_proposal_type?(type) do
    type in Proposal.proposal_types()
  end
end
