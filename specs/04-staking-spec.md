# Staking Specification

Staking provides economic security for the Locus Protocol. By locking BSV, ghost operators prove commitment and align incentives with protocol health.

## Design Principles

1. **Skin in the game** — Operators must risk capital to deploy ghosts
2. **Time preference** — Longer locks signal stronger commitment
3. **Slashing deterrent** — Misbehavior results in economic loss
4. **Permissionless** — Anyone can stake, no approval required

## Staking Tiers

### Minimum Requirements by Ghost Type

| Ghost Type | Minimum Stake | Lock Period | Max Timeout | Use Case |
|------------|---------------|-------------|-------------|----------|
| **GREETER** | 1M sats (0.01 BSV) | 5 months | 5 sec | Simple welcome messages |
| **ORACLE** | 10M sats (0.1 BSV) | 5 months | 30 sec | Data queries, prices |
| **GUARDIAN** | 50M sats (0.5 BSV) | 5 months | 60 sec | Security monitoring |
| **MERCHANT** | 10M sats (0.1 BSV) | 5 months | 30 sec | Commerce, escrow |
| **CUSTOM** | 100M sats (1 BSV) | 5-12 months | Negotiable | Specialized services |

### Time Calculations

```
Blocks per day: 144 (10-minute block time)
5 months: 144 × 30 × 5 = 21,600 blocks
12 months: 144 × 365 = 52,560 blocks
```

## Staking Transaction

### Locking Script (P2SH)

```bitcoin-script
# Lock script (redeemScript)
<lock_height>           # Block height when unlockable
OP_CHECKLOCKTIMEVERIFY  # Fail if nSequence < lock_height
OP_DROP                 # Drop lock_height from stack
<owner_pubkey>          # Owner's public key
OP_CHECKSIG             # Verify signature

# Script hash = HASH160(redeemScript)
# P2SH address = base58check(0x05 || script_hash)
```

### Example Lock Script Assembly

```
# Lock at block 850,000
# Owner pubkey: 03a1b2c3...

21430f                    # 850000 (lock height) as 3-byte little-endian
b1                        # OP_CHECKLOCKTIMEVERIFY
75                        # OP_DROP
2103a1b2c3d4e5f6...      # 33-byte compressed pubkey
ac                        # OP_CHECKSIG

# Total: 39 bytes
```

### Unlocking Transaction

After `lock_height` is reached, owner can spend:

```
Input:
  scriptSig: <signature> <redeemScript>
  sequence:  <lock_height> (enforced by CLTV)

Output:
  <owner_address>: <amount - fee>
```

## Protocol Staking Flow

### Registration

```
1. User creates ghost registration transaction
2. Includes P2SH stake output with CLTV
3. OP_RETURN includes stake metadata
4. Broadcast to network
5. Ghost enters PENDING state
```

### Validation

```python
def validate_stake(tx, ghost_payload):
    """Verify stake meets protocol requirements."""
    
    # Find stake output
    stake_output = find_p2sh_output(tx)
    if not stake_output:
        return False, "No P2SH output found"
    
    # Decode redeem script
    script = decode_redeem_script(stake_output)
    lock_height = parse_cltv_height(script)
    owner_pubkey = parse_pubkey(script)
    
    # Verify owner matches
    if owner_pubkey != ghost_payload['owner_pk']:
        return False, "Stake owner doesn't match ghost owner"
    
    # Verify lock period
    min_blocks = GHOST_TYPE_LOCKS[ghost_payload['ghost_type']]
    current_height = get_current_height()
    if lock_height < current_height + min_blocks:
        return False, f"Lock period too short, need {min_blocks} blocks"
    
    # Verify amount
    if stake_output['value'] < GHOST_TYPE_MINIMUMS[ghost_payload['ghost_type']]:
        return False, "Stake amount below minimum"
    
    return True, "Valid stake"
```

## Economic Parameters

### Base Amounts (subject to market adjustment)

```python
STAKING_TIERS = {
    'GREETER': {
        'min_sats': 1_000_000,      # 0.01 BSV
        'min_blocks': 21_600,        # ~5 months
        'slash_rate': 0.10           # 10% on minor violation
    },
    'ORACLE': {
        'min_sats': 10_000_000,     # 0.1 BSV
        'min_blocks': 21_600,
        'slash_rate': 0.25           # 25% on violation
    },
    'GUARDIAN': {
        'min_sats': 50_000_000,     # 0.5 BSV
        'min_blocks': 21_600,
        'slash_rate': 0.50           # 50% on violation
    },
    'MERCHANT': {
        'min_sats': 10_000_000,     # 0.1 BSV
        'min_blocks': 21_600,
        'slash_rate': 0.25
    },
    'CUSTOM': {
        'min_sats': 100_000_000,    # 1 BSV
        'min_blocks': 21_600,        # Minimum
        'max_blocks': 52_560,        # Maximum (~1 year)
        'slash_rate': 0.50
    }
}
```

### Fee Market Dynamics

Higher stakes may correlate with:
- Higher ghost fees (market positioning)
- Better placement in discovery
- Enhanced reputation

But stake amount does NOT affect:
- Protocol priority
- Challenge thresholds
- Heartbeat requirements

## Slashing Conditions

### Partial Slash (Warning → 10-25% burn)

