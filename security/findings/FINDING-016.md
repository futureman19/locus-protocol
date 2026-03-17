# FINDING-016: Silent RNG Failure in Ghost Host

**Severity:** LOW
**Component:** ghost/runtime
**File:** `ghost/runtime/src/host/mod.rs:126-131`
**Status:** Open

## Description

The `secure_random` function silently returns zeroes if the system RNG fails:

```rust
pub fn secure_random(&self) -> [u8; 32] {
    let mut buf = [0u8; 32];
    getrandom::getrandom(&mut buf).unwrap_or_default();
    buf
}
```

`unwrap_or_default()` on a `Result<(), getrandom::Error>` returns `()` (unit) on both success and failure, so the error is swallowed. If `getrandom` fails, `buf` remains all zeroes.

## Impact

- A ghost requesting randomness receives `[0u8; 32]` if the system RNG is unavailable
- This makes any cryptographic operations using this randomness completely predictable
- Gambling ghosts, lottery ghosts, or any ghost relying on unpredictable randomness would be exploitable
- The failure is silent — the ghost has no way to know it received non-random data

In practice, `getrandom` failing is extremely rare (requires /dev/urandom being unavailable or similar system-level issues), but silent failure is the wrong response for a security-critical function.

## Remediation

See `remediation/REM-016.md`
