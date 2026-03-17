# FINDING-009: Payment Channels Return Fake Data

**Severity:** MEDIUM
**Component:** ghost/runtime
**File:** `ghost/runtime/src/api/handlers.rs:178-214`
**Status:** Open

## Description

All three payment channel endpoints return hardcoded fake responses:

```rust
// open_channel: returns fake channel_id "chan-001"
// get_channel: returns hardcoded balances (user: 10000, ghost: 0)
// close_channel: returns fake "closed" status
```

## Impact

1. Integrators building against this API will receive misleading data
2. A front-end displaying channel state will show incorrect balances
3. If the `open_channel` endpoint is called in production, it returns success without actually creating a channel — users may believe their funds are locked when they are not
4. No actual payment channel is opened, updated, or settled — funds are at risk if users send BSV expecting channel functionality

## Remediation

See `remediation/REM-009.md`
