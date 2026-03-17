# Locus Protocol Python SDK - API Reference

Complete API reference for the Locus Protocol Python SDK.

## Table of Contents

- [LocusClient](#locusclient)
- [CityManager](#citymanager)
- [TerritoryManager](#territorymanager)
- [ObjectManager](#objectmanager)
- [TreasuryManager](#treasurymanager)
- [GovernanceManager](#governancemanager)
- [HeartbeatManager](#heartbeatmanager)
- [TransactionBuilder](#transactionbuilder)
- [Utilities](#utilities)
- [Types](#types)
- [Constants](#constants)

---

## LocusClient

Main entry point for the SDK.

```python
from locus import LocusClient

client = LocusClient(network='testnet', arc_api_key=None)
```

### Constructor

#### `LocusClient(network='testnet', arc_api_key=None)`

Initialize the Locus client.

**Parameters:**
- `network` (str): Network to connect to ('mainnet', 'testnet', 'stn')
- `arc_api_key` (str, optional): API key for authenticated ARC endpoints

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `network` | str | Connected network |
| `broadcaster` | ARCBroadcaster | ARC broadcaster instance |
| `city` | CityManager | City operations (static) |
| `territory` | TerritoryManager | Territory operations (static) |
| `objects` | ObjectManager | Object operations (static) |
| `treasury` | TreasuryManager | Treasury operations (static) |
| `governance` | GovernanceManager | Governance operations (static) |
| `heartbeat` | HeartbeatManager | Heartbeat operations (static) |
| `tx` | TransactionBuilder | Transaction building (static) |

### Methods

#### `broadcast(tx_hex: str) -> ARCBroadcastResult`

Broadcast a raw transaction hex to the BSV network.

**Parameters:**
- `tx_hex` (str): Raw transaction in hexadecimal

**Returns:** `ARCBroadcastResult` with txid and status

**Raises:** `requests.RequestException` on failure

#### `get_transaction_status(txid: str) -> ARCBroadcastResult`

Query transaction status from ARC.

**Parameters:**
- `txid` (str): Transaction ID

**Returns:** `ARCBroadcastResult` with status

---

## CityManager

City lifecycle operations.

### Static Methods

#### `build_found_transaction(params: CityFoundParams) -> bytes`

Build a CITY_FOUND transaction script. Requires 32 BSV stake.

**Example:**
```python
from locus import CityManager, CityFoundParams

script = CityManager.build_found_transaction(CityFoundParams(
    name='Neo-Tokyo',
    lat=35.6762,
    lng=139.6503,
    h3_res7='8f283080dcb019d',
    founder_pubkey='02abc...',
))
```

#### `build_join_transaction(city_id: str, citizen_pubkey: str) -> bytes`

Build a CITIZEN_JOIN transaction script.

#### `build_leave_transaction(city_id: str, citizen_pubkey: str) -> bytes`

Build a CITIZEN_LEAVE transaction script.

#### `get_phase(citizen_count: int) -> CityPhase | Literal["none"]`

Returns the current phase for a city based on citizen count.

**Returns:** One of: 'genesis', 'settlement', 'village', 'town', 'city', 'metropolis', 'none'

#### `get_governance_type(phase: CityPhase) -> GovernanceType`

Returns the governance type for the current phase.

**Returns:** One of: 'founder', 'tribal_council', 'republic', 'direct_democracy', 'senate'

#### `get_unlocked_blocks(citizen_count: int) -> int`

Returns the number of /16 blocks unlocked for the citizen count.

#### `get_founding_stake() -> int`

Returns the founding stake in satoshis (32 BSV = 3,200,000,000).

#### `get_lock_height(current_block_height: int) -> int`

Returns the CLTV lock height for founding at a given block.

#### `get_token_distribution() -> TokenDistribution`

Returns the token distribution for a new city.

#### `founder_vested_tokens(months_elapsed: int) -> int`

Calculate vested founder tokens at a given month. Linear vest: 1/12 per month.

#### `is_ubi_active(phase: CityPhase) -> bool`

Checks if UBI is active for the given phase (requires 'city' or 'metropolis').

#### `get_lock_period() -> int`

Returns the lock period in blocks (~21,600).

---

## TerritoryManager

Territory lifecycle operations.

### Static Methods

#### `build_claim_transaction(params: TerritoryClaimParams) -> bytes`

Build a TERRITORY_CLAIM transaction script.

**Example:**
```python
from locus import TerritoryManager, TerritoryClaimParams

script = TerritoryManager.build_claim_transaction(TerritoryClaimParams(
    level=8,  # /8 Building
    h3_index='891f1d48177ffff',
    owner_pubkey='owner_key',
    stake_amount=800_000_000,
    lock_height=821_600,
    parent_city='city_id',
))
```

#### `build_release_transaction(territory_id: str, owner_pubkey: str) -> bytes`

Build a TERRITORY_RELEASE transaction script.

#### `build_transfer_transaction(territory_id: str, from_pubkey: str, to_pubkey: str, price: int = 0) -> bytes`

Build a TERRITORY_TRANSFER transaction script.

#### `get_stake_for_level(level: TerritoryLevel) -> int`

Returns the base stake for a territory level.

| Level | Stake (BSV) | Stake (sats) |
|-------|-------------|--------------|
| 32    | 32          | 3,200,000,000 |
| 16    | 8           | 800,000,000  |
| 8     | 8           | 800,000,000  |
| 4     | 4           | 400,000,000  |

#### `get_progressive_tax(level: TerritoryLevel, property_number: int) -> int`

Returns the progressive tax for the Nth property at a given level.
Formula: `base * 2^(n-1)`

#### `get_lock_height(current_block_height: int) -> int`

Calculate CLTV lock height for a territory claim.

#### `distribute_fees(total_fee: int) -> FeeDistribution`

Distributes a fee amount according to the protocol split (50/40/10).

#### `distribute_territory_fees(territory_share: int) -> TerritoryFeeBreakdown`

Breaks down the territory share among building (50%), city (30%), block (20%).

---

## ObjectManager

Object lifecycle operations (including ghosts).

### Static Methods

#### `build_deploy_transaction(params: ObjectDeployParams) -> bytes`

Build an OBJECT_DEPLOY transaction script.

**Example:**
```python
from locus import ObjectManager, ObjectDeployParams

script = ObjectManager.build_deploy_transaction(ObjectDeployParams(
    object_type='agent',
    h3_index='891f1d48177ffff',
    owner_pubkey='owner_key',
    stake_amount=10_000_000,
    content_hash='abc123',
    parent_territory='parent_hex',
))
```

#### `build_update_transaction(object_id: str, owner_pubkey: str, updates: dict) -> bytes`

Build an OBJECT_UPDATE transaction script.

#### `build_destroy_transaction(object_id: str, owner_pubkey: str, reason: str = "") -> bytes`

Build an OBJECT_DESTROY transaction script.

#### `build_ghost_invoke_transaction(ghost_id: str, invoker_pubkey: str, invoker_location: str, session_id: str = "") -> bytes`

Build a GHOST_INVOKE transaction script.

#### `build_ghost_payment_transaction(ghost_id: str, payer_pubkey: str, amount: int, service_id: str = "") -> bytes`

Build a GHOST_PAYMENT transaction script.

#### `get_min_stake(object_type: ObjectType) -> int`

Returns the minimum stake for an object type.

| Object Type | Min Stake (BSV) | Min Stake (sats) |
|-------------|-----------------|------------------|
| item        | 0.0001          | 10,000           |
| waypoint    | 0.5             | 50,000,000       |
| agent       | 0.1             | 10,000,000       |
| billboard   | 10              | 1,000,000,000    |
| rare        | 16              | 1,600,000,000    |
| epic        | 32              | 3,200,000,000    |
| legendary   | 64              | 6,400,000,000    |

---

## TreasuryManager

Treasury operations including UBI and token redemption.

### Static Methods

#### `calculate_daily_ubi(treasury_sats: int, citizen_count: int) -> int`

Calculate daily UBI per citizen. Formula: `(treasury * 0.001) / citizen_count`

#### `calculate_monthly_cap(treasury_sats: int) -> int`

Calculate monthly cap on UBI distribution. Max 1% of treasury.

#### `is_ubi_eligible(phase: CityPhase, treasury_sats: int) -> bool`

Check if UBI can be distributed (phase + treasury minimums).

#### `get_ubi_info(phase: CityPhase, treasury_sats: int, citizen_count: int) -> UBIInfo`

Get full UBI info for a city.

#### `build_claim_transaction(city_id: str, citizen_pubkey: str, claim_periods: int) -> bytes`

Build a UBI_CLAIM transaction script.

#### `redemption_rate(treasury_sats: int, total_supply: int | None = None) -> float`

Calculate token redemption rate. Formula: `rate = treasury / total_supply`

#### `redeem_tokens(tokens: int, treasury_sats: int, total_supply: int | None = None) -> int`

Calculate BSV received for redeeming tokens.

#### `vested_founder_tokens(months_elapsed: int) -> int`

Calculate vested founder tokens at a given month. Linear: 1/12 per month.

---

## GovernanceManager

Governance operations including proposals and voting.

### Static Methods

#### `build_propose_transaction(params: ProposeParams) -> bytes`

Build a GOV_PROPOSE transaction script.

#### `build_vote_transaction(proposal_id: str, voter_pubkey: str, vote: VoteChoice) -> bytes`

Build a GOV_VOTE transaction script.

#### `build_execute_transaction(proposal_id: str, executor_pubkey: str) -> bytes`

Build a GOV_EXEC transaction script.

#### `get_threshold(proposal_type: ProposalType) -> float`

Returns the vote threshold for a proposal type.

| Proposal Type    | Threshold |
|------------------|-----------|
| parameter_change | 51%       |
| contract_upgrade | 66%       |
| treasury_spend   | 51%       |
| constitutional   | 75%       |
| emergency        | 58.3%     |

#### `get_quorum(phase: CityPhase) -> float`

Returns the quorum requirement for a phase.

| Phase      | Quorum |
|------------|--------|
| village    | 67%    |
| town       | 60%    |
| city       | 40%    |
| metropolis | 51%    |

#### `is_genesis_era(current_block_height: int) -> bool`

Check if in Genesis Era (before block 2,100,000).

#### `tally(votes_for: int, votes_against: int, votes_abstain: int, citizen_count: int, phase: CityPhase, proposal_type: ProposalType) -> Literal["passed", "rejected", "pending"]`

Tally votes and determine outcome.

#### `can_execute(voting_ends_at: int, current_block_height: int, proposal_type: ProposalType) -> bool`

Check if execution delay has been met.

#### `get_proposal_deposit() -> int`

Returns the proposal deposit in satoshis (10,000,000 = 0.1 BSV).

---

## HeartbeatManager

Heartbeat operations for proof of presence.

### Static Methods

#### `build_heartbeat_transaction(params: HeartbeatParams) -> bytes`

Build a HEARTBEAT transaction script.

#### `build_property_heartbeat(entity_id: str, h3_index: str, entity_type: int = 8) -> bytes`

Build a property heartbeat (type=1).

#### `build_citizen_heartbeat(citizen_pubkey: str, h3_index: str) -> bytes`

Build a citizen heartbeat (type=2).

#### `build_aura_heartbeat(owner_pubkey: str, h3_index: str) -> bytes`

Build an aura heartbeat (type=3).

#### `is_valid_timestamp(timestamp_secs: int) -> bool`

Validate heartbeat timestamp (within 24h window).

---

## TransactionBuilder

Low-level transaction building and decoding.

### Static Methods

#### `encode(type_name: MessageTypeName, payload: dict) -> bytes`

Encode a protocol message into an OP_RETURN script.

#### `decode(script: bytes) -> DecodedTransaction`

Decode an OP_RETURN script into protocol data.

#### `build_city_found(params: CityFoundParams) -> bytes`

Build CITY_FOUND script.

#### `build_citizen_join(city_id: str, citizen_pubkey: str) -> bytes`

Build CITIZEN_JOIN script.

#### `build_territory_claim(params: TerritoryClaimParams) -> bytes`

Build TERRITORY_CLAIM script.

#### `build_territory_transfer(territory_id: str, from_pubkey: str, to_pubkey: str, price: int = 0) -> bytes`

Build TERRITORY_TRANSFER script.

#### `build_object_deploy(params: ObjectDeployParams) -> bytes`

Build OBJECT_DEPLOY script.

#### `build_object_destroy(object_id: str, owner_pubkey: str, reason: str = "") -> bytes`

Build OBJECT_DESTROY script.

#### `build_gov_propose(params: ProposeParams) -> bytes`

Build GOV_PROPOSE script.

#### `build_gov_vote(proposal_id: str, voter_pubkey: str, vote: VoteChoice) -> bytes`

Build GOV_VOTE script.

#### `build_gov_exec(proposal_id: str, executor_pubkey: str) -> bytes`

Build GOV_EXEC script.

#### `build_heartbeat(params: HeartbeatParams) -> bytes`

Build HEARTBEAT script.

#### `build_ubi_claim(city_id: str, citizen_pubkey: str, claim_periods: int) -> bytes`

Build UBI_CLAIM script.

---

## Utilities

### Fibonacci Utilities

```python
from locus import (
    fibonacci_sequence,    # First n Fibonacci numbers
    fibonacci_sum,         # Sum of first n Fibonacci numbers
    blocks_for_citizens,   # Unlocked blocks for citizen count
    phase_for_citizens,    # Phase from citizen count
    governance_for_phase,  # Governance type from phase
    phase_number,          # Phase number (0-5)
)
```

### Stake Utilities

```python
from locus import (
    stake_for_level,            # Stake for territory level
    stake_for_object_type,      # Stake for object type
    calculate_lock_height,      # Lock height from current
    calculate_penalty,          # 10% emergency penalty
    calculate_emergency_return, # 90% emergency return
    progressive_tax,            # Progressive property tax
)
```

### MessagePack Utilities

```python
from locus import encode, decode

# Encode data
data = {"name": "Test", "value": 123}
encoded = encode(data)  # bytes

# Decode data
decoded = decode(encoded)  # dict
```

---

## Types

### Core Types

```python
from locus import (
    Network,                    # 'mainnet' | 'testnet' | 'stn'
    CityPhase,                  # 'genesis' | 'settlement' | 'village' | 'town' | 'city' | 'metropolis'
    GovernanceType,             # 'founder' | 'tribal_council' | 'republic' | 'direct_democracy' | 'senate'
    TerritoryLevel,             # 128 | 64 | 32 | 16 | 8 | 4 | 2 | 1
    ObjectType,                 # 'item' | 'waypoint' | 'agent' | 'billboard' | 'rare' | 'epic' | 'legendary'
    ProposalType,               # 'parameter_change' | 'contract_upgrade' | 'treasury_spend' | 'constitutional' | 'emergency'
    VoteChoice,                 # 'yes' | 'no' | 'abstain'
    MessageTypeName,            # All 17 message type names
)
```

### Dataclasses

```python
from locus import (
    CityFoundParams,            # Parameters for founding a city
    TerritoryClaimParams,       # Parameters for claiming territory
    ObjectDeployParams,         # Parameters for deploying object
    ProposeParams,              # Parameters for creating proposal
    HeartbeatParams,            # Parameters for heartbeat
    UBIInfo,                    # UBI information
    FeeDistribution,            # Fee distribution breakdown
    TerritoryFeeBreakdown,      # Territory fee breakdown
    TokenDistribution,          # Token distribution
    DecodedTransaction,         # Decoded transaction
    ARCBroadcastResult,         # ARC broadcast result
)
```

---

## Constants

### Protocol Constants

```python
from locus import (
    PROTOCOL_PREFIX,            # "LOCUS"
    PROTOCOL_VERSION,           # 0x01
    PROTOCOL_PREFIX_HEX,        # "4c4f435553"
)
```

### Type Codes

```python
from locus import (
    TYPE_CODES,                 # Dict[str, int] - all 17 types
    REVERSE_CODES,              # Dict[int, str] - reverse lookup
    PROPOSAL_TYPE_CODES,        # Proposal type codes
    VOTE_CODES,                 # Vote value codes
)
```

### Stakes

```python
from locus import (
    TERRITORY_STAKES,           # Territory stake requirements
    OBJECT_STAKES,              # Object stake requirements
    TOKEN_DISTRIBUTION,         # Token distribution
    LOCK_PERIOD_BLOCKS,         # ~21,600 blocks
    EMERGENCY_PENALTY_RATE,     # 0.10 (10%)
)
```

### Fees

```python
from locus import (
    FEE_DISTRIBUTION,           # Fee split (dev/territory/protocol)
    TERRITORY_FEE_SPLIT,        # Territory share split
)
```

### Governance

```python
from locus import (
    GOVERNANCE,                 # Governance parameters
    PROPOSAL_THRESHOLDS,        # Proposal thresholds
    QUORUM_BY_PHASE,            # Quorum requirements
)
```

### Network

```python
from locus import (
    ARC_ENDPOINTS,              # ARC endpoints by network
    DUST_LIMIT,                 # 546 sats
    DEFAULT_FEE_RATE,           # 0.5 sats/byte
)
```
