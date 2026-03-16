# 01 - Territory Hierarchy

**Version:** 1.0  
**Status:** Draft

---

## Overview

Locus organizes physical space into a hierarchical addressing system called **Geo-IPv6**. This creates a natural structure for governance, economics, and property rights.

Each level in the hierarchy has:
- A **stake requirement** (how much BSV to claim it)
- A **governance scope** (what decisions it can make)
- **Economic flows** (what fees it receives/pays)
- **Address format** (how it's identified)

---

## Address Hierarchy

```
Geo-IPv6 Address Structure

/128 Continent
  └── /64 Country/Jurisdiction
        └── /32 City (32 BSV)
              ├── /16 Public Block (Fibonacci unlock)
              │     └── /8 Building (8 BSV)
              │           └── /4 Home (4 BSV)
              │                 └── /2 Aura (user's 10ft bubble)
              │                       └── /1 Object (0.1-64 BSV)
              │                             ├── item (0.0001 BSV)
              │                             ├── waypoint (0.5-4 BSV)
              │                             ├── agent/ghost (0.1-4 BSV)
              │                             ├── billboard (10-100 BSV)
              │                             └── rare/epic/legendary (16-64 BSV)
              └── /16 Private Block (8 BSV)
                    └── /4 Home (4 BSV)
                          └── /2 Aura → /1 Object
```

---

## Level Details

### /128 — Continent

| Attribute | Value |
|-----------|-------|
| **Stake** | N/A |
| **Purpose** | Geographic region grouping |
| **Examples** | `2001:0db8::/128` (North America), `2001:0db9::/128` (Europe) |
| **Governance** | None (purely geographic) |
| **Fees** | None |

Continents are used for:
- Network partitioning
- Regional statistics
- UI organization

---

### /64 — Country/Jurisdiction

| Attribute | Value |
|-----------|-------|
| **Stake** | N/A |
| **Purpose** | Legal jurisdiction boundary |
| **Examples** | `2001:0db8:0001::/64` (USA), `2001:0db9:0044::/64` (UK) |
| **Governance** | None at protocol level |
| **Fees** | 0.05% of /8 building transactions (jurisdiction tax) |

Countries are used for:
- Legal compliance boundaries
- Tax jurisdiction tracking
- Regional treasury distribution

**Note:** The protocol doesn't enforce legal jurisdictions—it records them. If a region's legal status changes, the /64 address remains constant.

---

### /32 — City

| Attribute | Value |
|-----------|-------|
| **Stake** | **32 BSV** |
| **Purpose** | Metropolitan unit with full governance |
| **Address Format** | `2001:0db8:0001:0000::/32` |
| **Token Supply** | 3.2 million (fixed) |
| **Area** | H3 Resolution 7 (~5.1 km² average) |

**Claiming a City:**
1. Stake 32 BSV with 21,600-block CLTV lock
2. Specify city name, description, initial policies
3. Founder receives 20% of tokens (12-month vest)
4. City enters Phase 0 (Genesis)

**City Revenue:**
- 0.1% tax on all /1 object interactions within city
- Block auction proceeds (public /16 blocks)
- Building registration fees

**City Treasury:**
- 50% of token supply allocated to treasury
- Funds UBI, grants, public goods
- Redeemable by token holders

See [02-city-lifecycle.md](02-city-lifecycle.md) for complete phase progression.

---

### /16 — Public Block

| Attribute | Value |
|-----------|-------|
| **Stake** | **Public** (auctioned by city treasury) |
| **Purpose** | City-controlled land for development |
| **Address Format** | `2001:0db8:0001:0001::/16` |
| **Unlock Mechanism** | Fibonacci sequence based on citizen count |

**Fibonacci Unlock:**

Blocks unlock when city reaches citizen counts:

| Block # | Citizens Required | Status |
|---------|-------------------|--------|
| 1 | 1 | Unlocked at Genesis |
| 2 | 1 | Unlocked at Genesis |
| 3 | 2 | Unlocks with 2nd citizen |
| 4 | 3 | Unlocks with 3rd citizen |
| 5 | 5 | Unlocks with 5th citizen |
| 6 | 8 | Unlocks with 8th citizen |
| 7 | 13 | Unlocks with 13th citizen |
| 8 | 21 | Unlocks with 21st citizen |
| 9 | 34 | Unlocks with 34th citizen |
| ... | ... | Continues to 89, 144, 233... |

**Visual Progress Bar:**
```
Phase 0: [░░░░░░░░░░░░░░░] 1 citizen
Phase 2: [██░░░░░░░░░░░░░] 5 citizens (3 blocks unlocked)
Phase 4: [████████░░░░░░░] 25 citizens (16 blocks unlocked)
Phase 5: [████████████████] 55+ citizens (all blocks unlocked)
```

**Claiming a Block:**
1. City treasury auctions unlocked blocks
2. Winner pays BSV to city treasury
3. Block can be subdivided into /8 buildings
4. No CLTV lock (city treasury owns outright)

---

### /16 — Private Block

| Attribute | Value |
|-----------|-------|
| **Stake** | **8 BSV** |
| **Purpose** | Privately-owned development land |
| **Address Format** | `2001:0db8:0001:8000::/16` (high bit set) |

Private blocks are purchased directly (not auctioned) and can be subdivided into buildings.

---

### /8 — Building

| Attribute | Value |
|-----------|-------|
| **Stake** | **8 BSV** |
| **Purpose** | Commercial venue (shop, gallery, venue) |
| **Address Format** | `2001:0db8:0001:0001:0100::/8` |
| **Area** | H3 Resolution 9 (~0.1 km²) |

**Building Types:**
| Type | Description |
|------|-------------|
| `shop` | Retail space with inventory |
| `gallery` | Art/display space |
| `venue` | Event space |
| `office` | Workspace |
| `arcade` | Gaming/entertainment |

**Building Revenue:**
- 40% of all /1 object fees within building
- Direct microtransactions from visitors
- Premium positioning fees

---

### /4 — Home

| Attribute | Value |
|-----------|-------|
| **Stake** | **4 BSV** |
| **Purpose** | Private residence |
| **Address Format** | `2001:0db8:0001:0001:0100:0010::/4` |
| **Variants** | Fixed or Mobile |

**Fixed Home:**
- Anchored to specific GPS coordinates
- Can have /1 objects (furniture, decorations, ghosts)
- Can receive visitors

**Mobile Home:**
- Moves with owner's Aura (/2)
- Personal 10-foot AR bubble
- Cannot receive visitors (private)

**Home Features:**
- Personal ghost deployment (private AI assistants)
- Object storage
- Security settings
- Visitor permissions

---

### /2 — Aura

| Attribute | Value |
|-----------|-------|
| **Stake** | **N/A** (automatic with presence) |
| **Purpose** | 10-foot mobile AR bubble around user |
| **Address Format** | Derived from user's public key |
| **Duration** | Requires heartbeat every 6 months |

**Aura Properties:**
- Follows user's GPS location
- 10-foot radius sphere
- Private by default (only owner can see contents)
- Can deploy personal /1 objects
- Requires Proof of Presence (heartbeat) to maintain

**Aura Contents:**
- Personal waypoint markers
- Private ghosts (AI assistants)
- Notifications from nearby territory
- Mini-map of surroundings

---

### /1 — Object

| Attribute | Value |
|-----------|-------|
| **Stake** | **0.1-64 BSV** (depends on rarity/type) |
| **Purpose** | Digital items anchored to location |
| **Address Format** | `2001:0db8:0001:0001:0100:0010:0001::/1` |

**Object Types and Stakes:**

| Type | Stake | Description |
|------|-------|-------------|
| `item` | 0.0001 BSV | Basic item (coin, key, token) |
| `waypoint` | 0.5-4 BSV | Navigation marker |
| `agent` | 0.1-4 BSV | AI ghost (WASM agent) |
| `billboard` | 10-100 BSV | Public advertisement |
| `rare` | 16 BSV | Limited edition item |
| `epic` | 32 BSV | Very limited item |
| `legendary` | 64 BSV | Ultra rare item |

**Object Properties:**
- Content hash (IPFS/Arweave)
- Owner public key
- Creation timestamp
- Rarity tier
- Interaction history

See [05-ghost-protocol.md](05-ghost-protocol.md) for agent/ghost details.

---

## Fee Flow Summary

```
User interacts with /1 Object (Ghost)
  │
  ├── 50% → Ghost Developer
  │
  ├── 40% → Territory Owner
  │     ├── 50% → Building Owner (/8)
  │     ├── 30% → City Treasury (/32)
  │     └── 20% → Block Owner (/16)
  │
  ├── 10% → Protocol Treasury
  │
  ├── 0.1% → City Interaction Tax (extra)
  │
  └── 0.05% → Country Jurisdiction Tax (extra)
```

---

## Progressive Property Tax

To prevent monopoly ownership, each additional property costs more:

| Property # | Multiplier | Example (City = 32 BSV) |
|------------|------------|------------------------|
| 1st | 1× | 32 BSV |
| 2nd | 2× | 64 BSV |
| 3rd | 4× | 128 BSV |
| 4th | 8× | 256 BSV |
| 5th | 16× | 512 BSV |

**Formula:** `cost = base × 2^(n-1)` where n = property count

This makes it mathematically impossible to monopolize all territory in a city.

---

## Address Collision Prevention

H3 hex resolution ensures unique addresses:

| Level | H3 Resolution | Approximate Area | Addresses per km² |
|-------|---------------|------------------|-------------------|
| /32 City | 7 | 5.1 km² | ~0.2 |
| /8 Building | 9 | 0.1 km² | ~10 |
| /4 Home | 10 | 0.015 km² | ~67 |
| /1 Object | 12 | 0.003 km² | ~333 |

First claimer at a hex address wins. Disputes resolved by:
1. Earlier transaction timestamp
2. Higher stake amount
3. Continuous heartbeat maintenance

---

## Transaction Formats

See [07-transaction-formats.md](07-transaction-formats.md) for complete OP_RETURN schemas for claiming territory at each level.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-17 | Initial territory hierarchy for rewrite |
