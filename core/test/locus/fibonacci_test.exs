defmodule Locus.FibonacciTest do
  use ExUnit.Case, async: true

  alias Locus.Fibonacci

  describe "sequence/1" do
    test "returns empty for 0" do
      assert Fibonacci.sequence(0) == []
    end

    test "returns [1] for 1" do
      assert Fibonacci.sequence(1) == [1]
    end

    test "returns first 6 Fibonacci numbers" do
      assert Fibonacci.sequence(6) == [1, 1, 2, 3, 5, 8]
    end

    test "returns first 10 Fibonacci numbers" do
      assert Fibonacci.sequence(10) == [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
    end
  end

  describe "sum_up_to/1" do
    test "sums first 5 Fibonacci numbers" do
      assert Fibonacci.sum_up_to(5) == 12  # 1+1+2+3+5
    end

    test "sums first 1" do
      assert Fibonacci.sum_up_to(1) == 1
    end
  end

  describe "blocks_for_citizens/1" do
    test "returns correct block counts per spec" do
      # Per spec 02-city-lifecycle.md table
      assert Fibonacci.blocks_for_citizens(1) == 2     # Genesis
      assert Fibonacci.blocks_for_citizens(2) == 2     # Settlement
      assert Fibonacci.blocks_for_citizens(3) == 2     # Settlement
      assert Fibonacci.blocks_for_citizens(4) == 5     # Village
      assert Fibonacci.blocks_for_citizens(8) == 5     # Village
      assert Fibonacci.blocks_for_citizens(9) == 8     # Town
      assert Fibonacci.blocks_for_citizens(20) == 8    # Town
      assert Fibonacci.blocks_for_citizens(21) == 16   # City
      assert Fibonacci.blocks_for_citizens(50) == 16   # City
      assert Fibonacci.blocks_for_citizens(51) == 24   # Metropolis
      assert Fibonacci.blocks_for_citizens(100) == 24  # Metropolis
    end

    test "returns 0 for no citizens" do
      assert Fibonacci.blocks_for_citizens(0) == 0
    end
  end

  describe "phase_for_citizens/1" do
    test "returns correct phases per spec" do
      assert Fibonacci.phase_for_citizens(1) == :genesis
      assert Fibonacci.phase_for_citizens(2) == :settlement
      assert Fibonacci.phase_for_citizens(3) == :settlement
      assert Fibonacci.phase_for_citizens(4) == :village
      assert Fibonacci.phase_for_citizens(8) == :village
      assert Fibonacci.phase_for_citizens(9) == :town
      assert Fibonacci.phase_for_citizens(20) == :town
      assert Fibonacci.phase_for_citizens(21) == :city
      assert Fibonacci.phase_for_citizens(50) == :city
      assert Fibonacci.phase_for_citizens(51) == :metropolis
    end

    test "returns :none for 0 citizens" do
      assert Fibonacci.phase_for_citizens(0) == :none
    end
  end

  describe "governance_for_phase/1" do
    test "returns correct governance types per spec" do
      assert Fibonacci.governance_for_phase(:genesis) == :founder
      assert Fibonacci.governance_for_phase(:settlement) == :founder
      assert Fibonacci.governance_for_phase(:village) == :tribal_council
      assert Fibonacci.governance_for_phase(:town) == :republic
      assert Fibonacci.governance_for_phase(:city) == :direct_democracy
      assert Fibonacci.governance_for_phase(:metropolis) == :senate
    end

    test "returns :none for unknown phase" do
      assert Fibonacci.governance_for_phase(:bogus) == :none
    end
  end
end
