module "mainnet" {
  source = "../modules/azure-mainnet"

  project_name       = var.project_name
  environment        = var.environment
  azure_location     = var.azure_location
  resource_group     = var.resource_group
  address_space      = var.address_space
  app_subnet_cidr    = var.app_subnet_cidr
  db_subnet_cidr     = var.db_subnet_cidr
  db_name            = var.db_name
  aks_cluster_name   = var.aks_cluster_name
  node_vm_size       = var.node_vm_size
  node_min_instances = var.node_min_instances
  node_max_instances = var.node_max_instances
}
