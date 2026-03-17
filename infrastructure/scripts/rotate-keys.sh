#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

PROVIDER="aws"
ENVIRONMENT="prod"
TARGET="all"
ENV_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      PROVIDER="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

ensure_provider_supported "${PROVIDER}"
[[ "${PROVIDER}" == "aws" ]] || die "key rotation automation is currently implemented for aws only"

TF_DIR="$(terraform_dir_for_provider "${PROVIDER}")"
if [[ -z "${ENV_FILE}" ]]; then
  ENV_FILE="$(env_file_path_for_env "${ENVIRONMENT}")"
fi

load_env_file "${ENV_FILE}"

require_cmd terraform
require_cmd aws
require_cmd jq

arc_secret="$(terraform_output_raw "${TF_DIR}" arc_secret_name)"
indexer_secret="$(terraform_output_raw "${TF_DIR}" indexer_runtime_secret_name)"
protocol_secret="$(terraform_output_raw "${TF_DIR}" protocol_keys_secret_name)"
db_connection_secret="$(terraform_output_raw "${TF_DIR}" indexer_db_connection_secret_name)"
master_secret_arn="$(terraform_output_raw "${TF_DIR}" db_master_secret_arn)"
db_endpoint="$(terraform_output_raw "${TF_DIR}" db_primary_endpoint)"
db_name="$(terraform_output_raw "${TF_DIR}" db_name)"
cluster="$(terraform_output_raw "${TF_DIR}" ecs_cluster_name)"
indexer_service="$(terraform_output_raw "${TF_DIR}" indexer_service_name)"
ghost_service="$(terraform_output_raw "${TF_DIR}" ghost_service_name)"
node_asg="$(terraform_output_raw "${TF_DIR}" node_asg_name)"

guardian_keys="$(printf '%s' "${GUARDIAN_PUBLIC_KEYS:-}" | jq -Rc 'split(",") | map(select(length > 0))')"

case "${TARGET}" in
  arc|all)
    aws secretsmanager put-secret-value \
      --secret-id "${arc_secret}" \
      --secret-string "$(jq -cn \
        --arg arc_endpoint "${ARC_ENDPOINT:-https://arc.taal.com}" \
        --arg arc_api_key "${ARC_API_KEY:-}" \
        '{arc_endpoint: $arc_endpoint, arc_api_key: $arc_api_key}')" \
      >/dev/null
    ;;
esac

case "${TARGET}" in
  indexer-runtime|all)
    aws secretsmanager put-secret-value \
      --secret-id "${indexer_secret}" \
      --secret-string "$(jq -cn \
        --arg subscription_id "${JUNGLEBUS_SUBSCRIPTION_ID:-}" \
        --arg junglebus_url "${JUNGLEBUS_URL:-https://junglebus.gorillapool.io}" \
        '{junglebus_subscription_id: $subscription_id, junglebus_url: $junglebus_url}')" \
      >/dev/null
    ;;
esac

case "${TARGET}" in
  protocol|all)
    aws secretsmanager put-secret-value \
      --secret-id "${protocol_secret}" \
      --secret-string "$(jq -cn \
        --arg genesis_public_key "${GENESIS_PUBLIC_KEY:-}" \
        --argjson guardian_public_keys "${guardian_keys}" \
        '{genesis_public_key: $genesis_public_key, guardian_public_keys: $guardian_public_keys}')" \
      >/dev/null
    ;;
esac

case "${TARGET}" in
  db-connection|all)
    master_payload="$(aws secretsmanager get-secret-value --secret-id "${master_secret_arn}" --query SecretString --output text)"
    aws secretsmanager put-secret-value \
      --secret-id "${db_connection_secret}" \
      --secret-string "$(jq -cn \
        --argjson credentials "${master_payload}" \
        --arg host "${db_endpoint}" \
        --arg dbname "${db_name}" \
        '$credentials + {host: $host, dbname: $dbname}')" \
      >/dev/null
    ;;
esac

case "${TARGET}" in
  indexer-runtime|db-connection|all)
    aws ecs update-service --cluster "${cluster}" --service "${indexer_service}" --force-new-deployment >/dev/null
    ;;
esac

case "${TARGET}" in
  protocol|all)
    aws ecs update-service --cluster "${cluster}" --service "${ghost_service}" --force-new-deployment >/dev/null
    ;;
esac

case "${TARGET}" in
  arc|protocol|all)
    aws autoscaling start-instance-refresh \
      --auto-scaling-group-name "${node_asg}" \
      --preferences '{"MinHealthyPercentage":67,"InstanceWarmup":180}' \
      >/dev/null || true
    ;;
esac

log "rotation flow completed for target ${TARGET}"
