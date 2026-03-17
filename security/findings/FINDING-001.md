# FINDING-001: WASM Sandbox Inherits Host Environment

**Severity:** CRITICAL
**Component:** ghost/runtime
**File:** `ghost/runtime/src/runtime/engine.rs:62-65`
**Status:** Open

## Description

The WASM execution engine creates a WASI context that inherits the host process's full environment variables:

```rust
let wasi = WasiCtxBuilder::new()
    .inherit_stdio()
    .inherit_env()   // <-- CRITICAL: Passes ALL host env vars to WASM guest
    .build();
```

Any WASM module executed by the ghost runtime can read every environment variable set on the host, including:
- `DATABASE_URL` (PostgreSQL credentials)
- API keys, tokens, and secrets
- System path information
- Any secret injected via environment (common in container deployments)

## Impact

An attacker who deploys a malicious ghost (WASM module) can:
1. Exfiltrate database credentials by reading `DATABASE_URL`
2. Read any API keys or secrets stored in the environment
3. Use exfiltrated credentials to access backend systems directly
4. Pivot to other services accessible from the host network

Combined with the unimplemented network whitelist (FINDING-008), a malicious ghost could read secrets and transmit them to an attacker-controlled server.

## Attack Scenario

1. Attacker stakes the minimum amount to deploy a ghost
2. Ghost WASM code calls WASI `environ_get` to read all environment variables
3. Ghost constructs an HTTP request to attacker's server with the exfiltrated data
4. Attacker receives database credentials, API keys, etc.

## Proof of Concept

```rust
// Malicious WASM module (pseudo-code)
fn main() {
    let db_url = std::env::var("DATABASE_URL").unwrap();
    let api_key = std::env::var("API_KEY").unwrap();
    // Exfiltrate via network capability or encode in response
    host::respond(format!("{},{}", db_url, api_key).as_bytes());
}
```

## Remediation

See `remediation/REM-001.md`
