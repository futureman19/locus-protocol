# 07 - Transaction Formats

**Version:** 1.0  
**Status:** Draft

---

## Overview

All Locus protocol state changes are recorded as **BSV transactions** with protocol data encoded in `OP_RETURN` outputs. This document defines the exact byte-level formats for all transaction types.

---

## Encoding Standards

### MessagePack

All structured data uses **MessagePack** (binary JSON):

- Compact binary format
- Fast encoding/decoding
- Schema evolution friendly
- Language agnostic

### Hash Function

- **SHA-256** for all hashing
- Double-SHA256 for transaction IDs
- RIPEMD-160 for public key hashes

### Signature Scheme

- **ECDSA** with secp256k1 curve
- **Schnorr** signatures supported (BIP-340)
- DER encoding for ECDSA

---

## Common Structures

### Protocol Prefix

All Locus transactions start with:

```
OP_RETURN "LOCUS" {version} {message_type} {payload}
```

| Field | Size | Description |
|-------|------|-------------|
| Magic | 5 bytes | `"LOCUS"` (0x4C4F435553) |
| Version | 1 byte | Protocol version (0x01) |
| Type | 1 byte | Message type (see below) |
| Payload | variable | MessagePack encoded data |

### Message Types

| Code | Name | Description |
|------|------|-------------|
| 0x01 | CITY_FOUND | Create new city |
| 0x02 | CITY_UPDATE | Update city parameters |
| 0x03 | CITIZEN_JOIN | Join city as citizen |
| 0x04 | CITIZEN_LEAVE | Leave city |
| 0x10 | TERRITORY_CLAIM | Claim territory |
| 0x11 | TERRITORY_RELEASE | Release territory |
| 0x12 | TERRITORY_TRANSFER | Transfer ownership |
| 0x20 | OBJECT_DEPLOY | Deploy /1 object |
| 0x21 | OBJECT_UPDATE | Update object |
| 0x22 | OBJECT_DESTROY | Destroy object |
| 0x30 | HEARTBEAT | Proof of presence |
| 0x40 | GHOST_INVOKE | Invoke ghost |
| 0x41 | GHOST_PAYMENT | Ghost payment channel |
| 0x50 | GOV_PROPOSE | Governance proposal |
| 0x51 | GOV_VOTE | Governance vote |
| 0x52 | GOV_EXEC | Execute proposal |
| 0x60 | UBI_CLAIM | Claim UBI distribution |

---

## City Transactions

### CITY_FOUND (0x01)

**Purpose:** Create a new city at a location

**Transaction Structure:**
```
Inputs:
  - Funding UTXO (32 BSV + fees)

Outputs:
  1. OP_RETURN: Protocol data
  2. P2SH: City stake (32 BSV, CLTV locked)
  3. P2PKH: Change
```

**Payload Schema:**
```json
{
  "name": "string (max 50 chars)",
  "description": "string (max 500 chars)",
  "location": {
    "lat": "float",
    "lng": "float",
    "h3_res7": "string (H3 index)"
  },
  "founder_pubkey": "bytes (33 bytes compressed)",
  "policies": {
    "block_auction_period": "uint32 (seconds)",
    "block_starting_bid": "uint64 (satoshis)",
    "immigration_policy": "string"
  },
  "signature": "bytes (ECDSA signature)"
}
```

**Example (MessagePack hex):**
```
LOCUS 01 01
83 a4 6e616d65 a8 4e656f2d546f6b796f
a4 64657363 d9 01f4 437962657270756e6b206d6574726f706f6c697320666f722064...  
a8 6c6f636174696f6e 83 a3 6c6174 cb 4041... (truncated)
```

### CITIZEN_JOIN (0x03)

**Purpose:** Join an existing city

**Payload Schema:**
```json
{
  "city_id": "string (H3 index)",
  "citizen_pubkey": "bytes (33 bytes)",
  "timestamp": "uint32 (unix seconds)",
  "signature": "bytes"
}
```

---

## Territory Transactions

### TERRITORY_CLAIM (0x10)

**Purpose:** Claim territory at any level

**Payload Schema:**
```json
{
  "level": "uint8 (4, 8, 16, 32)",
  "location": "string (H3 index)",
  "owner_pubkey": "bytes (33 bytes)",
  "stake_amount": "uint64 (satoshis)",
  "lock_height": "uint32 (block height when unlockable)",
  "parent_city": "string (H3 index, for /8, /4, /1)",
  "metadata": "map (optional)",
  "signature": "bytes"
}
```

**Stake Amounts:**
| Level | Stake (BSV) | Stake (sats) |
|-------|-------------|--------------|
| /32 | 32.0 | 3,200,000,000 |
| /16 | 8.0 | 800,000,000 |
| /8 | 8.0 | 800,000,000 |
| /4 | 4.0 | 400,000,000 |
| /1 | 0.1-64.0 | 10,000,000-6,400,000,000 |

**CLTV Lock Calculation:**
```
lock_height = current_block_height + 21_600  # ~5 months
```

### TERRITORY_TRANSFER (0x12)

**Purpose:** Transfer territory to new owner

