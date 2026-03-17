# Ghost WASM Runtime

A minimal WASM runtime for executing autonomous Ghost agents that inhabit the Locus grid at `/1` object addresses.

## Overview

The Ghost Runtime implements a **Schrödinger State Machine** where ghost existence oscillates between:

1. **Dormant** (Blockchain) - 200-byte UTXO with stake
2. **Potential** (IPFS/Arweave) - Content-addressed WASM and assets
3. **Manifest** (Device) - Running locally in sandbox

## Features

- ✅ WASM sandbox using Wasmtime
- ✅ Capability-based security (location, payment, storage, network)
- ✅ Schrödinger state transitions
- ✅ Payment channel handling
- ✅ gRPC/HTTP API for ghost invocation
- ✅ IPFS/Arweave CID loading
- ✅ Resource limiting (memory, CPU, storage)

## Quick Start

### Run with Docker

```bash
docker-compose up -d
```

### Run locally

```bash
# Build
cargo build --release

# Run
./target/release/ghost-runtime

# Or with custom config
GHOST_RUNTIME_ADDR=0.0.0.0:8080 \
  MAX_MEMORY_PER_GHOST=128MB \
  cargo run
```

## API Endpoints

### HTTP REST API

```bash
# Health check
curl http://localhost:8080/health

# Invoke a ghost
curl -X POST http://localhost:8080/api/v1/invoke/ghost-001 \
  -H "Content-Type: application/json" \
  -d '{
    "user_pubkey": "02abc...",
    "user_location": {"lat": 35.6762, "lng": 139.6503},
    "action": "greet",
    "capabilities_requested": ["location", "storage"]
  }'

# Leave ghost location
curl -X POST http://localhost:8080/api/v1/ghosts/ghost-001/leave

# Get runtime stats
curl http://localhost:8080/api/v1/stats
```

### gRPC API

```protobuf
service GhostRuntime {
  rpc InvokeGhost(InvokeRequest) returns (InvokeResponse);
  rpc StreamInteractions(stream InteractionMessage) returns (stream InteractionMessage);
  rpc GetGhostState(GhostStateRequest) returns (GhostState);
  rpc OpenPaymentChannel(OpenChannelRequest) returns (PaymentChannel);
}
```

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `GHOST_RUNTIME_ADDR` | `0.0.0.0:8080` | Server bind address |
| `MAX_CONCURRENT_GHOSTS` | `100` | Max parallel executions |
| `MAX_MEMORY_PER_GHOST` | `64MB` | Memory limit per ghost |
| `MAX_EXECUTION_TIME` | `5s` | Execution timeout |
| `IPFS_GATEWAY` | `https://ipfs.io/ipfs` | IPFS gateway URL |
| `ARWEAVE_GATEWAY` | `https://arweave.net` | Arweave gateway URL |
| `ENABLE_PAYMENT_CHANNELS` | `true` | Enable micropayments |

## Host Functions

Ghosts can call these host-provided functions:

```rust
// Logging
fn log(level: u32, message: &str);

// Storage (ephemeral, per-session)
fn storage_read(key: &str) -> Option<Vec<u8>>;
fn storage_write(key: &str, value: &[u8]);

// Location
fn get_user_location() -> Option<Location>;
fn get_distance_to_ghost() -> f64;

// Time
fn get_current_time() -> u64;
fn get_block_height() -> u32;

// Payments
fn payment_request(amount: u64, description: &str) -> PaymentResult;
fn payment_channel_balance() -> u64;

// Random
fn secure_random() -> [u8; 32];

// Network (whitelisted)
fn fetch_url(url: &str) -> Result<Vec<u8>, Error>;
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GHOST RUNTIME                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  gRPC/HTTP   │  │    State     │  │   Payment    │       │
│  │    API       │──│   Machine    │──│   Channels   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│         │                 │                                    │
│         └─────────────────┘                                    │
│                   │                                          │
│         ┌─────────▼──────────┐                               │
│         │   WASM Sandbox     │                               │
│         │  (Wasmtime)        │                               │
│         │                    │                               │
│         │  ┌──────────────┐  │                               │
│         │  │   Ghost      │  │                               │
│         │  │   Module     │  │                               │
│         │  └──────────────┘  │                               │
│         └────────────────────┘                               │
│                   │                                          │
│         ┌─────────▼──────────┐                               │
│         │   Host Functions   │                               │
│         │  (capability-based)│                               │
│         └────────────────────┘                               │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │          CID Loader (IPFS/Arweave)                  │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Testing

```bash
# Run all tests
cargo test

# Run with logging
cargo test -- --nocapture

# Integration tests
cargo test --test integration_tests

# Benchmarks
cargo bench
```

## Sample Ghosts

See `sample-wasm/` for example implementations:

- **greeter.rs** - Simple welcoming ghost
- **merchant.rs** - Payment-accepting vendor
- **oracle.rs** - External data provider

## License

MIT License - See LICENSE file
