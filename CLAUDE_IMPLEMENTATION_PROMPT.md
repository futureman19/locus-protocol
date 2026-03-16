# Locus Protocol Implementation - Claude Assignment

## Background

We previously built a **ghost-centric** protocol implementation that was architecturally incorrect. That version has been archived at `futureman19/locus-protocol-ARCHIVED`.

The correct architecture is **territory-centric** with cities, blocks, buildings, homes, and ghosts as /1 objects. Complete specifications have been written in the new `futureman19/locus-protocol` repo.

## Your Task

Implement the **Core Territory Layer** in Elixir. This is Phase 1 of the reference implementation.

## Specifications (READ FIRST)

All specs are in `specs/` directory:
1. `00-principles.md` - Core protocol principles
2. `01-territory-hierarchy.md` - Geo-IPv6 addressing (/32 City → /1 Object)
3. `02-city-lifecycle.md` - 6 phases, Fibonacci unlock, governance evolution
4. `03-staking-economics.md` - Lock-to-mint, UBI, progressive tax
5. `04-governance.md` - Genesis/Federal eras, Cathedral Guardian
6. `05-ghost-protocol.md` - Schrödinger states (ghost layer - NOT your focus)
7. `06-heartbeat-presence.md` - Proof of Presence (coordinate with this)
8. `07-transaction-formats.md` - OP_RETURN schemas, MessagePack encoding

**CRITICAL:** Read specs 00-04, 07 thoroughly. Specs 05-06 are for context but not your primary implementation target.

## Implementation Scope

### Directory Structure
```
core/
├── lib/
│   ├── locus.ex                 # Main application module
│   ├── locus/
│   │   ├── application.ex       # OTP Application
│   │   ├── territory.ex         # Territory claiming/releasing
│   │   ├── city.ex              # City lifecycle management
│   │   ├── fibonacci.ex         # Block unlock calculations
│   │   ├── treasury.ex          # BSV treasury, UBI distribution
│   │   ├── governance.ex        # Voting, proposals, councils
│   │   ├── staking.ex           # CLTV lock scripts, unlocks
│   │   ├── transaction.ex       # Transaction building
│   │   ├── chain.ex             # Blockchain interaction (ARC)
│   │   └── state.ex             # In-memory state, indexing
│   └── locus/
│       └── schema/
│           ├── city.ex          # City struct
│           ├── territory.ex     # Territory struct
│           ├── citizen.ex       # Citizen struct
│           └── proposal.ex      # Governance proposal struct
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   └── testnet.exs
├── test/
│   ├── locus/
│   │   ├── city_test.exs
│   │   ├── territory_test.exs
│   │   ├── fibonacci_test.exs
│   │   ├── treasury_test.exs
│   │   └── governance_test.exs
│   └── test_helper.exs
├── mix.exs
└── README.md
```

### Module Requirements

#### 1. `Locus.City`

**Responsibilities:**
- Found new cities (`found/5`)
- Track city lifecycle phases
- Manage citizen registry
- Calculate Fibonacci unlocks

**Key Functions:**
```elixir
@spec found(String.t(), map(), String.t(), non_neg_integer(), String.t()) :: {:ok, City.t()} | {:error, term()}
def found(name, location, founder_pubkey, stake_amount, policies)

@spec get_phase(City.t()) :: :genesis | :settlement | :village | :town | :city | :metropolis
def get_phase(city)

@spec join_city(String.t(), String.t()) :: {:ok, Citizen.t()} | {:error, term()}
def join_city(city_id, citizen_pubkey)

@spec can_propose?(City.t(), String.t()) :: boolean()
def can_propose?(city, citizen_pubkey)
```

**Fibonacci Logic:**
```elixir
@spec unlocked_blocks(non_neg_integer()) :: non_neg_integer()
def unlocked_blocks(citizen_count)
# Returns number of blocks unlocked based on Fibonacci sequence
# 1 citizen = 2 blocks (1+1)
# 4 citizens = 5 blocks (1+1+2+1) - actually recalculate based on spec
```

#### 2. `Locus.Territory`

