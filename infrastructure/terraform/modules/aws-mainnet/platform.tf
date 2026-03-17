resource "aws_kms_key" "platform" {
  description             = "KMS key for ${local.name_prefix} platform encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "platform" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.platform.key_id
}

resource "aws_ecr_repository" "indexer" {
  name                 = "${var.project_name}/${var.environment}/indexer"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.platform.arn
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "ghost" {
  name                 = "${var.project_name}/${var.environment}/ghost-runtime"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.platform.arn
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "node" {
  name                 = "${var.project_name}/${var.environment}/node"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.platform.arn
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "indexer" {
  repository = aws_ecr_repository.indexer.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain latest 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "ghost" {
  repository = aws_ecr_repository.ghost.name
  policy     = aws_ecr_lifecycle_policy.indexer.policy
}

resource "aws_ecr_lifecycle_policy" "node" {
  repository = aws_ecr_repository.node.name
  policy     = aws_ecr_lifecycle_policy.indexer.policy
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.artifacts_bucket
  force_destroy = var.artifact_bucket_force_destroy
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.platform.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "backups" {
  bucket        = local.backup_bucket
  force_destroy = var.backup_bucket_force_destroy
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.platform.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.backup_retention_days
    }
  }
}

resource "aws_s3_object" "genesis" {
  bucket       = aws_s3_bucket.artifacts.id
  key          = "genesis/${var.environment}/genesis.json"
  source       = var.genesis_file_path
  etag         = filemd5(var.genesis_file_path)
  content_type = "application/json"
}

resource "aws_secretsmanager_secret" "arc_credentials" {
  name                    = "${local.name_prefix}/arc-credentials"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.platform.arn
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret" "indexer_runtime" {
  name                    = "${local.name_prefix}/indexer-runtime"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.platform.arn
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret" "protocol_keys" {
  name                    = "${local.name_prefix}/protocol-keys"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.platform.arn
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret" "indexer_db_connection" {
  name                    = "${local.name_prefix}/indexer-db-connection"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.platform.arn
  tags                    = local.common_tags
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = values(aws_subnet.private)[*].id
  tags       = local.common_tags
}

resource "aws_db_parameter_group" "main" {
  name   = "${local.name_prefix}-postgres"
  family = var.db_parameter_group_family

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = local.common_tags
}

resource "aws_db_instance" "indexer" {
  identifier                      = "${local.name_prefix}-indexer"
  engine                          = "postgres"
  engine_version                  = var.db_engine_version
  instance_class                  = var.db_instance_class
  allocated_storage               = var.db_allocated_storage
  max_allocated_storage           = var.db_max_allocated_storage
  db_name                         = var.db_name
  username                        = var.db_username
  manage_master_user_password     = true
  multi_az                        = true
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.platform.arn
  backup_retention_period         = var.backup_retention_days
  auto_minor_version_upgrade      = true
  apply_immediately               = true
  deletion_protection             = var.environment == "prod"
  skip_final_snapshot             = true
  copy_tags_to_snapshot           = true
  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  parameter_group_name            = aws_db_parameter_group.main.name
  publicly_accessible             = false
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.platform.arn
  tags                            = local.common_tags
}

resource "aws_db_instance" "indexer_replica" {
  identifier                 = "${local.name_prefix}-indexer-replica"
  replicate_source_db        = aws_db_instance.indexer.identifier
  instance_class             = var.db_replica_instance_class
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  apply_immediately          = true
  storage_encrypted          = true
  kms_key_id                 = aws_kms_key.platform.arn
  copy_tags_to_snapshot      = true
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  tags                       = local.common_tags
}

resource "aws_cloudwatch_log_group" "indexer" {
  name              = "/${local.name_prefix}/indexer"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.platform.arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "ghost" {
  name              = "/${local.name_prefix}/ghost-runtime"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.platform.arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "node" {
  name              = "/${local.name_prefix}/node"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.platform.arn
  tags              = local.common_tags
}
