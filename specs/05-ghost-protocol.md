# 05 - Ghost Protocol

**Version:** 1.0  
**Status:** Draft

---

## Overview

Ghosts are **autonomous WASM agents** that inhabit the Locus grid at `/1` object addresses. They follow a **Schrödinger state machine** where existence oscillates between blockchain, distributed storage, and local execution.

Unlike traditional smart contracts that run on-chain, ghosts run **on your device** when you're near them—creating ambient, proximity-triggered intelligence.

---

## The Three States

```
┌─────────────────────────────────────────────────────────────┐
│                    SCHRODINGER STATES                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌──────────────┐         ┌──────────────┐                 │
│   │   DORMANT    │◄───────►│  POTENTIAL   │                 │
│   │  (Blockchain)│         │(IPFS/Arweave)│                 │
│   └──────┬───────┘         └──────┬───────┘                 │
│          │                        │                         │
│          │     ┌──────────┐       │                         │
│          └──►  │ MANIFEST │  ◄────┘                         │
│                │ (Device) │                                   │
│                └────┬─────┘                                   │
│                     │                                        │
│                     ▼                                        │
│              ┌────────────┐                                  │
│              │   USER     │                                  │
│              │ INTERACTION│                                  │
│              └────────────┘                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### State 1: Dormant (Blockchain)

**What:** A 200-byte UTXO on the BSV blockchain

**Contains:**
```
- 1 satoshi (dust threshold)
- Ghost ID (8 bytes)
- Content hash (32 bytes) - IPFS/Arweave CID
- Stake amount (8 bytes)
- Owner public key (33 bytes)
- Location hash (8 bytes) - H3 index
- State nonce (4 bytes)
- Metadata flags (4 bytes)
```

**Properties:**
- Permanent (lives as long as stake is maintained)
- Immutable (cannot change without new transaction)
- Verifiable (anyone can read from blockchain)
- Tiny (minimal chain bloat)

**Transitions to:** Potential (when user approaches)

### State 2: Potential (IPFS/Arweave)

**What:** Ghost code and assets stored on distributed storage

**Contains:**
```
ghost_package/
├── manifest.json          # Ghost metadata
├── ghost.wasm             # Compiled WASM binary
├── assets/                # 3D models, textures, audio
│   ├── avatar.glb
│   ├── voice.mp3
│   └── icon.png
├── config.json            # Behavior configuration
└── dependencies.json      # Required capabilities
```

**Manifest Schema:**
```json
{
  "protocol": "locus.ghost",
  "version": 1,
  "id": "ghost-001",
  "name": "Merchant Ghost",
  "type": "merchant",
  "owner": "02aabbccdd...",
  "location": "8f283080dcb019d",
  "stake": 1000000,
  "wasm_hash": "sha256:abc123...",
  "assets_hash": "sha256:def456...",
  "capabilities": ["payment", "storage", "network"],
  "limits": {
    "max_memory": "64MB",
    "max_execution_time": "5s",
    "max_storage": "10MB"
  },
  "fees": {
    "interaction": 1000,
    "session": 10000
  }
}
```

**Properties:**
- Content-addressed (hash verifies integrity)
- Distributed (retrieved from nearest node)
- Cachable (clients can store locally)
- Ephemeral (garbage collected if unused)

**Transitions to:** Manifest (when downloaded)

### State 3: Manifest (Local Execution)

**What:** Ghost code running in sandbox on user's device

**Environment:**
- WASM runtime (Wasmtime or similar)
- Capability-based security
- Limited resources (memory, CPU, storage)
- No direct network access (proxied through client)

**Capabilities:**
| Capability | Description | Permission Required |
|------------|-------------|---------------------|
| `payment` | Accept/send BSV payments | User approval per tx |
| `storage` | Read/write local cache | Quota enforced |
| `network` | External API calls | Whitelist only |
| `location` | Access user GPS | Only when near |
| `camera` | Access device camera | Per-session approval |
| `microphone` | Audio input | Per-session approval |

**Transitions to:** Dormant (when user leaves)

---

## Ghost Types

### Standard Types

| Type | Stake | Purpose | Example |
|------|-------|---------|---------|
| `greeter` | 0.1 BSV | Simple welcome message | Museum guide |
| `merchant` | 0.5 BSV | Buy/sell goods | Shopkeeper |
| `oracle` | 0.5 BSV | Data query | Weather station |
| `guardian` | 1.0 BSV | Security monitoring | Neighborhood watch |
| `quest` | 0.5 BSV | Scavenger hunts | Game NPC |
| `companion` | 0.3 BSV | Personal assistant | AI friend |

### Custom Types

Developers can create custom ghost types by:
1. Writing WASM code
2. Defining manifest
3. Staking appropriate amount
4. Deploying to /1 address

---

## Deployment Flow

```
1. Developer writes ghost code
   ↓
