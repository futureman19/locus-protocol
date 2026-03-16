# 00 - Core Principles

**Version:** 1.0  
**Status:** Draft

These principles guide all protocol decisions. If a feature contradicts these principles, the feature must change—not the principles.

---

## 1. BSV Only

**The protocol uses only BSV.**

- No native protocol token
- No ERC-20 equivalents
- No inflationary rewards
- No "governance tokens" that vote on monetary policy

City tokens are **local utility tokens**, not protocol tokens. They are:
- Fixed supply per city (3.2M)
- Redeemable for BSV from city treasury
- Governance rights limited to that city only
- Not tradeable across cities

This principle ensures:
- No regulatory ambiguity around securities
- No complex token economics to design
- No inflation diluting participants
- Simple mental model: BSV in, BSV out

---

## 2. Lock-to-Mint

**Stakes are time-locked, never burned.**

When you stake BSV to claim territory:
1. Your BSV goes into a CLTV-locked output
2. Lock period: exactly 21,600 blocks (~5 months)
3. After lock expires, you can spend your BSV freely
4. Your entire stake returns to you

The "cost" of participating is **opportunity cost**—the BSV you could have earned elsewhere during those 5 months.

This principle ensures:
- No extractive token sales
- No Ponzi dynamics (new money pays old)
- Skin-in-the-game without destroying capital
- Participants can exit with full principal

**Contrast with other models:**
- **Burn models** (Ethereum gas): Value destroyed, miners extract
- **Stake-for-yield models**: Inflation pays stakers, diluting non-stakers
- **Lock-to-mint**: Opportunity cost only, capital preserved

---

## 3. Year 10 Sunset

**Centralized control automatically dissolves.**

- Years 0-10: /256 Genesis Key controls protocol
- Block 2,100,000 (~Year 10): Genesis key becomes unusable via CLTV
- Year 10+: Federal Council of Cities governs

This is **hardcoded and irreversible**. Even the founding team cannot extend centralized control past Year 10.

The Cathedral Guardian (7-of-12 multi-sig) exists only as emergency fallback if the Federal Council deadlocks. It can:
- Break governance deadlocks
- Extend decentralization (add more cities to council)
- **Never** reduce decentralization or restore Genesis key

This principle ensures:
- Temporary centralization, permanent decentralization
- Founders can iterate quickly early
- Users know exactly when decentralization happens
- No "we'll decentralize soon" promises

---

## 4. Permissionless

**No registration, no APIs, no central servers.**

Anyone can:
- Claim territory by staking BSV
- Found a city by staking 32 BSV
- Deploy a ghost by staking at /1
- Join any city (if they meet requirements)
- Read all protocol state from blockchain
- Verify all transactions independently

The protocol requires:
- No email addresses
- No KYC/AML
- No API keys
- No terms of service
- No geographic restrictions

This principle ensures:
- Censorship resistance
- Global accessibility
- No single point of failure
- True "unstoppable" property rights

**What "permissionless" does NOT mean:**
- No rules (protocol rules are enforced by code)
- No costs (staking requirements exist)
- No consequences (misbehavior can be slashed)

---

## 5. Progressive Decentralization

**Centralized start → Decentralized finish.**

Early decisions:
- Founder controls protocol evolution
- Rapid iteration possible
- Bugs can be fixed
- Features can be added

Late decisions (Year 10+):
- Federal Council of Cities votes
- Changes require majority
- Slow but legitimate
- Resistant to capture

This is **intentional**, not a compromise. The startup phase needs speed. The mature phase needs legitimacy.

This principle ensures:
- Protocol can evolve in early days
- Protocol becomes stable in mature phase
- Users understand the transition timeline
- No perpetual "temporary" centralization

---

## 6. Economic Alignment

**Territory owners earn from activity on their land.**

Fee distribution:
- 50% → Application/Ghost developer
- 40% → Territory owner (hex staker)
- 10% → Protocol treasury

If you own a building (/8) and someone deploys a shop ghost there, you earn 40% of all transaction fees from that ghost.

This principle ensures:
- Incentive to stake desirable territory
- Incentive to attract developers/builders
- Passive income for property owners
- Skin-in-the-game for territory quality

**Progressive Property Tax** enforces distribution:
- 1st property: base cost
- 2nd: 2× base
- 3rd: 4× base
- 4th: 8× base
- Mathematically impossible to monopolize

---

## 7. Geo-Spatial Hierarchy

**Physical space maps to digital address space.**

The Geo-IPv6 addressing creates natural hierarchy:
- /128 Continent → /64 Country → /32 City → /16 Block → /8 Building → /4 Home → /2 Aura → /1 Object

Each level:
- Inherits properties from above
- Pays fees to above
- Can govern levels below
- Has its own economics

This principle ensures:
- Natural organizational structure
- Clear jurisdiction boundaries
- Scalable governance (cities govern themselves)
- Intuitive mental model

---

## 8. State on Chain

**All protocol state derives from blockchain.**

No:
- Central databases
- Off-chain state that "syncs" to chain
- Trusted oracles for core functions
- API calls required to verify state

Yes:
- Ghost code stored on IPFS/Arweave (content-addressed, verifiable)
- WASM execution happens locally (stateless, reproducible)
- Payment channels for high-frequency interactions
- Blockchain as source of truth for ownership and stakes

This principle ensures:
- Permanent, immutable property records
- No server downtime affects protocol
- Anyone can verify state independently
- Censorship-resistant property rights

---

## 9. User Sovereignty

**Users own their data and keys.**

- Private keys never leave user's device
- No "accounts" on central servers
- No tracking of user activity
- No forced updates or changes

Ghost interactions happen in **payment channels**:
- Open channel with ghost
- Rapid microtransactions (off-chain)
- Close channel to settle on-chain
- Ghost never holds user funds

This principle ensures:
- No custodial risk
- No surveillance
- No platform lock-in
- True digital property rights

---

## 10. Open Source

**All protocol code is open source (MIT).**

- Anyone can read the code
- Anyone can fork the protocol
- Anyone can build on top
- No proprietary extensions

This principle ensures:
- Transparency
- Auditability
- Community contribution
- No hidden backdoors

---

## Principle Conflicts

If two principles conflict, resolve in this priority order:

1. **BSV Only** — Never create a protocol token
2. **Permissionless** — Never add registration requirements
3. **Year 10 Sunset** — Never extend centralized control
4. **Lock-to-Mint** — Never burn stakes
5. **State on Chain** — Minimize off-chain dependencies
6. **Economic Alignment** — Ensure territory owners benefit
7. **User Sovereignty** — Minimize custodial trust
8. **Progressive Decentralization** — Speed early, legitimacy late
9. **Geo-Spatial Hierarchy** — Maintain address structure
10. **Open Source** — Keep code accessible

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-17 | Initial principles for territory-based rewrite |
