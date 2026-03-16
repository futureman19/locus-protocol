defmodule Locus.Territory do
  @moduledoc """
  Territory management — claim, release, and transfer at all hierarchy levels.

  Territories use a Geo-IPv6 addressing scheme mapping the physical world
  into a 128-bit address space with 7 hierarchy levels.

  ## Progressive Taxation

  Citizens pay exponentially more for each additional territory:

      1st territory: base_cost
      2nd territory: base_cost × 2
      3rd territory: base_cost × 4
      Nth territory: base_cost × 2^(N-1)
  """

  alias Locus.Schemas.Territory, as: TerritorySchema

  # Bit layout: world(8) + continent(8) + country(16) + region(16) + city(24) + district(24) + block(32) = 128
  @level_specs [
    {:world,     8,   0},
    {:continent, 8,   8},
    {:country,   16,  16},
    {:region,    16,  32},
    {:city,      24,  48},
    {:district,  24,  72},
    {:block,     32,  96}
  ]

  @doc """
  Encode geographic coordinates into a Geo-IPv6 territory address.

  Takes a map of hierarchy components and returns a 128-bit (16-byte) binary.

  ## Examples

      iex> addr = Locus.Territory.encode(%{world: 1, continent: 3, country: 840, region: 36, city: 1})
      iex> byte_size(addr)
      16
  """
  @spec encode(map()) :: binary()
  def encode(components) when is_map(components) do
    world     = Map.get(components, :world, 0)
    continent = Map.get(components, :continent, 0)
    country   = Map.get(components, :country, 0)
    region    = Map.get(components, :region, 0)
    city      = Map.get(components, :city, 0)
    district  = Map.get(components, :district, 0)
    block     = Map.get(components, :block, 0)

    <<
      world::8,
      continent::8,
      country::16,
      region::16,
      city::24,
      district::24,
      block::32
    >>
  end

  @doc """
  Decode a 128-bit Geo-IPv6 address into its hierarchy components.

  ## Examples

      iex> Locus.Territory.decode(<<1, 3, 0, 42, 0, 36, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0>>)
      %{world: 1, continent: 3, country: 42, region: 36, city: 1, district: 0, block: 0}
  """
  @spec decode(binary()) :: map()
  def decode(<<
    world::8,
    continent::8,
    country::16,
    region::16,
    city::24,
    district::24,
    block::32
  >>) do
    %{
      world: world,
      continent: continent,
      country: country,
      region: region,
      city: city,
      district: district,
      block: block
    }
  end

  @doc """
  Determine the hierarchy level of a territory address.

  The level is determined by the most specific non-zero component.

  ## Examples

      iex> Locus.Territory.level(%{world: 1, continent: 3, country: 0, region: 0, city: 0, district: 0, block: 0})
      :continent
  """
  @spec level(binary() | map()) :: TerritorySchema.level()
  def level(addr) when is_binary(addr), do: level(decode(addr))

  def level(%{} = components) do
    cond do
      Map.get(components, :block, 0) > 0     -> :block
      Map.get(components, :district, 0) > 0   -> :district
      Map.get(components, :city, 0) > 0       -> :city
      Map.get(components, :region, 0) > 0     -> :region
      Map.get(components, :country, 0) > 0    -> :country
      Map.get(components, :continent, 0) > 0  -> :continent
      true                                     -> :world
    end
  end

  @doc """
  Get the parent address of a territory by zeroing out its most specific component.

  ## Examples

      iex> components = %{world: 1, continent: 3, country: 840, region: 0, city: 0, district: 0, block: 0}
      iex> Locus.Territory.parent(components)
      %{world: 1, continent: 3, country: 0, region: 0, city: 0, district: 0, block: 0}
  """
  @spec parent(binary() | map()) :: map() | nil
  def parent(addr) when is_binary(addr), do: parent(decode(addr))

  def parent(%{} = components) do
    current_level = level(components)

    case current_level do
      :world -> nil
      :continent -> %{components | continent: 0}
      :country   -> %{components | country: 0}
      :region    -> %{components | region: 0}
      :city      -> %{components | city: 0}
      :district  -> %{components | district: 0}
      :block     -> %{components | block: 0}
    end
  end

  @doc """
  Claim a territory for an owner.

  Returns `{:ok, territory}` or `{:error, reason}`.
  """
  @spec claim(binary(), binary(), non_neg_integer(), keyword()) ::
    {:ok, TerritorySchema.t()} | {:error, atom()}
  def claim(territory_id, owner_pubkey, block_height, opts \\ []) do
    level = level(territory_id)
    city_id = Keyword.get(opts, :city_id)
    tax_multiplier = Keyword.get(opts, :tax_multiplier, 1)

    territory = %TerritorySchema{
      id: territory_id,
      level: level,
      parent_id: parent(territory_id) |> maybe_encode(),
      owner_pubkey: owner_pubkey,
      city_id: city_id,
      claimed_at: block_height,
      status: :claimed,
      tax_multiplier: tax_multiplier
    }

    {:ok, territory}
  end

  @doc """
  Release a claimed territory back to unclaimed status.
  """
  @spec release(TerritorySchema.t(), binary()) ::
    {:ok, TerritorySchema.t()} | {:error, atom()}
  def release(%TerritorySchema{} = territory, owner_pubkey) do
    cond do
      territory.status != :claimed ->
        {:error, :not_claimed}

      territory.owner_pubkey != owner_pubkey ->
        {:error, :not_owner}

      true ->
        released = %{territory |
          owner_pubkey: nil,
          city_id: nil,
          status: :unclaimed,
          claimed_at: nil,
          tax_multiplier: 1
        }
        {:ok, released}
    end
  end

  @doc """
  Transfer a territory to a new owner.
  """
  @spec transfer(TerritorySchema.t(), binary(), binary()) ::
    {:ok, TerritorySchema.t()} | {:error, atom()}
  def transfer(%TerritorySchema{} = territory, from_pubkey, to_pubkey) do
    cond do
      territory.status != :claimed ->
        {:error, :not_claimed}

      territory.owner_pubkey != from_pubkey ->
        {:error, :not_owner}

      true ->
        transferred = %{territory | owner_pubkey: to_pubkey}
        {:ok, transferred}
    end
  end

  @doc """
  Calculate the progressive tax cost for claiming the Nth territory.

  Progressive tax doubles with each additional territory:
  1st = base, 2nd = 2×base, 3rd = 4×base, Nth = base × 2^(N-1)

  ## Examples

      iex> Locus.Territory.progressive_tax(10_000, 1)
      10_000
      iex> Locus.Territory.progressive_tax(10_000, 3)
      40_000
  """
  @spec progressive_tax(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def progressive_tax(base_cost, territory_number) when territory_number >= 1 do
    multiplier = Bitwise.bsl(1, territory_number - 1)
    base_cost * multiplier
  end

  @doc """
  Format a Geo-IPv6 address as a human-readable string.

  ## Examples

      iex> Locus.Territory.format_address(%{world: 1, continent: 3, country: 840, region: 36, city: 1, district: 0, block: 0})
      "01:03:0348:0024:000001:000000:00000000"
  """
  @spec format_address(binary() | map()) :: String.t()
  def format_address(addr) when is_binary(addr), do: format_address(decode(addr))

  def format_address(%{} = c) do
    world     = String.pad_leading(Integer.to_string(c.world, 16), 2, "0")
    continent = String.pad_leading(Integer.to_string(c.continent, 16), 2, "0")
    country   = String.pad_leading(Integer.to_string(c.country, 16), 4, "0")
    region    = String.pad_leading(Integer.to_string(c.region, 16), 4, "0")
    city      = String.pad_leading(Integer.to_string(c.city, 16), 6, "0")
    district  = String.pad_leading(Integer.to_string(c.district, 16), 6, "0")
    block     = String.pad_leading(Integer.to_string(c.block, 16), 8, "0")

    "#{world}:#{continent}:#{country}:#{region}:#{city}:#{district}:#{block}"
  end

  @doc "List of level specs: [{level, bit_width, bit_offset}, ...]"
  def level_specs, do: @level_specs

  # Encode a components map back to binary, or return nil
  defp maybe_encode(nil), do: nil
  defp maybe_encode(%{} = components), do: encode(components)
end
