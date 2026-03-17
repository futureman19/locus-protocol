#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/testnet/runtime"
FIXTURES_DIR="${ROOT_DIR}/testnet/fixtures"
START_NODES=1
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
    --dry-run|--no-start)
      START_NODES=0
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "${RUNTIME_DIR}"

if find "${RUNTIME_DIR}/nodes" -name node.pid -type f -print -quit 2>/dev/null | grep -q .; then
  echo "existing node pid files detected under ${RUNTIME_DIR}; run cleanup_testnet.sh first" >&2
  exit 1
fi

pushd "${ROOT_DIR}/core" >/dev/null
MIX_ENV="${MIX_ENV_NAME}" mix run --no-start ../testnet/scripts/generate_genesis.exs -- \
  --fixtures-dir "${FIXTURES_DIR}" \
  --output "${RUNTIME_DIR}/genesis.json" \
  --scenario-output "${RUNTIME_DIR}/scenario.json" \
  --validation-output "${RUNTIME_DIR}/validation.json"
popd >/dev/null

pushd "${ROOT_DIR}/node" >/dev/null
MIX_ENV="${MIX_ENV_NAME}" mix run --no-start ../testnet/scripts/render_node_runtime.exs -- \
  --fixtures-dir "${FIXTURES_DIR}" \
  --genesis "${RUNTIME_DIR}/genesis.json" \
  --runtime-dir "${RUNTIME_DIR}/nodes"
popd >/dev/null

if [[ "${START_NODES}" -eq 1 ]]; then
  while IFS= read -r node_dir; do
    env_file="${node_dir}/node.env"
    pid_file="${node_dir}/node.pid"
    log_file="${node_dir}/node.log"

    (
      set -a
      # shellcheck disable=SC1090
      source "${env_file}"
      set +a
      export MIX_ENV="${MIX_ENV_NAME}"
      cd "${ROOT_DIR}/node"
      nohup mix run --no-halt >"${log_file}" 2>&1 &
      echo $! >"${pid_file}"
    )
  done < <(find "${RUNTIME_DIR}/nodes" -mindepth 1 -maxdepth 1 -type d | sort)

  bash "${ROOT_DIR}/testnet/scripts/health_check.sh" --runtime-dir "${RUNTIME_DIR}"
fi

echo "testnet artifacts available in ${RUNTIME_DIR}"
