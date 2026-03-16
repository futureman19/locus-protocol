# Transaction Formats

This document specifies the exact byte-level encoding for all Locus Protocol transactions.

## Binary Encoding

All OP_RETURN payloads use the following encoding for compactness:

| Field | Type | Size | Description |
|-------|------|------|-------------|
| Protocol Prefix | Fixed bytes | 5 | `0x6c6f637573` ("locus") |
| Version | uint16 BE | 2 | Major * 256 + Minor |
| Type | uint8 | 1 | Transaction type code |
| Payload Length | uint16 BE | 2 | Length of following payload |
| Payload | Variable | N | MessagePack-encoded data |

### Version Encoding

```
Version 0.1.0 = 0x0001 (major 0, minor 1)
Version 1.0.0 = 0x0100 (major 1, minor 0)
```

### Type Codes

| Code | Name | Description |
|------|------|-------------|
| 0x01 | GHOST_REGISTER | Deploy new ghost |
| 0x02 | GHOST_UPDATE | Update ghost parameters |
| 0x03 | GHOST_RETIRE | Deactivate ghost |
| 0x04 | HEARTBEAT | Proof of liveness |
| 0x05 | INVOCATION | Invoke ghost service |
| 0x06 | CHALLENGE | File challenge |
| 0x07 | CHALLENGE_RESPONSE | Respond to challenge |
| 0x08 | STAKE | Stake transaction |
| 0x09 | UNSTAKE | Withdraw stake |

## GHOST_REGISTER (0x01)

### Transaction Structure

```
Input: Owner's UTXO (funds the tx + stake)
Output 1: P2SH stake lock (OP_CLTV + owner pubkey)
  Script: <lock_height> OP_CHECKLOCKTIMEVERIFY OP_DROP <owner_pubkey> OP_CHECKSIG
Output 2: OP_RETURN protocol data
Output 3: Change to owner
```

### MessagePack Payload Schema

```
{
  id: bytes(32),          // Ghost unique identifier
  name: string,           // Max 64 bytes
  type: uint8,            // 1=GREETER, 2=ORACLE, 3=GUARDIAN, 4=MERCHANT, 5=CUSTOM
  lat: int32,             // Latitude * 1,000,000 (microdegrees)
  lng: int32,             // Longitude * 1,000,000 (microdegrees)
  h3: uint64,             // H3 index
  stake_amt: uint64,      // Satoshis staked
  lock_blocks: uint32,    // Block count for lock
  unlock_h: uint32,       // Block height when unlocks
  owner_pk: bytes(33),    // Compressed public key
  code_hash: bytes(32),   // SHA-256 of ghost code
  code_uri: string,       // Optional code location
  base_fee: uint64,       // Base invocation fee
  timeout: uint16,        // Timeout in seconds
  meta: map<string,string> // Optional metadata
}
```

### Ghost ID Derivation

```
ghost_id = SHA256(stake_txid || output_index)
```

Where:
- `stake_txid` is the transaction ID of the staking output
- `output_index` is the index of the P2SH stake output (uint32 LE)

### Example Hex

```
6c6f637573              // Protocol prefix "locus"
0001                    // Version 0.1.0
01                      // Type: GHOST_REGISTER
00a3                    // Payload length: 163 bytes
[163 bytes MessagePack] // Encoded payload
```

## HEARTBEAT (0x04)

### Transaction Structure

```
Input: Any UTXO (546+ sats for dust limit)
Output 1: OP_RETURN protocol data
Output 2: Change (optional, remainder can be fee)
```

### MessagePack Payload Schema

```
{
  ghost_id: bytes(32),    // Ghost identifier
  ts: uint32,             // Unix timestamp
  seq: uint32,            // Sequence number (strictly increasing)
  h3: uint64,             // Current H3 location
  status_hash: bytes(32), // SHA-256 of compressed status
  metrics: {              // Optional performance metrics
    inv_24h: uint32,      // Invocations in last 24h
    avg_ms: uint16,       // Average response time
    uptime: uint8         // Uptime percentage (0-100)
  }
}
```

### Sequence Validation Rules

1. First heartbeat must have `seq = 0`
2. Each subsequent heartbeat must have `seq = previous + 1`
3. Gaps allowed but counted as missed heartbeats
4. Duplicate sequence numbers rejected

### Heartbeat Interval Requirements

| Network | Minimum | Recommended | Grace Period |
|---------|---------|-------------|--------------|
| Testnet | 24 hours | 6 hours | 48 hours |
| Mainnet | 24 hours | 6 hours | 48 hours |

After grace period without heartbeat, ghost marked INACTIVE.

## INVOCATION (0x05)

### Transaction Structure

```
Input: User's UTXO
Output 1: P2PKH ghost developer (70% of fee)
Output 2: P2PKH executor node (20% of fee)
Output 3: P2PKH protocol treasury (10% of fee)
Output 4: OP_RETURN protocol data
Output 5: Change to user
```

### Fee Distribution

```
developer_amount = floor(total_fee * 0.70)
executor_amount = floor(total_fee * 0.20)
treasury_amount = total_fee - developer_amount - executor_amount
```

### MessagePack Payload Schema

