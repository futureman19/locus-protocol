#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

PROVIDER="aws"
ENVIRONMENT="prod"
RELEASE_VERSION="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
ENV_FILE=""
AUTO_APPROVE=0
SKIP_BUILD=0
SKIP_MIGRATE=0

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
    --release-version)
      RELEASE_VERSION="$2"
      shift 2
      ;;
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --auto-approve)
      AUTO_APPROVE=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --skip-migrate)
      SKIP_MIGRATE=1
      shift
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

ensure_provider_supported "${PROVIDER}"

TF_DIR="$(terraform_dir_for_provider "${PROVIDER}")"
TFVARS="$(tfvars_path_for "${PROVIDER}" "${ENVIRONMENT}")"
GENESIS_PATH="$(genesis_path_for_env "${ENVIRONMENT}")"

if [[ -z "${ENV_FILE}" ]]; then
  ENV_FILE="$(env_file_path_for_env "${ENVIRONMENT}")"
fi

[[ -d "${TF_DIR}" ]] || die "terraform directory missing: ${TF_DIR}"
[[ -f "${TFVARS}" ]] || die "tfvars missing: ${TFVARS}"
[[ -f "${GENESIS_PATH}" ]] || die "genesis document missing: ${GENESIS_PATH}"

load_env_file "${ENV_FILE}"

require_cmd terraform
require_cmd jq

if [[ "${PROVIDER}" != "aws" ]]; then
  APPLY_ARGS=(
    -var-file="${TFVARS}"
    -var="environment=${ENVIRONMENT}"
  )

  if [[ "${AUTO_APPROVE}" -eq 1 ]]; then
    APPLY_ARGS=(-auto-approve "${APPLY_ARGS[@]}")
  fi

  log "running Terraform apply for ${PROVIDER} using ${ENVIRONMENT}"
  terraform -chdir="${TF_DIR}" init
  terraform -chdir="${TF_DIR}" apply "${APPLY_ARGS[@]}"
  exit 0
fi

require_cmd aws
require_cmd docker

TF_ARGS=(
  -var-file="${TFVARS}"
  -var="release_version=${RELEASE_VERSION}"
  -var="genesis_file_path=${GENESIS_PATH}"
)

if [[ "${AUTO_APPROVE}" -eq 1 ]]; then
  TF_ARGS+=(-auto-approve)
fi

bootstrap_apply() {
  log "bootstrapping ECR repositories and Secrets Manager containers"
  terraform -chdir="${TF_DIR}" apply "${TF_ARGS[@]}" \
    -target=module.mainnet.aws_ecr_repository.indexer \
    -target=module.mainnet.aws_ecr_repository.ghost \
    -target=module.mainnet.aws_ecr_repository.node \
    -target=module.mainnet.aws_secretsmanager_secret.arc_credentials \
    -target=module.mainnet.aws_secretsmanager_secret.indexer_runtime \
    -target=module.mainnet.aws_secretsmanager_secret.protocol_keys \
    -target=module.mainnet.aws_secretsmanager_secret.indexer_db_connection
}

build_and_push_images() {
  local indexer_repo ghost_repo node_repo registry_host

  indexer_repo="$(terraform_output_raw "${TF_DIR}" indexer_ecr_repository_url)"
  ghost_repo="$(terraform_output_raw "${TF_DIR}" ghost_ecr_repository_url)"
  node_repo="$(terraform_output_raw "${TF_DIR}" node_ecr_repository_url)"
  registry_host="$(ecr_registry_host "${indexer_repo}")"

  log "logging into ECR ${registry_host}"
  aws ecr get-login-password --region "${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}" \
    | docker login --username AWS --password-stdin "${registry_host}"

  log "building indexer image ${indexer_repo}:${RELEASE_VERSION}"
  docker build -t "${indexer_repo}:${RELEASE_VERSION}" "${REPO_ROOT}/indexer"
  docker push "${indexer_repo}:${RELEASE_VERSION}"

  log "building ghost runtime image ${ghost_repo}:${RELEASE_VERSION}"
  docker build -t "${ghost_repo}:${RELEASE_VERSION}" "${REPO_ROOT}/ghost/runtime"
  docker push "${ghost_repo}:${RELEASE_VERSION}"

  log "building node image ${node_repo}:${RELEASE_VERSION}"
  docker build -t "${node_repo}:${RELEASE_VERSION}" "${REPO_ROOT}/node"
  docker push "${node_repo}:${RELEASE_VERSION}"
}

