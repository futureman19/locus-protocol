# FINDING-017: Block Height Hardcoded in Ghost Host

**Severity:** MEDIUM
**Component:** ghost/runtime
**File:** `ghost/runtime/src/host/mod.rs:100-103`
**Status:** Open

## Description

The `get_block_height` function returns a hardcoded value:

```rust
pub fn get_block_height(&self) -> u32 {
    // TODO: Get from blockchain
    800000
}
```

## Impact

- Ghosts that make decisions based on block height (e.g., time-locked actions, CLTV verification, governance deadlines) will use stale/incorrect data
- A ghost checking if a CLTV lock has expired will always see block 800,000
- Since the Genesis Key expires at block 2,100,000, ghosts cannot correctly determine the current governance era
- Any time-dependent ghost logic is broken

## Remediation

See `remediation/REM-017.md`
