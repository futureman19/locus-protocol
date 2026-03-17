# Testnet Deployment Infrastructure

This directory contains the local testnet harness for Locus Protocol.

## What it does

- Generates a deterministic genesis config for a three-node testnet
- Founds five fixture-driven cities across genesis, settlement, village, city, and metropolis phases
- Applies automated citizen joins to trigger Fibonacci block unlocks
- Funds treasuries and runs UBI distribution rounds for eligible cities
- Starts reference nodes with per-node health status files
- Produces scenario and validation reports for CI artifacts

## Entry points

- `bash testnet/scripts/deploy_testnet.sh`
- `bash testnet/scripts/health_check.sh`
- `bash testnet/scripts/validate_testnet.sh`
- `bash testnet/scripts/cleanup_testnet.sh`

## Generated artifacts

- `testnet/runtime/genesis.json`
- `testnet/runtime/scenario.json`
- `testnet/runtime/validation.json`
- `testnet/runtime/nodes/<node>/status.json`
