defmodule Locus.CityTest do
  use ExUnit.Case, async: true

  alias Locus.{City, Fibonacci}
  alias Locus.Schemas.City, as: CitySchema

  @location %{lat: 35.6762, lng: 139.6503, h3_res7: "8f283080dcb019d"}
  @founder "founder_pubkey_compressed_33bytes"
  @block_height 800_000
  @founding_stake 3_200_000_000  # 32 BSV

  describe "found/5" do
    test "creates city with founder as first citizen" do
      {:ok, city, citizen} = found_city()

      assert city.name == "Neo-Tokyo"
      assert city.phase == :genesis
      assert city.citizen_count == 1
      assert city.founder_pubkey == @founder
      assert @founder in city.citizens
      assert city.treasury_bsv == @founding_stake
      assert city.token_supply == 3_200_000
      assert city.founder_tokens_total == 640_000
      assert city.treasury_tokens == 1_600_000
      assert city.blocks_unlocked == 2  # Fibonacci: 1 citizen = 2 blocks

      assert citizen.pubkey == @founder
      assert citizen.city_id == city.id
      assert citizen.status == :active
      assert citizen.lock_height == @block_height + 21_600
    end

    test "rejects insufficient stake (< 32 BSV)" do
      assert {:error, :insufficient_stake} = City.found(
        "Broke City", @location, @founder, @block_height,
        stake_amount: 1_000_000
      )
    end

    test "rejects name > 50 chars" do
      long_name = String.duplicate("x", 51)
      assert {:error, :name_too_long} = City.found(
        long_name, @location, @founder, @block_height,
        stake_amount: @founding_stake
      )
    end
  end

  describe "add_citizen/4 — citizen-count-driven phases" do
    test "phase transitions automatically on citizen join" do
      {:ok, city, _} = found_city()

      # Add 2nd citizen → settlement
      {:ok, city2, _} = City.add_citizen(city, "citizen_2", @block_height)
      assert city2.phase == :settlement
      assert city2.citizen_count == 2

      # Add 3rd citizen → still settlement
      {:ok, city3, _} = City.add_citizen(city2, "citizen_3", @block_height)
      assert city3.phase == :settlement

      # Add 4th citizen → village
      {:ok, city4, _} = City.add_citizen(city3, "citizen_4", @block_height)
      assert city4.phase == :village
      assert city4.blocks_unlocked == 5  # Fibonacci blocks for 4 citizens
    end

    test "rejects duplicate citizen" do
      {:ok, city, _} = found_city()
      assert {:error, :already_citizen} = City.add_citizen(city, @founder, @block_height)
    end

    test "reaches city phase at 21 citizens (UBI activates)" do
      city = build_city_with_citizens(21)
      assert city.phase == :city
      assert city.blocks_unlocked == 16
      assert City.ubi_active?(city)
    end

    test "reaches metropolis at 51 citizens" do
      city = build_city_with_citizens(51)
      assert city.phase == :metropolis
      assert city.blocks_unlocked == 24
    end
  end

  describe "remove_citizen/3" do
    test "cannot remove founder" do
      {:ok, city, _} = found_city()
      assert {:error, :cannot_remove_founder} = City.remove_citizen(city, @founder, @founder)
    end

    test "phase may drop when citizen leaves" do
      city = build_city_with_citizens(4)
      assert city.phase == :village

      {:ok, reduced} = City.remove_citizen(city, "citizen_3", "citizen_3")
      assert reduced.citizen_count == 3
      assert reduced.phase == :settlement
      # But blocks stay unlocked (per spec: no reverse)
      assert reduced.blocks_unlocked == 5
    end

    test "blocks remain unlocked even if phase drops" do
      city = build_city_with_citizens(21)
      assert city.blocks_unlocked == 16

      {:ok, reduced} = City.remove_citizen(city, "citizen_20", "citizen_20")
      assert reduced.blocks_unlocked == 16  # Never decreases
    end
  end

  describe "ubi_active?/1" do
    test "false before phase 4" do
      refute City.ubi_active?(build_city_with_citizens(1))
      refute City.ubi_active?(build_city_with_citizens(4))
      refute City.ubi_active?(build_city_with_citizens(9))
      refute City.ubi_active?(build_city_with_citizens(20))
    end

    test "true at phase 4+ (21+ citizens)" do
      assert City.ubi_active?(build_city_with_citizens(21))
      assert City.ubi_active?(build_city_with_citizens(51))
    end
  end

  describe "governance_type/1" do
    test "returns correct governance for each phase" do
      assert City.governance_type(build_city_with_citizens(1)) == :founder
      assert City.governance_type(build_city_with_citizens(3)) == :founder
      assert City.governance_type(build_city_with_citizens(4)) == :tribal_council
      assert City.governance_type(build_city_with_citizens(9)) == :republic
      assert City.governance_type(build_city_with_citizens(21)) == :direct_democracy
      assert City.governance_type(build_city_with_citizens(51)) == :senate
    end
  end

  describe "founder_vested_tokens/2" do
    test "vests linearly over 12 months" do
      {:ok, city, _} = found_city()

      # 0 months elapsed
      assert City.founder_vested_tokens(city, @block_height) == 0

      # 1 month (4320 blocks)
      assert City.founder_vested_tokens(city, @block_height + 4_320) == div(640_000, 12)

      # 6 months
      assert City.founder_vested_tokens(city, @block_height + 4_320 * 6) == div(640_000 * 6, 12)

      # 12+ months (fully vested)
      assert City.founder_vested_tokens(city, @block_height + 4_320 * 12) == 640_000
      assert City.founder_vested_tokens(city, @block_height + 4_320 * 24) == 640_000
    end
  end

  describe "dead?/1" do
    test "city is dead when citizen count is 0" do
      city = %CitySchema{citizen_count: 0}
      assert City.dead?(city)
    end

    test "city is alive with citizens" do
      city = %CitySchema{citizen_count: 1}
      refute City.dead?(city)
    end
  end

  # Helpers

  defp found_city do
    City.found("Neo-Tokyo", @location, @founder, @block_height,
      stake_amount: @founding_stake, stake_txid: "txid_founding",
      description: "Cyberpunk metropolis")
  end

  defp build_city_with_citizens(count) when count >= 1 do
    {:ok, city, _} = found_city()

    Enum.reduce(2..count, city, fn i, acc ->
      {:ok, updated, _} = City.add_citizen(acc, "citizen_#{i}", @block_height)
      updated
    end)
  end
end
