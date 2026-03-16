# Challenge System

The Challenge System provides decentralized dispute resolution for the Locus Protocol. Anyone can challenge ghost misbehavior, with economic incentives ensuring honest participation.

## Design Principles

1. **Permissionless** — Anyone can file a challenge
2. **Economic deterrence** — Challengers must stake to prevent spam
3. **Time-bound** — Fixed windows for responses and resolution
4. **Transparent** — All evidence on-chain, verifiable by all
5. **Proportional** — Penalties match violation severity

## Challenge Types

### NO_SHOW (Type 1)

**Description:** Ghost didn't respond to paid invocation within timeout.

**Evidence Required:**
- Invocation transaction (proves payment)
- Timeout proof (current time > invocation time + timeout)
- Optional: Retry attempts

**Severity:** LOW → MEDIUM
- First offense: Warning
- Repeat offenses: Slashing

### MALFUNCTION (Type 2)

**Description:** Ghost responded with invalid, corrupted, or malicious data.

**Evidence Required:**
- Invocation transaction
- Ghost's response (if any)
- Proof of invalidity (schema violation, wrong data, etc.)
- Optional: Expected correct response

**Severity:** MEDIUM
- Always results in penalty
- Severity based on impact

### LOCATION_FRAUD (Type 3)

**Description:** Ghost is not at claimed location.

**Evidence Required:**
- Ghost's claimed location (from registry)
- Contradictory heartbeat location
- GPS proof from challenger
- Optional: Photo/video evidence (IPFS hash)

**Severity:** HIGH
- Immediate slashing
- Full stake burn on proof

### FEE_EVASION (Type 4)

**Description:** Ghost circumvented fee distribution.

**Evidence Required:**
- Analysis of ghost's receiving addresses
- Comparison with declared fees
- Transaction graph showing hidden revenue

**Severity:** HIGH
- Immediate slashing
- Full stake burn

## Challenge Lifecycle

### 1. Filing

```
Challenger:
1. Gathers evidence
2. Stakes 10,000 sats minimum
3. Broadcasts CHALLENGE transaction
4. Pays transaction fee
```

**Challenge Transaction:**
```
Input: Challenger's UTXO (includes stake)
Output 1: P2SH (challenge stake locked)
  Script: <challenge_id> OP_DROP <resolution_pubkey> OP_CHECKSIG
Output 2: OP_RETURN challenge data
Output 3: Change to challenger
```

### 2. Notification

Upon challenge detection:
1. Ghost marked as DISPUTED
2. New invocations paused
3. Owner notified (via optional webhook)
4. Response window starts (72 hours)

### 3. Response

```
Ghost Owner:
1. Reviews challenge evidence
2. Gathers counter-evidence
3. Broadcasts CHALLENGE_RESPONSE
4. Within 72-hour window
```

**Response Transaction:**
```
Input: Owner's UTXO
Output 1: OP_RETURN response data
Output 2: Change (optional)
```

### 4. Resolution

```
Validators (any node):
1. Review challenge + response
2. Apply protocol rules
3. Broadcast RESOLUTION transaction
4. Distribute stakes accordingly
```

**Resolution Transaction:**
```
Input: Challenge P2SH (unlocked by resolution multisig)
Output 1: Challenger (if upheld) or Burn (if rejected)
Output 2: Protocol treasury (resolution fee)
Output 3: OP_RETURN resolution result
```

## Economic Model

### Challenger Stake

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Minimum** | 10,000 sats | Prevents spam |
| **Returned** | If upheld | Rewards honest challengers |
| **Burned** | If rejected | Punishes frivolous challenges |
| **Profit** | None directly | Incentive is protocol health |

### Slashing Penalties

| Challenge Type | First Offense | Repeat | Severe |
|----------------|---------------|--------|--------|
| **NO_SHOW** | Warning | 25% slash | 50% slash |
| **MALFUNCTION** | 25% slash | 50% slash | 100% slash |
| **LOCATION_FRAUD** | 100% slash | — | — |
| **FEE_EVASION** | 100% slash | — | — |

### Penalty Distribution

