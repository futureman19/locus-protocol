# Locus Protocol Specifications

This directory contains the formal specification for the Locus Protocol — a permissionless protocol for location-aware autonomous agents on BSV.

## Specification Documents

| Document | Status | Description |
|----------|--------|-------------|
| [01-overview.md](./01-overview.md) | Draft | Protocol concepts, state machines, economics |
| [02-transaction-formats.md](./02-transaction-formats.md) | Draft | Byte-level encoding for all transactions |
| [03-ghost-registry.md](./03-ghost-registry.md) | Draft | Ghost discovery and indexing |
| [04-staking-spec.md](./04-staking-spec.md) | Draft | Detailed staking mechanics |
| [05-heartbeat-protocol.md](./05-heartbeat-protocol.md) | Draft | Proof-of-liveness details |
| [06-fee-distribution.md](./06-fee-distribution.md) | Draft | Payment flows and economics |
| [07-challenge-system.md](./07-challenge-system.md) | Draft | Dispute resolution |

## JSON Schemas

Located in `./schemas/`, these define the structure for all protocol payloads:

- `ghost-register.json` — Ghost registration format
- `heartbeat.json` — Heartbeat transaction format
- `invocation.json` — Ghost invocation format
- `challenge.json` — Challenge transaction format

## Status Legend

| Status | Meaning |
|--------|---------|
| Draft | Under active development, may change significantly |
| Review | Feature-complete, seeking feedback |
| Stable | Production-ready, backward compatible changes only |
| Deprecated | Superseded by newer version |

## Versioning

Specifications follow [Semantic Versioning](https://semver.org/):

- **MAJOR:** Breaking protocol changes (hard fork)
- **MINOR:** New features, backward compatible (soft fork)
- **PATCH:** Clarifications, typo fixes, no functional changes

Current version: **0.1.0** (Testnet)

## Contributing

Protocol changes follow a BIP-style process:

1. Open an issue describing the problem or feature
2. Draft a specification update
3. Request review from protocol maintainers
4. After consensus, merge and update version

## Implementations

| Implementation | Language | Status | Notes |
|----------------|----------|--------|-------|
| Reference Node | Elixir | In Progress | See `/node/` |
| JavaScript Client | TypeScript | Planned | `@locusprotocol/client` |
| Python Client | Python | Planned | `locus-protocol` |

## References

- [H3 Geospatial Indexing](https://h3geo.org/)
- [BSV Technical Standards](https://github.com/bitcoin-sv-specs)
- [Bitcoin Script](https://wiki.bitcoinsv.io/index.php/Script)
