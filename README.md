# Locus Protocol

**Territory-based geospatial protocol for BSV.**  
*Cities, blocks, buildings, homes, and ghosts. Lock-to-mint economics with Year 10 governance sunset.*

---

## What Is Locus?

Locus is a **permissionless, blockchain-native protocol** for anchoring digital property to physical space. It creates a persistent grid of territories—cities, blocks, buildings, homes, and objects—where each level has its own economics, governance, and capabilities.

Unlike traditional geospatial systems that rely on central servers and API keys, L derives all state from the BSV blockchain. Anyone can participate by following protocol rules—no registration, no permissions, no gatekeepers.

### Core Innovation: Lock-to-Mint

Locus uses a **lock-to-mint** economic model:
- Stake BSV to claim territory (32 BSV for a city, 8 BSV for a building, etc.)
- Stakes are **time-locked via CLTV**, not burned or given away
- After 5 months (~21,600 blocks), you get your entire stake back
- The opportunity cost of locked capital is the only "cost"

This creates skin-in-the-game without extracting value from participants.

---

## Territory Hierarchy

Locus organizes space using a **Geo-IPv6 addressing scheme**:

| Level | Address | Stake | What It Is |
|-------|---------|-------|------------|
| /128 | Continent | N/A | Geographic region |
| /64 | Country | N/A | Jurisdiction level |
| **/32** | **City** | **32 BSV** | Metropolitan unit with mayor, council, treasury |
| /16 | Block | Public | City treasury land, Fibonacci unlock |
| **/8** | **Building** | **8 BSV** | Commercial venues (shops, galleries) |
| **/4** | **Home** | **4 BSV** | Private residence (fixed or mobile) |
| /2 | Aura | N/A | 10-foot mobile AR bubble around user |
| **/1** | **Object** | **0.1-64 BSV** | Digital items: ghosts, billboards, waypoints |

Each level inherits from and pays fees to the levels above it.

---

## City Lifecycle (6 Phases)

Cities evolve through Fibonacci-governed phases:

| Phase | Citizens | Unlocked Blocks | Governance | Key Feature |
|-------|----------|-----------------|------------|-------------|
| 0. Genesis | 1 (founder) | 0 | Founder | 20% tokens vesting |
| 1. Settlement | 2-3 | 0 | Founder | "Hardcore mode" - can die |
| 2. Village | 4-8 | 3 | Tribal Council | First expansion |
| 3. Town | 9-20 | 8 | Republic | Full blocks active |
| 4. City | 21-50 | 16 | Direct Democracy | **UBI ACTIVATED** |
| 5. Metropolis | 51+ | All | Senate | Full expansion |

**Fibonacci Unlock:** Blocks unlock at citizen counts: 1, 1, 2, 3, 5, 8, 13, 21, 34...

---

## Governance Evolution

### Years 0-10: Genesis Period
- **/256 Genesis Key** controls protocol
- Single founder/team can upgrade and evolve
- Cities operate autonomously but protocol is centralized

### Year 10+: Federal Era
- Genesis key **automatically dissolves** at Block 2,100,000 (hardcoded CLTV)
- **Federal Council of Cities** takes over
- Each city gets weighted vote based on activity/treasury
- Protocol becomes truly decentralized

### Emergency Fallback: Cathedral Guardian
- 7-of-12 multi-sig held by protocol developers
- Only activates if Federal Council deadlocks
- Can only extend, never reduce, decentralization

---

## Ghost Protocol (Integrated)

Ghosts are **autonomous WASM agents** that live at `/1` object addresses. They follow a Schrödinger state machine:

1. **Dormant** (Blockchain): 200-byte UTXO with stake, IPFS hash
2. **Potential** (IPFS/Arweave): WASM code + assets + manifest
3. **Manifest** (Local Execution): Downloads to device, runs in sandbox

When you approach a ghost, it manifests on your device. When you leave, it returns to potential state—existing only as a blockchain UTXO awaiting the next interaction.

### Fee Flow
```
User interacts with Ghost
  ├── 50% → Ghost Developer
  ├── 40% → Territory Owner (hex staker)
  └── 10% → Protocol Treasury
```

---

## Economic Model

### Progressive Property Tax
To prevent monopoly ownership:
- 1st property: base cost
- 2nd: 2× base
- 3rd: 4× base
- 4th: 8× base
- ...mathematically impossible to own everything

### City Tokenomics
Each city mints exactly **3.2 million tokens**:
- 20% Founder (12-month vesting)
- 50% Treasury (UBI, grants, public goods)
- 25% Public sale
- 5% Protocol development

Tokens are **redeemable for BSV** from city treasury—no secondary token mechanics, no inflation.

### Revenue Flows
- **0.1%** agent interaction tax → City treasury
- **1.5%** billboard royalty → Founder (ongoing)
- **0.05%** /64 jurisdiction tax → Countries

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    LOCUS PROTOCOL                           │
│                  (Territory Layer)                          │
├────────────────────────────────────────────────────────────┤
│  /32 City  │  /16 Block  │  /8 Building  │  /4 Home  │ /1  │
│   (32 BSV) │   (Public)  │    (8 BSV)    │  (4 BSV)  │Obj  │
└────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────┐
│                    GHOST PROTOCOL                           │
│               (WASM Execution Layer)                        │
│                                                             │
│  • Schrödinger state (Dormant→Potential→Manifest)          │
│  • WASM sandbox with capability-based security             │
│  • Payment channels for microtransactions                  │
│  • IPFS/Arweave storage for code/assets                    │
└────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
locus-protocol/
├── specs/              # Protocol specifications
│   ├── 00-principles.md
│   ├── 01-territory-hierarchy.md
│   ├── 02-city-lifecycle.md
│   ├── 03-staking-economics.md
│   ├── 04-governance.md
│   ├── 05-ghost-protocol.md
│   ├── 06-heartbeat-presence.md
│   └── 07-transaction-formats.md
│
├── core/               # Territory layer (Elixir)
│   └── lib/locus/
│       ├── territory.ex
│       ├── city.ex
│       ├── fibonacci.ex
│       ├── treasury.ex
│       ├── governance.ex
│       └── heartbeat.ex
│
├── ghost/              # Ghost layer (Elixir)
│   └── lib/locus_ghost/
│       ├── ghost.ex
│       ├── wasm_runtime.ex
│       ├── orchestrator.ex
│       └── invocation.ex
│
├── client/             # JavaScript SDK
│   └── src/
│       ├── locus.ts
│       ├── city.ts
│       ├── territory.ts
│       └── ghost.ts
│
└── testnet/            # Deployment & testing
    ├── fixtures/
    ├── scripts/
    └── config/
```

---

## Getting Started

See the [specs/](specs/) directory for complete protocol documentation.

To run a node:
```bash
cd core
mix deps.get
mix compile
iex -S mix
```

To use the JavaScript client:
```bash
cd client
npm install
npm run build
```

---

## Key Principles

1. **BSV Only** — No protocol tokens. City tokens are local utility, redeemable for BSV.
2. **Lock-to-Mint** — Stakes return after 5 months. Never burned.
3. **Year 10 Sunset** — Genesis control automatically dissolves. Irreversible.
4. **Permissionless** — No APIs, no registration, no central servers.
5. **Progressive Decentralization** — Centralized start, Federal Council finish.
6. **Economic Alignment** — Territory owners earn from activity on their land.

---

## License

MIT — See [LICENSE](LICENSE)

---

## Archived Version

The original ghost-centric prototype is preserved at [locus-protocol-ARCHIVED](https://github.com/futureman19/locus-protocol-ARCHIVED) for reference.
