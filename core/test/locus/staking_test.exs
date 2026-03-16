defmodule Locus.StakingTest do
  use ExUnit.Case, async: true

  alias Locus.Staking

  describe "calculate_lock_height/1" do
    test "adds lock period to current height" do
      assert Staking.calculate_lock_height(800_000) == 821_600
    end
  end

  describe "validate_stake/2" do
    test "accepts sufficient stake" do
      assert :ok = Staking.validate_stake(1_000_000)
    end

    test "rejects insufficient stake" do
      assert {:error, :insufficient_stake} = Staking.validate_stake(100)
    end

    test "accepts custom minimum" do
      assert :ok = Staking.validate_stake(500, min_stake: 500)
      assert {:error, :insufficient_stake} = Staking.validate_stake(499, min_stake: 500)
    end
  end

  describe "matured?/2" do
    test "returns true when current height >= lock height" do
      assert Staking.matured?(821_600, 821_600)
      assert Staking.matured?(821_600, 900_000)
    end

    test "returns false when not yet matured" do
      refute Staking.matured?(821_600, 800_000)
    end
  end

  describe "emergency_unlock/1" do
    test "calculates 50% penalty" do
      {:ok, returned, penalty} = Staking.emergency_unlock(1_000_000)
      assert penalty == 500_000
      assert returned == 500_000
      assert returned + penalty == 1_000_000
    end
  end

  describe "territory_tax/2" do
    test "progressive doubling" do
      base = 10_000
      assert Staking.territory_tax(base, 1) == 10_000
      assert Staking.territory_tax(base, 2) == 20_000
      assert Staking.territory_tax(base, 3) == 40_000
      assert Staking.territory_tax(base, 4) == 80_000
    end
  end
end