**Payload Schema:**
```json
{
  "territory_id": "string (H3 index)",
  "from_pubkey": "bytes (33 bytes)",
  "to_pubkey": "bytes (33 bytes)",
  "price": "uint64 (satoshis, 0 for gift)",
  "timestamp": "uint32",
  "signature_from": "bytes",
  "signature_to": "bytes (if price > 0)"
}
```

---

## Object Transactions

### OBJECT_DEPLOY (0x20)

**Purpose:** Deploy a /1 object (ghost, item, billboard)

**Payload Schema:**
```json
{
  "object_type": "string (item|waypoint|agent|billboard|rare|epic|legendary)",
  "location": "string (H3 index)",
  "owner_pubkey": "bytes (33 bytes)",
  "stake_amount": "uint64 (satoshis)",
  "content_hash": "bytes (32 bytes, IPFS/Arweave CID)",
  "manifest_hash": "bytes (32 bytes)",
  "parent_territory": "string (H3 index of /4, /8)",
  "capabilities": ["string"],
  "signature": "bytes"
}
```

**Object Type Stakes:**
| Type | Stake (BSV) |
|------|-------------|
| item | 0.0001 |
| waypoint | 0.5-4.0 |
| agent/ghost | 0.1-4.0 |
| billboard | 10-100 |
| rare | 16 |
| epic | 32 |
| legendary | 64 |

### OBJECT_DESTROY (0x22)

**Purpose:** Destroy object and reclaim stake

**Payload Schema:**
```json
{
  "object_id": "string (H3 index)",
  "owner_pubkey": "bytes (33 bytes)",
  "reason": "string (optional)",
  "timestamp": "uint32",
  "signature": "bytes"
}
```

**Post-conditions:**
- Stake unlocks after CLTV period
- Object enters "destroyed" state
- Content may persist on IPFS (unlinked)

---

## Heartbeat Transactions

### HEARTBEAT (0x30)

**Purpose:** Proof of presence for property or citizen

**Payload Schema:**
```json
{
  "heartbeat_type": "uint8 (1=property, 2=citizen, 3=aura)",
  "entity_id": "string (H3 index or pubkey hash)",
  "entity_type": "uint8 (4, 8, 32 for property)",
  "location": "string (H3 index)",
  "timestamp": "uint32 (unix seconds)",
  "nonce": "uint32",
  "signature": "bytes"
}
```

**Validation:**
```python
def validate_heartbeat(hb):
    # 1. Timestamp within 24h window
    assert abs(current_time() - hb.timestamp) < 86400
    
    # 2. Location matches entity (for property)
    if hb.heartbeat_type == 1:
        assert hb.location == hb.entity_id
    
    # 3. Signature valid
    message = sha256(hb.entity_id + hb.location + hb.timestamp + hb.nonce)
    assert verify_signature(hb.entity_pubkey, message, hb.signature)
    
    # 4. Not duplicate (check nonce)
    assert nonce_not_used(hb.nonce)
```

---

## Ghost Transactions

### GHOST_INVOKE (0x40)

**Purpose:** Invoke a ghost (triggers manifestation)

**Payload Schema:**
```json
{
  "ghost_id": "string (H3 index)",
  "invoker_pubkey": "bytes (33 bytes)",
  "location": "string (H3 index of invoker)",
  "timestamp": "uint32",
  "session_id": "bytes (16 bytes random)",
  "signature": "bytes"
}
```

**Distance Check:**
```python
def can_invoke(ghost_location, invoker_location):
    distance = h3.h3_distance(ghost_location, invoker_location)
    # H3 Res 12 distance ~50m per hex
    return distance <= 10  # Within ~500m
```

### GHOST_PAYMENT (0x41)

**Purpose:** Payment channel operation for ghost interaction

**Payload Schema:**
```json
{
  "channel_id": "string (txid:vout)",
  "operation": "uint8 (1=open, 2=update, 3=close)",
  "amount": "uint64 (satoshis)",
  "balance_user": "uint64",
  "balance_ghost": "uint64",
  "sequence": "uint32",
  "signatures": {
    "user": "bytes",
    "ghost": "bytes",
    "arbiter": "bytes (optional)"
  }
}
```

---

## Governance Transactions

### GOV_PROPOSE (0x50)

**Purpose:** Submit governance proposal

**Payload Schema:**
```json
{
  "proposal_type": "uint8",
  "scope": "uint8 (0=protocol, 1-255=city)",
  "title": "string (max 100 chars)",
  "description": "string (max 2000 chars)",
  "actions": [{
    "type": "string",
    "target": "string",
    "data": "bytes"
  }],
  "deposit": "uint64 (satoshis)",
  "proposer_pubkey": "bytes (33 bytes)",
  "timestamp": "uint32",
  "signature": "bytes"
}
```

**Proposal Types:**
| Code | Type | Threshold |
|------|------|-----------|
| 0x01 | Parameter Change | 51% |
| 0x02 | Contract Upgrade | 66% |
| 0x03 | Treasury Spend | 51% |
| 0x04 | Constitutional | 75% |
| 0x05 | Emergency | 7/12 Guardian |

