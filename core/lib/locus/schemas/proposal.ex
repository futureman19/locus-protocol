defmodule Locus.Schemas.Proposal do
  @moduledoc """
  Governance proposal schema.

  Proposals are the mechanism for collective decision-making in cities
  that have transitioned to the Federal governance era. In Genesis era,
  the founder decides unilaterally.

  ## Proposal Types

  - `:treasury_spend` — Allocate funds from the city treasury
  - `:parameter_change` — Modify city parameters (tax rates, UBI, etc.)
  - `:territory_claim` — City claims new territory
  - `:citizen_action` — Actions affecting citizens (ban, promote, etc.)
  - `:era_transition` — Transition from Genesis to Federal era
  """

  @proposal_types [
    :treasury_spend,
    :parameter_change,
    :territory_claim,
    :citizen_action,
    :era_transition
  ]

  @type proposal_type ::
    :treasury_spend | :parameter_change | :territory_claim |
    :citizen_action | :era_transition

  @type status :: :pending | :active | :passed | :rejected | :executed | :expired

  @type t :: %__MODULE__{
    id: binary(),
    city_id: binary(),
    proposer_pubkey: binary(),
    proposal_type: proposal_type(),
    title: String.t(),
    description: String.t(),
    params: map(),
    created_at: non_neg_integer(),
    expires_at: non_neg_integer(),
    votes_for: non_neg_integer(),
    votes_against: non_neg_integer(),
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
    :expires_at,
    :executed_at,
    :execution_txid,
    params: %{},
    votes_for: 0,
    votes_against: 0,
    voters: [],
    status: :pending,
    metadata: %{}
  ]

  def proposal_types, do: @proposal_types
end
