# FINDING-014: Governance Vote Tally Uses Float Division

**Severity:** MEDIUM
**Component:** core
**File:** `core/lib/locus/governance.ex:160-173`
**Status:** Open

## Description

The vote tally function uses floating-point division to determine if a proposal passes:

```elixir
def tally(%Proposal{} = proposal, %City{} = city) do
  threshold = Proposal.threshold(proposal.proposal_type)  # e.g., 0.51
  quorum = quorum_for_phase(city.phase)                     # e.g., 0.40

  total_votes = proposal.votes_for + proposal.votes_against + proposal.votes_abstain
  quorum_needed = ceil(city.citizen_count * quorum)

  cond do
    # ...
    proposal.votes_for / (proposal.votes_for + proposal.votes_against) >= threshold ->
      :passed
    # ...
  end
end
```

`proposal.votes_for / (proposal.votes_for + proposal.votes_against)` performs float division in Elixir when both operands are integers (returns a float). The `>=` comparison with the threshold float (`0.51`) is subject to IEEE 754 precision issues.

## Impact

Edge cases where the vote ratio is exactly at the threshold could produce incorrect results:
- Example: 51 votes for, 49 against. `51 / 100 = 0.51`. Is `0.51 >= 0.51`? Yes, but floating-point representation of 51/100 may not be exactly 0.51.
- In practice, `51 / 100` in Elixir returns `0.51` exactly (since these are small integers), but larger vote counts could produce rounding artifacts.

Additionally, `ceil(city.citizen_count * quorum)` uses float multiplication. For `citizen_count = 3` and `quorum = 0.67`: `3 * 0.67 = 2.0099999...` which `ceil` rounds to 3. This is likely the intended behavior, but it's non-obvious.

## Remediation

See `remediation/REM-014.md`