### GOV_VOTE (0x51)

**Purpose:** Vote on proposal

**Payload Schema:**
```json
{
  "proposal_id": "bytes (32 bytes, txid of proposal)",
  "voter_pubkey": "bytes (33 bytes)",
  "vote": "uint8 (1=yes, 0=no, 2=abstain)",
  "weight": "uint64 (token amount)",
  "timestamp": "uint32",
  "signature": "bytes"
}
```

---

## UBI Transactions

### UBI_CLAIM (0x60)

**Purpose:** Claim accumulated UBI distribution

**Payload Schema:**
```json
{
  "city_id": "string (H3 index)",
  "citizen_pubkey": "bytes (33 bytes)",
  "claim_periods": "uint16 (number of days claiming)",
  "amount": "uint64 (satoshis)",
  "timestamp": "uint32",
  "signature": "bytes"
}
```

**Automatic Distribution:**
Most UBI is distributed automatically by overlay nodes. `UBI_CLAIM` is only for:
- Manual claiming (if auto-distribution missed)
- Accumulated UBI from multiple periods
- Edge cases (citizen was offline)

---

## CLTV Lock Scripts

### Standard Lock (P2SH)

```bitcoin-script
# Redeem script (hashed to create P2SH address)
OP_IF
    # Normal unlock path (after timelock)
    <locktime> OP_CHECKLOCKTIMEVERIFY OP_DROP
    <owner_pubkey> OP_CHECKSIG
OP_ELSE
    # Emergency unlock path (with penalty)
    OP_10 OP_CHECKSEQUENCEVERIFY OP_DROP  # 10 block delay
    <penalty_address> OP_DUP OP_HASH160 <penalty_hash160> OP_EQUALVERIFY
    <owner_pubkey> OP_CHECKSIG
OP_ENDIF

# P2SH output: OP_HASH160 <redeem_hash160> OP_EQUAL
```

### Spending (After Lock Expires)

```bitcoin-script
# ScriptSig
<signature> <owner_pubkey> OP_TRUE <redeem_script>
```

### Emergency Spend (With Penalty)

```bitcoin-script
# ScriptSig  
<signature> <owner_pubkey> OP_FALSE <redeem_script>

# Results in:
# 90% to owner
# 10% to penalty address (protocol treasury)
```

---

## Transaction Validation Rules

### General Rules

1. **Protocol Version:** Must be 0x01
2. **Message Type:** Must be valid (0x01-0x60)
3. **OP_RETURN Size:** Max 100KB per output
4. **Multiple OP_RETURN:** Max 1 per transaction
5. **Signature:** Must verify against declared pubkey

### Specific Rules

| Type | Additional Validation |
|------|----------------------|
| CITY_FOUND | Stake == 3.2B sats, H3 Res 7, lock_height >= current + 21600 |
| TERRITORY_CLAIM | Stake matches level, parent exists, not already claimed |
| OBJECT_DEPLOY | Parent territory owned by same pubkey, content_hash present |
| HEARTBEAT | Timestamp within 24h, location matches entity |
| GHOST_INVOKE | Distance check passed, ghost exists |

### Replay Protection

- Each transaction must include unique nonce
- Nonce tracked per entity
- Duplicate nonces rejected

---

## Example Transactions

### Example 1: Found City

```json
{
  "txid": "a1b2c3d4e5f6...",
  "version": 2,
  "locktime": 0,
  "vin": [{
    "txid": "...",
    "vout": 0,
    "scriptSig": "...",
    "sequence": 4294967295
  }],
  "vout": [
    {
      "value": 0,
      "scriptPubKey": "OP_RETURN 4c4f435553 01 01 [MessagePack data]"
    },
    {
      "value": 3200000000,
      "scriptPubKey": "OP_HASH160 <redeem_hash> OP_EQUAL"
    },
    {
      "value": 1234567,
      "scriptPubKey": "OP_DUP OP_HASH160 <change_hash> OP_EQUALVERIFY OP_CHECKSIG"
    }
  ]
}
```

### Example 2: Submit Heartbeat

```json
{
  "txid": "b2c3d4e5f6a1...",
  "vin": [{
    "txid": "...",
    "vout": 1,
    "scriptSig": "..."
  }],
  "vout": [
    {
      "value": 0,
      "scriptPubKey": "OP_RETURN 4c4f435553 01 30 [heartbeat data]"
    },
    {
      "value": 890000,
      "scriptPubKey": "OP_DUP OP_HASH160 <change_hash> OP_EQUALVERIFY OP_CHECKSIG"
    }
  ],
  "fee": 500
}
```

---

## Implementation Notes

### For Wallet Developers

- Parse OP_RETURN starting with "LOCUS" magic
- Extract version and type byte
- Decode MessagePack payload
- Validate signature before displaying

### For Overlay Nodes

- Index all LOCUS transactions by type
- Maintain UTXO set for stakes
- Validate heartbeats for liveness
- Prune spent outputs

### For Explorers

- Display human-readable type names
- Show decoded MessagePack data
- Link related transactions
- Calculate confirmation status

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-17 | Initial transaction format specification |
