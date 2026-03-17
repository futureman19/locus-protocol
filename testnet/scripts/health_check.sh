#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/testnet/runtime"
TIMEOUT_SECONDS=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-dir)
      RUNTIME_DIR="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

NODES_DIR="${RUNTIME_DIR}/nodes"

if [[ ! -d "${NODES_DIR}" ]]; then
  echo "missing nodes directory: ${NODES_DIR}" >&2
  exit 1
fi

shopt -s nullglob
node_dirs=("${NODES_DIR}"/*)
shopt -u nullglob

if [[ "${#node_dirs[@]}" -eq 0 ]]; then
  echo "no node runtime directories found in ${NODES_DIR}" >&2
  exit 1
fi

for node_dir in "${node_dirs[@]}"; do
  [[ -d "${node_dir}" ]] || continue

  name="$(basename "${node_dir}")"
  pid_file="${node_dir}/node.pid"
  status_file="${node_dir}/status.json"
  deadline=$((SECONDS + TIMEOUT_SECONDS))

  while true; do
    if [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}")" 2>/dev/null && [[ -s "${status_file}" ]] && grep -q '"loaded": true' "${status_file}"; then
      echo "healthy: ${name}"
      break
    fi

    if (( SECONDS >= deadline )); then
      echo "health check failed for ${name}" >&2
      [[ -f "${status_file}" ]] && cat "${status_file}" >&2
      exit 1
    fi

    sleep 1
  done
done
