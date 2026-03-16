# 02 - City Lifecycle

**Version:** 1.0  
**Status:** Draft

---

## Overview

Cities in Locus evolve through **six distinct phases**, each with unique governance, economics, and capabilities. This lifecycle creates natural progression from founder-controlled startup to fully decentralized metropolis.

The progression is driven by **citizen count** and governed by the **Fibonacci sequence** for block unlocking.

---

## Quick Reference

| Phase | Name | Citizens | Unlocked Blocks | Governance | Key Feature |
|-------|------|----------|-----------------|------------|-------------|
| 0 | Genesis | 1 | 0 | Founder | 20% tokens vesting |
| 1 | Settlement | 2-3 | 0 | Founder | "Hardcore mode" |
| 2 | Village | 4-8 | 3 | Tribal Council | First expansion |
| 3 | Town | 9-20 | 8 | Republic | Full blocks active |
| 4 | City | 21-50 | 16 | Direct Democracy | **UBI ACTIVATED** |
| 5 | Metropolis | 51+ | All | Senate | Full expansion |

---

## Phase 0: Genesis

**Duration:** Single block (founding moment)  
**Citizens:** 1 (the founder)  
**Unlocked Blocks:** 0

### Founding a City

To found a city:

1. **Stake 32 BSV** with 21,600-block CLTV lock
2. **Specify metadata:**
   - City name (max 50 chars)
   - Description (max 500 chars)
   - Geographic center (lat/lng)
   - H3 hex index (Resolution 7)
   - Initial policies (JSON)

3. **Receive tokens:**
   - 640,000 tokens (20% of supply) to founder
   - 12-month vesting period
   - 1/12th unlocks each month

4. **City treasury receives:**
   - 1,600,000 tokens (50% of supply)
   - 32 BSV stake (locked)

### Genesis Policies

At founding, the founder sets initial policies:

```json
{
  "name": "Neo-Tokyo",
  "description": "Cyberpunk metropolis for digital nomads",
  "location": {
    "lat": 35.6762,
    "lng": 139.6503,
    "h3_res7": "8f283080dcb019d"
  },
  "policies": {
    "ubi_enabled": false,
    "ubi_amount": 0,
    "block_auction_period": 604800,
    "building_code": "permissive",
    "immigration_policy": "open"
  }
}
```

These policies can be changed by founder in Phase 0-1, by council in Phase 2-3, by vote in Phase 4-5.

### Risks

Phase 0 cities are vulnerable:
- Founder can abandon (tokens vest regardless)
- No citizens = no network effects
- If founder doesn't recruit, city dies in Phase 1

---

## Phase 1: Settlement

**Duration:** Until 4th citizen joins  
**Citizens:** 2-3  
**Unlocked Blocks:** 0  
**Governance:** Founder (absolute)

### "Hardcore Mode"

Phase 1 is intentionally difficult:

- **No blocks unlocked** → No public building possible
- **Founder controls everything** → No checks and balances
- **City can die** → If citizens leave, city collapses

### City Death Conditions

A city dies (returns to unclaimed) if:
1. Citizen count drops to 0
2. Founder doesn't maintain heartbeat for 12 months
3. All remaining citizens unanimously vote to dissolve

When a city dies:
- All stakes return to owners (CLTV expires)
- City tokens become worthless
- Objects within city enter "abandoned" state
- Territory becomes claimable again

### Survival Strategy

Founders must:
1. Recruit 3+ committed citizens quickly
2. Maintain active presence (heartbeat)
3. Promise governance transition
4. Build value before blocks unlock

---

## Phase 2: Village

**Duration:** Until 9th citizen joins  
**Citizens:** 4-8  
**Unlocked Blocks:** 3 (Fibonacci: 1, 1, 2)  
**Governance:** Tribal Council

### Fibonacci Unlock: First Expansion

With 4 citizens, the city unlocks its first 3 blocks:

| Block | Unlock At | Fibonacci # |
|-------|-----------|-------------|
| Block 1 | Genesis | 1 |
| Block 2 | Genesis | 1 |
| Block 3 | 4 citizens | 2 |

