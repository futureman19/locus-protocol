data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

locals {
  name_prefix      = "${var.project_name}-${var.environment}"
  tls_enabled      = var.acm_certificate_arn != ""
  public_subnets   = { for idx, az in var.availability_zones : az => var.public_subnet_cidrs[idx] }
  private_subnets  = { for idx, az in var.availability_zones : az => var.private_subnet_cidrs[idx] }
  common_tags      = merge(var.tags, { Project = var.project_name, Environment = var.environment, ManagedBy = "terraform" })
  artifacts_bucket = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-artifacts"
  backup_bucket    = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-backups"
  protocol_network = var.environment == "prod" ? "mainnet" : "testnet"
  indexer_image    = var.indexer_image != "" ? var.indexer_image : "${aws_ecr_repository.indexer.repository_url}:${var.release_version}"
  ghost_image      = var.ghost_image != "" ? var.ghost_image : "${aws_ecr_repository.ghost.repository_url}:${var.release_version}"
  node_image       = var.node_image != "" ? var.node_image : "${aws_ecr_repository.node.repository_url}:${var.release_version}"
  node_registry    = split("/", local.node_image)[0]
}
