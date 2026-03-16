defmodule Locus.TerritoryTest do
  use ExUnit.Case, async: true

  alias Locus.Territory
  alias Locus.Schemas.Territory, as: TerritorySchema

  describe "claim/1" do
    test "creates a claimed territory" do
      {:ok, territory} = Territory.claim(%{
        level: :building,
        h3_index: "891f1d48177ffff",
        owner_pubkey: "owner_pubkey_33bytes",
        stake_amount: 800_000_000,
        block_height: 800_000,
        city_id: "city_123"
      })

      assert territory.status == :claimed
      assert territory.owner_pubkey == "owner_pubkey_33bytes"
      assert territory.level == :building
      assert territory.claimed_at == 800_000
      assert territory.lock_height == 821_600
      assert territory.stake_amount == 800_000_000
    end

    test "rejects insufficient stake for building" do
      assert {:error, :insufficient_stake} = Territory.claim(%{
        level: :building,
        h3_index: "891f1d48177ffff",
        owner_pubkey: "owner",
        stake_amount: 100,
        block_height: 800_000
      })
    end

    test "allows zero stake for non-staked levels" do
      {:ok, territory} = Territory.claim(%{
        level: :continent,
        h3_index: "811fbffffffffff",
        owner_pubkey: "owner",
        stake_amount: 0,
        block_height: 800_000
      })

      assert territory.status == :claimed
    end
  end

  describe "release/2" do
    test "releases a claimed territory" do
      {:ok, territory} = claim_building()
      {:ok, released} = Territory.release(territory, "owner_pubkey")

      assert released.status == :unclaimed
      assert released.owner_pubkey == nil
      assert released.stake_amount == 0
    end

    test "fails if not owner" do
      {:ok, territory} = claim_building()
      assert {:error, :not_owner} = Territory.release(territory, "other_key")
    end

    test "fails if not claimed" do
      territory = %TerritorySchema{status: :unclaimed}
      assert {:error, :not_claimed} = Territory.release(territory, "any")
    end
  end

  describe "transfer/3" do
    test "transfers ownership" do
      {:ok, territory} = claim_building()
      {:ok, transferred} = Territory.transfer(territory, "owner_pubkey", "new_owner")

      assert transferred.owner_pubkey == "new_owner"
      assert transferred.status == :claimed
    end

    test "fails if not owner" do
      {:ok, territory} = claim_building()
      assert {:error, :not_owner} = Territory.transfer(territory, "wrong", "new_owner")
    end
  end

  describe "progressive_tax/2" do
    test "calculates exponential tax per spec" do
      # Per spec 03-staking-economics.md
      base = 800_000_000  # 8 BSV for building

      assert Territory.progressive_tax(base, 1) == 800_000_000    # 8 BSV
      assert Territory.progressive_tax(base, 2) == 1_600_000_000  # 16 BSV
      assert Territory.progressive_tax(base, 3) == 3_200_000_000  # 32 BSV
      assert Territory.progressive_tax(base, 4) == 6_400_000_000  # 64 BSV
      assert Territory.progressive_tax(base, 5) == 12_800_000_000 # 128 BSV
    end
  end

  describe "total_cost/2" do
    test "calculates total for N properties" do
      base = 800_000_000
      # Total = base × (2^N - 1)
      assert Territory.total_cost(base, 1) == 800_000_000    # 8 BSV
      assert Territory.total_cost(base, 2) == 2_400_000_000  # 24 BSV
      assert Territory.total_cost(base, 5) == 24_800_000_000 # 248 BSV
    end
  end

  describe "distribute_fees/1" do
    test "splits fees per spec 50/40/10" do
      fees = Territory.distribute_fees(10_000)

      assert fees.developer == 5_000        # 50%
      assert fees.territory_total == 4_000  # 40%
      assert fees.protocol == 1_000         # 10%

      # Territory breakdown: 50/30/20 of 40%
      assert fees.building_owner == 2_000   # 50% of 4000
      assert fees.city_treasury == 1_200    # 30% of 4000
      assert fees.block_owner == 800        # 20% of 4000
    end
  end

  describe "stake_for_level/1" do
    test "returns correct stakes per spec" do
      assert TerritorySchema.stake_for_level(:city) == 3_200_000_000
      assert TerritorySchema.stake_for_level(:block) == 800_000_000
      assert TerritorySchema.stake_for_level(:building) == 800_000_000
      assert TerritorySchema.stake_for_level(:home) == 400_000_000
      assert TerritorySchema.stake_for_level(:continent) == 0
    end
  end

  # Helpers
  defp claim_building do
    Territory.claim(%{
      level: :building,
      h3_index: "891f1d48177ffff",
      owner_pubkey: "owner_pubkey",
      stake_amount: 800_000_000,
      block_height: 800_000
    })
  end
end
