output "indexer_ecr_repository_url" {
  value = aws_ecr_repository.indexer.repository_url
}

output "ghost_ecr_repository_url" {
  value = aws_ecr_repository.ghost.repository_url
}

output "node_ecr_repository_url" {
  value = aws_ecr_repository.node.repository_url
}

output "arc_secret_name" {
  value = aws_secretsmanager_secret.arc_credentials.name
}

output "indexer_runtime_secret_name" {
  value = aws_secretsmanager_secret.indexer_runtime.name
}

output "protocol_keys_secret_name" {
  value = aws_secretsmanager_secret.protocol_keys.name
}

output "indexer_db_connection_secret_name" {
  value = aws_secretsmanager_secret.indexer_db_connection.name
}

output "db_master_secret_arn" {
  value = aws_db_instance.indexer.master_user_secret[0].secret_arn
}

output "db_primary_endpoint" {
  value = aws_db_instance.indexer.address
}

output "db_instance_identifier" {
  value = aws_db_instance.indexer.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.main.name
}

output "db_instance_class" {
  value = var.db_instance_class
}

output "db_name" {
  value = var.db_name
}

output "backup_bucket_name" {
  value = aws_s3_bucket.backups.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "indexer_task_definition_arn" {
  value = aws_ecs_task_definition.indexer.arn
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

output "private_subnet_ids" {
  value = values(aws_subnet.private)[*].id
}

output "indexer_service_name" {
  value = aws_ecs_service.indexer.name
}

output "ghost_service_name" {
  value = aws_ecs_service.ghost.name
}

output "node_asg_name" {
  value = aws_autoscaling_group.node.name
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

output "public_indexer_url" {
  value = local.tls_enabled ? "https://${var.domain_name != "" ? var.domain_name : aws_lb.public.dns_name}" : "http://${aws_lb.public.dns_name}"
}

output "internal_ghost_url" {
  value = "http://${aws_lb.internal.dns_name}:${var.ghost_port}"
}

output "internal_node_url" {
  value = "http://${aws_lb.internal.dns_name}:${var.node_http_port}"
}
