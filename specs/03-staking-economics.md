# 03 - Staking Economics

**Version:** 1.0  
**Status:** Draft

---

## Overview

Locus uses a **Lock-to-Mint** economic model. Unlike traditional proof-of-stake systems that burn tokens or distribute inflationary rewards, Locus participants lock BSV for a fixed period, receive it back in full, and earn yield from activity on their territory.

The "cost" of participation is **opportunity cost**—the returns you could have earned elsewhere with that capital during the lock period.

---

## Core Principle: Lock-to-Mint

### How It Works

1. **Stake BSV** to claim territory at any level (/32, /8, /4, /1)
2. **Lock period:** Exactly 21,600 blocks (~5 months at 10-minute block times)
3. **CLTV enforcement:** Bitcoin script `OP_CHECKLOCKTIMEVERIFY` ensures immutability
4. **Full return:** After lock expires, you reclaim 100% of your stake
5. **Yield:** Earn fees from activity on your territory during the lock period

### Why Lock-to-Mint?

| Model | Description | Problem |
|-------|-------------|---------|
| **Burn** (Ethereum gas) | Value destroyed permanently | Extractive, deflationary pressure |
| **Stake-for-yield** (PoS) | Inflation pays stakers | Dilutes non-stakers, infinite supply |
| **Lock-to-mint** (Locus) | Time-lock only, full return | Opportunity cost only, capital preserved |