sync_runtime_secrets() {
  local arc_secret indexer_secret protocol_secret guardian_keys

  arc_secret="$(terraform_output_raw "${TF_DIR}" arc_secret_name)"
  indexer_secret="$(terraform_output_raw "${TF_DIR}" indexer_runtime_secret_name)"
  protocol_secret="$(terraform_output_raw "${TF_DIR}" protocol_keys_secret_name)"

  guardian_keys="$(printf '%s' "${GUARDIAN_PUBLIC_KEYS:-}" | jq -Rc 'split(",") | map(select(length > 0))')"

  aws secretsmanager put-secret-value \
    --secret-id "${arc_secret}" \
    --secret-string "$(jq -cn \
      --arg arc_endpoint "${ARC_ENDPOINT:-https://arc.taal.com}" \
      --arg arc_api_key "${ARC_API_KEY:-}" \
      '{arc_endpoint: $arc_endpoint, arc_api_key: $arc_api_key}')" \
    >/dev/null

  aws secretsmanager put-secret-value \
    --secret-id "${indexer_secret}" \
    --secret-string "$(jq -cn \
      --arg subscription_id "${JUNGLEBUS_SUBSCRIPTION_ID:-}" \
      --arg junglebus_url "${JUNGLEBUS_URL:-https://junglebus.gorillapool.io}" \
      '{junglebus_subscription_id: $subscription_id, junglebus_url: $junglebus_url}')" \
    >/dev/null

  aws secretsmanager put-secret-value \
    --secret-id "${protocol_secret}" \
    --secret-string "$(jq -cn \
      --arg genesis_public_key "${GENESIS_PUBLIC_KEY:-}" \
      --argjson guardian_public_keys "${guardian_keys}" \
      '{genesis_public_key: $genesis_public_key, guardian_public_keys: $guardian_public_keys}')" \
    >/dev/null
}

sync_db_connection_secret() {
  local master_secret_arn db_endpoint db_secret db_name master_payload connection_payload

  master_secret_arn="$(terraform_output_raw "${TF_DIR}" db_master_secret_arn)"
  db_endpoint="$(terraform_output_raw "${TF_DIR}" db_primary_endpoint)"
  db_secret="$(terraform_output_raw "${TF_DIR}" indexer_db_connection_secret_name)"
  db_name="$(terraform_output_raw "${TF_DIR}" db_name)"
  master_payload="$(aws secretsmanager get-secret-value --secret-id "${master_secret_arn}" --query SecretString --output text)"

  connection_payload="$(jq -cn \
    --argjson credentials "${master_payload}" \
    --arg host "${db_endpoint}" \
    --arg dbname "${db_name}" \
    '$credentials + {host: $host, dbname: $dbname}')"

  aws secretsmanager put-secret-value \
    --secret-id "${db_secret}" \
    --secret-string "${connection_payload}" \
    >/dev/null
}

run_indexer_migration() {
  local cluster task_def ecs_sg subnet_json network_config overrides task_arn exit_code

  cluster="$(terraform_output_raw "${TF_DIR}" ecs_cluster_name)"
  task_def="$(terraform_output_raw "${TF_DIR}" indexer_task_definition_arn)"
  ecs_sg="$(terraform_output_raw "${TF_DIR}" ecs_security_group_id)"
  subnet_json="$(terraform_output_json "${TF_DIR}" private_subnet_ids)"

  network_config="$(jq -cn \
    --argjson subnets "${subnet_json}" \
    --arg sg "${ecs_sg}" \
    '{awsvpcConfiguration: {subnets: $subnets, securityGroups: [$sg], assignPublicIp: "DISABLED"}}')"

  overrides="$(jq -cn \
    '{containerOverrides: [{name: "indexer", command: ["node", "dist/db/migrate.js"]}]}')"

  task_arn="$(aws ecs run-task \
    --cluster "${cluster}" \
    --launch-type FARGATE \
    --task-definition "${task_def}" \
    --network-configuration "${network_config}" \
    --overrides "${overrides}" \
    --query 'tasks[0].taskArn' \
    --output text)"

  aws ecs wait tasks-stopped --cluster "${cluster}" --tasks "${task_arn}"

  exit_code="$(aws ecs describe-tasks \
    --cluster "${cluster}" \
    --tasks "${task_arn}" \
    --query 'tasks[0].containers[0].exitCode' \
    --output text)"

  [[ "${exit_code}" == "0" ]] || die "indexer migration task failed with exit code ${exit_code}"
}

restart_services() {
  local cluster indexer_service ghost_service

  cluster="$(terraform_output_raw "${TF_DIR}" ecs_cluster_name)"
  indexer_service="$(terraform_output_raw "${TF_DIR}" indexer_service_name)"
  ghost_service="$(terraform_output_raw "${TF_DIR}" ghost_service_name)"

  aws ecs update-service --cluster "${cluster}" --service "${indexer_service}" --force-new-deployment >/dev/null
  aws ecs update-service --cluster "${cluster}" --service "${ghost_service}" --force-new-deployment >/dev/null
}

log "initializing Terraform in ${TF_DIR}"
terraform -chdir="${TF_DIR}" init

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  bootstrap_apply
  build_and_push_images
  sync_runtime_secrets
fi

log "applying full Terraform stack for ${ENVIRONMENT} release ${RELEASE_VERSION}"
terraform -chdir="${TF_DIR}" apply "${TF_ARGS[@]}"

sync_db_connection_secret

if [[ "${SKIP_MIGRATE}" -eq 0 ]]; then
  log "running indexer schema migration task"
  run_indexer_migration
fi

restart_services

log "deployment complete"
log "public indexer: $(terraform_output_raw "${TF_DIR}" public_indexer_url)"
log "internal ghost endpoint: $(terraform_output_raw "${TF_DIR}" internal_ghost_url)"
log "internal node endpoint: $(terraform_output_raw "${TF_DIR}" internal_node_url)"
