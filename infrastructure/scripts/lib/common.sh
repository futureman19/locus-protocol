#!/usr/bin/env bash
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${COMMON_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"

log() {
  printf '[locus-infra] %s\n' "$*" >&2
}

die() {
  log "$*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

abs_path() {
  local input="$1"
  if [[ "${input}" = /* ]]; then
    printf '%s\n' "${input}"
    return
  fi

  local dir
  dir="$(cd "$(dirname "${input}")" && pwd)"
  printf '%s/%s\n' "${dir}" "$(basename "${input}")"
}

load_env_file() {
  local env_file="$1"

  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
  fi
}

terraform_dir_for_provider() {
  printf '%s\n' "${INFRA_DIR}/terraform/$1"
}

tfvars_path_for() {
  printf '%s\n' "${INFRA_DIR}/config/environments/$2/$1.tfvars"
}

genesis_path_for_env() {
  printf '%s\n' "${INFRA_DIR}/config/environments/$1/genesis.json"
}

env_file_path_for_env() {
  printf '%s\n' "${INFRA_DIR}/config/environments/$1/mainnet.env"
}

terraform_output_raw() {
  terraform -chdir="$1" output -raw "$2"
}

terraform_output_json() {
  terraform -chdir="$1" output -json "$2"
}

ecr_registry_host() {
  printf '%s\n' "${1%%/*}"
}

ensure_provider_supported() {
  case "$1" in
    aws|gcp|azure) ;;
    *) die "unsupported provider: $1" ;;
  esac
}
