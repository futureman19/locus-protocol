variable "project_name" {
  type    = string
  default = "locus"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "availability_zones" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "allowed_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "db_name" {
  type    = string
  default = "locus_indexer"
}

variable "db_username" {
  type    = string
  default = "locus"
}

variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_replica_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_allocated_storage" {
  type    = number
  default = 200
}

variable "db_max_allocated_storage" {
  type    = number
  default = 1000
}

variable "db_engine_version" {
  type    = string
  default = "16.3"
}

variable "db_parameter_group_family" {
  type    = string
  default = "postgres16"
}

variable "release_version" {
  type    = string
  default = "latest"
}

variable "genesis_file_path" {
  type = string
}

variable "indexer_image" {
  type    = string
  default = ""
}

variable "ghost_image" {
  type    = string
  default = ""
}

variable "node_image" {
  type    = string
  default = ""
}

variable "indexer_desired_count" {
  type    = number
  default = 2
}

variable "ghost_desired_count" {
  type    = number
  default = 2
}

variable "indexer_cpu" {
  type    = number
  default = 1024
}

variable "indexer_memory" {
  type    = number
  default = 2048
}

variable "ghost_cpu" {
  type    = number
  default = 1024
}

variable "ghost_memory" {
  type    = number
  default = 2048
}

variable "node_instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "node_min_size" {
  type    = number
  default = 3
}

variable "node_desired_capacity" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 9
}

variable "node_http_port" {
  type    = number
  default = 4100
}

variable "indexer_port" {
  type    = number
  default = 3000
}

variable "ghost_port" {
  type    = number
  default = 8080
}

variable "junglebus_url" {
  type    = string
  default = "https://junglebus.gorillapool.io"
}

variable "start_block" {
  type    = number
  default = 0
}

variable "log_level" {
  type    = string
  default = "info"
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "acm_certificate_arn" {
  type    = string
  default = ""
}

variable "route53_zone_id" {
  type    = string
  default = ""
}

variable "artifact_bucket_force_destroy" {
  type    = bool
  default = false
}

variable "backup_bucket_force_destroy" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 35
}

variable "tags" {
  type    = map(string)
  default = {}
}
