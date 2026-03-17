# Locus Protocol Python SDK

A reference implementation of the Locus Protocol SDK in Python. Provides territory-centric blockchain operations on BSV.

> **Cities are the core primitive. Ghosts are just one type of /1 Object.**

## Features

- 🏙️ **Complete City Lifecycle**: Found cities, manage citizens, track phases
- 🗺️ **Territory Management**: Claim, release, and transfer territories at all levels
- 👻 **Object/Ghost Deployment**: Deploy and manage objects including ghosts
- 💰 **Treasury & UBI**: Calculate UBI distributions and token redemptions
- 🏛️ **Governance**: Create proposals, tally votes, manage execution
- 📡 **ARC Broadcasting**: Broadcast transactions to BSV network
- 🔧 **Full Type Safety**: Complete type annotations (Python 3.10+)

## Installation

```bash
pip install locus-protocol
```

## Quick Start

```python
from locus import LocusClient, CityManager, TerritoryManager

# Initialize client
client = LocusClient(network='testnet')

# Found a city (32 BSV stake)
from locus import CityFoundParams

script = CityManager.build_found_transaction(CityFoundParams(
    name='Neo-Tokyo',
    lat=35.6762,
    lng=139.6503,
    h3_res7='8f283080dcb019d',
    founder_pubkey='02abc...',
))

# Get city phase by citizen count
phase = CityManager.get_phase(25)  # 'city'
governance = CityManager.get_governance_type(phase)  # 'direct_democracy'

# Claim territory
from locus import TerritoryClaimParams

claim_script = TerritoryManager.build_claim_transaction(TerritoryClaimParams(
    level=8,  # /8 Building
    h3_index='891f1d48177ffff',
    owner_pubkey='owner_key',
    stake_amount=800_000_000,  # 8 BSV
    lock_height=821_600,
    parent_city='city_id',
))
```

## Documentation

- [API Reference](docs/API.md) - Full API documentation
- [Examples](examples/) - Code examples for common use cases

## Territory Hierarchy

Per the Locus Protocol specification:

```
/128 Continent
  └── /64 Country
       └── /32 City (32 BSV stake)
            └── /16 Block (8 BSV)
                 └── /8 Building (8 BSV)
                      └── /4 Home (4 BSV)
                           └── /2 Aura
                                └── /1 Object (Ghost, Item, etc.)
```

## City Phases

| Citizens | Phase       | Governance        | Blocks |
|----------|-------------|-------------------|--------|
| 1        | Genesis     | Founder           | 2      |
| 2-3      | Settlement  | Founder           | 2      |
| 4-8      | Village     | Tribal Council    | 5      |
| 9-20     | Town        | Republic          | 8      |
| 21-50    | City        | Direct Democracy  | 16     |
| 51+      | Metropolis  | Senate            | 24     |

## Transaction Types

The SDK supports all 17 Locus Protocol transaction types:

### City Operations
- `city_found` (0x01) - Found a new city
- `city_update` (0x02) - Update city parameters
- `citizen_join` (0x03) - Citizen joins a city
- `citizen_leave` (0x04) - Citizen leaves a city

### Territory Operations
- `territory_claim` (0x10) - Claim a territory
- `territory_release` (0x11) - Release a territory
- `territory_transfer` (0x12) - Transfer territory ownership

### Object Operations
- `object_deploy` (0x20) - Deploy an object
- `object_update` (0x21) - Update an object
- `object_destroy` (0x22) - Destroy an object

### Protocol Operations
- `heartbeat` (0x30) - Proof of presence
- `ghost_invoke` (0x40) - Invoke a ghost
- `ghost_payment` (0x41) - Pay a ghost

### Governance Operations
- `gov_propose` (0x50) - Create a proposal
- `gov_vote` (0x51) - Vote on a proposal
- `gov_exec` (0x52) - Execute a proposal

### Treasury Operations
- `ubi_claim` (0x60) - Claim UBI distribution

## API Overview

### LocusClient

Main entry point for the SDK:

```python
from locus import LocusClient

client = LocusClient(network='testnet', arc_api_key='optional_key')

# Broadcast a transaction
result = client.broadcast(tx_hex)

# Check transaction status
status = client.get_transaction_status(txid)
```

### Managers

All managers are accessible as static classes:

```python
from locus import (
    CityManager,        # City operations
    TerritoryManager,   # Territory operations
    ObjectManager,      # Object/Ghost operations
    TreasuryManager,    # Treasury & UBI
    GovernanceManager,  # Governance operations
    HeartbeatManager,   # Heartbeat operations
    TransactionBuilder, # Raw transaction building
)

# Or through the client
client = LocusClient()
client.city.get_phase(25)  # Same as CityManager.get_phase(25)
```

### Utilities

```python
from locus import (
    # Fibonacci sequence for city block unlocking
    fibonacci_sequence,
    blocks_for_citizens,
    phase_for_citizens,
    
    # Stake calculations
    stake_for_level,
    stake_for_object_type,
    progressive_tax,
    calculate_lock_height,
    calculate_penalty,
    
    # MessagePack encoding
    encode,
    decode,
)
```

## Constants

All protocol constants are available:

```python
from locus import (
    PROTOCOL_PREFIX,      # "LOCUS"
    PROTOCOL_VERSION,     # 0x01
    TYPE_CODES,           # All 17 type codes
    TERRITORY_STAKES,     # Territory stake requirements
    OBJECT_STAKES,        # Object stake requirements
    TOKEN_DISTRIBUTION,   # Token distribution percentages
    LOCK_PERIOD_BLOCKS,   # ~5 months
    FEE_DISTRIBUTION,     # 50/40/10 split
    GOVERNANCE,           # Governance parameters
)
```

## Development

### Setup

```bash
git clone https://github.com/locusprotocol/locus-protocol.git
cd locus-protocol/python-sdk
pip install -e ".[dev]"
```

### Running Tests

```bash
# Run all tests
pytest

# With coverage
pytest --cov=locus --cov-report=html

# Run specific test file
pytest tests/test_city_manager.py
```

### Code Quality

```bash
# Format with black
black locus tests

# Lint with ruff
ruff check locus tests

# Type check with mypy
mypy locus
```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please read our [Contributing Guide](../../CONTRIBUTING.md) for details.

## Specification

This SDK implements the [Locus Protocol Specification](../../specs/). Key documents:

- [01-territory-hierarchy.md](../../specs/01-territory-hierarchy.md)
- [02-city-lifecycle.md](../../specs/02-city-lifecycle.md)
- [03-staking-economics.md](../../specs/03-staking-economics.md)
- [04-governance.md](../../specs/04-governance.md)
- [07-transaction-formats.md](../../specs/07-transaction-formats.md)
