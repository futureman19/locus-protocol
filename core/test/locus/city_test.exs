defmodule Locus.CityTest do
  use ExUnit.Case, async: true

  alias Locus.{City, Territory, Fibonacci}
  alias Locus.Schemas.City, as: CitySchema

  @territory_id Territory.encode(%{
    world: 1, continent: 3, country: 840,
    region: 36, city: 1, district: 0, block: 0
  })
  @founder "founder_pubkey_compressed_33bytes!!"
  @block_height 800_000

  describe "found/5" do
    test "creates a new city with founder as first citizen" do
      {:ok, city, citizen} = City.found(
        "Genesis City",
        @territory_id,
        @founder,
        @block_height,
        stake_amount: 1_000_000, stake_txid: "txid123"
      )

      assert city.name == "Genesis City"
      assert city.phase == :founded
      assert city.governance_era == :genesis
      assert city.citizen_count == 1
      assert city.founder_pubkey == @founder
      assert @founder in city.citizens
      assert @territory_id in city.territories

      assert citizen.pubkey == @founder
      assert citizen.city_id == city.id
      assert citizen.status == :active
    end

    test "rejects insufficient stake" do
      assert {:error, :insufficient_stake} = City.found(
        "Broke City",
        @territory_id,
        @founder,
        @block_height,
        stake_amount: 100
      )
    end
  end

  describe "add_citizen/4" do
    test "adds citizen when city is settled" do
      {:ok, city, _} = found_city()

      # Advance to settled phase
      base = Fibonacci.base_blocks()
      settled_height = @block_height + 2 * base
      {:ok, settled_city} = City.advance_phase(city, settled_height)
      assert settled_city.phase == :settled

      {:ok, updated, citizen} = City.add_citizen(
        settled_city, "new_citizen", settled_height,
        stake_amount: 500_000, stake_txid: "txid456"
      )

      assert updated.citizen_count == 2
      assert "new_citizen" in updated.citizens
      assert citizen.pubkey == "new_citizen"
    end

    test "rejects adding to founded-only city" do
      {:ok, city, _} = found_city()
      assert {:error, :city_not_settled} = City.add_citizen(city, "new_citizen", @block_height)
    end

    test "rejects duplicate citizens" do
      {:ok, city, _} = found_city()
      base = Fibonacci.base_blocks()
      settled_height = @block_height + 2 * base
      {:ok, settled_city} = City.advance_phase(city, settled_height)

      assert {:error, :already_citizen} = City.add_citizen(settled_city, @founder, settled_height)
    end
  end

  describe "remove_citizen/3" do
    test "cannot remove founder" do
      {:ok, city, _} = found_city()
      assert {:error, :cannot_remove_founder} = City.remove_citizen(city, @founder, @founder)
    end
  end

  describe "phase transitions" do
    test "advances through phases based on Fibonacci blocks" do
      {:ok, city, _} = found_city()
      base = Fibonacci.base_blocks()

      # Phase 1 → 2 (Settled) at cumulative Fib sum = 2 × base
      {:ok, settled} = City.advance_phase(city, @block_height + 2 * base)
      assert settled.phase == :settled

      # Phase 2 → 3 (Established) at cumulative = 4 × base
      {:ok, established} = City.advance_phase(settled, @block_height + 4 * base)
      assert established.phase == :established

      # Phase 3 → 4 (Thriving) at cumulative = 7 × base
      {:ok, thriving} = City.advance_phase(established, @block_height + 7 * base)
      assert thriving.phase == :thriving
    end

    test "advance_all_phases catches up" do
      {:ok, city, _} = found_city()
      base = Fibonacci.base_blocks()

      # Jump far enough for all 6 phases
      caught_up = City.advance_all_phases(city, @block_height + 20 * base)
      assert caught_up.phase == :sovereign
    end

    test "rejects premature advancement" do
      {:ok, city, _} = found_city()
      assert {:error, :not_enough_blocks} = City.advance_phase(city, @block_height + 1)
    end

    test "rejects advancement past sovereign" do
      {:ok, city, _} = found_city()
      base = Fibonacci.base_blocks()
      sovereign = City.advance_all_phases(city, @block_height + 20 * base)
      assert {:error, :already_sovereign} = City.advance_phase(sovereign, @block_height + 100 * base)
    end
  end

  describe "check_federal_transition/1" do
    test "transitions when enough citizens" do
      {:ok, city, _} = found_city()
      city_with_citizens = %{city | citizen_count: 21}

      {:ok, federal} = City.check_federal_transition(city_with_citizens)
      assert federal.governance_era == :federal
    end

    test "rejects when too few citizens" do
      {:ok, city, _} = found_city()
      assert {:error, :insufficient_citizens} = City.check_federal_transition(city)
    end
  end

  # Helpers
  defp found_city do
    City.found("Test City", @territory_id, @founder, @block_height,
      stake_amount: 1_000_000, stake_txid: "txid_test")
  end
end
