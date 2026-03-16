defmodule Locus.Schemas.City do
  @moduledoc """
  City schema — the primary primitive of the Locus Protocol.

  Per spec 02-city-lifecycle.md:

  ## Lifecycle Phases (driven by citizen count)

      Phase 0 — Genesis:     1 citizen      (founder only)
      Phase 1 — Settlement:  2-3 citizens   (hardcore mode)
      Phase 2 — Village:     4-8 citizens   (tribal council, first blocks)
      Phase 3 — Town:        9-20 citizens  (republic governance)
      Phase 4 — City:        21-50 citizens (UBI ACTIVATED, direct democracy)
      Phase 5 — Metropolis:  51+ citizens   (senate, full expansion)

  ## Token Distribution (3.2M per city)

      Founder:      640,000 (20%) — 12-month linear vest
      Treasury:   1,600,000 (50%) — UBI, grants, public goods
      Public Sale:  800,000 (25%) — Immediate
      Protocol Dev: 160,000 (5%)  — 24-month vest
  """

  @phases [:genesis, :settlement, :village, :town, :city, :metropolis]

  @total_token_supply 3_200_000
  @founder_tokens     640_000
  @treasury_tokens  1_600_000
  @public_tokens      800_000
  @dev_tokens         160_000
  @founding_stake_sats 3_200_000_000  # 32 BSV

  @type phase :: :genesis | :settlement | :village | :town | :city | :metropolis

  @type t :: %__MODULE__{
    id: binary(),
    name: String.t(),
    description: String.t(),
    territory_id: binary(),
    founder_pubkey: binary(),
    founded_at: non_neg_integer(),
    phase: phase(),
    citizens: [binary()],
    citizen_count: non_neg_integer(),
    treasury_bsv: non_neg_integer(),
    treasury_tokens: non_neg_integer(),
    token_supply: non_neg_integer(),
    founder_tokens_total: non_neg_integer(),
    founder_tokens_vested: non_neg_integer(),
    territories: [binary()],
    blocks_unlocked: non_neg_integer(),
    founding_txid: binary() | nil,
    location: map(),
    policies: map(),
    metadata: map()
  }

  defstruct [
    :id,
    :name,
    :territory_id,
    :founder_pubkey,
    :founded_at,
    :founding_txid,
    description: "",
    phase: :genesis,
    citizens: [],
    citizen_count: 0,
    treasury_bsv: 0,
    treasury_tokens: @treasury_tokens,
    token_supply: @total_token_supply,
    founder_tokens_total: @founder_tokens,
    founder_tokens_vested: 0,
    territories: [],
    blocks_unlocked: 0,
    location: %{},
    policies: %{},
    metadata: %{}
  ]

  def phases, do: @phases
  def total_token_supply, do: @total_token_supply
  def founder_token_allocation, do: @founder_tokens
  def treasury_token_allocation, do: @treasury_tokens
  def public_token_allocation, do: @public_tokens
  def dev_token_allocation, do: @dev_tokens
  def founding_stake_sats, do: @founding_stake_sats
end