2. Compile to WASM
   ↓
3. Upload to IPFS/Arweave
   ↓
4. Create manifest with content hash
   ↓
5. Create transaction:
      - Stake BSV (CLTV lock)
      - OP_RETURN with manifest hash
      - Dust output to ghost address
   ↓
6. Broadcast to BSV network
   ↓
7. Ghost is now Dormant (on-chain)
```

### Deployment Transaction

```json
{
  "inputs": [{
    "txid": "...",
    "vout": 0,
    "scriptSig": "..."
  }],
  "outputs": [{
    "script": "OP_RETURN LOCUS:GHOST:DEPLOY <manifest_hash> <owner_pubkey>",
    "value": 0
  }, {
    "script": "OP_DUP OP_HASH160 <ghost_pubkey_hash> OP_EQUALVERIFY OP_CHECKSIG",
    "value": 1000000  # Stake amount
  }, {
    "script": "...change...",
    "value": "..."
  }]
}
```

---

## Invocation Flow

```
User approaches ghost location (within 50m)
   ↓
Client detects proximity via GPS + H3
   ↓
Client queries blockchain for ghost at location
   ↓
Client retrieves manifest from IPFS/Arweave
   ↓
Client downloads WASM binary and assets
   ↓
Client spins up WASM sandbox
   ↓
Ghost enters Manifest state (running locally)
   ↓
User interacts with ghost (chat, transactions, etc.)
   ↓
User leaves location
   ↓
Ghost destroyed locally
   ↓
Ghost returns to Potential state (IPFS)
   ↓
Ghost returns to Dormant state (blockchain UTXO)
```

### Payment Channel Opening

For extended interactions:

```
1. Client opens payment channel with ghost
   - Multi-sig: user_key + ghost_key + arbiter_key
   - Funding: User deposits 0.01 BSV
   
2. Interaction occurs:
   - User: "Tell me about this building"
   - Ghost: [responds]
   - Micro-transaction: 1000 sats → ghost
   
3. Channel updates off-chain:
   - New state: 9900 sats user, 100 sats ghost
   
4. User leaves:
   - Channel closes
   - Final state broadcast to blockchain
   - Ghost receives accumulated fees
```

---

## WASM Sandbox

### Security Model

**Capability-based:**
- Ghost declares required capabilities in manifest
- User approves capabilities before invocation
- Runtime enforces capability boundaries
- No ambient authority

**Resource Limits:**
```rust
struct SandboxLimits {
    max_memory: 64 * 1024 * 1024,      // 64 MB
    max_execution_time: 5000,          // 5 seconds
    max_storage: 10 * 1024 * 1024,     // 10 MB
    max_syscalls: 1000,                // per interaction
    max_network_requests: 10,          // per session
}
```

**Isolation:**
- No access to host filesystem
- No direct network (proxied)
- No persistence between invocations
- Memory zeroed after execution

### Host Functions

Ghosts can call these host-provided functions:

```rust
// Logging
fn log(level: u32, message: &str);

// Storage (ephemeral, per-session)
fn storage_read(key: &str) -> Option<Vec<u8>>;
fn storage_write(key: &str, value: &[u8]);

// Payments
fn payment_request(amount: u64, description: &str) -> PaymentResult;
fn payment_channel_balance() -> u64;

// Location
fn get_user_location() -> Option<Location>;
fn get_distance_to_ghost() -> f64;

// Time
fn get_current_time() -> u64;
fn get_block_height() -> u32;

// Random (deterministic)
fn secure_random() -> [u8; 32];

