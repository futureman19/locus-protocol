# FINDING-010: WASM Memory Read Always From Offset 0

**Severity:** MEDIUM
**Component:** ghost/runtime
**File:** `ghost/runtime/src/runtime/engine.rs:177-185`
**Status:** Open

## Description

The WASM entry point call ignores the actual input data and always reads the result from memory offset 0:

```rust
// For simplicity, return empty result for now
// TODO: Proper memory management and input/output passing
let result = func.call_async(store, (0, 0)).await  // Always passes (0, 0) as input
    .map_err(|e| GhostError::wasm(format!("Execution failed: {}", e)))?;

// Return result based on pointer
let mut output = vec![0u8; result as usize];
memory.read(store, 0, &mut output)?;  // Always reads from offset 0
```

## Impact

1. Input data (`_input: &[u8]`) is never passed to the WASM module
2. The function always receives `(0, 0)` as arguments regardless of actual input
3. Reading from offset 0 with length `result` could read arbitrary WASM memory if `result` is large
4. If the WASM module stores sensitive data at the beginning of its memory, it could be leaked in the response
5. No actual input/output protocol exists — ghosts cannot receive invocation parameters

## Remediation

See `remediation/REM-010.md`
