# FINDING-002: Invocation Nonce Hardcoded to Zero

**Severity:** HIGH
**Component:** ghost/runtime
**File:** `ghost/runtime/src/api/handlers.rs:102`
**Status:** Open

## Description

The ghost invocation handler sets the nonce to a hardcoded value of 0 for every invocation:

```rust
let invocation = InvocationRequest {
    // ...
    nonce: 0, // TODO: Generate properly
    // ...
};
```

## Impact

Without unique nonces, invocation requests are vulnerable to replay attacks:
1. An attacker can capture a valid invocation request
2. Replay it indefinitely to trigger the same ghost action multiple times
3. If the ghost performs payment operations, funds can be drained by replaying payment-triggering invocations
4. If the ghost modifies state, replayed invocations corrupt state

## Attack Scenario

1. User invokes a ghost that charges 1,000 sats for a service
2. Attacker captures the HTTP request
3. Attacker replays the request 100 times
4. Ghost charges the user 100,000 sats total (if payment channel has funds)

## Remediation

See `remediation/REM-002.md`
