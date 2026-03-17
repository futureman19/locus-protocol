# Sample WASM Ghosts

This directory contains example Ghost implementations in Rust that compile to WASM.

## Building

Install the WASM target:
```bash
rustup target add wasm32-wasi
```

Build a ghost:
```bash
cd greeter
cargo build --target wasm32-wasi --release
```

The output will be in `target/wasm32-wasi/release/greeter.wasm`

## Ghost Types

### Greeter (`greeter.rs`)
Simple welcoming ghost that:
- Logs messages
- Gets user distance
- Reads/writes ephemeral storage
- Returns greeting message

**Capabilities:** `location`, `storage`

### Merchant (`merchant.rs`)
Commercial ghost that:
- Displays product catalog
- Accepts payment channel payments
- Delivers digital goods

**Capabilities:** `payment`, `storage`

### Oracle (`oracle.rs`)
Data provider ghost that:
- Fetches external data from whitelisted APIs
- Provides weather, prices, etc.
- Caches results

**Capabilities:** `network`, `storage`

## Host Functions

All ghosts have access to these host-provided functions:

```rust
// Logging
fn host_log(level: i32, ptr: *const u8, len: usize);

// Storage (ephemeral, per-session)
fn host_storage_read(key_ptr: *const u8, key_len: usize, out_ptr: *mut u8, out_len: usize) -> i32;
fn host_storage_write(key_ptr: *const u8, key_len: usize, value_ptr: *const u8, value_len: usize);

// Location
fn host_get_distance_to_ghost() -> f64;

// Time
fn host_get_current_time() -> i64;

// Payments
fn host_payment_request(amount: u64, desc_ptr: *const u8, desc_len: usize) -> i32;
fn host_payment_channel_balance() -> u64;

// Network (whitelisted)
fn host_fetch_url(url_ptr: *const u8, url_len: usize, out_ptr: *mut u8, out_len: usize) -> i32;
```

## Testing

```bash
cargo test --target wasm32-wasi
```

## Deployment

1. Build the WASM
2. Upload to IPFS/Arweave
3. Note the CID
4. Create ghost manifest
5. Stake BSV and deploy on-chain
