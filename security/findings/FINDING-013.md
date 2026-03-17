# FINDING-013: Token Redemption Potential Race Condition

**Severity:** LOW
**Component:** core
**File:** `core/lib/locus/treasury.ex:176-195`
**Status:** Open

## Description

The `redeem_tokens/3` function accepts a `%City{}` struct as input and checks `bsv_amount > city.treasury_bsv`. If the city struct is stale (fetched before another concurrent redemption), two redemptions could both pass validation:

```elixir
def redeem_tokens(%City{} = city, token_amount, _redeemer_pubkey) do
  rate = redemption_rate(city.treasury_bsv, city.token_supply)
  bsv_amount = rate * token_amount
  cond do
    bsv_amount > city.treasury_bsv -> {:error, :insufficient_treasury}
    # ...
    true ->
      updated = %{city | treasury_bsv: city.treasury_bsv - bsv_amount}
      {:ok, bsv_amount, updated}
  end
end
```

## Impact

In the current GenServer architecture, the Treasury GenServer serializes calls, providing some protection. However:
1. The `redeem_tokens/3` function operates on a passed-in `%City{}` struct, not the GenServer's internal state
2. If called directly (not through GenServer), concurrent calls with the same city struct could both succeed
3. The returned `updated` city is not automatically persisted — the caller must handle state update
4. If two callers both read the city, both call `redeem_tokens`, and both try to apply the update, the second one operates on stale data

## Remediation

See `remediation/REM-013.md`
