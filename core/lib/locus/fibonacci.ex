defmodule Locus.Fibonacci do
  @moduledoc """
  Fibonacci-based block unlock calculations for city phase transitions.

  The Fibonacci sequence (1, 1, 2, 3, 5, 8, 13, 21, ...) determines
  when each city phase unlocks. Each phase N requires Fib(N) × base_blocks
  cumulative blocks from the city's founding.

  ## Phase Unlock Schedule

  With default base_blocks = 144 (~1 day at 10-min blocks):

      Phase 1 (Founded):       Fib(1) × 144 =   144 blocks (~1 day)
      Phase 2 (Settled):       Fib(2) × 144 =   288 blocks (~2 days cumulative)
      Phase 3 (Established):   Fib(3) × 144 =   576 blocks (~4 days cumulative)
      Phase 4 (Thriving):      Fib(4) × 144 = 1,008 blocks (~7 days cumulative)
      Phase 5 (Metropolitan):  Fib(5) × 144 = 1,728 blocks (~12 days cumulative)
      Phase 6 (Sovereign):     Fib(6) × 144 = 2,880 blocks (~20 days cumulative)
  """

  @doc """
  Return the Nth Fibonacci number (1-indexed).

  ## Examples

      iex> Locus.Fibonacci.at(1)
      1
      iex> Locus.Fibonacci.at(6)
      8
      iex> Locus.Fibonacci.at(10)
      55
  """
  @spec at(pos_integer()) :: pos_integer()
  def at(n) when is_integer(n) and n >= 1 do
    do_fib(n, 1, 1)
  end

  defp do_fib(1, a, _b), do: a
  defp do_fib(n, a, b), do: do_fib(n - 1, b, a + b)

  @doc """
  Generate the first N Fibonacci numbers.

  ## Examples

      iex> Locus.Fibonacci.sequence(6)
      [1, 1, 2, 3, 5, 8]
      iex> Locus.Fibonacci.sequence(10)
      [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
  """
  @spec sequence(pos_integer()) :: [pos_integer()]
  def sequence(n) when is_integer(n) and n >= 1 do
    Enum.map(1..n, &at/1)
  end

  @doc """
  Get the block threshold for a city phase (1-6).

  Returns the cumulative number of blocks from founding required to
  unlock the given phase. Each phase adds Fib(phase) × base_blocks.

  ## Examples

      iex> Locus.Fibonacci.phase_threshold(1)
      144
      iex> Locus.Fibonacci.phase_threshold(6)
      2880
  """
  @spec phase_threshold(1..6) :: pos_integer()
  def phase_threshold(phase) when phase >= 1 and phase <= 6 do
    base = base_blocks()

    1..phase
    |> Enum.map(&at/1)
    |> Enum.sum()
    |> Kernel.*(base)
  end

  @doc """
  Get all 6 phase thresholds as a list.

  ## Examples

      iex> Locus.Fibonacci.phase_thresholds()
      [144, 288, 576, 1008, 1728, 2880]
  """
  @spec phase_thresholds() :: [pos_integer()]
  def phase_thresholds do
    Enum.map(1..6, &phase_threshold/1)
  end

  @doc """
  Determine the current phase index (1-6) based on blocks elapsed
  since city founding.

  ## Examples

      iex> Locus.Fibonacci.current_phase_index(0)
      0
      iex> Locus.Fibonacci.current_phase_index(144)
      1
      iex> Locus.Fibonacci.current_phase_index(3000)
      6
  """
  @spec current_phase_index(non_neg_integer()) :: 0..6
  def current_phase_index(blocks_elapsed) when blocks_elapsed < 0, do: 0

  def current_phase_index(blocks_elapsed) do
    thresholds = phase_thresholds()

    thresholds
    |> Enum.with_index(1)
    |> Enum.reduce(0, fn {threshold, index}, acc ->
      if blocks_elapsed >= threshold, do: index, else: acc
    end)
  end

  @doc """
  Calculate blocks remaining until the next phase unlock.

  Returns `{:ok, blocks_remaining}` or `{:max_phase, 0}` if already
  at Sovereign (phase 6).
  """
  @spec blocks_until_next_phase(non_neg_integer()) ::
    {:ok, non_neg_integer()} | {:max_phase, 0}
  def blocks_until_next_phase(blocks_elapsed) do
    current = current_phase_index(blocks_elapsed)

    if current >= 6 do
      {:max_phase, 0}
    else
      next_threshold = phase_threshold(current + 1)
      {:ok, max(0, next_threshold - blocks_elapsed)}
    end
  end

  @doc """
  Calculate the unlock block height for a given phase, relative to
  a city's founding block height.

  ## Examples

      iex> Locus.Fibonacci.unlock_height(100_000, 3)
      100_576
  """
  @spec unlock_height(non_neg_integer(), 1..6) :: non_neg_integer()
  def unlock_height(founded_at, phase) do
    founded_at + phase_threshold(phase)
  end

  @doc """
  Get the configurable base block multiplier.
  Default: 144 (~1 day of Bitcoin blocks at 10-min intervals).
  """
  @spec base_blocks() :: pos_integer()
  def base_blocks do
    Application.get_env(:locus_core, :fibonacci_base_blocks, 144)
  end
end
