# 06 - Heartbeat & Proof of Presence

**Version:** 1.0  
**Status:** Draft

---

## Overview

**Proof of Presence** is the mechanism by which Locus verifies that users and property owners are physically present at claimed locations. This prevents "dead" territory—claims without activity—and enables liveness-based rewards like UBI.

The mechanism is simple: **periodic heartbeats**—small transactions that prove you (or your property) are still there.

---

## Core Concepts

### What is a Heartbeat?

A heartbeat is a **BSV transaction** that:
1. Includes a signed proof of current GPS location
2. References the territory or user identity being maintained
3. Pays a small network fee (~500 satoshis)
4. Is recorded on the blockchain

### Why Heartbeats?

| Problem | Heartbeat Solution |
|---------|-------------------|
| Dead territory | Forces liveness proof |
| UBI farming | Requires physical presence |
| Ghost abandonment | Owner must maintain |
| City death | Citizens must stay active |
| Sybil attacks | Physical location hard to fake |

### Key Properties

- **Permissionless:** Anyone can submit
- **Verifiable:** On-chain proof
- **Low cost:** ~$0.00025 per heartbeat
- **Privacy-preserving:** H3 hex, not exact GPS
- **Non-coercive:** Grace periods before expiration

---

## Heartbeat Types

### 1. Property Heartbeat

Maintains ownership of territory:

| Level | Frequency | Grace Period | On Expiry |
|-------|-----------|--------------|-----------|
| /32 City | 6 months | 30 days | City enters "inactive" |
| /8 Building | 6 months | 30 days | Building becomes unclaimed |
| /4 Home | 6 months | 30 days | Home becomes unclaimed |
| /1 Object | 6 months | 30 days | Object enters "abandoned" |

**Transaction format:**
```json
{
  "protocol": "locus.heartbeat",
  "type": "property",
  "territory_id": "8f283080dcb019d",
  "territory_level": 8,
  "owner_pubkey": "02aabbccdd...",
  "location": "8f283080dcb019d",
  "timestamp": 1710720000,
  "signature": "..."
}
```

### 2. Citizen Heartbeat

Maintains citizenship and UBI eligibility:

| Requirement | Details |
|-------------|---------|
| **Frequency** | Every 30 days (minimum) |
| **Grace period** | 30 days after expiry |
| **On expiry** | Citizenship paused, UBI stops |
| **Recovery** | Submit heartbeat to resume |

**Transaction format:**
```json
{
  "protocol": "locus.heartbeat",
  "type": "citizen",
  "city_id": "8f283080dcb019d",
  "citizen_pubkey": "02aabbccdd...",
  "location": "8f283080dcb019d",
  "timestamp": 1710720000,
  "signature": "..."
}
```

### 3. Aura Heartbeat

Maintains user's 10-foot personal bubble:

| Requirement | Details |
|-------------|---------|
| **Frequency** | Every 30 days |
| **Grace period** | 7 days |
| **On expiry** | Aura disappears, personal objects hidden |
| **Auto-submit** | Can be bundled with other transactions |

**Transaction format:**
```json
{
  "protocol": "locus.heartbeat",
  "type": "aura",
  "user_pubkey": "02aabbccdd...",
  "location": "8f283080dcb019d",
  "timestamp": 1710720000,
  "signature": "..."
}
```

---

## Location Verification

### GPS + H3 Encoding

Heartbeats don't store exact GPS coordinates. Instead:

1. **Device captures GPS:** `(lat: 35.6762, lng: 139.6503)`
2. **Convert to H3:** Resolution 12 for /1, Resolution 10 for /4, etc.
3. **Store H3 index:** `8f283080dcb019d`
4. **Privacy:** ~3 meter precision at Res 12

### Range Verification

For property heartbeats, location must match claimed territory:

```python
def verify_heartbeat_location(heartbeat_h3, property_h3, property_level):
    """
    Verify heartbeat location is within claimed territory
    """
    # Get parent H3 at property's resolution
    parent_res = get_resolution(property_level)
    heartbeat_parent = h3.h3_to_parent(heartbeat_h3, parent_res)
    
    # Must match
    return heartbeat_parent == property_h3

# Example:
# Property: /4 home at H3 Res 10
# Heartbeat: GPS → H3 Res 12 → parent Res 10
# Verify: parent == property location
```

