variable "project_name" {
  type    = string
  default = "locus"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "zones" {
  type = list(string)
}

variable "network_cidr" {
  type = string
}

variable "subnetwork_cidr" {
  type = string
}

variable "db_name" {
  type    = string
  default = "locus_indexer"
}

variable "cluster_name" {
  type    = string
  default = "locus-mainnet"
}

variable "node_machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "node_min_replicas" {
  type    = number
  default = 3
}

variable "node_max_replicas" {
  type    = number
  default = 9
}
