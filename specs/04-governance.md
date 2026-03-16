# 04 - Governance

**Version:** 1.0  
**Status:** Draft

---

## Overview

Locus governance evolves through two distinct eras:

1. **Genesis Era (Years 0-10):** Centralized control via /256 Genesis Key
2. **Federal Era (Year 10+):** Decentralized governance via Federal Council of Cities

This progressive decentralization is **hardcoded and irreversible**. The founding team cannot extend centralized control past Year 10.

---

## Timeline Summary

```
Year 0                    Year 5                    Year 10
  │                         │                         │
  ▼                         ▼                         ▼
Genesis ────────────────────────────────────────► Federal
  │                                               Council
  │                         │                         │
  │                    /256 Key                      │
  │                   Still Active                   │
  │                         │                    Auto-Expires
  │                         │                         │
  │                    Cities grow                     │
  │                   Learn to govern                  │
  │                         │                         │
  ▼                         ▼                         ▼
Speed ►────────────────────────► Legitimacy
```

---

## Genesis Era (Years 0-10)

### /256 Genesis Key

The Genesis Key is a **single private key** that controls protocol-level changes during the early years.

**Powers:**
- Upgrade protocol smart contracts
- Adjust fee parameters (within bounds)
- Emergency interventions
- Allocate protocol treasury funds

**Boundaries:**
- Cannot confiscate user stakes
- Cannot change token supplies
- Cannot bypass lock periods
- Cannot extend past Block 2,100,000

### Why Centralized Start?

**Speed:**
- Rapid iteration on protocol design
- Quick bug fixes
- Feature development

**Learning:**
- Observe how cities form organically
- Understand attack vectors
- Refine economic models

**Bootstrapping:**
- Initial liquidity provision
- First cities need support
- Developer tooling

### Limitations

Even during Genesis Era, the key **cannot**:
- Take user funds
- Change staking amounts arbitrarily
- Bypass the 5-month lock period
- Prevent cities from operating autonomously

---

## Federal Era (Year 10+)

### Automatic Transition

At **Block 2,100,000** (approximately Year 10):

1. /256 Genesis key becomes unusable (CLTV expires)
2. Federal Council activates automatically
3. Protocol enters permanent decentralized state
4. No human can reverse this

### Federal Council of Cities

**Composition:**
- All cities with >10 active citizens
- Weighted voting based on activity and treasury size
- Minimum 3 cities required for quorum

**Voting Weights:**
```
Weight = sqrt(Citizen_Count × Treasury_BSV)

Example:
  City A: 50 citizens, 1000 BSV treasury
  Weight = sqrt(50 × 1000) = sqrt(50000) = 223.6
  
  City B: 20 citizens, 500 BSV treasury  
  Weight = sqrt(20 × 500) = sqrt(10000) = 100
```

Square root prevents largest cities from dominating.

### Council Powers

**Can Do:**
- Upgrade protocol contracts (with 66% vote)
- Adjust fee parameters (with 51% vote)
- Allocate protocol treasury (with 51% vote)
- Add/remove council members (with 75% vote)

**Cannot Do:**
- Confiscate user stakes (impossible by design)
- Change lock periods (hardcoded)
- Create new tokens (impossible by design)
- Override city governance (cities are sovereign)

### Proposal Process

1. **Submission:** Any council member submits proposal
2. **Discussion:** 7-day discussion period
3. **Voting:** 14-day voting window
4. **Execution:** Automatic if threshold reached
5. **Timelock:** 3-day delay before execution (emergency除外)

---

## Cathedral Guardian

### Purpose

Emergency fallback if Federal Council deadlocks or is captured.

### Structure

- **7-of-12 multi-signature wallet**
- 12 trusted protocol developers/ researchers
- Geographic and ideological diversity
- Anonymous if desired

### Powers

**Can Do:**
- Break governance deadlocks (with 7/12)
- Extend decentralization (add more cities)
- Emergency protocol pause (7/12, max 30 days)
- Veto malicious council proposals (7/12)

**Cannot Do:**
- Restore /256 Genesis key
- Reduce decentralization
- Confiscate funds
- Change core protocol rules unilaterally

### Constraints

1. **Transparency:** All actions public
2. **Time limits:** Emergency powers expire if not used
3. **Rotation:** Members rotate every 2 years
4. **Dissolution:** Can vote to dissolve itself (requires 12/12)

---

## City-Level Governance

Each city evolves its own governance as it grows (see [02-city-lifecycle.md](02-city-lifecycle.md)):

| Phase | Governance | Decision Makers |
|-------|------------|-----------------|
| 0-1 | Founder | 1 person |
| 2 | Tribal Council | Founder + 2 elected |
| 3 | Republic | Mayor + 5 council |
| 4 | Direct Democracy | All citizens vote |
| 5 | Senate | Elected representatives |

### City Governance Powers

**Sovereign Powers** (cities decide independently):
- Local policies and regulations
- Block auction parameters
- Building codes
- UBI amount (within protocol bounds)
- Immigration policy

**Non-Sovereign Powers** (protocol determines):
- Stake amounts
- Lock periods
- Fee splits
- Token supplies

### City Governance Attacks

**Mayor Capture:**
- Mitigation: Term limits, recall elections

**Low Voter Turnout:**
- Mitigation: Liquid democracy (delegate votes)