**Responsibilities:**
- Claim territory at any level
- Verify stake amounts
- Handle transfers
- Track ownership

**Key Functions:**
```elixir
@spec claim(integer(), String.t(), String.t(), non_neg_integer(), String.t()) :: {:ok, Territory.t()} | {:error, term()}
def claim(level, location, owner_pubkey, stake_amount, parent_city)
# level: 32, 16, 8, 4, 1

@spec release(String.t(), String.t()) :: {:ok, Transaction.t()} | {:error, term()}
def release(territory_id, owner_pubkey)

@spec transfer(String.t(), String.t(), String.t(), non_neg_integer()) :: {:ok, Territory.t()} | {:error, term()}
def transfer(territory_id, from_pubkey, to_pubkey, price)

@spec calculate_stake(integer(), non_neg_integer()) :: non_neg_integer()
def calculate_stake(level, property_count)
# Progressive tax: 1st=base, 2nd=2×, 3rd=4×, etc.
```

#### 3. `Locus.Fibonacci`

**Responsibilities:**
- Pure Fibonacci calculations
- Block unlock progression

**Key Functions:**
```elixir
@spec sequence(non_neg_integer()) :: list(non_neg_integer())
def sequence(n)
# Returns first n Fibonacci numbers: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144...]

@spec sum_up_to(non_neg_integer()) :: non_neg_integer()
def sum_up_to(n)
# Sum of Fibonacci sequence up to nth number

@spec blocks_for_citizens(non_neg_integer()) :: non_neg_integer()
def blocks_for_citizens(citizen_count)
# Returns how many /16 blocks are unlocked for given citizen count
# See spec 02-city-lifecycle.md for exact mapping
```

#### 4. `Locus.Treasury`

**Responsibilities:**
- Track BSV balances per city
- Calculate UBI distributions
- Process redemptions
- Handle fee distribution

**Key Functions:**
```elixir
@spec deposit(String.t(), non_neg_integer(), String.t()) :: {:ok, Treasury.t()} | {:error, term()}
def deposit(city_id, amount_satoshis, source)

@spec calculate_ubi(String.t()) :: non_neg_integer()
def calculate_ubi(city_id)
# daily_ubi = (treasury_bsv × 0.001) / citizen_count

@spec distribute_ubi(String.t()) :: list(Transaction.t())
def distribute_ubi(city_id)
# Returns list of UBI transactions for all eligible citizens

@spec redeem_tokens(String.t(), String.t(), non_neg_integer()) :: {:ok, Transaction.t()} | {:error, term()}
def redeem_tokens(city_id, citizen_pubkey, token_amount)
# Burn tokens, return BSV at redemption rate
```

#### 5. `Locus.Governance`

**Responsibilities:**
- Proposal creation
- Voting
- Proposal execution
- Council management

**Key Functions:**
```elixir
@spec propose(String.t(), String.t(), String.t(), String.t(), list(map()), non_neg_integer()) :: {:ok, Proposal.t()} | {:error, term()}
def propose(city_id, proposer_pubkey, title, description, actions, deposit)

@spec vote(String.t(), String.t(), String.t(), integer(), non_neg_integer()) :: {:ok, Vote.t()} | {:error, term()}
def vote(proposal_id, voter_pubkey, vote_type, weight)
# vote_type: 1=yes, 0=no, 2=abstain

@spec execute(String.t()) :: {:ok, term()} | {:error, term()}
def execute(proposal_id)
# Executes proposal if passed and timelock expired

@spec get_threshold(String.t()) :: float()
def get_threshold(proposal_type)
# Returns required vote threshold (0.51, 0.66, 0.75)
```

#### 6. `Locus.Staking`

**Responsibilities:**
- Build CLTV locking scripts
- Build unlocking transactions
- Calculate lock heights

