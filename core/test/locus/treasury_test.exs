defmodule Locus.TreasuryTest do
  use ExUnit.Case, async: false

  alias Locus.Treasury
  alias Locus.Schemas.City

  describe "calculate_ubi/2" do
    test "calculates UBI per citizen" do
      # treasury = 1_000_000, rate = 0.001, citizens = 10
      # daily_pool = 1_000_000 * 0.001 = 1_000
      # per_citizen = 1_000 / 10 = 100
      assert Treasury.calculate_ubi(1_000_000, 10) == 100
    end

    test "returns 0 for zero citizens" do
      assert Treasury.calculate_ubi(1_000_000, 0) == 0
    end

    test "returns 0 for tiny treasury" do
      # 100 * 0.001 = 0.1, truncated to 0, / 10 = 0
      assert Treasury.calculate_ubi(100, 10) == 0
    end
  end

  describe "distribute_ubi/2" do
    test "distributes UBI only to thriving+ cities" do
      city = %City{
        id: "city1",
        name: "Test",
        territory_id: <<0::128>>,
        founder_pubkey: "founder",
        founded_at: 0,
        phase: :established,
        citizens: ["a", "b"],
        citizen_count: 2,
        treasury_balance: 1_000_000
      }

      assert {:error, :city_not_thriving} = Treasury.distribute_ubi(city, 100)
    end

    test "distributes UBI to all citizens of thriving city" do
      city = %City{
        id: "city1",
        name: "Test",
        territory_id: <<0::128>>,
        founder_pubkey: "founder",
        founded_at: 0,
        phase: :thriving,
        citizens: ["alice", "bob", "carol"],
        citizen_count: 3,
        treasury_balance: 3_000_000
      }

      {:ok, distributions, updated_city} = Treasury.distribute_ubi(city, 100)

      assert length(distributions) == 3
      {_pubkey, amount} = hd(distributions)
      assert amount == 1_000   # 3_000_000 * 0.001 / 3

      total_distributed = amount * 3
      assert updated_city.treasury_balance == city.treasury_balance - total_distributed
    end
  end
end