**Whale Dominance:**
- Mitigation: Quadratic voting (optional)

---

## Proposal Types

### Protocol-Level Proposals (Federal Council)

| Type | Threshold | Description |
|------|-----------|-------------|
| Parameter Change | 51% | Adjust fee percentages, lock times |
| Contract Upgrade | 66% | Deploy new protocol contracts |
| Treasury Spend | 51% | Allocate protocol treasury funds |
| Constitutional | 75% | Change core governance rules |
| Emergency | 7/12 Guardian | Pause protocol, veto malicious |

### City-Level Proposals

| Type | Phase | Threshold | Description |
|------|-------|-----------|-------------|
| Policy | 2+ | 51% | Change local policies |
| Expenditure | 3+ | 51% | Spend city treasury |
| Constitutional | 4+ | 66% | Change city charter |
| Recall | 3+ | 60% | Remove elected official |

---

## Voting Mechanisms

### Direct Voting

One token = one vote.

```
Vote Power = Token_Balance
```

### Liquid Democracy

Citizens can delegate votes to representatives:

```
If citizen delegates:
  Representative_Vote_Power += Citizen_Token_Balance
  Citizen retains right to override on specific votes
```

Delegation is:
- Revocable at any time
- Specific to proposal types (optional)
- Transparent (public delegations)

### Quadratic Voting (Optional)

For high-stakes decisions:

```
Cost = Votes²

Example:
  1 vote = 1 token
  2 votes = 4 tokens
  3 votes = 9 tokens
  10 votes = 100 tokens
```

Prevents whale dominance but requires more tokens for strong preferences.

---

## Governance Attacks and Defenses

### Attack: 51% Takeover

**Scenario:** Single entity acquires 51% of city tokens.

**Defense:**
- Quadratic voting makes this expensive
- Federal Council overrides malicious cities
- Token redemption allows exit
- Reputation loss

### Attack: Low Voter Participation

**Scenario:** <10% of token holders vote.

**Defense:**
- Liquid democracy (delegation increases participation)
- Dynamic quorum (adjusts based on turnout history)
- Default "abstain" doesn't block proposals

### Attack: Governance Bloat

**Scenario:** Too many proposals, decision fatigue.

**Defense:**
- Proposal fees (small BSV cost to submit)
- Discussion periods prevent spam
- Priority queue (stake-weighted)

### Attack: Flash Loan Voting

**Scenario:** Borrow tokens, vote, return tokens.

**Defense:**
- Voting power snapshot at proposal start
- Token lock during voting period
- Flash loans impossible (no lending protocol)

### Attack: Bribery

**Scenario:** Pay voters to vote specific way.

**Defense:**
- Secret ballots (cryptographic)
- Vote commitment scheme (reveal after deadline)
- Social slashing for proven bribery

---

## Governance Parameters

### Protocol-Level (Federal Council Sets)

| Parameter | Genesis Default | Range | Description |
|-----------|-----------------|-------|-------------|
| `fee_developer` | 50% | 40-60% | Developer fee share |
| `fee_territory` | 40% | 30-50% | Territory fee share |
| `fee_protocol` | 10% | 5-15% | Protocol fee share |
| `ubi_rate` | 0.1% | 0.05-0.2% | Daily UBI as % of treasury |
| `heartbeat_expiry` | 6 months | 3-12 months | Heartbeat validity period |
| `proposal_deposit` | 0.1 BSV | 0.01-1 BSV | Cost to submit proposal |

### City-Level (City Governance Sets)

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `block_auction_period` | 7 days | 1-30 days | Auction duration |
| `block_starting_bid` | 1 BSV | 0.1-10 BSV | Minimum bid |
| `immigration_policy` | "open" | enum | Who can join |
| `building_code` | "permissive" | enum | Construction rules |

---

## Governance Transparency

### On-Chain Records

All governance actions recorded on BSV blockchain:

- Proposal submissions (OP_RETURN)
- Votes (signed transactions)
- Executions (transaction results)
- Treasury flows (traceable)

### Off-Chain Tools

- Governance explorers (UI for proposals)
- Notification services (new proposals, votes)
- Delegation interfaces (liquid democracy)
- Analytics (participation rates, voting patterns)

---

## Transition Planning

### Year 8-9: Preparation

- Cities practice self-governance
- Federal Council mechanics tested
- Guardian members selected
- Documentation finalized

### Year 10: Handover

```
Block 2,099,900: Final Genesis Key actions
Block 2,100,000: Genesis Key expires
Block 2,100,001: Federal Council activates
Block 2,100,100: First council vote
```

### Post-Transition

- Genesis team becomes "Protocol Fellows"
- No special powers
- Can submit proposals like anyone else
- Cathedral Guardian stands ready

---

## Comparison to Other Governance Models

| Model | Locus | DAOs | Nation-States | Corporations |
|-------|-------|------|---------------|--------------|
| **Centralized start** | Yes (temp) | Rare | N/A | Yes (permanent) |
| **Decentralized end** | Yes (forced) | Varies | Partial | Rare |
| **Token voting** | Yes | Yes | No | Shareholder |
| **Territorial** | Yes | No | Yes | No |
| **Liquid democracy** | Yes | Rare | No | No |
| **Sunset clause** | Yes | Rare | No | No |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-17 | Initial governance specification |
