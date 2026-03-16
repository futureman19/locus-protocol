defmodule Locus.Schemas.Territory do
  @moduledoc """
  Territory schema — a unit of claimable space in the Geo-IPv6 hierarchy.

  ## Geo-IPv6 Address Layout (128 bits)

      Bits   0-7:   World       (8 bits  — 256 worlds)
      Bits   8-15:  Continent   (8 bits  — 256 per world)
      Bits  16-31:  Country     (16 bits — 65,536 per continent)
      Bits  32-47:  Region      (16 bits — 65,536 per country)
      Bits  48-71:  City        (24 bits — 16M per region)
      Bits  72-95:  District    (24 bits — 16M per city)
      Bits 96-127:  Block       (32 bits — 4B per district)
  """

  @levels [:world, :continent, :country, :region, :city, :district, :block]

  @type level :: :world | :continent | :country | :region | :city | :district | :block
  @type status :: :unclaimed | :claimed | :locked | :disputed

  @type t :: %__MODULE__{
    id: binary(),
    level: level(),
    parent_id: binary() | nil,
    owner_pubkey: binary() | nil,
    city_id: binary() | nil,
    claimed_at: non_neg_integer() | nil,
    status: status(),
    tax_multiplier: non_neg_integer(),
    metadata: map()
  }

  defstruct [
    :id,
    :level,
    :parent_id,
    :owner_pubkey,
    :city_id,
    :claimed_at,
    status: :unclaimed,
    tax_multiplier: 1,
    metadata: %{}
  ]

  def levels, do: @levels

  @doc "Bit width for each hierarchy level"
  def bit_width(:world), do: 8
  def bit_width(:continent), do: 8
  def bit_width(:country), do: 16
  def bit_width(:region), do: 16
  def bit_width(:city), do: 24
  def bit_width(:district), do: 24
  def bit_width(:block), do: 32

  @doc "Bit offset for each hierarchy level"
  def bit_offset(:world), do: 0
  def bit_offset(:continent), do: 8
  def bit_offset(:country), do: 16
  def bit_offset(:region), do: 32
  def bit_offset(:city), do: 48
  def bit_offset(:district), do: 72
  def bit_offset(:block), do: 96
end
