# Fee Distribution

The Locus Protocol's economic model ensures sustainable incentives for all participants through a transparent, automated fee distribution system.

## The 70/20/10 Model

Every invocation fee is split three ways:

| Recipient | Share | Role | Motivation |
|-----------|-------|------|------------|
| **Developer** | 70% | Creates ghost code | Build quality ghosts |
| **Executor** | 20% | Runs ghost node | Provide reliable infrastructure |
| **Protocol** | 10% | Maintains ecosystem | Fund development, grants, insurance |

## Rationale

### Developer Majority (70%)

- Ghosts are intellectual property
- Quality code requires ongoing development
- Incentivizes innovation and features
- Aligns creator with ghost success

### Executor Incentive (20%)

- Running nodes has real costs (hardware, bandwidth)
- Must be profitable to sustain network
- Performance quality affects earnings
- Competition drives reliability

### Protocol Sustainability (10%)

- Core team development funding
- Security audits and bug bounties
- Grants for ecosystem growth
- Insurance pool for user protection

## Fee Calculation

### Base Fees by Type

| Ghost Type | Minimum Fee | Typical Range | Rationale |
|------------|-------------|---------------|-----------|
| **GREETER** | 100 sats | 100-500 sats | Simple, high volume |
| **ORACLE** | 1,000 sats | 1K-10K sats | Data processing, API costs |
| **GUARDIAN** | 5,000 sats | 5K-50K sats | Security critical, low volume |
| **MERCHANT** | 500 sats | 500-5K sats | Commerce facilitation |
| **CUSTOM** | Negotiable | Variable | Specialized services |

### Dynamic Pricing

Ghosts can implement:

```python
# Time-based pricing
if peak_hours():
    fee = base_fee * 2
else:
    fee = base_fee

# Load-based pricing
if queue_depth > 10:
    fee = base_fee * (1 + queue_depth * 0.1)

# Complexity-based pricing
fee = base_fee + (compute_units * unit_price)
```

### Distribution Formula

```python
def distribute_fee(total_fee_sats):
    """Calculate exact distribution amounts."""
    
    # Developer: 70% (rounded down)
    dev_amount = (total_fee_sats * 70) // 100
    
    # Executor: 20% (rounded down)
    exec_amount = (total_fee_sats * 20) // 100
    
    # Protocol: Remainder (handles rounding)
    protocol_amount = total_fee_sats - dev_amount - exec_amount
    
    # Verify
    assert dev_amount + exec_amount + protocol_amount == total_fee_sats
    
    return {
        'developer': dev_amount,
        'executor': exec_amount,
        'protocol': protocol_amount
    }

# Example: 1,000 sat fee
distribute_fee(1000)
# => {'developer': 700, 'executor': 200, 'protocol': 100}

# Example: 100 sat fee
distribute_fee(100)
# => {'developer': 70, 'executor': 20, 'protocol': 10}
```

## Transaction Structure

### Invocation Transaction Outputs

```
Input: User's UTXO(s)

Output 1: P2PKH (Developer)
  Value: 70% of fee
  Address: ghost.developer_address

Output 2: P2PKH (Executor)
  Value: 20% of fee
  Address: ghost.executor_address (or determined at runtime)

Output 3: P2PKH (Protocol)
  Value: 10% of fee (remainder)
  Address: PROTOCOL_TREASURY_ADDRESS

Output 4: OP_RETURN
  Protocol metadata

Output 5: P2PKH (Change)
  Value: Input sum - fee - miner_fee
  Address: user's change address
```

### Example Hex

```
# Invocation with 5,000 sat fee
# Developer: 3,500 sats
# Executor: 1,000 sats  
# Protocol: 500 sats

Output 1: 76a914...88ac (3500 sats)
Output 2: 76a914...88ac (1000 sats)
Output 3: 76a914...88ac (500 sats)
Output 4: 6a056c6f637573000104...[payload]
Output 5: 76a914...88ac (change)
```

## Developer Address Assignment

### At Registration

```python
ghost.developer_address = registration_tx['developer_address']
```

The developer address is fixed at ghost creation and:
- Cannot be changed (ensures consistent payments)
- May differ from owner address (allows team structures)
- Receives all 70% shares for that ghost

### Multi-Developer Split

For teams, use external splitting:

```
Ghost Developer Address
        ↓
    [Splitting Contract]
        ↓
   ┌────┼────┐
   ↓    ↓    ↓
Dev1  Dev2  Dev3
```

## Executor Address Determination

### Static Assignment

Ghost specifies fixed executor:

```python
ghost.executor_address = "1ExecutorAddressHere"
```

Simple but creates centralization.

### Dynamic Discovery (Recommended)

Executor determined at invocation time:

1. **User selects executor** — From registry of available nodes
2. **Geographic proximity** — Closest node to minimize latency
3. **Reputation score** — Best performing node
4. **Load balancing** — Round-robin or least-loaded

