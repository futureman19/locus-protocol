output "indexer_ecr_repository_url" {
  value = module.mainnet.indexer_ecr_repository_url
}

output "ghost_ecr_repository_url" {
  value = module.mainnet.ghost_ecr_repository_url
}

output "node_ecr_repository_url" {
  value = module.mainnet.node_ecr_repository_url
}

output "arc_secret_name" {
  value = module.mainnet.arc_secret_name
}

output "indexer_runtime_secret_name" {
  value = module.mainnet.indexer_runtime_secret_name
}

output "protocol_keys_secret_name" {
  value = module.mainnet.protocol_keys_secret_name
}

output "indexer_db_connection_secret_name" {
  value = module.mainnet.indexer_db_connection_secret_name
}

output "db_master_secret_arn" {
  value = module.mainnet.db_master_secret_arn
}

output "db_primary_endpoint" {
  value = module.mainnet.db_primary_endpoint
}

output "db_instance_identifier" {
  value = module.mainnet.db_instance_identifier
}

output "db_subnet_group_name" {
  value = module.mainnet.db_subnet_group_name
}

output "db_instance_class" {
  value = module.mainnet.db_instance_class
}

output "db_name" {
  value = module.mainnet.db_name
}

output "backup_bucket_name" {
  value = module.mainnet.backup_bucket_name
}

output "ecs_cluster_name" {
  value = module.mainnet.ecs_cluster_name
}

output "indexer_task_definition_arn" {
  value = module.mainnet.indexer_task_definition_arn
}

output "ecs_security_group_id" {
  value = module.mainnet.ecs_security_group_id
}

output "private_subnet_ids" {
  value = module.mainnet.private_subnet_ids
}

output "indexer_service_name" {
  value = module.mainnet.indexer_service_name
}

output "ghost_service_name" {
  value = module.mainnet.ghost_service_name
}

output "node_asg_name" {
  value = module.mainnet.node_asg_name
}

output "rds_security_group_id" {
  value = module.mainnet.rds_security_group_id
}

output "public_indexer_url" {
  value = module.mainnet.public_indexer_url
}

output "internal_ghost_url" {
  value = module.mainnet.internal_ghost_url
}

output "internal_node_url" {
  value = module.mainnet.internal_node_url
}
