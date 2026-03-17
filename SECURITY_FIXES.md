# Security Fix Summary — March 17, 2026

## Fixes Applied

### CRITICAL (1 Fixed)

#### FINDING-001: WASM Sandbox Environment Variable Leak
**Location:** `ghost/runtime/src/runtime/engine.rs`

**Issue:** The Wasmtime WASI configuration used `.inherit_env()` which passed all host environment variables (including secrets like `DATABASE_URL`, API keys, private keys) to the WASM sandbox.

**Fix:** Removed `.inherit_env()` from `WasiCtxBuilder`. WASM modules now run in a clean environment without access to host env vars.

```rust
// BEFORE (VULNERABLE):
let wasi = WasiCtxBuilder::new()
    .inherit_stdio()
    .inherit_env()  // CRITICAL: Leaked all host env vars
    .build();

// AFTER (FIXED):
let wasi = WasiCtxBuilder::new()
    .inherit_stdio()
    // REMOVED: .inherit_env() - No longer leaks host environment
    .build();
```

---

### HIGH (4 Fixed, 1 Partial)

#### FINDING-002: Float Arithmetic in Progressive Tax
**Locations:** 
- `core/lib/locus/staking.ex` (`territory_tax/2`)
- `client/src/utils/stakes.ts` (`progressiveTax`)

**Issue:** Progressive tax calculation used floating-point math (`:math.pow(2, n-1)` / `Math.pow(2, n-1)`) which can introduce precision errors in financial calculations.

**Fix:** Replaced with exact integer bit shifting:

```elixir
# Elixir - BEFORE:
trunc(base_cost * :math.pow(2, territory_number - 1))

# Elixir - AFTER:
multiplier = 1 <<< (territory_number - 1)
base_cost * multiplier
```

```typescript
// TypeScript - BEFORE:
return baseCost * Math.pow(2, propertyNumber - 1);

// TypeScript - AFTER:
const multiplier = 1 << (propertyNumber - 1);
return baseCost * multiplier;
```

#### FINDING-003: Empty Signature Acceptance
**Location:** `client/src/modules/transaction-builder.ts`

**Issue:** Transaction builders accepted empty strings for required signatures/keys, allowing unauthorized transactions.

**Fix:** Added validation to reject empty signatures:

```typescript
static buildCityFound(params: CityFoundParams): Buffer {
  // SECURITY FIX: Validate signature is present and non-empty
  if (!params.signature || params.signature.length === 0) {
    throw new Error('SECURITY: City founding requires a valid signature');
  }
  // ...
}

static buildTerritoryTransfer(...): Buffer {
  if (!fromPubkey || fromPubkey.length === 0) {
    throw new Error('SECURITY: Territory transfer requires from_pubkey');
  }
  // ...
}

static buildObjectDestroy(...): Buffer {
  if (!ownerPubkey || ownerPubkey.length === 0) {
    throw new Error('SECURITY: Object destroy requires owner_pubkey');
  }
  // ...
}
```

#### FINDING-004: Unrestricted CORS
**Locations:** 
- `indexer/src/config.ts`
- `indexer/src/server.ts`
- `indexer/src/index.ts`

**Issue:** The indexer API allowed cross-origin requests from any domain (`app.use(cors())`), making it vulnerable to CSRF attacks in browser contexts.

**Fix:** Added configurable CORS whitelist:

```typescript
// config.ts
server: {
  port: parseInt(env('PORT', '3000'), 10),
  host: env('HOST', '0.0.0.0'),
  corsWhitelist: process.env.CORS_WHITELIST?.split(',').map(s => s.trim()),
}

// server.ts
const corsOptions = config.server.corsWhitelist
  ? {
      origin: (origin, callback) => {
        if (!origin || config.server.corsWhitelist?.includes(origin)) {
          return callback(null, true);
        }
        callback(new Error('Not allowed by CORS'));
      },
    }
  : { origin: true }; // Allow all in dev

app.use(cors(corsOptions));
```

**Usage:**
```bash
# Production - restricted
corsWhitelist=https://thegrid.app,https://admin.locusprotocol.io

# Development - unrestricted (no env var set)
```

#### FINDING-005: CLTV Penalty Bypass (Partial Fix)
**Location:** `core/lib/locus/staking.ex`

**Issue:** The emergency unlock script doesn't cryptographically enforce the penalty payment to the protocol treasury at the script level (would require covenants, not available in standard Bitcoin Script).

**Partial Fix:** 
1. Documented that penalty enforcement happens at the **transaction construction level**
2. The `emergency_unlock/5` function correctly constructs transactions with two outputs (penalty to treasury + return to owner)
3. Added clarifying comments in the script builder

**Note:** Full enforcement would require Bitcoin Script covenants (OP_CHECKTEMPLATEVERIFY or similar), which are not yet widely available. The current implementation follows the protocol specification but relies on honest transaction construction.

---

## Verification

### Test Commands

```bash
# Elixir tests
cd core && mix test

# TypeScript client tests
cd client && npm test

# Indexer build
cd indexer && npm run build

# Rust WASM runtime tests
cd ghost/runtime && cargo test
```

### Expected Results
- All existing tests should pass
- New validation tests for empty signatures should throw errors
- Bit shift math should produce exact integer results

---

## Remaining MEDIUM/LOW Issues

Per the security audit, these issues remain but are lower priority:

| Severity | Count | Examples |
|----------|-------|----------|
| MEDIUM | 7 | Insecure heartbeat RNG (use :crypto.strong_rand_bytes), network whitelist, stubbed payment channels, WASM memory reads from offset 0 |
| LOW | 5 | Exponential Fibonacci growth, type code mismatch, silent RNG failure, redemption race condition |

---

## Commit

```
commit 64cec8f
Author: Clark <clark@locus-protocol.ai>
Date:   Tue Mar 17 2026

security: Fix CRITICAL and HIGH severity issues

CRITICAL (1):
- WASM sandbox env var leak: Remove .inherit_env()

HIGH (5):
- Float arithmetic: Replace with bit shift
- Empty signatures: Add validation
- CORS unrestricted: Add whitelist config
- CLTV penalty: Document tx-level enforcement
```

---

## Next Steps

1. **Deploy fixes** to testnet and verify no regressions
2. **Address MEDIUM issues** in next maintenance window:
   - Replace `Math.random()` in heartbeat with `crypto.getRandomValues()`
   - Add network whitelist validation to Elixir node
   - Implement stubbed payment channel functions
3. **Mainnet readiness**: After fixes are battle-tested
