# Locus Protocol Specification v0.1.0

## Table of Contents
1. [Overview](#overview)
2. [Protocol Concepts](#protocol-concepts)
3. [Transaction Formats](#transaction-formats)
4. [Ghost Lifecycle](#ghost-lifecycle)
5. [Staking Mechanics](#staking-mechanics)
6. [Heartbeat Protocol](#heartbeat-protocol)
7. [Fee Distribution](#fee-distribution)
8. [Challenge System](#challenge-system)
9. [State Validation](#state-validation)

---

## Overview

The Locus Protocol is a permissionless system for deploying location-aware autonomous agents ("ghosts") on the Bitcoin SV blockchain.

**Design Principles:**
- **Permissionless:** No registration, no API keys, no central authority
- **Blockchain-native:** All state lives on-chain or is derived from chain
- **Economic incentives:** Staking and fees align participant interests
- **Trustless:** Cryptographic verification, no trusted intermediaries

**Protocol Version:** 0.1.0 (Testnet)  
**Target Mainnet:** 1.0.0  
**Last Updated:** March 2026

---

## Protocol Concepts

### Ghost
An autonomous software agent with:
- Unique identifier (derived from registration tx)
- Geolocation (lat/lng coordinates)
- Execution code (referenced by hash)
- Economic parameters (stakes, fees)
- Lifecycle state

### Territory
A geographic hexagon in the H3 grid system:
- Resolution 9 hexagons (~170m edge length)
- Ownership via staking
- Ghost deployment permission tied to territory rights

### Staking
Locking BSV to:
- Prove economic commitment
- Enable ghost deployment
- Align incentives (slashing for misbehavior)

### Heartbeat
Periodic on-chain proof-of-liveness:
- Required for active ghosts
- Timeout triggers inactivity penalties
- Prevents "zombie" ghosts

---

## Transaction Formats

All protocol transactions use OP_RETURN outputs with prefixed data.

### Prefix Standards

| Protocol | Prefix Hex | Prefix String |
|----------|------------|---------------|
| Locus Protocol | `0x6c6f637573` | `locus` |
| Version 0.1.0 | `0x0100` | — |

### Common Structure

```
OP_RETURN
  [Protocol Prefix: 5 bytes] "locus"
  [Version: 2 bytes] 0x0100
  [Transaction Type: 1 byte]
  [Payload: variable]
```

### Transaction Types

| Type Code | Name | Description |
|-----------|------|-------------|
| 0x01 | GHOST_REGISTER | Deploy new ghost |
| 0x02 | GHOST_UPDATE | Modify ghost parameters |
| 0x03 | GHOST_RETIRE | Deactivate ghost |
| 0x04 | HEARTBEAT | Proof of liveness |
| 0x05 | INVOCATION | Invoke ghost service |
| 0x06 | CHALLENGE | Dispute ghost behavior |
| 0x07 | CHALLENGE_RESPONSE | Respond to challenge |

---

## Ghost Lifecycle

### State Machine

```
                    ┌─────────────┐
    Register        │   PENDING   │◄────┐
         │          │  (0 days)   │     │ Challenge
         ▼          └──────┬──────┘     │ upheld
    ┌─────────┐            │            │
    │ PENDING │────────────┤            │
    │ (stake) │            ▼            │
    └────┬────┘      ┌─────────────┐    │
         │           │   ACTIVE    │    │
         │           │  (staking)  │────┘
         │           └──────┬──────┘
         │                  │ Heartbeat
         │                  │ timeout
         │                  ▼
         │           ┌─────────────┐
         │           │  INACTIVE   │◄────┐
         │           │ (no longer  │     │ Reactivate
         │           │  serving)   │─────┘
         │           └──────┬──────┘
         │                  │ Challenge
         │                  │ upheld
         │                  ▼
         │           ┌─────────────┐
         └──────────►│   SLASHED   │
              Retire │  (stake     │
                     │  burned)    │
                     └─────────────┘
```

### State Definitions

| State | Duration | Requirements | Capabilities |
|-------|----------|--------------|--------------|
| **PENDING** | 0-7 days | Stake locked, registration valid | None (activation period) |
| **ACTIVE** | Indefinite | Heartbeat every 24h, stake maintained | Accept invocations, earn fees |
| **INACTIVE** | Indefinite | Heartbeat timeout or voluntary pause | No invocations, stake locked |
| **SLASHED** | Permanent | Challenge upheld or critical violation | None, stake partially burned |

### Transitions

| From | To | Trigger | Conditions |
|------|-----|---------|------------|
| PENDING | ACTIVE | Automatic | 7 days elapsed + valid stake |
| ACTIVE | INACTIVE | Heartbeat timeout | > 48h since last heartbeat |
| ACTIVE | INACTIVE | Manual pause | Signed by ghost owner |
| INACTIVE | ACTIVE | Manual resume | Signed by ghost owner + fresh heartbeat |
| ACTIVE | SLASHED | Challenge upheld | Valid challenge proof submitted |
| INACTIVE | SLASHED | Challenge upheld | Valid challenge proof submitted |
| ANY | RETIRED | Retirement tx | Signed by ghost owner |

---

## Staking Mechanics

### Staking Tiers

| Tier | Minimum Stake | Lock Period | Ghost Type |
|------|---------------|-------------|------------|
| Basic | 1,000,000 sats (0.01 BSV) | 5 months (21,600 blocks) | Greeter |
| Standard | 10,000,000 sats (0.1 BSV) | 5 months | Oracle, Merchant |
| Premium | 50,000,000 sats (0.5 BSV) | 5 months | Guardian |
| Custom | 100,000,000+ sats (1+ BSV) | 5-12 months negotiable | Special purpose |

### Staking Transaction

**Structure:**
```
Input: UTXO from owner
Output 1: P2SH stake lock (OP_CHECKLOCKTIMEVERIFY + owner pubkey)
Output 2: OP_RETURN protocol data
Output 3: Change
```

**OP_RETURN Payload (Stake):**
```json
{
  "protocol": "locus",
  "version": "0.1.0",
  "type": "STAKE",
  "ghost_id": "<ghost_identifier>",
  "amount_sats": 10000000,
  "lock_blocks": 21600,
  "unlock_height": 850000,
  "owner_pubkey": "<33_byte_pubkey_hex>"
}
```

### Withdrawal

Stakes unlock automatically after lock period:
- Owner broadcasts spending transaction after `unlock_height`
- No protocol action required
- Early withdrawal impossible (enforced by Bitcoin script)

---

## Heartbeat Protocol

### Purpose
Prove ghost node is operational and maintain ACTIVE status.

### Frequency
- **Required:** Minimum 1 heartbeat per 24-hour period
- **Recommended:** Every 6 hours for reliability
- **Grace period:** 48 hours before marking INACTIVE

### Heartbeat Transaction

**Structure:**
```
Input: Any UTXO (dust acceptable, 546+ sats)
Output 1: OP_RETURN protocol data
Output 2: Change (optional)
```

**OP_RETURN Payload (Heartbeat):**
```json
{
  "protocol": "locus",
  "version": "0.1.0",
  "type": "HEARTBEAT",
  "ghost_id": "<ghost_identifier>",
  "timestamp": 1710528000,
  "sequence": 42,
  "location_hash": "<h3_index_at_resolution_9>",
  "status_hash": "<sha256_of_compressed_status>"
}
```

### Sequence Requirements
- Strictly incrementing integers starting from 0
- Gaps allowed (missed heartbeats) but tracked
- Duplicate sequence numbers rejected by validators

### Location Verification
- Heartbeat includes H3 index at resolution 9
- Must match registered location (within 1 hex tolerance for mobile ghosts)
- Rapid location changes (> 100km/hour) flagged for review

---

## Fee Distribution

### Base Fee Structure

| Ghost Type | Base Fee | Timeout | Complexity |
|------------|----------|---------|------------|
| Greeter | 100 sats | 5 sec | Low |
| Oracle | 1,000 sats | 30 sec | Medium |
| Guardian | 5,000 sats | 60 sec | High |
| Merchant | 500 sats | 30 sec | Medium |
| Custom | Variable | Variable | Variable |

### Fee Distribution Model: 70/20/10

For every invocation fee:
- **70%** → Ghost developer (creates the ghost code)
- **20%** → Ghost executor (node that runs the ghost)
- **10%** → Protocol treasury (development, grants, insurance)

### Invocation Transaction

**Structure:**
```
Input: User's UTXO(s)
Output 1: Ghost payment address (P2PKH) - 70%
Output 2: Executor address (P2PKH) - 20%
Output 3: Treasury address (P2PKH) - 10%
Output 4: OP_RETURN protocol data
Output 5: Change to user
```

**OP_RETURN Payload (Invocation):**
```json
{
  "protocol": "locus",
  "version": "0.1.0",
  "type": "INVOCATION",
  "ghost_id": "<ghost_identifier>",
  "invocation_id": "<unique_uuid>",
  "fee_sats": 1000,
  "timestamp": 1710528000,
  "input_hash": "<sha256_of_input_params>",
  "response_address": "<optional_bsv_address_for_response>"
}
```

### Timeout Protection
- User-specified timeout in invocation (max 300 seconds)
- If ghost doesn't respond: automatic refund via smart contract
- Executor forfeits 20% share if timeout occurs

---

## Challenge System

### Challenge Types

| Type | Description | Evidence Required | Penalty |
|------|-------------|-------------------|---------|
| **NO_SHOW** | Ghost didn't respond to paid invocation | Unsigned invocation + timeout proof | Warning → Slashing |
| **MALFUNCTION** | Ghost responded with invalid/corrupted data | Valid invocation + invalid response proof | Warning → Slashing |
| **LOCATION_FRAUD** | Ghost not at claimed location | GPS proof + contradictory heartbeat | Immediate slashing |
| **FEE_EVASION** | Ghost circumvented fee distribution | Transaction analysis | Immediate slashing |

### Challenge Transaction

**OP_RETURN Payload (Challenge):**
```json
{
  "protocol": "locus",
  "version": "0.1.0",
  "type": "CHALLENGE",
  "ghost_id": "<ghost_identifier>",
  "challenge_id": "<unique_uuid>",
  "challenger": "<bsv_address>",
  "challenge_type": "NO_SHOW",
  "evidence_txid": "<referencing_transaction>",
  "stake_sats": 10000,
  "description_hash": "<sha256_of_detailed_description>"
}
```

### Challenge Staking
- Challenger must stake 10,000 sats
- Returned if challenge upheld
- Forfeited if challenge rejected (prevents spam)

### Resolution Process

1. **Challenge submitted** → Ghost enters DISPUTED state
2. **Response window** → 72 hours for ghost to respond
3. **Evidence review** → Validators evaluate proof
4. **Resolution** → Uphold (slash ghost) or Reject (slash challenger)

### Response Transaction

**OP_RETURN Payload (Challenge Response):**
```json
{
  "protocol": "locus",
  "version": "0.1.0",
  "type": "CHALLENGE_RESPONSE",
  "challenge_id": "<matching_challenge_uuid>",
  "ghost_id": "<ghost_identifier>",
  "evidence_txids": ["<proof_1>", "<proof_2>"],
  "response_hash": "<sha256_of_detailed_response>"
}
```

---

## State Validation

### Deriving Ghost State from Blockchain

Validating nodes reconstruct state by scanning relevant transactions:

```elixir
def derive_ghost_state(ghost_id, block_height) do
  # Find registration
  registration = find_registration_tx(ghost_id)
  
  # Get all heartbeats
  heartbeats = find_heartbeat_txs(ghost_id, after: registration.block)
  
  # Get all challenges
  challenges = find_challenge_txs(ghost_id)
  
  # Get stake status
  stake = find_stake_utxo(ghost_id)
  
  # Apply state machine logic
  calculate_state(
    registration: registration,
    heartbeats: heartbeats,
    challenges: challenges,
    stake: stake,
    current_height: block_height
  )
end
```

### Validation Rules

1. **Registration valid:** Must be unique ghost_id, valid stake, proper format
2. **Heartbeats valid:** Sequence increasing, within time windows, correct location
3. **Challenges resolved:** No pending challenges for ACTIVE status
4. **Stake maintained:** UTXO unspent, lock period valid

### Fork Handling
- Deep reorgs (> 6 blocks) trigger state recalculation
- Confirmed challenges cannot be reversed
- Orphaned transactions re-evaluated in new context

---

## Appendix A: H3 Integration

### Resolution Table

| Resolution | Average Area | Use Case |
|------------|--------------|----------|
| 7 | ~5.2 km² | City neighborhoods |
| 8 | ~740,000 m² | Districts |
| 9 | ~105,000 m² | **Territory standard** |
| 10 | ~15,000 m² | Building clusters |
| 11 | ~2,000 m² | Individual buildings |

### Location Encoding
- H3 index as 64-bit unsigned integer
- Hex string representation in JSON
- Example: `8928308280fffff`

---

## Appendix B: Cryptographic Requirements

### Key Types
- **Secp256k1** for all signatures
- **SHA-256** for all hashes
- **33-byte compressed** public key format

### Signature Schemes
- Transaction inputs: Standard Bitcoin signing (SIGHASH_ALL)
- Ghost identity: Registration txid + output index
- Message signing: BIP-322 compatible

---

## Appendix C: Network Parameters

### Testnet (Current)
- Network: BSV Testnet
- Dust limit: 546 satoshis
- Default fee rate: 0.5 sat/byte
- Min heartbeat: 1 per 24h
- Challenge window: 72 hours

### Mainnet (Target)
- Network: BSV Mainnet
- Dust limit: 546 satoshis
- Default fee rate: 0.05 sat/byte
- Min heartbeat: 1 per 24h
- Challenge window: 72 hours

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2026-03-16 | Initial testnet specification |

---

## References

- [H3 Documentation](https://h3geo.org/docs/)
- [BSV Technical Standards](https://github.com/bitcoin-sv-specs)
- [ARC (Atomic Record Commander)](https://github.com/bitcoin-sv/arc)