```python
def select_executor(ghost, user_location):
    """Choose best executor for invocation."""
    candidates = find_executors_for_ghost(ghost.ghost_id)
    
    # Score by distance, load, reputation
    scored = [
        {
            'executor': ex,
            'score': (
                0.4 * (1 / haversine(user_location, ex.location)) +
                0.3 * (1 / ex.current_load) +
                0.3 * ex.reputation_score
            )
        }
        for ex in candidates
    ]
    
    return max(scored, key=lambda x: x['score'])['executor']
```

## Protocol Treasury

### Address Management

```python
PROTOCOL_TREASURY_MAINNET = "1LocusTreasuryAddressHere"
PROTOCOL_TREASURY_TESTNET = "mipcBbFg9gMiCh81Kj8tVcd1xQ8"
```

Treasury is a multisig address for security:
- 2-of-3 multisig
- Keys held by core team
- Spending requires consensus

### Treasury Usage

| Category | Allocation | Purpose |
|----------|------------|---------|
| **Development** | 50% | Core protocol development |
| **Grants** | 30% | Ecosystem grants |
| **Security** | 15% | Audits, bug bounties |
| **Reserve** | 5% | Emergency fund |

### Transparency

All treasury spending is:
- Published on-chain
- Documented in public proposals
- Subject to community review

## Timeout Protection

### User-Specified Timeout

```python
invocation = {
    'ghost_id': ghost_id,
    'timeout_seconds': 30,  # User sets this
    # ...
}
```

### Automatic Refund

If ghost doesn't respond within timeout:

```python
def process_timeout(invocation_tx):
    """Handle expired invocation."""
    if time.now() > invocation_tx['timestamp'] + invocation_tx['timeout']:
        # User can broadcast refund
        refund_tx = create_refund(invocation_tx)
        
        # Executor forfeits share
        # Developer keeps share (attempted work)
        # Protocol returns share
        
        return refund_tx
```

### Refund Transaction

```
Input: Original invocation inputs (with timeout proof)
Output 1: User refund (fee - miner_fee)
Output 2: OP_RETURN (timeout marker)
```

## Economic Attack Prevention

### Fee Flooding

**Attack:** Spam cheap invocations to drain ghost resources.

**Defenses:**
- Minimum fees (dust protection)
- Rate limiting per user
- Priority queue for higher fees

### Fee Evasion

**Attack:** Ghost circumvents fee distribution.

**Detection:**
- Monitor ghost's receiving addresses
- Compare declared vs actual fees
- Challenge system for reporting

**Penalty:**
- Immediate slashing on proof
- Full stake burn
- Ghost delisting

### Developer-Executor Collusion

**Attack:** Same party claims both 70% and 20% shares.

**Acceptance:** This is actually fine:
- Natural for solo operators
- Market competition prevents monopoly
- Users choose which ghosts to invoke

## Fee Market Dynamics

### Supply and Demand

```
Ghost Supply:
- Low barrier to entry (stake + code)
- Global competition
- No licensing required

User Demand:
- Quality service
- Low fees
- Fast response

Equilibrium:
- Quality ghosts command higher fees
- Efficient operators offer lower fees
- Market discovers fair prices
```

### Fee Estimation

```python
def estimate_fee(ghost_type, market_conditions):
    """Recommend fee for ghost registration."""
    base = BASE_FEES[ghost_type]
    
    # Adjust for network congestion
    if market_conditions['avg_block_size'] > 90%:
        multiplier = 1.5
    else:
        multiplier = 1.0
    
    # Adjust for ghost quality score
    quality_premium = ghost.quality_score / 1000
    
    return int(base * multiplier * (1 + quality_premium))
```

## Implementation Example

### Building Invocation Transaction

```javascript
const bsv = require('bsv');

async function buildInvocationTx(userKey, ghost, params, feeSats) {
    // Calculate distribution
    const devAmount = Math.floor(feeSats * 0.70);
    const execAmount = Math.floor(feeSats * 0.20);
    const protocolAmount = feeSats - devAmount - execAmount;
    
    // Select executor
    const executor = await selectExecutor(ghost, params.userLocation);
    
    // Build transaction
    const tx = new bsv.Transaction()
        .from(userUtxos)
        .to(ghost.developerAddress, devAmount)
        .to(executor.address, execAmount)
        .to(PROTOCOL_TREASURY, protocolAmount)
        .addSafeData(encodeInvocationPayload(ghost, params))
        .change(userKey.toAddress());
    
    return tx.sign(userKey);
}
```

## Testing Fee Distribution

```python
def test_fee_distribution():
    """Verify correct split for various amounts."""
    test_cases = [
        (100, {'dev': 70, 'exec': 20, 'protocol': 10}),
        (1000, {'dev': 700, 'exec': 200, 'protocol': 100}),
        (10000, {'dev': 7000, 'exec': 2000, 'protocol': 1000}),
        (12345, {'dev': 8641, 'exec': 2469, 'protocol': 1235}),
    ]
    
    for total, expected in test_cases:
        result = distribute_fee(total)
        assert result['developer'] == expected['dev']
        assert result['executor'] == expected['exec']
        assert result['protocol'] == expected['protocol']
        assert sum(result.values()) == total
```
