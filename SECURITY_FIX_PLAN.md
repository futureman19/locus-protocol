# Complete Security Fix Plan — Locus Protocol

## Already Fixed ✅

| Severity | Issue | Commit |
|----------|-------|--------|
| CRITICAL | WASM env var leak | 64cec8f |
| HIGH | Float arithmetic in progressive tax | 64cec8f |
| HIGH | Empty signature validation | 64cec8f |
| HIGH | Unrestricted CORS | 64cec8f |
| HIGH | CLTV penalty bypass (documented) | 64cec8f |

---

## Remaining Issues To Fix

### 🔴 HIGH Priority

#### 1. Insecure RNG in TypeScript SDK (HIGH)
**Location:** `client/src/modules/transaction-builder.ts:202`
```typescript
nonce: params.nonce ?? Math.floor(Math.random() * 0xffffffff),
```
**Fix:** Use `crypto.getRandomValues()` for cryptographically secure randomness.

#### 2. Type Code Mismatch Between Node and Core (HIGH)
**Issue:** `node/lib/locus/tx_builder.ex` uses old ghost-centric type codes (ghost_register: 0x01) while `core/lib/locus/transaction.ex` uses territory-centric codes (city_found: 0x01).
**Fix:** Update node tx_builder to use territory-centric type codes.

#### 3. WASM Memory Read from Offset 0 (MEDIUM → HIGH)
**Location:** `ghost/runtime/src/runtime/engine.rs:185`
```rust
memory.read(store, 0, &mut output)?;
```
**Issue:** Reading from offset 0 can read invalid/null data.
**Fix:** Use proper memory allocation and pointer management.

---

### 🟡 MEDIUM Priority

#### 4. Float Vote Tally (MEDIUM)
**Issue:** Governance vote tallying may use float arithmetic.
**Fix:** Use integer arithmetic for all vote calculations.

#### 5. Hardcoded Block Height (MEDIUM)
**Issue:** Check for any hardcoded block heights that could cause issues.
**Fix:** Make all block heights configurable or derived.

#### 6. No Network Whitelist (MEDIUM)
**Issue:** Elixir node accepts connections from any network.
**Fix:** Add IP whitelist configuration.

#### 7. Stubbed Payment Channels (MEDIUM)
**Issue:** Payment channel functions are stubbed/not implemented.
**Fix:** Implement or document as future work.

---

### 🟢 LOW Priority

#### 8. Exponential Fibonacci (LOW)
**Issue:** Fibonacci growth is exponential (1,1,2,3,5,8,13,21,34...).
**Status:** This is by design per the protocol spec. Not a bug.

#### 9. Silent RNG Failure (LOW)
**Issue:** RNG could fail silently in some edge cases.
**Fix:** Add explicit error handling for RNG failures.

#### 10. Redemption Race Condition (LOW)
**Issue:** Token redemption may have race conditions.
**Fix:** Add proper locking/atomic operations.

#### 11. Permissive Governance Auth (LOW)
**Issue:** Tribal council auth may be too permissive.
**Fix:** Review and tighten governance authorization.

---

## Implementation Order

### Phase 1: Critical Fixes (Must have for mainnet)
1. ✅ WASM env leak (DONE)
2. TypeScript SDK insecure RNG
3. Type code mismatch (node vs core)
4. WASM memory read safety

### Phase 2: Important Fixes (Should have)
5. Float vote tally
6. Hardcoded block height
7. Network whitelist

### Phase 3: Nice to have
8. Payment channels
9. RNG failure handling
10. Redemption race conditions
11. Governance auth tightening

---

## Files to Modify

| File | Issue | Lines |
|------|-------|-------|
| `client/src/modules/transaction-builder.ts` | Insecure RNG | ~202 |
| `client/src/utils/crypto.ts` (new) | Secure RNG utility | new |
| `node/lib/locus/tx_builder.ex` | Type code mismatch | Multiple |
| `ghost/runtime/src/runtime/engine.rs` | Memory safety | ~185 |
| `core/lib/locus/governance.ex` | Float vote tally | Check |
| `core/lib/locus/treasury.ex` | Race conditions | Check |
| `node/config/runtime.exs` | Network whitelist | Add config |

---

## Testing Checklist

After all fixes:
- [ ] All TypeScript tests pass
- [ ] All Elixir tests pass
- [ ] All Rust tests pass
- [ ] Integration tests pass
- [ ] Security audit re-run
- [ ] The Grid integration tested
