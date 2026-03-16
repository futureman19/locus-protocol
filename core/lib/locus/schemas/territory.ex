defmodule Locus.Schemas.Territory do
  @moduledoc """
  Territory schema — a unit in the Geo-IPv6 hierarchy.

  Per spec 01-territory-hierarchy.md:

      /128 Continent
        └── /64 Country
              └── /32 City        (32 BSV)
                    ├── /16 Block (public=auctioned, private=8 BSV)
                    │     └── /8 Building (8 BSV)
                    │           └── /4 Home (4 BSV)
                    │                 └── /2 Aura (auto)
                    │                       └── /1 Object (0.1-64 BSV)
                    └── /16 Private Block (8 BSV)
  """

  @levels [:continent, :country, :city, :block, :building, :home, :aura, :object]

  @type level :: :continent | :country | :city | :block | :building | :home | :aura | :object
  @type status :: :unclaimed | :claimed | :locked | :disputed | :abandoned

  @type t :: %__MODULE__{
    id: binary(),
    h3_index: String.t() | nil,
    level: level(),
    parent_id: binary() | nil,
    owner_pubkey: binary() | nil,
    city_id: binary() | nil,
    claimed_at: non_neg_integer() | nil,
    stake_amount: non_neg_integer(),
    lock_height: non_neg_integer(),
    status: status(),
    territory_type: atom(),
    metadata: map()
  }

  defstruct [
    :id,
    :h3_index,
    :level,
    :parent_id,
    :owner_pubkey,
    :city_id,
    :claimed_at,
    stake_amount: 0,
    lock_height: 0,
    status: :unclaimed,
    territory_type: :public,
    metadata: %{}
  ]

  def levels, do: @levels

  @doc "Stake amount in satoshis for each territory level"
  def stake_for_level(:city),     do: 3_200_000_000   # 32 BSV
  def stake_for_level(:block),    do:   800_000_000   #  8 BSV (private)
  def stake_for_level(:building), do:   800_000_000   #  8 BSV
  def stake_for_level(:home),     do:   400_000_000   #  4 BSV
  def stake_for_level(_),         do: 0
end
