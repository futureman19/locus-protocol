#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_DIR="${ROOT_DIR}/testnet/runtime"
PRESERVE_ARTIFACTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-dir)
      RUNTIME_DIR="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      shift 2
      ;;
    --preserve-artifacts)
      PRESERVE_ARTIFACTS=1
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -d "${RUNTIME_DIR}/nodes" ]]; then
  for pid_file in "${RUNTIME_DIR}/nodes"/*/node.pid; do
    [[ -f "${pid_file}" ]] || continue
    pid="$(cat "${pid_file}")"

    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
    fi

    rm -f "${pid_file}"
  done
fi

if [[ "${PRESERVE_ARTIFACTS}" -eq 0 ]]; then
  rm -rf "${RUNTIME_DIR}/nodes"
fi
