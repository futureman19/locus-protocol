defmodule Locus.TestnetValidationTest do
  use ExUnit.Case, async: true

  alias Locus.Testnet

  @fixtures_dir Path.expand("../../../testnet/fixtures", __DIR__)

  test "bootstraps five deterministic cities with expected initial phases" do
    scenario = Testnet.build_scenario!(fixtures_dir: @fixtures_dir)

    assert length(scenario.cities) == 5

    assert city_state(scenario, "atlas", :initial_state).phase == "genesis"
    assert city_state(scenario, "beacon", :initial_state).phase == "settlement"
    assert city_state(scenario, "cedar", :initial_state).phase == "village"
    assert city_state(scenario, "delta", :initial_state).phase == "city"
    assert city_state(scenario, "echelon", :initial_state).phase == "metropolis"

    assert city_state(scenario, "atlas", :initial_state).blocks_unlocked == 2
    assert city_state(scenario, "beacon", :initial_state).blocks_unlocked == 2
    assert city_state(scenario, "cedar", :initial_state).blocks_unlocked == 5
    assert city_state(scenario, "delta", :initial_state).blocks_unlocked == 16
    assert city_state(scenario, "echelon", :initial_state).blocks_unlocked == 24
  end

  test "citizen join plans trigger Fibonacci unlock thresholds" do
    scenario = Testnet.build_scenario!(fixtures_dir: @fixtures_dir)

    assert %{
             city_slug: "atlas",
             actual_phase: "village",
             actual_blocks_unlocked: 5,
             passed: true
           } = join_plan(scenario, "atlas-growth")

    assert %{
             city_slug: "beacon",
             actual_phase: "town",
             actual_blocks_unlocked: 8,
             passed: true
           } = join_plan(scenario, "beacon-growth")

    assert %{
             city_slug: "cedar",
             actual_phase: "city",
             actual_blocks_unlocked: 16,
             passed: true
           } = join_plan(scenario, "cedar-growth")
  end

  test "treasury funding and UBI math validate end-to-end" do
    scenario = Testnet.build_scenario!(fixtures_dir: @fixtures_dir)

    assert scenario.validation.passed

    for slug <- ["cedar", "delta", "echelon"] do
      city = find_city!(scenario, slug)

      assert city.final_state.ubi_active
      assert city.final_state.treasury_bsv > 0
      assert length(city.ubi_events) >= 1

      Enum.each(city.ubi_events, fn event ->
        assert event.total_sats == event.per_citizen_sats * event.citizen_count_before
        assert event.treasury_after_sats == event.treasury_before_sats - event.total_sats
      end)
    end
  end

  defp city_state(scenario, slug, key) do
    scenario
    |> find_city!(slug)
    |> Map.fetch!(key)
  end

  defp join_plan(scenario, id) do
    Enum.find(scenario.join_plan_results, &(&1.id == id))
  end

  defp find_city!(scenario, slug) do
    Enum.find(scenario.cities, &(&1.slug == slug))
  end
end
