#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/testnet/runtime"
FIXTURES_DIR="${ROOT_DIR}/testnet/fixtures"
MIX_ENV_NAME="${MIX_ENV:-test}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-dir)
      RUNTIME_DIR="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      shift 2
      ;;
    --fixtures-dir)
      FIXTURES_DIR="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "${RUNTIME_DIR}"

pushd "${ROOT_DIR}/core" >/dev/null
MIX_ENV="${MIX_ENV_NAME}" mix run --no-start ../testnet/scripts/found_test_cities.exs -- \
  --fixtures-dir "${FIXTURES_DIR}" \
  --output "${RUNTIME_DIR}/scenario.json" \
  --validation-output "${RUNTIME_DIR}/validation.json"
MIX_ENV="${MIX_ENV_NAME}" mix test test/locus/testnet_validation_test.exs
popd >/dev/null

grep -q '"passed": true' "${RUNTIME_DIR}/validation.json"
echo "validation passed"
