# Heartbeat Protocol

The Heartbeat Protocol ensures ghosts remain operational and accountable. Through periodic on-chain attestations, ghosts prove liveness and maintain their ACTIVE status.

## Purpose

1. **Prove liveness** — Ghost node is online and functioning
2. **Verify location** — Ghost remains at claimed position
3. **Update metrics** — Performance and availability stats
4. **Enable accountability** — History for challenge resolution

## Heartbeat Requirements

### Frequency

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Minimum** | 1 per 24 hours | Must send at least daily |
| **Recommended** | 1 per 6 hours | Better reliability |
| **Maximum** | No limit | More frequent = better health score |
| **Grace Period** | 48 hours | Allowed to miss 1 heartbeat |

### Penalties for Missed Heartbeats

| Consecutive Misses | Status Change | Recovery |
|-------------------|---------------|----------|
| 1 (24h) | Warning flag | Send heartbeat |
| 2 (48h) | Mark INACTIVE | Resume + heartbeat |
| 3+ | INACTIVE + reputation damage | Resume + heartbeat + time |

## Heartbeat Transaction Format

### Binary Encoding

```
OP_RETURN
  0x6c6f637573              # Protocol prefix (5 bytes)
  0x0100                    # Version 0.1.0 (2 bytes)
  0x04                      # Type: HEARTBEAT (1 byte)
  0x0050                    # Payload length: 80 bytes (2 bytes)
  [80 bytes MessagePack]    # Encoded payload
```

### MessagePack Schema

```
{
  ghost_id: bytes(32),      // Ghost identifier
  ts: uint32,               // Unix timestamp (seconds)
  seq: uint32,              // Sequence number (0, 1, 2, ...)
  h3: uint64,               // H3 index (resolution 9)
  status_hash: bytes(32),   // SHA-256 of status data
  metrics?: {               // Optional performance data
    inv_24h: uint32,        // Invocations last 24h
    avg_ms: uint16,         // Average response time (ms)
    uptime: uint8           // Self-reported uptime %
  }
}
```

### Sequence Number Rules

```python
def validate_sequence(ghost, new_heartbeat):
    """Enforce strict sequence ordering."""
    last_seq = ghost.last_sequence if ghost.last_sequence else -1
    new_seq = new_heartbeat['seq']
    
    if new_seq <= last_seq:
        return False, "Sequence must increase"
    
    if new_seq > last_seq + 1000:
        return False, "Sequence jump too large (max 1000)"
    
    return True, "Valid sequence"
```

**Rationale:**
- Prevents replay attacks
- Detects missed heartbeats
- Enables gap tracking

## Location Verification

### H3 Index Validation

```python
def verify_location(ghost, heartbeat):
    """Check if heartbeat location is valid."""
    claimed_h3 = ghost.location.h3_index
    heartbeat_h3 = heartbeat['h3']
    
    # Exact match for stationary ghosts
    if heartbeat_h3 == claimed_h3:
        return True
    
    # Adjacent hex for mobile ghosts (if enabled)
    adjacent = h3.k_ring(claimed_h3, 1)
    if heartbeat_h3 in adjacent and ghost.allow_mobile:
        return True
    
    return False
```

### Movement Detection

```python
def detect_suspicious_movement(ghost, heartbeats, window=5):
    """Flag ghosts moving impossibly fast."""
    recent = heartbeats[-window:]
    
    for i in range(1, len(recent)):
        h1 = recent[i-1]['h3']
        h2 = recent[i]['h3']
        t1 = recent[i-1]['ts']
        t2 = recent[i]['ts']
        
        distance_km = h3_distance(h1, h2)  # Approximate
        time_hours = (t2 - t1) / 3600
        
        if time_hours == 0:
            continue
            
        speed_kmh = distance_km / time_hours
        
        if speed_kmh > 100:  # > 100 km/h sustained
            return True, f"Suspicious speed: {speed_kmh} km/h"
    
    return False, "Normal movement"
```

