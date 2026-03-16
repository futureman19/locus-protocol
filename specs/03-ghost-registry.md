# Ghost Registry

The Ghost Registry is the discovery mechanism for finding and verifying autonomous agents on the Locus Protocol.

## Overview

Unlike centralized services, the Locus Protocol has no single registry server. Instead, the registry is:

1. **Derived from the blockchain** — Anyone can scan for GHOST_REGISTER transactions
2. **Validated by each node** — State computed independently, no trusted source
3. **Queryable via any interface** — HTTP API, gRPC, or direct chain scan

## Registry Data Structure

### Ghost Record

```typescript
interface GhostRecord {
  // Identity
  ghost_id: string;           // 64-character hex (32 bytes)
  name: string;               // Human-readable name
  description?: string;       // Optional description
  
  // Location
  location: {
    lat: number;              // -90 to 90
    lng: number;              // -180 to 180
    h3_index: string;         // 15-character hex (H3 resolution 9)
  };
  
  // Classification
  ghost_type: 'GREETER' | 'ORACLE' | 'GUARDIAN' | 'MERCHANT' | 'CUSTOM';
  code_hash: string;          // 64-character hex (SHA-256 of code)
  code_uri?: string;          // Optional: IPFS hash, HTTPS URL
  
  // Economics
  stake: {
    amount_sats: number;      // Staked amount
    locked_until: number;     // Block height
    stake_txid: string;       // Reference transaction
  };
  fees: {
    base_fee_sats: number;    // Minimum fee
    timeout_seconds: number;  // Max execution time
  };
  
  // Ownership
  owner: {
    pubkey: string;           // 66-character hex (33-byte compressed)
    address: string;          // BSV address
  };
  
  // Lifecycle
  state: 'PENDING' | 'ACTIVE' | 'INACTIVE' | 'SLASHED' | 'RETIRED';
  registered_at: number;      // Block height of registration
  activated_at?: number;      // Block height of activation
  last_heartbeat?: number;    // Block height of last heartbeat
  
  // Activity
  stats: {
    total_invocations: number;
    total_fees_earned: number;
    last_invocation?: number;
  };
  
  // Reputation
  challenges: {
    filed: number;
    upheld: number;
    rejected: number;
  };
}
```

## Deriving the Registry

### Algorithm

```python
def build_registry(start_block, end_block):
    """
    Build complete ghost registry from blockchain data.
    """
    ghosts = {}
    
    for block in range(start_block, end_block + 1):
        for tx in get_block_transactions(block):
            if not is_protocol_tx(tx):
                continue
                
            payload = parse_op_return(tx)
            type_code = payload['type']
            
            if type_code == GHOST_REGISTER:
                ghost = process_registration(tx, payload)
                ghosts[ghost.id] = ghost
                
            elif type_code == GHOST_UPDATE:
                update_ghost(ghosts, tx, payload)
                
            elif type_code == HEARTBEAT:
                update_heartbeat(ghosts, tx, payload)
                
            elif type_code == INVOCATION:
                update_invocation_stats(ghosts, tx, payload)
                
            elif type_code == CHALLENGE:
                process_challenge(ghosts, tx, payload)
                
            elif type_code == CHALLENGE_RESPONSE:
                process_challenge_response(ghosts, tx, payload)
    
    return ghosts

def process_registration(tx, payload):
    """Validate and create ghost record."""
    ghost_id = compute_ghost_id(tx)
    
    # Verify stake output exists
    stake_output = find_stake_output(tx)
    if not stake_output:
        raise InvalidRegistration("No stake output")
    
    # Verify lock script
    if not verify_lock_script(stake_output, payload['unlock_height'], payload['owner_pk']):
        raise InvalidRegistration("Invalid lock script")
    
    return GhostRecord(
        ghost_id=ghost_id,
        state='PENDING',
        registered_at=tx['block_height'],
        # ... other fields from payload
    )
```

### Validation Rules

When processing registrations:

1. **Ghost ID uniqueness** — Reject if ghost_id already exists
2. **Stake verification** — P2SH output must match protocol format
3. **Location validity** — H3 index must decode to valid lat/lng
4. **Minimum stake** — Must meet tier requirements
5. **Type validity** — Must be recognized ghost type
6. **Fee reasonableness** — Base fee must be ≥ minimum for type

## State Transitions

### PENDING → ACTIVE

**Automatic after 7 days (1008 blocks)**

```python
def check_activation(ghost, current_block):
    if ghost.state != 'PENDING':
        return
        
    blocks_since_reg = current_block - ghost.registered_at
    
    if blocks_since_reg >= 1008:
        ghost.state = 'ACTIVE'
        ghost.activated_at = current_block
```

### ACTIVE → INACTIVE

**Trigger: Missed heartbeat deadline**

```python
def check_inactivity(ghost, current_block):
    if ghost.state != 'ACTIVE':
        return
        
    if not ghost.last_heartbeat:
        # Never sent heartbeat
        if current_block - ghost.activated_at > 288:  # 48 hours
            ghost.state = 'INACTIVE'
        return
        
    blocks_since_heartbeat = current_block - ghost.last_heartbeat
    
    if blocks_since_heartbeat > 288:  # 48 hours grace
        ghost.state = 'INACTIVE'
```

### ACTIVE/INACTIVE → SLASHED

**Trigger: Challenge upheld**

```python
def process_challenge_resolution(ghost, challenge, resolution):
    if resolution == 'UPHELD':
        ghost.state = 'SLASHED'
        ghost.slash_reason = challenge.type
        ghost.slash_block = current_block
        
        # Stake partially or fully burned
        burn_stake(ghost, challenge.proposed_resolution)
```

### Any → RETIRED

**Trigger: Owner broadcasts retirement transaction**

```python
def process_retirement(ghost, tx):
    verify_owner_signature(tx, ghost.owner.pubkey)
    
    if ghost.state == 'ACTIVE' or ghost.state == 'INACTIVE':
        ghost.state = 'RETIRED'
        ghost.retired_at = current_block
        
        # Stake unlocks normally after lock period
```

## Querying the Registry

### By Location (Proximity Search)

```python
def find_ghosts_near(lat, lng, radius_meters):
    """
    Find all ghosts within radius of coordinates.
    """
    # Get H3 indexes covering the radius
    center_h3 = lat_lng_to_h3(lat, lng, 9)
    ring_size = meters_to_ring_size(radius_meters)
    h3_indexes = h3.k_ring(center_h3, ring_size)
    
    # Filter active ghosts in those hexagons
    results = []
    for ghost in registry.values():
        if ghost.state != 'ACTIVE':
            continue
        if ghost.location.h3_index in h3_indexes:
            # Precise distance check
            distance = haversine(lat, lng, ghost.location.lat, ghost.location.lng)
            if distance <= radius_meters:
                results.append({
                    'ghost': ghost,
                    'distance_meters': distance
                })
    
    return sorted(results, key=lambda x: x['distance_meters'])
```

### By Type

```python
def find_ghosts_by_type(ghost_type, state='ACTIVE'):
    """Filter ghosts by type and state."""
    return [
        ghost for ghost in registry.values()
        if ghost.ghost_type == ghost_type
        and ghost.state == state
    ]
```

### By Owner

```python
def find_ghosts_by_owner(address):
    """Find all ghosts owned by address."""
    return [
        ghost for ghost in registry.values()
        if ghost.owner.address == address
    ]
```

## Registry Indexing

For performance, nodes typically maintain indexes:

```elixir
defmodule Locus.Registry.Index do
  @moduledoc "In-memory indexes for fast queries"
  
  defstruct [
    :by_id,              # Map: ghost_id => ghost
    :by_h3,              # Map: h3_index => [ghost_ids]
    :by_owner,           # Map: address => [ghost_ids]
    :by_type,            # Map: type => [ghost_ids]
    :by_state,           # Map: state => [ghost_ids]
    :pending_challenges  # Map: challenge_id => challenge
  ]
  
  def new do
    %__MODULE__{
      by_id: %{},
      by_h3: %{},
      by_owner: %{},
      by_type: %{},
      by_state: %{},
      pending_challenges: %{}
    }
  end
  
  def add_ghost(index, ghost) do
    index
    |> put_in([:by_id, ghost.ghost_id], ghost)
    |> update_in([:by_h3, ghost.location.h3_index], &[ghost.ghost_id | &1 || []])
    |> update_in([:by_owner, ghost.owner.address], &[ghost.ghost_id | &1 || []])
    |> update_in([:by_type, ghost.ghost_type], &[ghost.ghost_id | &1 || []])
    |> update_in([:by_state, ghost.state], &[ghost.ghost_id | &1 || []])
  end
end
```