### Anti-Spoofing Measures

**GPS Spoofing:**
- Mitigation: Multiple location sources (GPS + WiFi + cell towers)
- Mitigation: Velocity checks (can't teleport)
- Mitigation: Time-based movement constraints

**Remote Submission:**
- Mitigation: Heartbeat must reference current block height
- Mitigation: Maximum 24-hour submission window
- Mitigation: Cryptographic freshness (timestamp + signature)

**Replay Attacks:**
- Mitigation: Sequence numbers in heartbeat
- Mitigation: Timestamp within recent window
- Mitigation: Signature includes unique nonce

---

## Fog of War

### Concept

Not all territory is visible to all users. The **Fog of War** reveals territory based on:

1. **Proximity:** Within 1km of current location
2. **Ownership:** Your own property always visible
3. **History:** Places you've visited before
4. **Discovery:** Unclaimed territory

### Visibility Zones

```
User Location (GPS)
    │
    ├── 0-50m: HIGH RESOLUTION
    │   ├── All /1 objects visible
    │   ├── Ghosts manifest
    │   └── Detailed building info
    │
    ├── 50m-1km: MEDIUM RESOLUTION
    │   ├── /8 buildings visible
    │   ├── Ghost counts (not details)
    │   └── Property ownership visible
    │
    ├── 1km-10km: LOW RESOLUTION
    │   ├── /32 cities visible
    │   ├── Block boundaries
    │   └── Population density
    │
    └── 10km+: MINIMAL
        ├── Major landmarks
        └── City names only
```

### Dynamic Reveal

As you move, the map reveals:

```
1. User walks to new location
   ↓
2. Client queries blockchain for territory at location
   ↓
3. Overlay network returns relevant transactions
   ↓
4. Map updates with newly visible territory
   ↓
5. Cached for offline viewing
```

### Privacy Implications

- Your exact path is NOT recorded on-chain
- Only H3 hexes of heartbeats are stored
- Historical location requires explicit opt-in
- Third parties can't track you without your keys

---

## Heartbeat Economics

### Costs

| Component | Cost (sats) | USD (@ $50/BSV) |
|-----------|-------------|-----------------|
| Network fee | ~500 | ~$0.00025 |
| Protocol fee | 0 | Free |
| Total | ~500 | ~$0.00025 |

### Subsidies

Cities may subsidize citizen heartbeats:

```
If city_treasury > 1000 BSV:
  - Reimburse heartbeat fees for active citizens
  - Auto-submit on behalf of citizens (optional)
```

### Batching

Multiple heartbeats can be batched in one transaction:

```json
{
  "protocol": "locus.heartbeat",
  "type": "batch",
  "heartbeats": [
    {"type": "property", "territory_id": "...", ...},
    {"type": "citizen", "city_id": "...", ...},
    {"type": "aura", "user_pubkey": "...", ...}
  ],
  "timestamp": 1710720000,
  "signature": "..."
}
```

Cost: Same network fee (~500 sats) for up to 10 heartbeats.

---

## Proof of Presence Protocol

### Formal Definition

**Proof of Presence** is a cryptographic proof that entity E was at location L at time T.

```
PoP = Sign(E_priv, H(L || T || N))

Where:
  E_priv = Private key of entity
  H = SHA-256 hash function
  L = H3 location index
  T = Timestamp (unix seconds)
  N = Nonce (prevents replay)
```

### Verification

```python
def verify_pop(pop, entity_pubkey, claimed_location, time_window):
    """
    Verify Proof of Presence
    """
    # Extract components
    location, timestamp, nonce = pop.data
    signature = pop.signature
    
    # Check timestamp within window
    if abs(current_time - timestamp) > time_window:
        return False  # Too old or future
    
    # Check location match
    if location != claimed_location:
        return False  # Wrong location
    
    # Verify signature
    message = sha256(location || timestamp || nonce)
    if !verify_signature(entity_pubkey, message, signature):
        return False  # Invalid signature
    
    return True
```

### Multi-Factor Presence

For high-security applications (e.g., city governance voting):

```
PoP_strong = {
  "gps": Sign(priv, H(gps_location || timestamp)),
  "wifi": Sign(priv, H(wifi_fingerprint || timestamp)),
  "bluetooth": Sign(priv, H(bt_nearby || timestamp)),
  "cell": Sign(priv, H(cell_towers || timestamp))
}

Verification requires 3 of 4 factors
```

---

## Implementation

### Client-Side (Mobile App)

```typescript
async function submitHeartbeat(
  type: 'property' | 'citizen' | 'aura',
  entityId: string,
  privateKey: string
): Promise<Transaction> {
  // 1. Get current GPS
  const gps = await getCurrentPosition();
  
  // 2. Convert to H3
  const h3Index = gpsToH3(gps.lat, gps.lng, 12);
  
  // 3. Create heartbeat data
  const timestamp = Math.floor(Date.now() / 1000);
  const nonce = generateNonce();
  const data = {
    protocol: 'locus.heartbeat',
    type,
    entityId,
    location: h3Index,
    timestamp,
    nonce
  };
  
  // 4. Sign
  const signature = sign(privateKey, sha256(data));
  
  // 5. Build transaction
  const tx = buildTransaction({
    outputs: [{
      script: `OP_RETURN ${encodeHeartbeat(data, signature)}`,
      value: 0
    }],
    fee: 500
  });
  
  // 6. Broadcast
  return await broadcast(tx);
}
```

### Server-Side (Overlay Node)

```elixir
defmodule Locus.Heartbeat do
  @moduledoc "Heartbeat processing and validation"
  
  @heartbeat_expiry %{
    property: 6 * 30 * 24 * 60 * 60,  # 6 months
    citizen: 30 * 24 * 60 * 60,         # 30 days
    aura: 30 * 24 * 60 * 60             # 30 days
  }
  
  def verify_heartbeat(tx) do
    case decode_heartbeat(tx) do
      {:ok, heartbeat} ->
        with :ok <- verify_signature(heartbeat),
             :ok <- verify_timestamp(heartbeat),
             :ok <- verify_location(heartbeat),
             :ok <- verify_entity_exists(heartbeat) do
          {:ok, heartbeat}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def is_alive?(entity_id, type) do
    last_heartbeat = get_last_heartbeat(entity_id, type)
    expiry = @heartbeat_expiry[type]
    
    last_heartbeat.timestamp + expiry > current_time()
  end
end
```

---

## UBI Integration

### Eligibility Requirements

To receive UBI, citizen must:

1. Hold at least 1 city token
2. Submit heartbeat within last 30 days
3. Be registered citizen of city
4. City must be Phase 4+ (UBI active)

### Automatic Distribution

```
Daily at 00:00 UTC:
  For each city in Phase 4+:
    eligible_citizens = citizens.where(heartbeat < 30.days.ago)
    daily_ubi = (treasury * 0.001) / citizen_count
    
    For each eligible_citizen:
      Create UBI transaction
      Add to mempool
```

### Heartbeat Reminders

Client app reminds users:

- 7 days before expiry: "Submit heartbeat to maintain UBI"
- 1 day before expiry: "URGENT: Submit heartbeat today"
- On expiry: "UBI paused. Submit heartbeat to resume"

---

## Security Considerations

### Privacy

**Risk:** Location tracking via heartbeats

**Mitigations:**
- H3 hex precision limits (not exact GPS)
- No historical trail by default
- Optional: Submit via Tor/proxy
- Optional: Delayed publication (submit later)

### Censorship

**Risk:** Miners censor heartbeat transactions

**Mitigations:**
- Small transactions (hard to filter)
- Standard P2PKH outputs (indistinguishable)
- Batch submissions (hide in volume)
- Multiple broadcast endpoints

### Cost Escalation

**Risk:** BSV fee market makes heartbeats expensive

**Mitigations:**
- Small transaction size (250 bytes)
- City subsidies for citizens
- Batching reduces per-heartbeat cost
- Grace periods allow waiting for low fees

---

## Comparison to Other Systems

| System | Proof Method | Cost | Privacy | Decentralization |
|--------|--------------|------|---------|------------------|
| Locus | GPS + H3 | Very low | Good | Full |
| FOAM | Zone anchors | Medium | Medium | Partial |
| Helium | Hotspot beacons | Low | Poor | Partial |
| Proof of Humanity | Video + vouch | Free | Poor | Centralized |
| BrightID | Social graph | Free | Medium | Centralized |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-17 | Initial heartbeat and proof of presence specification |
