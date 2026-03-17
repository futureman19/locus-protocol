#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

PROVIDER="aws"
ENVIRONMENT="prod"
WAIT_FOR_SNAPSHOT=0
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
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --wait)
      WAIT_FOR_SNAPSHOT=1
      shift
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

ensure_provider_supported "${PROVIDER}"
[[ "${PROVIDER}" == "aws" ]] || die "backup automation is currently implemented for aws only"

TF_DIR="$(terraform_dir_for_provider "${PROVIDER}")"
GENESIS_PATH="$(genesis_path_for_env "${ENVIRONMENT}")"
if [[ -z "${ENV_FILE}" ]]; then
  ENV_FILE="$(env_file_path_for_env "${ENVIRONMENT}")"
fi

load_env_file "${ENV_FILE}"

require_cmd terraform
require_cmd aws
require_cmd jq
require_cmd tar

snapshot_id="locus-${ENVIRONMENT}-$(date +%Y%m%d%H%M%S)"
db_identifier="$(terraform_output_raw "${TF_DIR}" db_instance_identifier)"
backup_bucket="$(terraform_output_raw "${TF_DIR}" backup_bucket_name)"

log "creating RDS snapshot ${snapshot_id}"
aws rds create-db-snapshot \
  --db-instance-identifier "${db_identifier}" \
  --db-snapshot-identifier "${snapshot_id}" \
  >/dev/null

if [[ "${WAIT_FOR_SNAPSHOT}" -eq 1 ]]; then
  log "waiting for snapshot ${snapshot_id} to become available"
  aws rds wait db-snapshot-available --db-snapshot-identifier "${snapshot_id}"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

cp "${GENESIS_PATH}" "${tmp_dir}/genesis.json"
terraform -chdir="${TF_DIR}" output -json > "${tmp_dir}/terraform-outputs.json"

aws ecs describe-services \
  --cluster "$(terraform_output_raw "${TF_DIR}" ecs_cluster_name)" \
  --services \
    "$(terraform_output_raw "${TF_DIR}" indexer_service_name)" \
    "$(terraform_output_raw "${TF_DIR}" ghost_service_name)" \
  > "${tmp_dir}/ecs-services.json"

aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$(terraform_output_raw "${TF_DIR}" node_asg_name)" \
  > "${tmp_dir}/node-asg.json"

jq -cn \
  --arg snapshot_id "${snapshot_id}" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{snapshot_id: $snapshot_id, generated_at: $generated_at}' \
  > "${tmp_dir}/backup-manifest.json"

archive_path="${tmp_dir}/chain-state-backup.tar.gz"
tar -czf "${archive_path}" -C "${tmp_dir}" .

s3_prefix="manual-backups/${ENVIRONMENT}/$(date +%Y/%m/%d/%H%M%S)"
aws s3 cp "${archive_path}" "s3://${backup_bucket}/${s3_prefix}/chain-state-backup.tar.gz" >/dev/null

log "snapshot created: ${snapshot_id}"
log "chain-state archive uploaded to s3://${backup_bucket}/${s3_prefix}/chain-state-backup.tar.gz"