## Registry API (gRPC)

Nodes expose registry queries via gRPC (local only by default):

```protobuf
syntax = "proto3";

service Registry {
  // Get single ghost by ID
  rpc GetGhost(GetGhostRequest) returns (Ghost);
  
  // Search ghosts by various criteria
  rpc SearchGhosts(SearchRequest) returns (stream Ghost);
  
  // Get ghosts near location
  rpc ProximitySearch(ProximityRequest) returns (stream GhostWithDistance);
  
  // Subscribe to ghost updates
  rpc SubscribeUpdates(SubscribeRequest) returns (stream GhostUpdate);
}

message GetGhostRequest {
  string ghost_id = 1;
}

message SearchRequest {
  optional GhostType type = 1;
  optional GhostState state = 2;
  optional string owner_address = 3;
  uint32 limit = 4;
}

message ProximityRequest {
  double lat = 1;
  double lng = 2;
  uint32 radius_meters = 3;
  optional GhostType filter_type = 4;
}

message GhostWithDistance {
  Ghost ghost = 1;
  uint32 distance_meters = 2;
}

message SubscribeRequest {
  repeated string ghost_ids = 1;  // Empty = all ghosts
  bool include_heartbeats = 2;
  bool include_invocations = 3;
}
```

## Registry Synchronization

### Initial Sync

New nodes sync the entire registry:

1. Query peer for current block height
2. Download block headers for verification
3. Scan all blocks from protocol genesis
4. Build registry incrementally
5. Verify against merkle roots

### Incremental Updates

After initial sync, nodes update via:

1. **Block subscription** — New blocks via ZMQ/WebSocket
2. **Transaction mempool** — Pending protocol txs
3. **Periodic heartbeat** — Check for missed blocks

### Fork Handling

```python
def handle_reorg(new_chain_tip, common_ancestor):
    """Recompute registry after blockchain reorganization."""
    # Undo blocks from old chain
    for block in range(old_tip, common_ancestor, -1):
        undo_block_effects(block)
    
    # Apply blocks from new chain
    for block in range(common_ancestor + 1, new_tip + 1):
        apply_block_effects(block)
```

## Registry Consistency

All honest nodes should derive identical registry states given the same blockchain data. This is ensured by:

1. **Deterministic parsing** — Same rules for all transactions
2. **Ordered processing** — Blocks processed in height order
3. **Idempotent operations** — Same tx processed multiple times = same result
4. **Canonical ordering** — Registry iteration order well-defined

## Caching Strategy

```python
# Hot data: Keep in memory
ACTIVE_GHOSTS_CACHE = TTLCache(maxsize=10000, ttl=300)

# Warm data: Redis/Memcached
GHOST_METADATA_CACHE = RedisCache(ttl=3600)

# Cold data: Disk/Database (optional)
HISTORICAL_GHOSTS = DiskStorage()
```

## Privacy Considerations

1. **Ghost locations are public** — Part of registration tx
2. **Owner addresses are public** — Can be linked to real identity
3. **Invocation patterns are public** — On-chain record

**Mitigations:**
- Ghosts can be owned by one-time addresses
- High-security ghosts can use proof-of-location (not revealed in heartbeat)
- Users can use privacy-preserving wallets

## Testing the Registry

```python
def test_registry_consistency():
    """Verify two nodes derive same registry."""
    node1 = build_registry(start=800000, end=850000)
    node2 = build_registry(start=800000, end=850000)
    
    assert node1.registry == node2.registry
    assert node1.index.by_h3 == node2.index.by_h3
```