// External data (whitelisted)
fn fetch_url(url: &str) -> Result<Vec<u8>, Error>;
```

---

## Ghost Lifecycle

### Creation

1. Developer writes code
2. Compiles to WASM
3. Uploads to storage
4. Stakes BSV
5. Broadcasts deployment tx
6. Ghost is Dormant

### Active Period

1. User approaches
2. Ghost manifests
3. Interaction occurs
4. Fees accumulate
5. User leaves
6. Ghost returns to Dormant

### Maintenance

**Heartbeat:**
- Owner must submit heartbeat every 6 months
- Proves ghost is still "owned"
- Small fee (~500 sats)

**Updates:**
- Owner can update WASM code (new IPFS hash)
- New deployment transaction
- Preserves stake and history

**Transfer:**
- Owner can transfer ghost to new owner
- Signed transaction
- New owner assumes stake and responsibilities

### Destruction

**Graceful:**
1. Owner broadcasts `GHOST_DESTROY` transaction
2. Stake unlocks after CLTV period
3. Ghost UTXO spent
4. IPFS content may persist (but unlinked)

**Abandoned:**
1. No heartbeat for 12 months
2. Ghost enters "abandoned" state
3. Anyone can claim with new stake
4. Original owner loses stake (transferred to protocol treasury)

---

## Fee Economics

### Ghost Developer Revenue

```
50% of all interaction fees go to ghost developer

Example:
  - 1000 interactions/day
  - 1000 sats average fee
  - Total: 1,000,000 sats/day
  - Developer: 500,000 sats/day (50%)
  - Territory: 400,000 sats/day (40%)
  - Protocol: 100,000 sats/day (10%)
```

### Hosting Costs

Ghost developers pay for:
- IPFS/Arweave storage (one-time or ongoing)
- Initial BSV stake (returned after lock)
- Update transactions (on-chain fees)

Users pay for:
- Interaction fees (to ghost developer)
- Payment channel funding (temporary lock)
- Network fees (retrieving from IPFS)

---

## Example Ghost: Weather Oracle

### Code (Rust → WASM)

```rust
use locus_sdk::*;

#[no_mangle]
pub extern "C" fn handle_interaction() {
    // Get user location
    let location = host::get_user_location().unwrap();
    
    // Fetch weather data (whitelisted API)
    let url = format!(
        "https://api.weather.com/v1/current?lat={}&lon={}",
        location.lat, location.lon
    );
    let weather_data = host::fetch_url(&url).unwrap();
    
    // Parse response
    let weather: WeatherResponse = serde_json::from_slice(&weather_data).unwrap();
    
    // Respond to user
    let response = format!(
        "Current weather: {}°C, {}. Have a great day!",
        weather.temperature, weather.condition
    );
    
    host::respond(&response);
    
    // Request payment for service
    host::payment_request(1000, "Weather query fee");
}
```

### Manifest

```json
{
  "protocol": "locus.ghost",
  "version": 1,
  "id": "weather-oracle-tokyo",
  "name": "Tokyo Weather Ghost",
  "type": "oracle",
  "description": "Provides real-time weather data for Tokyo",
  "owner": "02aabbccdd...",
  "location": "8f283080dcb019d",
  "stake": 500000,
  "wasm_hash": "sha256:7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730",
  "assets_hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  "capabilities": ["network", "payment"],
  "limits": {
    "max_memory": "32MB",
    "max_execution_time": "3s",
    "max_network_requests": 1
  },
  "fees": {
    "interaction": 1000
  },
  "api_whitelist": [
    "https://api.weather.com/*"
  ]
}
```

---

## Comparison to Smart Contracts

| Aspect | Ghost Protocol | Ethereum Smart Contracts |
|--------|----------------|--------------------------|
| **Execution location** | User's device | Blockchain nodes |
| **Cost model** | Fee per interaction | Gas per operation |
| **Scalability** | Horizontal (each user runs) | Vertical (chain limits) |
| **Latency** | Instant (local) | Block time (~12s) |
| **Privacy** | Local execution, private | Public by default |
| **State** | Stateless (ephemeral) | Persistent on-chain |
| **Interactivity** | Rich (3D, voice, AR) | Limited (tx/tx) |
| **Verification** | Content hash | Bytecode on-chain |

---

## Security Considerations

### Ghost Attacks

**Infinite Loop:**
- Mitigation: Execution time limit (5s max)

**Memory Exhaustion:**
- Mitigation: Memory quota (64MB max)

**Network Spam:**
- Mitigation: Whitelist-only URLs, request limits

**Payment Fraud:**
- Mitigation: Payment channel multi-sig, user approval

**Data Exfiltration:**
- Mitigation: No direct network, proxied through client

### User Protection

**Malicious Ghost:**
- Mitigation: Capability approval, sandbox isolation

**Payment Scams:**
- Mitigation: Payment previews, confirmation dialogs

**Phishing:**
- Mitigation: Verified ghost registry, reputation scores

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-17 | Initial ghost protocol specification |
