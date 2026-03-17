# FINDING-018: Tribal Council Proposal Authorization Too Permissive

**Severity:** LOW
**Component:** core
**File:** `core/lib/locus/governance.ex:244-246`
**Status:** Open

## Description

The `can_propose?/3` function for tribal council governance allows any citizen to create proposals:

```elixir
def can_propose?(%City{} = city, pubkey, :tribal_council) do
  pubkey == city.founder_pubkey or pubkey in city.citizens
end
```

Per spec 04-governance.md, tribal council governance (Village phase) should only allow the founder + 2 elected council members to propose. The current implementation allows any citizen to propose.

## Impact

- In the Village phase (4-8 citizens), any citizen can create proposals
- This bypasses the intended tribal council restriction
- A hostile citizen could spam proposals (each requiring a 0.1 BSV deposit, so the economic cost provides some mitigation)
- The governance spec's intended power structure is not enforced

## Remediation

See `remediation/REM-018.md`