**Benefits:**
- No Ponzi dynamics (new money doesn't pay old)
- No token inflation
- Participants can exit with full principal
- Skin-in-the-game without destruction
- Aligns incentives: want territory to be productive

---

## Stake Requirements by Level

| Level | Type | Stake (BSV) | Lock Period | What You Get |
|-------|------|-------------|-------------|--------------|
| /32 | City | 32.0 | 21,600 blocks | City governance, 20% tokens (vested), treasury control |
| /16 | Block (private) | 8.0 | 21,600 blocks | Development rights, subdivision to buildings |
| /8 | Building | 8.0 | 21,600 blocks | 40% of object fees, commercial rights |
| /4 | Home | 4.0 | 21,600 blocks | Private residence, personal objects, Aura |
| /1 | Object (item) | 0.0001 | 21,600 blocks | Digital item ownership |
| /1 | Object (waypoint) | 0.5-4.0 | 21,600 blocks | Navigation marker |
| /1 | Object (agent/ghost) | 0.1-4.0 | 21,600 blocks | AI agent deployment |
| /1 | Object (billboard) | 10-100 | 21,600 blocks | Public advertisement |
| /1 | Object (rare) | 16 | 21,600 blocks | Limited edition item |
| /1 | Object (epic) | 32 | 21,600 blocks | Very limited item |
| /1 | Object (legendary) | 64 | 21,600 blocks | Ultra rare item |

**Note:** Public /16 blocks are auctioned by city treasury, not staked.

---

## CLTV Script Structure

### Lock Script (P2SH)

```bitcoin-script
# Locking Script (output)
OP_IF
    # Normal unlock after locktime
    <locktime_block> OP_CHECKLOCKTIMEVERIFY OP_DROP
    <owner_pubkey> OP_CHECKSIG
OP_ELSE
    # Emergency unlock (with penalty)
    <emergency_pubkey> OP_CHECKSIG
    <penalty_output_hash> OP_EQUALVERIFY
OP_ENDIF
```

**Locktime calculation:**
```elixir
locktime = current_block_height + 21_600  # ~5 months
```

### Unlock Transaction

After lock period expires:

```json
{
  "inputs": [{
    "txid": "...",
    "vout": 0,
    "scriptSig": "<signature> <owner_pubkey> OP_TRUE"
  }],
  "outputs": [{
    "address": "owner_address",
    "value": 3200000000  # 32 BSV (full stake returned)
  }]
}
```

### Emergency Unlock (With Penalty)

If owner needs funds before lock expires:

```json
{
  "inputs": [{
    "txid": "...",
    "vout": 0,
    "scriptSig": "<signature> OP_FALSE"
  }],
  "outputs": [{
    "address": "penalty_address",  # Protocol treasury
    "value": 320000000   # 10% penalty
  }, {
    "address": "owner_address",
    "value": 2880000000   # 90% returned
  }]
}
```

**Penalty:** 10% of stake goes to protocol treasury, 90% returned to owner.

---

## Fee Distribution Model

### Primary Fee Split

When a user interacts with a /1 object (ghost, shop, etc.):

```
Total Fee: 100%
├── 50% → Application/Ghost Developer
├── 40% → Territory Owner(s)
│   ├── 50% → Building Owner (/8)
│   ├── 30% → City Treasury (/32)
│   └── 20% → Block Owner (/16)
└── 10% → Protocol Treasury
```

### Secondary Taxes

Additional fees layered on top:

| Tax | Rate | Destination | Trigger |
|-----|------|-------------|---------|
| City Interaction Tax | 0.1% | City Treasury | Any /1 interaction within city |
| Jurisdiction Tax | 0.05% | Country Treasury | Any /8+ transaction |
| Billboard Royalty | 1.5% | Founder | Billboard content changes |

**Total effective fee example:**
```
Base interaction: 10,000 satoshis
├── Developer: 5,000 sats (50%)
├── Territory: 4,000 sats (40%)
├── Protocol: 1,000 sats (10%)
├── City Tax: 10 sats (0.1%)
└── Total: 10,010 sats
```

---

## Yield Calculation

### Building Owner (/8) Example

**Scenario:**
- Stake: 8 BSV (8,000,000,000 satoshis)
- Lock period: 5 months
- Daily interactions on building: 100
- Average interaction fee: 1,000 satoshis

**Calculation:**
```
Daily volume: 100 × 1,000 = 100,000 satoshis
Territory share (40%): 40,000 satoshis
Building share (50% of territory): 20,000 satoshis

Monthly yield: 20,000 × 30 = 600,000 satoshis
5-month yield: 600,000 × 5 = 3,000,000 satoshis

Annualized yield: (3,000,000 / 8,000,000,000) × (12/5) = 0.9%
```

**With higher activity:**
```
Daily interactions: 1,000
Daily yield: 200,000 satoshis
5-month yield: 30,000,000 satoshis
Annualized yield: 9%
```

### City Founder (/32) Example

**Scenario:**
- Stake: 32 BSV
- City reaches Phase 4 (21+ citizens, UBI active)
- Daily city-wide volume: 10,000 interactions
- Average fee: 1,000 satoshis

**Calculation:**
```
Daily volume: 10,000,000 satoshis
City tax (0.1%): 10,000 satoshis
Territory share from objects in city: varies

Founder also receives:
- 20% of city tokens (640,000 tokens)
- Token value depends on treasury size
- UBI as citizen (if maintains presence)
```

---

## City Token Economics

### Token Distribution

Each city mints exactly **3.2 million tokens** at founding:

| Allocation | Amount | % | Vesting/Lock |
|------------|--------|---|--------------|
| Founder | 640,000 | 20% | 12-month linear vest |
| Treasury | 1,600,000 | 50% | Immediate (for UBI/grants) |
| Public Sale | 800,000 | 25% | Immediate |
| Protocol Dev | 160,000 | 5% | 24-month vest |
| **Total** | **3,200,000** | **100%** | |

### Token Utility

**Governance Rights:**
- Propose policies (requires 100 tokens)
- Vote on proposals (1 token = 1 vote)
- Delegate votes to representatives

**Economic Rights:**
- Redeem for BSV from treasury (burn tokens)
- Receive UBI (requires holding 1+ token)
- Access premium city features

**Non-Rights:**
- No profit share (treasury is for public goods, not dividends)
- No transfer restrictions
- No additional minting ever

### Treasury Redemption

Tokens can be redeemed for BSV from city treasury:

```
Redemption rate = Treasury_BSV / Total_Token_Supply

Example:
  Treasury: 1000 BSV
  Total supply: 3,200,000 tokens
  Redemption rate: 0.0003125 BSV per token
  
  1000 tokens = 0.3125 BSV
```

**Redemption mechanism:**
1. Send tokens to treasury burn address
2. Receive BSV at current redemption rate
3. Tokens are permanently burned
4. Redemption rate increases for remaining holders

This creates a **floor price** for city tokens based on treasury holdings.

---

## Universal Basic Income (UBI)

### Activation

UBI activates when city reaches **Phase 4 (21+ citizens)**.

### Formula

```
Daily UBI per citizen = (Treasury_BSV × 0.001) / Citizen_Count

Monthly cap: 1% of treasury total
```

**Example:**
```
Treasury: 1000 BSV
Citizens: 25

Daily UBI = (1000 × 0.001) / 25 = 0.04 BSV per citizen
Monthly UBI = 1.2 BSV per citizen
Treasury spend = 30 BSV/month (3% of treasury)
```

### Sustainability Guardrails

To prevent treasury depletion:

1. **Monthly cap:** Max 1% of treasury distributed as UBI
2. **Minimum treasury:** UBI pauses if treasury < 100 BSV
3. **Heartbeat requirement:** Must have active heartbeat (within 30 days)
4. **Accumulation:** Unclaimed UBI accumulates (no expiration)

### UBI Funding Sources

City treasury receives:
- 30% of object territory fees
- 0.1% city interaction tax
- Public block auction proceeds
- Building registration fees
- Optional: donations, investments

---

## Progressive Property Tax

To prevent monopoly ownership of territory:

### Tax Schedule

| Property # | Multiplier | City Cost | Building Cost | Home Cost |
|------------|------------|-----------|---------------|-----------|
| 1st | 1× | 32 BSV | 8 BSV | 4 BSV |
| 2nd | 2× | 64 BSV | 16 BSV | 8 BSV |
| 3rd | 4× | 128 BSV | 32 BSV | 16 BSV |
| 4th | 8× | 256 BSV | 64 BSV | 32 BSV |
| 5th | 16× | 512 BSV | 128 BSV | 64 BSV |
| nth | 2^(n-1)× | 32 × 2^(n-1) | 8 × 2^(n-1) | 4 × 2^(n-1) |

**Formula:**
```
Cost(n) = Base_Cost × 2^(n-1)

Total Cost for N properties = Base_Cost × (2^N - 1)
```

### Example: Owning Multiple Buildings

| Building # | Cost | Cumulative |
|------------|------|------------|
| 1 | 8 BSV | 8 BSV |
| 2 | 16 BSV | 24 BSV |
| 3 | 32 BSV | 56 BSV |
| 4 | 64 BSV | 120 BSV |
| 5 | 128 BSV | 248 BSV |

**To own 5 buildings: 248 BSV** (vs. 40 BSV at flat rate)

### Economic Impact

This makes it **mathematically impossible** to monopolize all territory:

- 10 cities: 32,736 BSV (prohibitive)
- 20 buildings: 8,388,608 BSV (impossible)

Forces distribution of ownership, creating:
- More diverse governance
- Better price discovery
- Resilience against capture
- Opportunity for new entrants

---

## Network Fees

### Transaction Costs

All transactions require BSV network fees (paid to miners):

| Transaction Type | Size (bytes) | Fee (sats) | USD (@ $50/BSV) |
|------------------|--------------|------------|-----------------|
| Standard | 250 | ~125 | ~$0.00006 |
| City Found | 400 | ~200 | ~$0.0001 |
| Building Claim | 350 | ~175 | ~$0.00009 |
| Heartbeat | 300 | ~150 | ~$0.00008 |
| Ghost Deploy | 450 | ~225 | ~$0.00011 |
| Object Mint | 320 | ~160 | ~$0.00008 |

**Note:** Fees go to BSV miners, not Locus Protocol.

### Fee Market

During congestion:
- Fees increase (standard Bitcoin fee market)
- Transactions may be delayed
- Protocol cannot influence fees
- Users can bid higher for priority

---

## Economic Attack Vectors

### 1. Territory Squatting

**Attack:** Buy territory and do nothing with it.

**Mitigation:**
- Opportunity cost of locked capital
- Progressive tax makes large holdings expensive
- No yield without activity
- Heartbeat requirement maintains liveness

### 2. City Death Spiral

**Attack:** Recruit citizens, extract value, abandon.

**Mitigation:**
- Founder tokens vest over 12 months
- UBI creates loyalty
- Token redemption floor protects citizens
- Reputation loss (founder can't easily start new city)

### 3. Sybil Citizens

**Attack:** Create fake citizens to unlock blocks faster.

**Mitigation:**
- Heartbeat requires Proof of Presence
- CLTV locks prevent rapid cycling
- Citizen removal process
- 6-month heartbeat expiry

### 4. Treasury Drain

**Attack:** Extract all treasury value via UBI.

**Mitigation:**
- 1% monthly cap on UBI
- Minimum treasury floor (100 BSV)
- Treasury income from fees
- Governance can adjust parameters

---

## Comparison to Other Models

| Aspect | Locus | Bitcoin (PoW) | Ethereum (PoS) | Axie (Play-to-Earn) |
|--------|-------|---------------|----------------|---------------------|
| **Capital required** | Yes (stake) | Yes (hardware) | Yes (stake) | Yes (buy NFTs) |
| **Capital returned** | Yes (100%) | No (depreciation) | Yes (unstake) | No (resale only) |
| **Yield source** | Activity fees | Block reward | Inflation + fees | New players |
| **Sustainability** | Activity-based | Energy-based | Inflation-based | Ponzi risk |
| **Entry barrier** | Medium | High | Medium | High |
| **Exit liquidity** | After lock | Continuous | Delayed | Market-dependent |

---

## Implementation Notes

### For Core Developers

- CLTV scripts must be carefully validated
- Lock heights must account for block time variance
- Emergency unlock requires multi-sig approval
- Treasury accounting must be precise (satoshis)

### For Client Developers

- Show users exact lock expiration dates
- Calculate opportunity cost comparisons
- Display real-time yield estimates
- Warn about emergency unlock penalties

### For Users

- Understand 5-month lock period before staking
- Monitor territory activity for yield optimization
- Consider progressive tax when scaling
- Claim UBI regularly (can accumulate but why wait?)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-17 | Initial lock-to-mint economics specification |