**Visual:** `[███░░░░░░░░░░░░]`

### Tribal Council Governance

With multiple citizens, governance evolves:

- **Founder:** Retains veto power
- **Citizens:** Can propose policies
- **Council:** Founder + 2 elected citizens
- **Votes:** 2/3 majority for policy changes

### Block Auctions

Unlocked blocks are auctioned by city treasury:

1. **Auction period:** 7 days (default)
2. **Starting bid:** 1 BSV
3. **Winner:** Highest bidder
4. **Proceeds:** 100% to city treasury

### Village Economics

- **Treasury income:** Block auctions, building fees
- **Expenses:** None (UBI not yet active)
- **Token value:** Speculative (no redemption yet)

---

## Phase 3: Town

**Duration:** Until 21st citizen joins  
**Citizens:** 9-20  
**Unlocked Blocks:** 8 (Fibonacci: 1, 1, 2, 3)  
**Governance:** Republic

### Fibonacci Unlock: Major Expansion

With 9 citizens, total blocks unlocked = 8:

| Block | Unlock At | Fibonacci # |
|-------|-----------|-------------|
| 1-3 | See Phase 2 | 1, 1, 2 |
| 4 | 9 citizens | 3 |
| 5 | 9 citizens | 3 |
| 6 | 9 citizens | 3 |
| 7 | 9 citizens | 3 |
| 8 | 9 citizens | 3 |

**Visual:** `[████████░░░░░░░]`

### Republic Governance

More formal structure:

- **Mayor:** Elected by citizens (1-year term)
- **Council:** 5 elected representatives
- **Proposals:** Any citizen can submit
- **Quorum:** 60% of citizens must vote
- **Threshold:** 51% majority to pass

Mayor powers:
- Execute council decisions
- Represent city externally
- Manage day-to-day operations

Cannot:
- Spend treasury without council approval
- Change constitution
- Veto supermajority (75%) decisions

### Town Economics

- **Building boom:** 8 blocks = ~128 buildings possible
- **Diverse economy:** Shops, galleries, venues compete
- **Treasury growth:** Multiple revenue streams
- **Still no UBI** (savings accumulate)

---

## Phase 4: City

**Duration:** Until 51st citizen joins  
**Citizens:** 21-50  
**Unlocked Blocks:** 16 (Fibonacci: 1, 1, 2, 3, 5)  
**Governance:** Direct Democracy  
**🔥 UBI ACTIVATED 🔥**

### Fibonacci Unlock: Near Complete

With 21 citizens, total blocks unlocked = 16:

| Block Range | Unlock At | Fibonacci # |
|-------------|-----------|-------------|
| 1-8 | See Phase 3 | 1, 1, 2, 3 |
| 9-13 | 21 citizens | 5 |
| 14-16 | 21 citizens | 5 |

**Visual:** `[████████████░░░]`

### Direct Democracy

Maximum citizen participation:

- **No mayor** (or ceremonial only)
- **All citizens vote** on all proposals
- **Liquid democracy:** Can delegate votes
- **Quorum:** 40% (lower since more citizens)
- **Threshold:** 51% for most, 75% for constitutional

### Universal Basic Income (UBI)

**The big activation.** Citizens receive regular BSV distributions:

```
UBI Formula:
  daily_ubi = (treasury_bsv × 0.001) / citizen_count
  
  Example:
    Treasury: 1000 BSV
    Citizens: 25
    Daily UBI: (1000 × 0.001) / 25 = 0.04 BSV per citizen
```

**UBI Rules:**
- Distributed daily automatically
- Requires active heartbeat (within 30 days)
- Accumulates if not claimed
- Capped at 1% of treasury per month (sustainability)

**Why UBI changes everything:**
- Passive income attracts citizens
- Treasury must balance spending
- Citizens become economically invested
- City becomes "too big to fail"

### City Economics

- **Self-sustaining:** UBI creates loyalty
- **Network effects:** 21+ people = critical mass
- **Diverse:** Multiple industries, shops, services
- **Stable:** Less likely to die than smaller phases

---

## Phase 5: Metropolis

