# FINDING-008: Network Whitelist Not Implemented

**Severity:** MEDIUM
**Component:** ghost/runtime
**File:** `ghost/runtime/src/host/mod.rs:135-146`
**Status:** Open

## Description

The ghost host's `fetch_url` function checks for the `network` capability but does not enforce the URL whitelist:

```rust
pub async fn fetch_url(&self, url: &str) -> Result<Vec<u8>, NetworkError> {
    if !self.has_capability("network") {
        return Err(NetworkError::CapabilityDenied);
    }
    // TODO: Check whitelist
    // TODO: Implement actual fetch with reqwest
    tracing::info!("Fetch URL: {}", url);
    Ok(vec![])
}
```

## Impact

When the fetch is implemented, any ghost with the `network` capability will be able to:
1. Make requests to any URL, including internal network services
2. Perform SSRF (Server-Side Request Forgery) attacks against the host's local network
3. Exfiltrate data to external servers (critical when combined with FINDING-001)
4. Scan internal infrastructure

Currently mitigated by the fact that `fetch_url` returns an empty vec without making any request.

## Remediation

See `remediation/REM-008.md`
