defmodule Locus.FibonacciTest do
  use ExUnit.Case, async: true

  alias Locus.Fibonacci

  describe "at/1" do
    test "returns correct Fibonacci numbers" do
      assert Fibonacci.at(1) == 1
      assert Fibonacci.at(2) == 1
      assert Fibonacci.at(3) == 2
      assert Fibonacci.at(4) == 3
      assert Fibonacci.at(5) == 5
      assert Fibonacci.at(6) == 8
      assert Fibonacci.at(7) == 13
      assert Fibonacci.at(10) == 55
    end
  end

  describe "sequence/1" do
    test "generates first 6 Fibonacci numbers" do
      assert Fibonacci.sequence(6) == [1, 1, 2, 3, 5, 8]
    end

    test "generates first 10 Fibonacci numbers" do
      assert Fibonacci.sequence(10) == [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
    end
  end

  describe "phase_thresholds/0" do
    test "returns 6 cumulative thresholds" do
      thresholds = Fibonacci.phase_thresholds()
      assert length(thresholds) == 6

      # Each threshold is strictly greater than the previous
      thresholds
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] -> assert b > a end)
    end

    test "thresholds are Fibonacci-cumulative × base_blocks" do
      base = Fibonacci.base_blocks()

      # Phase 1: Fib(1) = 1, cumulative = 1
      assert Fibonacci.phase_threshold(1) == 1 * base

      # Phase 2: Fib(1) + Fib(2) = 1 + 1 = 2
      assert Fibonacci.phase_threshold(2) == 2 * base

      # Phase 3: 1 + 1 + 2 = 4
      assert Fibonacci.phase_threshold(3) == 4 * base

      # Phase 6: 1 + 1 + 2 + 3 + 5 + 8 = 20
      assert Fibonacci.phase_threshold(6) == 20 * base
    end
  end

  describe "current_phase_index/1" do
    test "returns 0 before any phase unlocks" do
      assert Fibonacci.current_phase_index(0) == 0
      assert Fibonacci.current_phase_index(100) == 0
    end

    test "returns correct phase for elapsed blocks" do
      base = Fibonacci.base_blocks()

      assert Fibonacci.current_phase_index(1 * base) == 1
      assert Fibonacci.current_phase_index(2 * base) == 2
      assert Fibonacci.current_phase_index(4 * base) == 3
      assert Fibonacci.current_phase_index(20 * base) == 6
    end

    test "returns 6 for very large block counts" do
      assert Fibonacci.current_phase_index(1_000_000) == 6
    end
  end

  describe "blocks_until_next_phase/1" do
    test "returns blocks remaining for next phase" do
      base = Fibonacci.base_blocks()

      {:ok, remaining} = Fibonacci.blocks_until_next_phase(0)
      assert remaining == 1 * base
    end

    test "returns max_phase when at sovereign" do
      assert Fibonacci.blocks_until_next_phase(1_000_000) == {:max_phase, 0}
    end
  end

  describe "unlock_height/2" do
    test "calculates absolute unlock height" do
      base = Fibonacci.base_blocks()
      founded_at = 100_000

      assert Fibonacci.unlock_height(founded_at, 1) == founded_at + 1 * base
      assert Fibonacci.unlock_height(founded_at, 6) == founded_at + 20 * base
    end
  end
end
