defmodule Locus.TerritoryTest do
  use ExUnit.Case, async: true

  alias Locus.Territory
  alias Locus.Schemas.Territory, as: TerritorySchema

  describe "encode/1 and decode/1" do
    test "round-trips territory address" do
      components = %{
        world: 1,
        continent: 3,
        country: 840,
        region: 36,
        city: 1,
        district: 0,
        block: 0
      }

      encoded = Territory.encode(components)
      assert byte_size(encoded) == 16

      decoded = Territory.decode(encoded)
      assert decoded == components
    end

    test "encodes zero address" do
      zero = Territory.encode(%{})
      assert zero == <<0::128>>
    end
  end

  describe "level/1" do
    test "determines level from components" do
      assert Territory.level(%{world: 1, continent: 0, country: 0, region: 0, city: 0, district: 0, block: 0}) == :world
      assert Territory.level(%{world: 1, continent: 3, country: 0, region: 0, city: 0, district: 0, block: 0}) == :continent
      assert Territory.level(%{world: 1, continent: 3, country: 840, region: 0, city: 0, district: 0, block: 0}) == :country
      assert Territory.level(%{world: 1, continent: 3, country: 840, region: 36, city: 1, district: 0, block: 0}) == :city
      assert Territory.level(%{world: 1, continent: 3, country: 840, region: 36, city: 1, district: 5, block: 0}) == :district
      assert Territory.level(%{world: 1, continent: 3, country: 840, region: 36, city: 1, district: 5, block: 42}) == :block
    end

    test "determines level from binary address" do
      addr = Territory.encode(%{world: 1, continent: 3, country: 840, region: 0, city: 0, district: 0, block: 0})
      assert Territory.level(addr) == :country
    end
  end

  describe "parent/1" do
    test "returns parent by zeroing most specific component" do
      components = %{world: 1, continent: 3, country: 840, region: 36, city: 1, district: 0, block: 0}
      parent = Territory.parent(components)
      assert parent == %{world: 1, continent: 3, country: 840, region: 36, city: 0, district: 0, block: 0}
    end

    test "returns nil for world level" do
      assert Territory.parent(%{world: 1, continent: 0, country: 0, region: 0, city: 0, district: 0, block: 0}) == nil
    end
  end

  describe "claim/4" do
    test "creates a claimed territory" do
      territory_id = Territory.encode(%{world: 1, continent: 3, country: 840, region: 36, city: 1, district: 0, block: 0})
      owner = "owner_pubkey"

      {:ok, territory} = Territory.claim(territory_id, owner, 100_000)
      assert territory.status == :claimed
      assert territory.owner_pubkey == owner
      assert territory.level == :city
      assert territory.claimed_at == 100_000
    end
  end

  describe "release/2" do
    test "releases a claimed territory" do
      territory_id = Territory.encode(%{world: 1, continent: 3, country: 840, region: 0, city: 0, district: 0, block: 0})
      {:ok, territory} = Territory.claim(territory_id, "owner", 100_000)
      {:ok, released} = Territory.release(territory, "owner")

      assert released.status == :unclaimed
      assert released.owner_pubkey == nil
    end

    test "fails if not owner" do
      territory_id = Territory.encode(%{world: 1, continent: 3, country: 840, region: 0, city: 0, district: 0, block: 0})
      {:ok, territory} = Territory.claim(territory_id, "owner", 100_000)
      assert {:error, :not_owner} = Territory.release(territory, "other")
    end
  end

  describe "transfer/3" do
    test "transfers ownership" do
      territory_id = Territory.encode(%{world: 1, continent: 3, country: 840, region: 0, city: 0, district: 0, block: 0})
      {:ok, territory} = Territory.claim(territory_id, "alice", 100_000)
      {:ok, transferred} = Territory.transfer(territory, "alice", "bob")

      assert transferred.owner_pubkey == "bob"
      assert transferred.status == :claimed
    end
  end

  describe "progressive_tax/2" do
    test "calculates exponential tax" do
      base = 10_000
      assert Territory.progressive_tax(base, 1) == 10_000
      assert Territory.progressive_tax(base, 2) == 20_000
      assert Territory.progressive_tax(base, 3) == 40_000
      assert Territory.progressive_tax(base, 4) == 80_000
      assert Territory.progressive_tax(base, 5) == 160_000
    end
  end

  describe "format_address/1" do
    test "formats as colon-separated hex" do
      components = %{world: 1, continent: 3, country: 840, region: 36, city: 1, district: 0, block: 0}
      formatted = Territory.format_address(components)
      assert is_binary(formatted)
      assert String.contains?(formatted, ":")
    end
  end
end
