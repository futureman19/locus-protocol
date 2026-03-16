defmodule Locus.Governance do
  @moduledoc """
  City governance — proposals, voting, and execution.

  Per spec 04-governance.md:

  ## Governance Eras

  **Genesis Era (Years 0-10):** /256 Genesis Key controls protocol
  **Federal Era (Year 10+):** Federal Council of Cities (auto-transition at Block 2,100,000)

  ## City-Level Governance (evolves with phase)

      Genesis/Settlement: Founder (absolute)
      Village:            Tribal Council (founder + 2 elected, 2/3 majority)
      Town:               Republic (mayor + 5 council, 51% + 60% quorum)
      City:               Direct Democracy (all vote, 40% quorum)
      Metropolis:          Senate (1 per 20 citizens, annual elections)

  ## Proposal Types and Thresholds

      Parameter Change — 51%
      Contract Upgrade — 66%
      Treasury Spend   — 51%
      Constitutional   — 75%
      Emergency        — 7/12 Guardian

  ## Proposal Deposit: 0.1 BSV (10,000,000 sats)
  """

  use GenServer
  require Logger

  alias Locus.Schemas.{City, Proposal}
  alias Locus.Fibonacci

  @proposal_deposit 10_000_000             # 0.1 BSV
  @discussion_period_blocks 1_008          # ~7 days (144 × 7)
  @voting_period_blocks 2_016              # ~14 days (144 × 14)
  @execution_delay_blocks 432              # ~3 days (144 × 3)
  @genesis_key_expiry_block 2_100_000      # Year 10

  defstruct [
    proposals: %{}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a governance proposal.

  Per spec 04-governance.md:
  - Deposit: 0.1 BSV
  - 7-day discussion period
  - 14-day voting window

  Who can propose depends on governance type:
  - :founder → only founder
  - :tribal_council → founder + council members
  - :republic → any citizen (100 tokens)
  - :direct_democracy → any citizen
  - :senate → elected senators
  """
  @spec create_proposal(City.t(), binary(), map(), non_neg_integer()) ::
    {:ok, Proposal.t()} | {:error, atom()}
  def create_proposal(%City{} = city, proposer_pubkey, params, current_height) do
    governance = Fibonacci.governance_for_phase(city.phase)

    cond do
      not can_propose?(city, proposer_pubkey, governance) ->
        {:error, :unauthorized}

      not valid_proposal_type?(params[:proposal_type]) ->
        {:error, :invalid_proposal_type}

      true ->
        proposal = %Proposal{
          id: derive_proposal_id(city.id, proposer_pubkey, current_height),
          city_id: city.id,
          proposer_pubkey: proposer_pubkey,
          proposal_type: params[:proposal_type],
          title: params[:title] || "",
          description: params[:description] || "",
          actions: params[:actions] || [],
          deposit: @proposal_deposit,
          created_at: current_height,
          discussion_ends_at: current_height + @discussion_period_blocks,
          voting_ends_at: current_height + @discussion_period_blocks + @voting_period_blocks,
          status: :pending
        }

        # In founder governance, proposals auto-pass
        proposal = if governance == :founder and proposer_pubkey == city.founder_pubkey do
          %{proposal | status: :passed}
        else
          %{proposal | status: :active}
        end

        GenServer.call(__MODULE__, {:store_proposal, proposal})
        {:ok, proposal}
    end
  end

  @doc """
  Cast a vote on an active proposal.

  Per spec 04-governance.md:
  - One token = one vote (direct voting)
  - Vote: 1=yes, 0=no, 2=abstain
  - Each citizen votes once per proposal
  """
  @spec vote(binary(), binary(), City.t(), :yes | :no | :abstain, non_neg_integer()) ::
    {:ok, Proposal.t()} | {:error, atom()}
  def vote(proposal_id, voter_pubkey, %City{} = city, vote_choice, current_height) do
    governance = Fibonacci.governance_for_phase(city.phase)

    cond do
      governance == :founder ->
        {:error, :founder_governance}

      voter_pubkey not in city.citizens ->
        {:error, :not_citizen}

      true ->
        GenServer.call(__MODULE__, {:vote, proposal_id, voter_pubkey, vote_choice, current_height})
    end
  end

  @doc """
  Tally votes and determine proposal result.

  Per spec 04-governance.md thresholds:
  - parameter_change: 51%
  - contract_upgrade: 66%
  - treasury_spend: 51%
  - constitutional: 75%

  Quorum depends on phase:
  - Republic (Town): 60%
  - Direct Democracy (City): 40%
  - Senate (Metropolis): 51%
  """
  @spec tally(Proposal.t(), City.t()) :: :passed | :rejected | :pending
  def tally(%Proposal{} = proposal, %City{} = city) do
    threshold = Proposal.threshold(proposal.proposal_type)
    quorum = quorum_for_phase(city.phase)

    total_votes = proposal.votes_for + proposal.votes_against + proposal.votes_abstain
    quorum_needed = ceil(city.citizen_count * quorum)

    cond do
      total_votes < quorum_needed ->
        :pending

      proposal.votes_for + proposal.votes_against == 0 ->
        :pending

      proposal.votes_for / (proposal.votes_for + proposal.votes_against) >= threshold ->
        :passed

      true ->
        :rejected
    end
  end

  @doc """
  Execute a passed proposal after execution delay.

  Per spec 04-governance.md:
  - 3-day timelock before execution (except emergency)
  """
  @spec execute(Proposal.t(), non_neg_integer(), keyword()) ::
    {:ok, Proposal.t()} | {:error, atom()}
  def execute(%Proposal{} = proposal, current_height, opts \\ []) do
    execution_txid = Keyword.get(opts, :txid)
    delay = if proposal.proposal_type == :emergency, do: 0, else: @execution_delay_blocks

    cond do
      proposal.status != :passed ->
        {:error, :not_passed}

      current_height < proposal.voting_ends_at + delay ->
        {:error, :execution_delay_not_met}

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
  Check if we're still in Genesis era (protocol level).

  Per spec 04-governance.md:
  Genesis Key expires at Block 2,100,000 (~Year 10).
  """
  @spec genesis_era?(non_neg_integer()) :: boolean()
  def genesis_era?(current_height) do
    current_height < @genesis_key_expiry_block
  end

  @doc "Get a proposal by ID."
  @spec get_proposal(binary()) :: {:ok, Proposal.t()} | {:error, :not_found}
  def get_proposal(proposal_id) do
    GenServer.call(__MODULE__, {:get_proposal, proposal_id})
  end

  @doc "List proposals for a city."
  @spec list_proposals(binary()) :: [Proposal.t()]
  def list_proposals(city_id) do
    GenServer.call(__MODULE__, {:list_proposals, city_id})
  end

  @doc "Expire proposals past their voting window."
  @spec expire_proposals(binary(), non_neg_integer()) :: [Proposal.t()]
  def expire_proposals(city_id, current_height) do
    GenServer.call(__MODULE__, {:expire_proposals, city_id, current_height})
  end

  # ---------------------------------------------------------------------------
  # Authorization Checks
  # ---------------------------------------------------------------------------

  @doc "Check if a pubkey can propose given the city's governance type."
  @spec can_propose?(City.t(), binary(), atom()) :: boolean()
  def can_propose?(%City{} = city, pubkey, :founder) do
    pubkey == city.founder_pubkey
  end

  def can_propose?(%City{} = city, pubkey, :tribal_council) do
    pubkey == city.founder_pubkey or pubkey in city.citizens
  end

  def can_propose?(%City{} = city, pubkey, _governance) do
    pubkey in city.citizens
  end

  @doc "Quorum requirement per city phase."
  @spec quorum_for_phase(atom()) :: float()
  def quorum_for_phase(:town), do: 0.60
  def quorum_for_phase(:city), do: 0.40
  def quorum_for_phase(:metropolis), do: 0.51
  def quorum_for_phase(:village), do: 0.67
  def quorum_for_phase(_), do: 1.0

  @doc "Proposal deposit amount in satoshis."
  def proposal_deposit, do: @proposal_deposit

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
  def handle_call({:vote, proposal_id, voter_pubkey, vote_choice, current_height}, _from, state) do
    case Map.get(state.proposals, proposal_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %Proposal{status: :active} = proposal ->
        cond do
          current_height < proposal.discussion_ends_at ->
            {:reply, {:error, :discussion_period}, state}

          current_height > proposal.voting_ends_at ->
            {:reply, {:error, :voting_ended}, state}

          voter_pubkey in proposal.voters ->
            {:reply, {:error, :already_voted}, state}

          true ->
            updated = apply_vote(proposal, voter_pubkey, vote_choice)
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
      |> Enum.filter(&(&1.city_id == city_id))
      |> Enum.sort_by(& &1.created_at, :desc)

    {:reply, proposals, state}
  end

  @impl true
  def handle_call({:expire_proposals, city_id, current_height}, _from, state) do
    {expired, updated_proposals} =
      Enum.reduce(state.proposals, {[], state.proposals}, fn {id, p}, {exp, all} ->
        if p.city_id == city_id and p.status == :active and current_height > p.voting_ends_at do
          expired_p = %{p | status: :expired}
          {[expired_p | exp], Map.put(all, id, expired_p)}
        else
          {exp, all}
        end
      end)

    {:reply, expired, %{state | proposals: updated_proposals}}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp apply_vote(proposal, voter_pubkey, :yes) do
    %{proposal |
      votes_for: proposal.votes_for + 1,
      voters: [voter_pubkey | proposal.voters]
    }
  end

  defp apply_vote(proposal, voter_pubkey, :no) do
    %{proposal |
      votes_against: proposal.votes_against + 1,
      voters: [voter_pubkey | proposal.voters]
    }
  end

  defp apply_vote(proposal, voter_pubkey, :abstain) do
    %{proposal |
      votes_abstain: proposal.votes_abstain + 1,
      voters: [voter_pubkey | proposal.voters]
    }
  end

  defp derive_proposal_id(city_id, proposer_pubkey, height) do
    :crypto.hash(:sha256, city_id <> proposer_pubkey <> <<height::64>>)
  end

  defp valid_proposal_type?(type), do: type in Proposal.proposal_types()
end