**Duration:** Permanent  
**Citizens:** 51+  
**Unlocked Blocks:** All (Fibonacci complete)  
**Governance:** Senate

### Fibonacci Unlock: Complete

With 51 citizens, ALL blocks unlock:

| Block Range | Unlock At | Fibonacci # |
|-------------|-----------|-------------|
| 1-16 | See Phase 4 | 1, 1, 2, 3, 5 |
| 17-21 | 34 citizens | 8 |
| 22-29 | 34 citizens | 8 |
| 30-37 | 55 citizens | 13 |
| ... | ... | continues to 89, 144... |

**Visual:** `[████████████████]`

### Senate Governance

For large populations, representative efficiency:

- **Senators:** 1 per 20 citizens (minimum 3)
- **Elections:** Annual
- **Term limits:** Max 3 consecutive terms
- **Powers:** Same as Republic mayor+council
- **Transparency:** All votes public

### Maximum Expansion

Unlimited building potential:
- Hundreds of blocks
- Thousands of buildings
- Tens of thousands of homes
- Unlimited objects

### Metropolis Economics

- **Major economy:** Comparable to small country
- **Diverse revenue:** Taxes, fees, investments
- **Sophisticated treasury:** Portfolio management
- **Global significance:** Part of Federal Council

---

## Fibonacci Unlock Reference

Complete Fibonacci sequence for city growth:

| Citizen Count | Blocks Unlocked | Fibonacci Sum | Phase |
|---------------|-----------------|---------------|-------|
| 1 | 2 | 1+1 | Genesis |
| 2 | 3 | 1+1+2 | Settlement |
| 4 | 5 | 1+1+2+3 | Village |
| 9 | 8 | +3 | Town |
| 21 | 16 | +5 | City |
| 34 | 24 | +8 | Metropolis |
| 55 | 37 | +13 | Metropolis |
| 89 | 60 | +21 | Metropolis |
| 144 | 97 | +34 | Metropolis |
| 233 | 157 | +55 | Metropolis |

**Formula:** `blocks = sum(Fibonacci(i)) for i where Fibonacci(i) <= citizens`

---

## Governance Comparison

| Aspect | Founder | Tribal | Republic | Democracy | Senate |
|--------|---------|--------|----------|-----------|--------|
| **Decision speed** | Fast | Medium | Medium | Slow | Medium |
| **Participation** | 1 person | 3 people | 6 people | All | Representatives |
| **Legitimacy** | Low | Medium | Medium | High | High |
| **Efficiency** | High | Medium | Medium | Low | Medium |
| **Risk of capture** | High | Medium | Medium | Low | Medium |

---

## State Transitions

```
Genesis → Settlement → Village → Town → City → Metropolis
   │           │          │       │      │        │
   │           │          │       │      │        └── (permanent)
   │           │          │       │      └── UBI activates
   │           │          │       └── Republic governance
   │           │          └── Tribal Council
   │           └── Can die (hardcore mode)
   └── Founder vesting begins
```

**No Reverse Transitions:**
- Once unlocked, blocks stay unlocked
- Once UBI activates, it stays active
- Governance can evolve but not devolve

---

## City Death and Rebirth

### Death Triggers

1. **Abandonment:** All citizens leave
2. **Founder expiry:** Founder doesn't heartbeat for 12 months
3. **Unanimous dissolution:** 100% of citizens vote to dissolve

### Death Process

1. City enters "dissolving" state (30-day grace)
2. All stakes unlock (CLTV expires)
3. City tokens become worthless
4. Objects enter "abandoned" state
5. Territory becomes unclaimed

### Rebirth

Anyone can claim a dead city:
1. Stake 32 BSV
2. New founder, new tokens, new treasury
3. Old objects remain abandoned (can be claimed)
4. Fresh start, clean slate

---

## Transaction Formats

See [07-transaction-formats.md](07-transaction-formats.md) for:
- `CITY_FOUND` transaction
- `CITIZEN_JOIN` transaction
- `GOVERNANCE_PROPOSE` transaction
- `GOVERNANCE_VOTE` transaction

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-17 | Initial city lifecycle for rewrite |
