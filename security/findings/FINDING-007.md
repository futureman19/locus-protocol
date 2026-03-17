# FINDING-007: Heartbeat Nonce Uses Math.random()

**Severity:** MEDIUM
**Component:** client
**File:** `client/src/modules/transaction-builder.ts:188`
**Status:** Open

## Description

The heartbeat message builder uses `Math.random()` to generate nonces:

```typescript
static buildHeartbeat(params: HeartbeatParams): Buffer {
  return TransactionBuilder.encode('heartbeat', {
    // ...
    nonce: params.nonce ?? Math.floor(Math.random() * 0xffffffff),
  });
}
```

`Math.random()` is not cryptographically secure. It uses a PRNG (typically xorshift128+ in V8) that can be predicted if an attacker observes sufficient outputs.

## Impact

- Heartbeat nonces could be predicted, allowing an attacker to forge heartbeats
- If heartbeats serve as proof-of-presence (per spec), predictable nonces weaken the proof
- An attacker who can predict nonces could pre-compute valid heartbeats

Note: The Elixir core uses `:crypto.strong_rand_bytes(4)` which IS cryptographically secure. This inconsistency means the client and server have different security guarantees.

## Remediation

See `remediation/REM-007.md`