Triggered by:
- First NO_SHOW challenge upheld
- Repeated slow responses (> timeout)
- MALFUNCTION with minor impact

### Full Slash (50-100% burn)

Triggered by:
- LOCATION_FRAUD proven
- FEE_EVASION detected
- Multiple upheld challenges
- Critical security violations

### Slash Execution

```python
def execute_slash(ghost, challenge, severity):
    """Burn portion of staked funds."""
    stake_output = find_stake_output(ghost.stake.stake_txid)
    total_sats = stake_output['value']
    
    if severity == 'PARTIAL':
        slash_amount = int(total_sats * ghost.stake.slash_rate)
    else:  # FULL
        slash_amount = total_sats
    
    # Create burn transaction
    burn_tx = create_transaction(
        inputs=[stake_output],
        outputs=[
            # OP_RETURN burn (provably unspendable)
            {'script': 'OP_RETURN <slash_proof>', 'value': 0},
            # Return remaining to owner (if partial)
            {'address': ghost.owner.address, 'value': total_sats - slash_amount - fee}
        ]
    )
    
    broadcast(burn_tx)
```

## Stake Management

### Increasing Stake

Operators can increase stake by:
1. Creating new stake output
2. Broadcasting STAKE_UPDATE transaction
3. Ghost benefits from higher stake (reputation)

```python
# New transaction adds to existing stake
def increase_stake(ghost, additional_sats):
    new_stake_tx = create_stake_transaction(
        amount=additional_sats,
        lock_height=max(ghost.stake.locked_until, new_height),
        owner=ghost.owner.pubkey
    )
    
    # Update ghost record
    ghost.stake.amount_sats += additional_sats
    ghost.stake.locked_until = new_stake_tx.lock_height
```

### Early Exit (Not Allowed)

Stakes CANNOT be withdrawn early. This is enforced by Bitcoin's CLTV, not protocol rules.

**Rationale:**
- Prevents hit-and-run attacks
- Ensures long-term commitment
- Aligns with ghost lifecycle

### Stake Expiration

When lock period ends:
1. Owner can broadcast withdrawal tx
2. No protocol action required
3. Ghost can continue operating with new stake
4. Or retire if no new stake provided

## Multi-Stake Support

Advanced operators can maintain multiple stakes:

```
Stake 1: 10M sats, locked until block 850,000
Stake 2: 5M sats, locked until block 860,000
Stake 3: 5M sats, locked until block 870,000
```

Benefits:
- Rolling lock periods (never all unlocked at once)
- Increased total stake (reputation)
- Flexibility to adjust over time

Protocol treats them as single combined stake for minimums.

## Staking Calculator

```python
class StakingCalculator:
    """Helper for calculating stake parameters."""
    
    def __init__(self, current_block):
        self.current_block = current_block
    
    def calculate_unlock(self, lock_months):
        """Calculate unlock block from months."""
        blocks = lock_months * 30 * 144  # 144 blocks/day
        return self.current_block + blocks
    
    def estimate_apr(self, ghost_type, monthly_fees):
        """Estimate annual return from fees."""
        min_stake = STAKING_TIERS[ghost_type]['min_sats']
        annual_fees = monthly_fees * 12
        return (annual_fees / min_stake) * 100
    
    def optimal_lock(self, ghost_type, market_conditions):
        """Recommend lock period based on market."""
        # Shorter locks in volatile markets
        # Longer locks for stability
        pass
```

## Security Considerations

### Cold Storage

Recommendations:
- Use hardware wallets for stake keys
- Separate hot keys for heartbeats/operations
- Multisig for high-value stakes (2-of-3)

### Key Rotation

Stake keys CANNOT be changed without:
1. Withdrawing old stake (after lock)
2. Creating new registration
3. Migrating ghost state (if protocol allows)

**Important:** Lost keys = lost stake after unlock

### 51% Attack Protection

Staking makes Sybil attacks expensive:
- Each ghost requires real BSV
- Slashing punishes misbehavior
- No benefit from ghost count alone

## Test Cases

### Valid Stakes

```python
test_cases = [
    {
        'name': 'Minimum GREETER stake',
        'type': 'GREETER',
        'amount': 1_000_000,
        'lock_months': 5,
        'valid': True
    },
    {
        'name': 'Large GUARDIAN stake',
        'type': 'GUARDIAN', 
        'amount': 100_000_000,
        'lock_months': 12,
        'valid': True
    },
    {
        'name': 'CUSTOM 1-year lock',
        'type': 'CUSTOM',
        'amount': 500_000_000,
        'lock_months': 12,
        'valid': True
    }
]
```

### Invalid Stakes

```python
invalid_cases = [
    {
        'name': 'Insufficient GREETER stake',
        'type': 'GREETER',
        'amount': 500_000,  # Below minimum
        'lock_months': 5,
        'valid': False,
        'error': 'Below minimum stake'
    },
    {
        'name': 'Short lock period',
        'type': 'ORACLE',
        'amount': 10_000_000,
        'lock_months': 2,  # Below minimum
        'valid': False,
        'error': 'Lock period too short'
    },
    {
        'name': 'Mismatched owner',
        'type': 'GUARDIAN',
        'amount': 50_000_000,
        'lock_months': 5,
        'owner_mismatch': True,
        'valid': False,
        'error': 'Owner mismatch'
    }
]
```
