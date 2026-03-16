defmodule Locus.Schemas.Citizen do
  @moduledoc """
  Citizen schema — a participant in a city.

  Per spec 03-staking-economics.md:
  - Citizens stake BSV to join (CLTV locked, 21,600 blocks)
  - Progressive territory tax: base × 2^(N-1)
  - UBI eligible at Phase 4+ (city phase, 21+ citizens)
  - Heartbeat required within 30 days for UBI eligibility
  """

  @type status :: :active | :inactive | :exited

  @type t :: %__MODULE__{
    pubkey: binary(),
    city_id: binary(),
    joined_at: non_neg_integer(),
    stake_amount: non_neg_integer(),
    stake_txid: binary() | nil,
    lock_height: non_neg_integer(),
    token_balance: non_neg_integer(),
    last_ubi_claim: non_neg_integer(),
    last_heartbeat: non_neg_integer(),
    territories_claimed: non_neg_integer(),
    status: status(),
    metadata: map()
  }

  defstruct [
    :pubkey,
    :city_id,
    :joined_at,
    :stake_txid,
    stake_amount: 0,
    lock_height: 0,
    token_balance: 0,
    last_ubi_claim: 0,
    last_heartbeat: 0,
    territories_claimed: 0,
    status: :active,
    metadata: %{}
  ]
end
