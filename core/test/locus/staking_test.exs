defmodule Locus.StakingTest do
  use ExUnit.Case, async: true

  alias Locus.Staking

  describe "calculate_lock_height/1" do
    test "adds 21,600 blocks" do
      assert Staking.calculate_lock_height(800_000) == 821_600
    end
  end

  describe "calculate_penalty/1" do
    test "10% penalty per spec (NOT 50%)" do
      # 32 BSV stake
      stake = 3_200_000_000
      penalty = Staking.calculate_penalty(stake)
      assert penalty == 320_000_000  # 10% = 3.2 BSV
    end
  end

  describe "calculate_emergency_return/1" do
    test "returns 90% of stake" do
      stake = 3_200_000_000
      returned = Staking.calculate_emergency_return(stake)
      assert returned == 2_880_000_000  # 90% = 28.8 BSV
    end

    test "penalty + return == original stake" do
      stake = 3_200_000_000
      penalty = Staking.calculate_penalty(stake)
      returned = Staking.calculate_emergency_return(stake)
      assert penalty + returned == stake
    end
  end

  describe "territory_tax/2" do
    test "progressive doubling per spec" do
      # Per spec 03-staking-economics.md: cost = base × 2^(n-1)
      base = 800_000_000  # 8 BSV for building

      assert Staking.territory_tax(base, 1) == 800_000_000
      assert Staking.territory_tax(base, 2) == 1_600_000_000
      assert Staking.territory_tax(base, 3) == 3_200_000_000
      assert Staking.territory_tax(base, 4) == 6_400_000_000
    end

    test "city founding progressive tax" do
      base = 3_200_000_000  # 32 BSV for city

      assert Staking.territory_tax(base, 1) == 3_200_000_000   # 32 BSV
      assert Staking.territory_tax(base, 2) == 6_400_000_000   # 64 BSV
      assert Staking.territory_tax(base, 3) == 12_800_000_000  # 128 BSV
      assert Staking.territory_tax(base, 5) == 51_200_000_000  # 512 BSV
    end
  end
end
