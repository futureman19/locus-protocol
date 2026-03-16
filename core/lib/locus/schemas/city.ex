defmodule Locus.Schemas.City do
  @moduledoc """
  City schema — the primary primitive of the Locus Protocol.

  ## Lifecycle Phases

  Cities progress through 6 phases, each unlocked after a Fibonacci
  number of block periods from the founding block:

      Phase 1 — Founded:       Fib(1) = 1   (city exists, founder only)
      Phase 2 — Settled:       Fib(2) = 1   (first citizens join)
      Phase 3 — Established:   Fib(3) = 2   (services begin)
      Phase 4 — Thriving:      Fib(4) = 3   (treasury active, UBI starts)
      Phase 5 — Metropolitan:  Fib(5) = 5   (multi-district expansion)
      Phase 6 — Sovereign:     Fib(6) = 8   (full self-governance)

  Thresholds are Fib(N) × `fibonacci_base_blocks` (default 144 ≈ 1 day).
  """

  @phases [:founded, :settled, :established, :thriving, :metropolitan, :sovereign]

  @type phase :: :founded | :settled | :established | :thriving | :metropolitan | :sovereign
  @type governance_era :: :genesis | :federal

  @type t :: %__MODULE__{
    id: binary(),
    name: String.t(),
    territory_id: binary(),
    founder_pubkey: binary(),
    founded_at: non_neg_integer(),
    phase: phase(),
    phase_changed_at: non_neg_integer(),
    citizens: [binary()],
    citizen_count: non_neg_integer(),
    treasury_balance: non_neg_integer(),
    territories: [binary()],
    governance_era: governance_era(),
    founding_txid: binary(),
    metadata: map()
  }

  defstruct [
    :id,
    :name,
    :territory_id,
    :founder_pubkey,
    :founded_at,
    :founding_txid,
    phase: :founded,
    phase_changed_at: 0,
    citizens: [],
    citizen_count: 0,
    treasury_balance: 0,
    territories: [],
    governance_era: :genesis,
    metadata: %{}
  ]

  def phases, do: @phases

  @doc "Index of a phase (1-based)"
  def phase_index(:founded), do: 1
  def phase_index(:settled), do: 2
  def phase_index(:established), do: 3
  def phase_index(:thriving), do: 4
  def phase_index(:metropolitan), do: 5
  def phase_index(:sovereign), do: 6

  @doc "Phase from index (1-based)"
  def phase_from_index(1), do: :founded
  def phase_from_index(2), do: :settled
  def phase_from_index(3), do: :established
  def phase_from_index(4), do: :thriving
  def phase_from_index(5), do: :metropolitan
  def phase_from_index(6), do: :sovereign
  def phase_from_index(_), do: nil

  @doc "Next phase in the lifecycle, or nil if sovereign"
  def next_phase(:founded), do: :settled
  def next_phase(:settled), do: :established
  def next_phase(:established), do: :thriving
  def next_phase(:thriving), do: :metropolitan
  def next_phase(:metropolitan), do: :sovereign
  def next_phase(:sovereign), do: nil
end
