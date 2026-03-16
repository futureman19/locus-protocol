defmodule Locus.Schemas.Proposal do
  @moduledoc """
  Governance proposal schema.

  Per spec 04-governance.md:

  ## Proposal Types and Thresholds

      0x01 Parameter Change — 51% majority
      0x02 Contract Upgrade — 66% supermajority
      0x03 Treasury Spend   — 51% majority
      0x04 Constitutional   — 75% supermajority
      0x05 Emergency        — 7/12 Guardian

  ## Deposit: 0.1 BSV (10,000,000 sats)

  ## Lifecycle

      pending → active → (voting 14 days) → passed/rejected → executed
  """

  @proposal_types [
    :parameter_change,
    :contract_upgrade,
    :treasury_spend,
    :constitutional,
    :emergency
  ]

  @proposal_deposit 10_000_000  # 0.1 BSV

  @type proposal_type ::
    :parameter_change | :contract_upgrade | :treasury_spend |
    :constitutional | :emergency

  @type status :: :pending | :active | :passed | :rejected | :executed | :expired

  @type t :: %__MODULE__{
    id: binary(),
    city_id: binary(),
    proposer_pubkey: binary(),
    proposal_type: proposal_type(),
    title: String.t(),
    description: String.t(),
    actions: [map()],
    deposit: non_neg_integer(),
    created_at: non_neg_integer(),
    discussion_ends_at: non_neg_integer(),
    voting_ends_at: non_neg_integer(),
    votes_for: non_neg_integer(),
    votes_against: non_neg_integer(),
    votes_abstain: non_neg_integer(),
    voters: [binary()],
    status: status(),
    executed_at: non_neg_integer() | nil,
    execution_txid: binary() | nil,
    metadata: map()
  }

  defstruct [
    :id,
    :city_id,
    :proposer_pubkey,
    :proposal_type,
    :title,
    :description,
    :created_at,
    :discussion_ends_at,
    :voting_ends_at,
    :executed_at,
    :execution_txid,
    actions: [],
    deposit: @proposal_deposit,
    votes_for: 0,
    votes_against: 0,
    votes_abstain: 0,
    voters: [],
    status: :pending,
    metadata: %{}
  ]

  def proposal_types, do: @proposal_types
  def proposal_deposit, do: @proposal_deposit

  @doc "Voting threshold percentage for each proposal type"
  def threshold(:parameter_change), do: 0.51
  def threshold(:contract_upgrade), do: 0.66
  def threshold(:treasury_spend),   do: 0.51
  def threshold(:constitutional),   do: 0.75
  def threshold(:emergency),        do: 0.583  # 7/12
  def threshold(_),                 do: 0.51
end
