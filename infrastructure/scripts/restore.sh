#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

PROVIDER="aws"
ENVIRONMENT="prod"
SNAPSHOT_ID=""
RESTORE_IDENTIFIER=""
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
    --snapshot-id)
      SNAPSHOT_ID="$2"
      shift 2
      ;;
    --restore-identifier)
      RESTORE_IDENTIFIER="$2"
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
[[ "${PROVIDER}" == "aws" ]] || die "restore automation is currently implemented for aws only"
[[ -n "${SNAPSHOT_ID}" ]] || die "--snapshot-id is required"

TF_DIR="$(terraform_dir_for_provider "${PROVIDER}")"
if [[ -z "${ENV_FILE}" ]]; then
  ENV_FILE="$(env_file_path_for_env "${ENVIRONMENT}")"
fi

load_env_file "${ENV_FILE}"

require_cmd terraform
require_cmd aws
require_cmd jq

db_identifier="$(terraform_output_raw "${TF_DIR}" db_instance_identifier)"
db_secret_name="$(terraform_output_raw "${TF_DIR}" indexer_db_connection_secret_name)"
master_secret_arn="$(terraform_output_raw "${TF_DIR}" db_master_secret_arn)"
db_name="$(terraform_output_raw "${TF_DIR}" db_name)"
subnet_group="$(terraform_output_raw "${TF_DIR}" db_subnet_group_name)"
rds_sg="$(terraform_output_raw "${TF_DIR}" rds_security_group_id)"
db_class="$(terraform_output_raw "${TF_DIR}" db_instance_class)"
cluster="$(terraform_output_raw "${TF_DIR}" ecs_cluster_name)"
indexer_service="$(terraform_output_raw "${TF_DIR}" indexer_service_name)"

if [[ -z "${RESTORE_IDENTIFIER}" ]]; then
  RESTORE_IDENTIFIER="${db_identifier}-restore-$(date +%Y%m%d%H%M%S)"
fi

log "restoring ${SNAPSHOT_ID} into ${RESTORE_IDENTIFIER}"
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "${RESTORE_IDENTIFIER}" \
  --db-snapshot-identifier "${SNAPSHOT_ID}" \
  --db-instance-class "${db_class}" \
  --db-subnet-group-name "${subnet_group}" \
  --vpc-security-group-ids "${rds_sg}" \
  --multi-az \
  --no-publicly-accessible \
  >/dev/null

log "waiting for restored instance to become available"
aws rds wait db-instance-available --db-instance-identifier "${RESTORE_IDENTIFIER}"

restored_endpoint="$(aws rds describe-db-instances \
  --db-instance-identifier "${RESTORE_IDENTIFIER}" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)"

master_payload="$(aws secretsmanager get-secret-value --secret-id "${master_secret_arn}" --query SecretString --output text)"
connection_payload="$(jq -cn \
  --argjson credentials "${master_payload}" \
  --arg host "${restored_endpoint}" \
  --arg dbname "${db_name}" \
  '$credentials + {host: $host, dbname: $dbname}')"

aws secretsmanager put-secret-value \
  --secret-id "${db_secret_name}" \
  --secret-string "${connection_payload}" \
  >/dev/null

aws ecs update-service --cluster "${cluster}" --service "${indexer_service}" --force-new-deployment >/dev/null

log "indexer database connection secret now points at ${restored_endpoint}"
log "terraform state still references the original DB instance; reconcile after the incident window"