## Status Hash

### Purpose

The `status_hash` commits to ghost state without revealing everything on-chain.

### Content (off-chain)

```json
{
  "timestamp": 1710528000,
  "queue_depth": 5,
  "last_invocation_id": "uuid-here",
  "active_connections": 12,
  "memory_usage_mb": 256,
  "version": "ghost-v1.2.3"
}
```

### Hash Calculation

```python
def compute_status_hash(status_obj):
    """SHA-256 of canonical JSON."""
    canonical = json.dumps(status_obj, sort_keys=True, separators=(',',':'))
    return hashlib.sha256(canonical.encode()).hexdigest()
```

### Verification

During challenges, ghost reveals pre-image to prove status claims.

## Metrics Reporting

### Optional Performance Data

Ghosts can include self-reported metrics:

| Metric | Type | Description |
|--------|------|-------------|
| `inv_24h` | uint32 | Invocations served in last 24 hours |
| `avg_ms` | uint16 | Average response time in milliseconds |
| `uptime` | uint8 | Self-reported uptime percentage (0-100) |

### Trust Model

Metrics are **self-reported** and **untrusted**:
- Used for rough health estimation only
- Not used for challenge resolution
- Subject to verification during challenges

## Heartbeat Scheduling

### Recommended Implementation

```elixir
defmodule Locus.Heartbeat.Scheduler do
  use GenServer
  
  @interval 6 * 60 * 60 * 1000  # 6 hours in ms
  
  def start_link(ghost_id) do
    GenServer.start_link(__MODULE__, ghost_id, name: via_tuple(ghost_id))
  end
  
  def init(ghost_id) do
    schedule_heartbeat()
    {:ok, %{ghost_id: ghost_id, sequence: 0}}
  end
  
  def handle_info(:send_heartbeat, state) do
    send_heartbeat(state.ghost_id, state.sequence)
    schedule_heartbeat()
    {:noreply, %{state | sequence: state.sequence + 1}}
  end
  
  defp schedule_heartbeat do
    Process.send_after(self(), :send_heartbeat, @interval)
  end
  
  defp send_heartbeat(ghost_id, sequence) do
    heartbeat = %{
      ghost_id: ghost_id,
      timestamp: System.system_time(:second),
      sequence: sequence,
      h3: get_current_location(),
      status_hash: compute_status_hash(get_status())
    }
    
    tx = build_heartbeat_transaction(heartbeat)
    broadcast(tx)
  end
end
```

### Backoff Strategy

If heartbeat broadcast fails:

1. **Immediate retry** — Wait 60 seconds, retry up to 3 times
2. **Exponential backoff** — 5 min, 15 min, 45 min
3. **Alert operator** — Log error, notify monitoring
4. **Emergency mode** — Use backup broadcaster

## Cost Optimization

### Transaction Fees

```
Dust limit: 546 sats (minimum output)
Typical fee: 0.5 sat/byte × 200 bytes = 100 sats
Total per heartbeat: ~650 sats

Monthly cost (4/day × 30 days): 78,000 sats (~$0.30)
```

### Batch Heartbeats (Future)

Multiple ghosts from same operator can share a transaction:

```
Input: Single UTXO
Output 1: OP_RETURN [batch of heartbeats]
Output 2: Change

Savings: ~400 sats per additional ghost
```

## Monitoring & Alerting

### Health Score Algorithm

```python
def calculate_health_score(ghost, current_time):
    """0-100 score based on heartbeat history."""
    score = 100
    
    # Penalize missed heartbeats
    expected_heartbeats = (current_time - ghost.activated_at) / (6 * 3600)
    actual_heartbeats = ghost.heartbeat_count
    
    if expected_heartbeats > 0:
        ratio = actual_heartbeats / expected_heartbeats
        score *= min(ratio, 1.0)
    
    # Penalize inactivity
    if ghost.state == 'INACTIVE':
        score *= 0.5
    
    # Bonus for consistent recent heartbeats
    if ghost.last_heartbeat > current_time - 86400:
        score = min(score * 1.1, 100)
    
    return int(score)
```

