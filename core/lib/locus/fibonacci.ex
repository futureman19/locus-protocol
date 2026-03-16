defmodule Locus.Fibonacci do
  @moduledoc """
  Fibonacci sequence calculations for city block unlocking.
  
  Per spec 02-city-lifecycle.md:
  - Blocks unlock based on CITIZEN COUNT (not block height)
  - Sequence: 1, 1, 2, 3, 5, 8, 13, 21, 34...
  - Citizen count thresholds determine how many /16 blocks are unlocked
  
  CORRECT (per spec):
  - 1 citizen = 2 blocks (Genesis)
  - 4 citizens = 5 blocks (Village)  
  - 9 citizens = 8 blocks (Town)
  - 21 citizens = 16 blocks (City)
  - 51 citizens = 24 blocks (Metropolis)
  
  WRONG (previous implementation):
  - Using block height: 144 blocks, 288 blocks, etc.
  - This is NOT what the spec says
  """

  @doc """
  Returns the first n Fibonacci numbers.
  
  ## Examples
      iex> Fibonacci.sequence(1)
      [1]
      
      iex> Fibonacci.sequence(5)
      [1, 1, 2, 3, 5]
      
      iex> Fibonacci.sequence(10)
      [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
  """
  @spec sequence(non_neg_integer()) :: list(non_neg_integer())
  def sequence(0), do: []
  def sequence(1), do: [1]
  def sequence(2), do: [1, 1]
  
  def sequence(n) when n > 2 do
    sequence(n - 1) ++ [next_fib(List.last(sequence(n - 1)), List.last(sequence(n - 1) |> Enum.drop(-1)))]
  end
  
  defp next_fib(a, b), do: a + b
  
  @doc """
  Returns the sum of first n Fibonacci numbers.
  
  ## Examples
      iex> Fibonacci.sum_up_to(1)
      1
      
      iex> Fibonacci.sum_up_to(5)
      12  # 1+1+2+3+5
  """
  @spec sum_up_to(non_neg_integer()) :: non_neg_integer()
  def sum_up_to(n), do: sequence(n) |> Enum.sum()
  
  @doc """
  Returns the number of /16 blocks unlocked for a given citizen count.
  
  Per spec 02-city-lifecycle.md table:
  | Citizens | Blocks | Phase |
  |----------|--------|-------|
  | 1        | 2      | Genesis |
  | 2-3      | 2      | Settlement |
  | 4-8      | 5      | Village |
  | 9-20     | 8      | Town |
  | 21-50    | 16     | City |
  | 51+      | 24     | Metropolis |
  """
  @spec blocks_for_citizens(non_neg_integer()) :: non_neg_integer()
  def blocks_for_citizens(citizen_count) when citizen_count >= 51, do: 24
  def blocks_for_citizens(citizen_count) when citizen_count >= 21, do: 16
  def blocks_for_citizens(citizen_count) when citizen_count >= 9, do: 8
  def blocks_for_citizens(citizen_count) when citizen_count >= 4, do: 5
  def blocks_for_citizens(citizen_count) when citizen_count >= 1, do: 2
  def blocks_for_citizens(_), do: 0
  
  @doc """
  Returns the city phase based on citizen count.
  
  Per spec 02-city-lifecycle.md:
  - Phase 0 Genesis: 1 citizen
  - Phase 1 Settlement: 2-3 citizens  
  - Phase 2 Village: 4-8 citizens
  - Phase 3 Town: 9-20 citizens
  - Phase 4 City: 21-50 citizens
  - Phase 5 Metropolis: 51+ citizens
  
  NOTE: Phase 4 is called :city (not :thriving as in wrong implementation)
  """
  @spec phase_for_citizens(non_neg_integer()) :: atom()
  def phase_for_citizens(citizen_count) when citizen_count >= 51, do: :metropolis
  def phase_for_citizens(citizen_count) when citizen_count >= 21, do: :city
  def phase_for_citizens(citizen_count) when citizen_count >= 9, do: :town
  def phase_for_citizens(citizen_count) when citizen_count >= 4, do: :village
  def phase_for_citizens(citizen_count) when citizen_count >= 2, do: :settlement
  def phase_for_citizens(citizen_count) when citizen_count >= 1, do: :genesis
  def phase_for_citizens(_), do: :none
  
  @doc """
  Returns the governance type for a given phase.
  
  Per spec 02-city-lifecycle.md:
  - Genesis/Settlement: Founder
  - Village: Tribal Council
  - Town: Republic
  - City: Direct Democracy
  - Metropolis: Senate
  """
  @spec governance_for_phase(atom()) :: atom()
  def governance_for_phase(:genesis), do: :founder
  def governance_for_phase(:settlement), do: :founder
  def governance_for_phase(:village), do: :tribal_council
  def governance_for_phase(:town), do: :republic
  def governance_for_phase(:city), do: :direct_democracy
  def governance_for_phase(:metropolis), do: :senate
  def governance_for_phase(_), do: :none
end
