# FINDING-011: Fibonacci Sequence Has Exponential Time Complexity

**Severity:** LOW
**Component:** core
**File:** `core/lib/locus/fibonacci.ex:40-44`
**Status:** Open

## Description

The `sequence/1` function uses naive recursion without memoization:

```elixir
def sequence(n) when n > 2 do
  sequence(n - 1) ++ [next_fib(List.last(sequence(n - 1)), List.last(sequence(n - 1) |> Enum.drop(-1)))]
end
```

Each call to `sequence(n)` makes 3 recursive calls to `sequence(n-1)`, giving O(3^n) time complexity. For `n = 30`, this would take billions of operations.

## Impact

- **DoS risk:** If `sequence/1` is ever called with user-controlled input, the node will hang
- Currently NOT called in production paths — `blocks_for_citizens/1` uses a hardcoded lookup table
- If a future developer calls `sequence(n)` for any `n > 20`, the node becomes unresponsive

## Remediation

See `remediation/REM-011.md`
