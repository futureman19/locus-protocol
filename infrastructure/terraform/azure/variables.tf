variable "project_name" {
  type    = string
  default = "locus"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "azure_location" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "address_space" {
  type = string
}

variable "app_subnet_cidr" {
  type = string
}

variable "db_subnet_cidr" {
  type = string
}

variable "db_name" {
  type    = string
  default = "locus_indexer"
}

variable "aks_cluster_name" {
  type    = string
  default = "locus-mainnet"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "node_min_instances" {
  type    = number
  default = 3
}

variable "node_max_instances" {
  type    = number
  default = 9
}
