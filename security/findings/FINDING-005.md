# FINDING-005: Progressive Tax Uses Float Arithmetic

**Severity:** HIGH
**Component:** core, client
**Files:** `core/lib/locus/staking.ex:166`, `client/src/constants/stakes.ts:92-94`
**Status:** Open

## Description

The progressive territory tax uses floating-point exponentiation:

**Elixir:**
```elixir
def territory_tax(base_cost, territory_number) when territory_number >= 1 do
  trunc(base_cost * :math.pow(2, territory_number - 1))
end
```

**TypeScript:**
```typescript
export function progressiveTax(baseCost: number, propertyNumber: number): number {
  return baseCost * Math.pow(2, propertyNumber - 1);
}
```

`:math.pow/2` and `Math.pow` return IEEE 754 doubles. For `territory_number >= 54`, `2^53` exceeds the range where doubles can represent consecutive integers. `trunc()` of an imprecise float produces a wrong integer.

Additionally, the TypeScript version has no `Math.floor()` or `Math.trunc()` call — it returns a raw float, which may produce non-integer satoshi amounts.

## Impact

- **Consensus divergence:** Different nodes could calculate different tax amounts for the same territory claim if float rounding differs across platforms/architectures
- **Determinism failure:** The same inputs could produce different outputs depending on the runtime's floating-point implementation
- **Client/server mismatch:** TypeScript returns float, Elixir returns truncated integer — they disagree on the tax amount

While 54+ territories per entity is unlikely in practice, this is a **consensus-critical** calculation. Any non-determinism in economic formulas undermines protocol integrity.

## Remediation

See `remediation/REM-005.md`