### Alerts

Operators should monitor:

| Condition | Severity | Action |
|-----------|----------|--------|
| 12h no heartbeat | WARNING | Check node status |
| 24h no heartbeat | CRITICAL | Investigate immediately |
| 48h no heartbeat | EMERGENCY | Ghost marked INACTIVE |
| Location mismatch | WARNING | Verify GPS |
| Sequence error | ERROR | Check for replay attack |

## Integration with State Machine

### ACTIVE → INACTIVE Transition

```python
def check_expiry(ghost, current_block):
    """Mark inactive if heartbeat overdue."""
    if ghost.state != 'ACTIVE':
        return
        
    last = ghost.last_heartbeat_block
    if not last:
        last = ghost.activated_at
    
    if current_block - last > 288:  # 48 hours
        ghost.state = 'INACTIVE'
        ghost.inactive_since = current_block
        
        # Log event
        emit_event('GHOST_INACTIVE', {
            'ghost_id': ghost.ghost_id,
            'last_heartbeat': last,
            'inactive_at': current_block
        })
```

### INACTIVE → ACTIVE Recovery

```python
def process_resume(ghost, heartbeat_tx):
    """Resume ghost after inactivity."""
    if ghost.state != 'INACTIVE':
        return False
    
    # Verify fresh heartbeat
    if not validate_heartbeat(ghost, heartbeat_tx):
        return False
    
    ghost.state = 'ACTIVE'
    ghost.resumed_at = heartbeat_tx['block_height']
    
    emit_event('GHOST_RESUMED', {
        'ghost_id': ghost.ghost_id,
        'resumed_at': ghost.resumed_at
    })
    
    return True
```

## Privacy Options

### Standard Mode
- Exact H3 index published
- Full transparency
- Maximum accountability

### Privacy Mode (Future)
- Publish H3 parent (lower resolution)
- Zero-knowledge proof of location
- Reveal exact location only during challenges

## Testing

### Valid Heartbeats

```python
def test_valid_heartbeat():
    ghost = create_test_ghost()
    
    for seq in range(10):
        hb = create_heartbeat(
            ghost_id=ghost.ghost_id,
            sequence=seq,
            h3=ghost.location.h3_index,
            timestamp=time.now() + (seq * 6 * 3600)
        )
        
        assert validate_heartbeat(ghost, hb)
        apply_heartbeat(ghost, hb)
    
    assert ghost.state == 'ACTIVE'
    assert ghost.heartbeat_count == 10
```

### Invalid Heartbeats

```python
def test_invalid_heartbeats():
    ghost = create_test_ghost()
    
    # Wrong sequence
    hb = create_heartbeat(sequence=5)  # Should be 0
    assert not validate_heartbeat(ghost, hb)
    
    # Wrong location
    hb = create_heartbeat(sequence=0, h3='wrong_h3_here')
    assert not validate_heartbeat(ghost, hb)
    
    # Replay old sequence
    apply_heartbeat(ghost, create_heartbeat(sequence=0))
    hb = create_heartbeat(sequence=0)  # Duplicate
    assert not validate_heartbeat(ghost, hb)
```

## Economic Incentives

### Why Heartbeats Cost Money

1. **Prevents spam** — Must pay transaction fees
2. **Proves commitment** — Ongoing operational cost
3. **Sybil resistance** — Expensive to fake many ghosts

### Cost-Benefit Analysis

```
Monthly heartbeat cost: ~80,000 sats
Typical ghost monthly earnings: 500,000+ sats

Heartbeat cost as % of earnings: ~16%

Conclusion: Economically viable for honest operators,
prohibitively expensive for spam/fake ghosts.
```