```
{
  ghost_id: bytes(32),    // Target ghost
  invoke_id: bytes(16),   // UUID (128 bits)
  fee: uint64,            // Total fee in satoshis
  ts: uint32,             // Timestamp
  input_hash: bytes(32),  // SHA-256 of input params
  resp_addr: bytes(21),   // Optional response address (raw bytes)
  timeout: uint16,        // Timeout in seconds (max 300)
  priority: uint8         // 0=LOW, 1=NORMAL, 2=HIGH
}
```

### Response Address Encoding

If `resp_addr` is provided:
- First byte: address type (0x00 = P2PKH, 0x01 = P2SH)
- Remaining 20 bytes: hash160

### Timeout Protection

1. User specifies `timeout` in invocation
2. Ghost must respond within timeout window
3. If timeout expires:
   - User can broadcast refund transaction
   - Executor forfeits 20% share
   - Developer keeps 70% (work was attempted)

## CHALLENGE (0x06)

### Transaction Structure

```
Input: Challenger's UTXO (must include 10,000+ sat stake)
Output 1: P2SH challenge stake (locked until resolution)
  Script: <challenge_id> OP_DROP <resolution_pubkey> OP_CHECKSIG
Output 2: OP_RETURN protocol data
Output 3: Change to challenger
```

### MessagePack Payload Schema

```
{
  ghost_id: bytes(32),    // Challenged ghost
  challenge_id: bytes(16),// UUID
  challenger: bytes(21),  // Challenger address (raw)
  type: uint8,            // 1=NO_SHOW, 2=MALFUNCTION, 3=LOCATION_FRAUD, 4=FEE_EVASION
  evidence_tx: bytes(32), // TXID of evidence
  stake: uint64,          // Challenger stake (min 10,000)
  desc_hash: bytes(32),   // SHA-256 of description
  proposed: uint8         // 0=WARNING, 1=SLASH_PARTIAL, 2=SLASH_FULL
}
```

### Challenge Types

| Type | Code | Evidence Required | Response Window |
|------|------|-------------------|-----------------|
| NO_SHOW | 1 | Invocation tx + timeout proof | 72 hours |
| MALFUNCTION | 2 | Invocation tx + invalid response | 72 hours |
| LOCATION_FRAUD | 3 | GPS proof + contradictory heartbeat | 72 hours |
| FEE_EVASION | 4 | Transaction analysis | 72 hours |

### Challenge Staking

- Minimum stake: 10,000 satoshis
- Stake returned if challenge upheld
- Stake forfeited if challenge rejected (prevents spam)
- Stake locked in P2SH until resolution

## CHALLENGE_RESPONSE (0x07)

### Transaction Structure

```
Input: Ghost owner's UTXO
Output 1: OP_RETURN protocol data
Output 2: Change (optional)
```

### MessagePack Payload Schema

```
{
  challenge_id: bytes(16),// Matching challenge UUID
  ghost_id: bytes(32),    // Ghost identifier
  evidence: [bytes(32)],  // Array of evidence TXIDs
  resp_hash: bytes(32)    // SHA-256 of detailed response
}
```

## Stake Transactions

### STAKE (0x08)

This is a protocol marker for stake transactions, typically the same transaction as GHOST_REGISTER.

```
OP_RETURN payload:
{
  ghost_id: bytes(32),
  amount: uint64,
  lock_blocks: uint32,
  unlock_h: uint32,
  owner_pk: bytes(33)
}
```

### UNSTAKE (0x09)

Broadcast when stake lock expires to claim funds.

```
Input: P2SH stake UTXO (signed by owner, after lock_height)
Output 1: Owner's receiving address
Output 2: OP_RETURN protocol data (optional marker)
```

## Validation Rules

### Transaction Validation

All protocol transactions must pass:

1. **Protocol prefix check:** Must start with `0x6c6f637573`
2. **Version check:** Must be recognized version
3. **Type check:** Must be valid type code
4. **Payload validation:** Must decode per schema
5. **Signature verification:** Inputs must be validly signed
6. **Consensus rules:** Must follow protocol state transitions

### Ghost-Specific Validation

| Transaction | Prerequisites |
|-------------|---------------|
| GHOST_REGISTER | Unique ghost_id, valid stake amount, valid location |
| HEARTBEAT | Ghost exists and is ACTIVE or INACTIVE, valid sequence |
| INVOCATION | Ghost is ACTIVE, sufficient fee paid, valid ghost_id |
| CHALLENGE | Ghost exists, valid evidence, sufficient stake |
| CHALLENGE_RESPONSE | Matching pending challenge, within response window |

## Size Limits

| Component | Maximum Size |
|-----------|--------------|
| Total OP_RETURN | 100 KB (BSV limit) |
| Protocol payload | 99 KB (after prefix) |
| Ghost name | 64 bytes |
| Ghost description | 512 bytes |
| Metadata keys | 10 keys |
| Metadata value | 256 bytes per value |
| Code URI | 256 bytes |

## Test Vectors

See `/test-vectors/fixtures/` for:
- Valid registrations (various ghost types)
- Valid heartbeats (sequence progression)
- Valid invocations (fee distribution)
- Valid challenges (all types)
- Invalid transactions (should be rejected)

## References

- [MessagePack Specification](https://msgpack.org/)
- [BSV Transaction Format](https://wiki.bitcoinsv.io/index.php/Transaction)
- [OP_RETURN Limits](https://wiki.bitcoinsv.io/index.php/OP_RETURN)