```python
def distribute_penalty(ghost, severity):
    """Distribute slashed funds."""
    slashed_amount = calculate_slash(ghost, severity)
    
    if severity == 'FULL':
        # 50% to challenger
        challenger_reward = slashed_amount // 2
        # 50% to protocol
        protocol_share = slashed_amount - challenger_reward
        
        return {
            'challenger': challenger_reward,
            'protocol': protocol_share
        }
    else:
        # Partial slash: all to protocol
        return {
            'protocol': slashed_amount
        }
```

## Validation Rules

### Challenge Validity

```python
def validate_challenge(challenge_tx, ghost):
    """Check if challenge meets requirements."""
    
    # 1. Ghost exists and is active/disputed
    if ghost.state not in ['ACTIVE', 'INACTIVE', 'DISPUTED']:
        return False, "Ghost not challengeable"
    
    # 2. Challenger staked minimum
    if challenge_tx['stake'] < MIN_CHALLENGE_STAKE:
        return False, "Insufficient stake"
    
    # 3. Evidence references valid transaction
    if not tx_exists(challenge_tx['evidence_txid']):
        return False, "Evidence transaction not found"
    
    # 4. Not duplicate challenge
    if challenge_exists(challenge_tx['challenge_id']):
        return False, "Challenge already exists"
    
    # 5. Challenge type recognized
    if challenge_tx['challenge_type'] not in VALID_TYPES:
        return False, "Invalid challenge type"
    
    return True, "Valid challenge"
```

### Evidence Standards

| Challenge Type | Required Evidence | Optional Evidence |
|----------------|-------------------|-------------------|
| NO_SHOW | Invocation tx | Retry logs |
| MALFUNCTION | Invocation tx + Response | Schema validation |
| LOCATION_FRAUD | Contradictory heartbeat | GPS data, Photos |
| FEE_EVASION | Transaction analysis | Graph proof |

### Resolution Criteria

```python
def resolve_challenge(challenge, response, ghost):
    """Determine challenge outcome."""
    
    if challenge.type == 'NO_SHOW':
        # Check if invocation timed out
        if proof_timeout(challenge.evidence):
            return 'UPHELD'
        if response and proof_response_delivered(response):
            return 'REJECTED'
    
    elif challenge.type == 'MALFUNCTION':
        # Check if response was invalid
        if proof_invalid_response(challenge.evidence):
            return 'UPHELD'
        if response and proof_valid_response(response):
            return 'REJECTED'
    
    elif challenge.type == 'LOCATION_FRAUD':
        # Check location discrepancy
        if proof_location_fraud(challenge.evidence):
            return 'UPHELD'
        if response and proof_location_valid(response):
            return 'REJECTED'
    
    elif challenge.type == 'FEE_EVASION':
        # Check fee distribution
        if proof_fee_evasion(challenge.evidence):
            return 'UPHELD'
        if response and proof_fees_paid(response):
            return 'REJECTED'
    
    # Default: insufficient evidence
    return 'REJECTED'
```

## Time Windows

```
T+0:    Challenge filed
        ↓
T+0 to T+72h:  Response window
               Ghost owner can respond
               ↓
T+72h:  Response window closes
        ↓
T+72h to T+168h:  Resolution window
                  Validators evaluate
                  ↓
T+168h:  Resolution deadline
         Auto-resolve if no validator action
```

### Auto-Resolution

If no validator resolves by deadline:

```python
def auto_resolve(challenge, ghost):
    """Default resolution if validators don't act."""
    
    if challenge.type in ['LOCATION_FRAUD', 'FEE_EVASION']:
        # High severity: favor challenger
        return 'UPHELD'
    else:
        # Lower severity: favor ghost
        return 'REJECTED'
```

## Validator Incentives

### Who Can Validate

Any node can resolve challenges:
- No registration required
- No minimum stake
- Economic incentive: resolution fee

### Resolution Fee

```python
RESOLUTION_FEE = 1000  # sats

# Deducted from challenger stake (either returned or burned)
# Paid to validator who broadcasts resolution
```

### Validator Selection