**Key Functions:**
```elixir
@spec build_lock_script(String.t(), non_neg_integer(), non_neg_integer()) :: binary()
def build_lock_script(owner_pubkey, lock_height, penalty_pubkey_hash)

@spec build_unlock_transaction(String.t(), non_neg_integer(), String.t()) :: Transaction.t()
def build_unlock_transaction(utxo_txid, utxo_vout, owner_privkey)

@spec calculate_lock_height(non_neg_integer()) :: non_neg_integer()
def calculate_lock_height(current_height)
# current_height + 21_600 blocks

@spec emergency_unlock(String.t(), non_neg_integer(), String.t(), String.t()) :: Transaction.t()
def emergency_unlock(utxo_txid, utxo_vout, owner_privkey, penalty_address)
# 90% to owner, 10% penalty to treasury
```

#### 7. `Locus.Transaction`

**Responsibilities:**
- Build protocol transactions
- Encode OP_RETURN data (MessagePack)
- Sign transactions

**Key Functions:**
```elixir
@spec build_city_found(map()) :: Transaction.t()
def build_city_found(params)

@spec build_territory_claim(map()) :: Transaction.t()
def build_territory_claim(params)

@spec build_heartbeat(map()) :: Transaction.t()
def build_heartbeat(params)

@spec encode_op_return(integer(), map()) :: binary()
def encode_op_return(message_type, payload)
# Prefix: "LOCUS" + version (0x01) + type + MessagePack(payload)
```

#### 8. `Locus.Chain`

**Responsibilities:**
- Interact with BSV blockchain
- ARC broadcasting
- UTXO tracking
- Block height queries

**Key Functions:**
```elixir
@spec broadcast(Transaction.t()) :: {:ok, String.t()} | {:error, term()}
def broadcast(transaction)
# Returns txid on success

@spec get_block_height() :: non_neg_integer()
def get_block_height()

@spec get_utxos(String.t()) :: list(map())
def get_utxos(address)

@spec get_transaction(String.t()) :: map()
def get_transaction(txid)
```

### Schemas

Define these structs with proper types:

```elixir
defmodule Locus.Schema.City do
  defstruct [
    :id,                    # H3 index (string)
    :name,                  # String
    :description,           # String
    :location,              # %{lat: float, lng: float, h3_res7: string}
    :founder_pubkey,        # String
    :stake_amount,          # Integer (satoshis)
    :stake_lock_height,     # Integer (block height)
    :created_at,            # DateTime
    :phase,                 # Atom
    :policies,              # Map
    :treasury_bsv,          # Integer (satoshis)
    :token_supply,          # Integer (3.2M tokens)
    :citizen_count,         # Integer
    :unlocked_blocks        # Integer
  ]
  
  @type t :: %__MODULE__{...}
end

defmodule Locus.Schema.Territory do
  defstruct [
    :id,                    # H3 index
    :level,                 # Integer (32, 16, 8, 4, 1)
    :location,              # H3 index
    :owner_pubkey,          # String
    :stake_amount,          # Integer
    :stake_lock_height,     # Integer
    :claimed_at,            # DateTime
    :parent_city,           # String (H3 index)
    :metadata               # Map
  ]
end

defmodule Locus.Schema.Citizen do
  defstruct [
    :city_id,               # H3 index
    :pubkey,                # String
    :joined_at,             # DateTime
    :last_heartbeat,        # DateTime
    :token_balance,         # Integer
    :ubi_claimed_at         # DateTime
  ]
end

defmodule Locus.Schema.Proposal do
  defstruct [
    :id,                    # Transaction hash
    :city_id,               # H3 index
    :type,                  # Atom
    :title,                 # String
    :description,           # String
    :actions,               # List of maps
    :proposer,              # String (pubkey)
    :deposit,               # Integer
    :created_at,            # DateTime
    :voting_ends_at,        # DateTime
    :status,                # Atom (:pending, :passed, :rejected, :executed)
    :votes_yes,             # Integer
    :votes_no,              # Integer
    :votes_abstain          # Integer
  ]
end
```

### Configuration

