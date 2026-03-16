defmodule Locus.Schemas.Citizen do
  @moduledoc """
  Citizen schema — a participant in a city.

  Citizens stake BSV to join a city and receive UBI distributions
  from the city treasury. Each citizen may claim territories with
  progressive taxation (1st = base, 2nd = 2×, 3rd = 4×, etc.).
  """

  @type status :: :active | :inactive | :exited

  @type t :: %__MODULE__{
    pubkey: binary(),
    city_id: binary(),
    joined_at: non_neg_integer(),
    stake_amount: non_neg_integer(),
    stake_txid: binary() | nil,
    lock_height: non_neg_integer(),
    last_ubi_claim: non_neg_integer(),
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
    last_ubi_claim: 0,
    territories_claimed: 0,
    status: :active,
    metadata: %{}
  ]
end