First valid resolution transaction wins:
- Race to broadcast
- Prevents spam (only first gets fee)
- Encourages monitoring

## Challenge State Machine

```
[PENDING] ──> Filed, awaiting response ──> [RESPONDED]
    │                              │
    │ (72h timeout)                │ (168h timeout)
    ▼                              ▼
[EXPIRED]                    [RESOLVED]
    │ UPHELD / REJECTED / EXPIRED
    ▼
[EXECUTED]
    Stakes distributed
    Ghost state updated
```

## Integration with Ghost State

### DISPUTED Status

```python
def apply_challenge(ghost, challenge):
    """Update ghost state when challenged."""
    
    ghost.challenges_active.append(challenge)
    
    # Pause new invocations
    if ghost.state == 'ACTIVE':
        ghost.state = 'DISPUTED'
    
    # Track challenge metrics
    ghost.challenges_filed += 1
```

### Post-Resolution

```python
def apply_resolution(ghost, challenge, outcome):
    """Update ghost after challenge resolved."""
    
    ghost.challenges_active.remove(challenge)
    
    if outcome == 'UPHELD':
        ghost.challenges_upheld += 1
        
        # Apply penalty
        if challenge.type in ['LOCATION_FRAUD', 'FEE_EVASION']:
            ghost.state = 'SLASHED'
            execute_slash(ghost, 'FULL')
        else:
            execute_slash(ghost, 'PARTIAL')
            ghost.state = 'ACTIVE'  # Can resume
            
    else:  # REJECTED
        ghost.challenges_rejected += 1
        
        # Resume if no other active challenges
        if not ghost.challenges_active:
            ghost.state = 'ACTIVE'
```

## Privacy Considerations

### Public Nature

All challenges are public:
- Evidence on blockchain
- Anyone can view
- Permanent record

### Sensitive Evidence

For privacy-sensitive data:

```python
# Store hash on-chain, data off-chain
evidence = {
    'data_hash': sha256(sensitive_data),
    'data_uri': 'ipfs://Qm...',  # Encrypted
    'encryption_pubkey': challenger_pubkey
}

# Reveal only during resolution if needed
```

## Testing Challenge Flow

```python
def test_no_show_challenge():
    """End-to-end NO_SHOW challenge."""
    
    # Setup
    ghost = create_active_ghost()
    user = create_user()
    
    # User invokes ghost
    invocation = invoke_ghost(user, ghost, fee=1000)
    
    # Wait for timeout
    time.sleep(invocation.timeout + 1)
    
    # User files challenge
    challenge = file_challenge(
        challenger=user,
        ghost=ghost,
        type='NO_SHOW',
        evidence=invocation.txid,
        stake=10000
    )
    
    assert ghost.state == 'DISPUTED'
    
    # Ghost doesn't respond (no defense)
    time.sleep(72 * 3600)
    
    # Validator resolves
    resolution = resolve_challenge(challenge, None, ghost)
    assert resolution == 'UPHELD'
    
    # Check outcome
    assert ghost.state == 'ACTIVE'  # First offense = warning
    assert ghost.warnings == 1
```

## Attack Scenarios

### Challenge Spam

**Attack:** File frivolous challenges to harass ghost operators.

**Defense:**
- 10,000 sat stake burned on rejection
- Validator fees paid by loser
- Rate limiting per challenger address

### Ghost Ignore

**Attack:** Ghost operator ignores all challenges.

**Defense:**
- Auto-upheld after response window
- Reputation damage
- Escalating penalties

### Validator Collusion

**Attack:** Validators consistently rule for friends.

**Defense:**
- Public evidence requirement
- Anyone can validate (no cabal)
- Appeals process (v2)

## Future Enhancements

### v2: Appeals

Losing party can appeal within 7 days:
- Higher stake required
- Panel of 3 validators
- Binding decision

### v2: Insurance

Users can buy challenge insurance:
- Small premium on each invocation
- Automated challenge filing on failure
- Guaranteed refund

### v2: Reputation System

Track validator accuracy:
- Score based on upheld vs rejected ratio
- High-score validators earn more fees
- Sybil-resistant (based on historical performance)