Create `config/testnet.exs`:
```elixir
import Config

config :locus, Locus.Chain,
  network: :testnet,
  arc_endpoint: "https://arc-test.taal.com",
  whats_on_chain_endpoint: "https://api.whatsonchain.com/v1/bsv/test",
  junglebus_endpoint: "https://junglebus.gorillapool.io"

config :locus, Locus.Staking,
  lock_period_blocks: 21_600,
  penalty_rate: 0.1  # 10%

config :locus, Locus.Treasury,
  ubi_daily_rate: 0.001,  # 0.1% of treasury
  ubi_monthly_cap: 0.01,  # 1% max per month
  min_treasury_for_ubi: 100_000_000  # 100 BSV

config :locus, Locus.Governance,
  proposal_deposit: 10_000_000,  # 0.1 BSV
  voting_period_days: 14,
  timelock_days: 3
```

## Implementation Priorities

### Phase 1A: Foundation (Week 1)
1. Project setup (`mix new`, dependencies)
2. Schemas (City, Territory, Citizen, Proposal)
3. `Locus.Fibonacci` (pure functions, easy wins)
4. `Locus.Territory` (basic claim/release)
5. Basic tests

### Phase 1B: City Lifecycle (Week 2)
1. `Locus.City` (found, phases, citizens)
2. `Locus.Treasury` (deposits, basic tracking)
3. Integration tests

### Phase 1C: Governance (Week 3)
1. `Locus.Governance` (proposals, voting)
2. `Locus.Treasury` (UBI, redemptions)
3. Governance tests

### Phase 1D: Staking & Transactions (Week 4)
1. `Locus.Staking` (CLTV scripts)
2. `Locus.Transaction` (OP_RETURN encoding)
3. `Locus.Chain` (ARC integration)
4. End-to-end tests

## Testing Requirements

Every module must have comprehensive tests:

```elixir
defmodule Locus.CityTest do
  use ExUnit.Case
  alias Locus.City
  alias Locus.Schema.City, as: CitySchema
  
  describe "found/5" do
    test "creates city with correct initial state" do
      # Test implementation
    end
    
    test "fails with insufficient stake" do
      # Test implementation
    end
  end
  
  describe "get_phase/1" do
    test "returns genesis with 1 citizen" do
      # Test implementation
    end
    
    test "returns city with 21 citizens" do
      # Test implementation
    end
  end
end
```

**Test Coverage Target:** 90%+ for core modules

## Dependencies

Add to `mix.exs`:
```elixir
defp deps do
  [
    # BSV SDK
    {:bsv_sdk, "~> 1.1"},
    
    # H3 hex grid
    {:h3, "~> 3.7"},
    
    # MessagePack encoding
    {:msgpax, "~> 2.3"},
    
    # HTTP client for ARC
    {:req, "~> 0.4"},
    
    # Testing
    {:exvcr, "~> 0.13", only: :test},
    {:mox, "~> 1.0", only: :test}
  ]
end
```

## BSV Skill Reference

Full BSV technical reference available at:
`/root/.openclaw/workspace/skills/bsv/SKILL.md`

Key sections:
- `bsv_sdk` usage (Elixir)
- CLTV script patterns
- ARC broadcasting
- BEEF format
- MessagePack encoding

## Success Criteria

Before declaring Phase 1 complete, verify:

- [ ] All 8 core modules implemented
- [ ] All schemas defined with typespecs
- [ ] Test coverage > 90% for core logic
- [ ] All specs 00-04 requirements implemented
- [ ] Can found a city end-to-end (transaction builds correctly)
- [ ] Can claim territory with CLTV locking
- [ ] Fibonacci calculations correct per spec
- [ ] UBI calculation formula correct
- [ ] OP_RETURN encoding matches spec 07
- [ ] Documentation (moduledoc) for all public functions

## Communication

Progress updates should include:
1. Modules completed
2. Tests passing count
3. Blockers or questions
4. Next module in queue

## Files to Reference

Keep these open while working:
- `specs/02-city-lifecycle.md` - Phase progression, Fibonacci unlock
- `specs/03-staking-economics.md` - Lock-to-mint, UBI formulas
- `specs/07-transaction-formats.md` - Transaction schemas
- `skills/bsv/SKILL.md` - BSV technical implementation

## Questions?

If anything in the spec is unclear:
1. Check the specific spec file first
2. If still unclear, ask for clarification with specific quote
3. Don't guess—specs are the source of truth

---

**Start with:** Project setup → Schemas → Fibonacci module (simplest)

**Good luck!**
