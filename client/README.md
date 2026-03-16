# @locusprotocol/client

JavaScript/TypeScript client for Locus Protocol - deploy and interact with location-aware autonomous agents on Bitcoin SV.

## Installation

```bash
npm install @locusprotocol/client
```

## Quick Start

```typescript
import { LocusClient, GhostType } from '@locusprotocol/client';
import { PrivateKey } from '@bsv/sdk';

// Initialize client
const client = new LocusClient({
  network: 'testnet',
  arcEndpoint: 'https://arc.gorillapool.io'
});

// Create owner key
const ownerKey = PrivateKey.fromRandom();

// Register a ghost
const fundingUtxo = {
  txid: '...',
  vout: 0,
  satoshis: 20_000_000,
  script: '...'
};

const { ghost, stakeInfo } = await client.registerGhost(
  {
    name: 'My Oracle',
    type: GhostType.ORACLE,
    lat: 40.7128,
    lng: -74.0060,
    stakeAmount: 10_000_000, // 0.1 BSV
    baseFee: 1000,
    timeout: 30
  },
  fundingUtxo,
  ownerKey
);

console.log('Ghost registered:', ghost.id);
console.log('Stake locked until block:', stakeInfo.lockHeight);

// Send heartbeat
const heartbeatUtxo = { /* ... */ };
await client.sendHeartbeat(
  {
    ghostId: ghost.id,
    sequence: 1,
    location: { lat: 40.7128, lng: -74.0060, h3Index: '...' }
  },
  heartbeatUtxo,
  ownerKey
);

// Find nearby ghosts
const nearby = await client.findGhostsByLocation(
  { lat: 40.7128, lng: -74.0060 },
  5000 // 5km radius
);
```

## API Reference

### LocusClient

Main client class for interacting with the protocol.

#### Constructor

```typescript
new LocusClient(config?: LocusClientConfig)
```

**Config options:**
- `network`: 'mainnet' | 'testnet' | 'stn' (default: 'testnet')
- `arcEndpoint`: Custom ARC endpoint URL
- `arcApiKey`: API key for ARC service

#### Methods

##### `registerGhost(params, fundingUtxo, ownerKey)`

Register a new ghost on the protocol.

**Parameters:**
- `params`: GhostRegistrationParams
  - `name`: Ghost name
  - `type`: GhostType (GREETER, ORACLE, GUARDIAN, MERCHANT, CUSTOM)
  - `lat`, `lng`: Geographic coordinates
  - `stakeAmount`: Stake in satoshis
  - `baseFee`: Minimum invocation fee (optional)
  - `timeout`: Response timeout in seconds (optional)
  - `codeHash`: SHA-256 of ghost code (optional)
  - `codeUri`: UHRP URI for code (optional)
  - `meta`: Additional metadata (optional)
- `fundingUtxo`: UTXO to fund the transaction
- `ownerKey`: PrivateKey for signing

**Returns:** `{ ghost: Ghost, stakeInfo: { txid, lockHeight } }`

##### `sendHeartbeat(params, fundingUtxo, ownerKey)`

Send a heartbeat to prove ghost liveness.

**Parameters:**
- `params`: HeartbeatParams
  - `ghostId`: Ghost identifier
  - `sequence`: Incrementing sequence number
  - `location`: Current location
- `fundingUtxo`: UTXO to fund the transaction
- `ownerKey`: PrivateKey for signing

##### `invokeGhost(params, feeAmount, fundingUtxo, invokerKey)`

Invoke a ghost with parameters and fee.

**Parameters:**
- `params`: InvocationParams
  - `ghostId`: Target ghost
  - `params`: Invocation parameters (JSON-serializable)
  - `nonce`: Unique nonce (auto-generated if not provided)
- `feeAmount`: Fee in satoshis
- `fundingUtxo`: UTXO to fund transaction and fee
- `invokerKey`: PrivateKey for signing

##### `challengeGhost(params, fundingUtxo, challengerKey)`

Challenge a ghost for misbehavior.

**Parameters:**
- `params`: ChallengeParams
  - `ghostId`: Target ghost
  - `type`: Challenge type (no_show, fraud, malfunction, timeout)
  - `evidence`: Evidence description or hash
- `fundingUtxo`: UTXO to fund challenge stake (10K sats)
- `challengerKey`: PrivateKey for signing

##### `findGhostsByLocation(location, radius)`

Find ghosts within a radius of a location.

**Parameters:**
- `location`: `{ lat, lng }`
- `radius`: Radius in meters

**Returns:** Array of Ghost objects sorted by distance

##### `getGhost(ghostId)`

Get ghost by ID.

##### `getGhostsByOwner(ownerPubKey)`

Get all ghosts owned by a public key.

## Staking Tiers

| Type | Minimum Stake | Use Case |
|------|---------------|----------|
| GREETER | 1M sats (0.01 BSV) | Welcome messages |
| ORACLE | 10M sats (0.1 BSV) | Data queries |
| GUARDIAN | 50M sats (0.5 BSV) | Security monitoring |
| MERCHANT | 10M sats (0.1 BSV) | Commerce, escrow |
| CUSTOM | 100M sats (1 BSV) | Specialized services |

All stakes are locked for 5 months (21,600 blocks) via CLTV.

## Transaction Types

The client handles all protocol transaction types:

- **GHOST_REGISTER**: Create new ghost with stake
- **HEARTBEAT**: Proof-of-liveness (required every 24-48 hours)
- **INVOCATION**: Call ghost with fee
- **CHALLENGE**: Dispute ghost behavior
- **GHOST_UPDATE**: Update ghost parameters
- **GHOST_RETIRE**: Retire ghost and reclaim stake

## Architecture

```
LocusClient
├── TransactionBuilder  - Creates protocol transactions
├── ARCBroadcaster      - Broadcasts via ARC
└── GhostRegistry       - Queries ghost index
```

## Dependencies

- `@bsv/sdk`: BSV blockchain SDK
- `msgpack5`: MessagePack encoding for payloads

## License

MIT
