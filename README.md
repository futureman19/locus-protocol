# Locus Protocol

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A permissionless protocol for deploying location-aware autonomous agents ("ghosts") on the Bitcoin SV blockchain.

## Overview

Locus Protocol enables anyone to deploy software agents that:
- Exist at specific geographic coordinates
- Respond to invocations with microtransaction fees
- Prove liveness through on-chain heartbeats
- Maintain economic security via time-locked staking

## Design Principles

- **Permissionless**: No registration, no API keys, no central authority
- **Blockchain-native**: All state lives on-chain or is derived from chain
- **Economic alignment**: Staking and fees align participant interests
- **Trustless**: Cryptographic verification, no trusted intermediaries

## Protocol Specifications

See the `/specs` directory for detailed specifications:

| Document | Description |
|----------|-------------|
| `01-overview.md` | Protocol concepts, ghost lifecycle, state machine |
| `02-transaction-formats.md` | Binary encoding, OP_RETURN schemas, validation |
| `03-ghost-registry.md` | Chain-derived registry, state transitions, indexing |
| `04-staking-spec.md` | CLTV staking, tiers, slashing conditions |
| `05-heartbeat-protocol.md` | Proof-of-liveness, sequence validation |
| `06-fee-distribution.md` | 70/20/10 economic model, treasury |
| `07-challenge-system.md` | Dispute resolution, permissionless challenges |

## Reference Implementation

The `node/` directory contains an Elixir reference implementation:

```bash
cd node
mix deps.get
mix compile
```

### Architecture

- **No database**: All state derived from blockchain
- **No REST API**: gRPC for local clients only
- **Configuration-driven**: Single config file for all parameters

### Modules

| Module | Responsibility |
|--------|---------------|
| `Locus.Ghost` | Ghost lifecycle (register, activate, retire, slash) |
| `Locus.Staking` | CLTV locks, time-locked withdrawals, slashing |
| `Locus.Heartbeat` | Proof-of-liveness, inactivity detection |
| `Locus.Invocation` | Fee processing, execution, timeout handling |
| `Locus.Challenge` | Dispute resolution, fraud detection |
| `Locus.Chain` | BSV blockchain interaction (read/write) |
| `Locus.Registry` | In-memory ghost state index |

## Quick Start

### Register a Ghost

```elixir
alias Locus.Ghost

ghost = %Ghost{
  name: "My Oracle",
  type: :oracle,
  lat: 40.7128,
  lng: -74.0060,
  stake_amount: 10_000_000,  # 0.1 BSV
  # ... other fields
}

Ghost.validate_registration(ghost, current_height)
```

### Build Staking Script

```elixir
alias Locus.Staking

redeem_script = Staking.build_lock_script(lock_height, owner_pubkey)
p2sh_address = Staking.p2sh_address(redeem_script)
```

## Staking Tiers

| Type | Minimum Stake | Lock Period | Use Case |
|------|---------------|-------------|----------|
| GREETER | 1M sats (0.01 BSV) | 5 months | Simple welcome messages |
| ORACLE | 10M sats (0.1 BSV) | 5 months | Data queries, prices |
| GUARDIAN | 50M sats (0.5 BSV) | 5 months | Security monitoring |
| MERCHANT | 10M sats (0.1 BSV) | 5 months | Commerce, escrow |
| CUSTOM | 100M sats (1 BSV) | 5-12 months | Specialized services |

## Fee Distribution

All invocation fees are split:
- **70%** - Ghost developer
- **20%** - Executor (node that processed)
- **10%** - Protocol treasury

## Challenge System

Anyone can challenge a ghost for:
- **No-show**: Didn't respond to invocation
- **Fraud**: Produced fraudulent result
- **Malfunction**: Crashed or errored
- **Timeout**: Exceeded timeout

Challenger stakes 10K sats (returned if upheld, burned if rejected).

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

This is an open protocol. Contributions welcome:
1. Propose changes via PR
2. Discuss in issues
3. Fork and experiment

## Resources

- [BSV SDK Documentation](https://bsv-blockchain.github.io/ts-sdk/)
- [BRC Standards](https://github.com/bitcoin-sv/BRCs)
- [1Sat Ordinals](https://docs.1satordinals.com/)

## Acknowledgments

Built with:
- [bsv_sdk](https://hex.pm/packages/bsv_sdk) - Elixir BSV SDK
- [shruggr/lockup](https://github.com/shruggr/lockup) - Time-lock reference
- [ARC](https://github.com/bitcoin-sv/arc) - Transaction processor
