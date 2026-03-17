locals {
  blueprint = {
    provider        = "azure"
    location        = var.azure_location
    resource_group  = var.resource_group
    network = {
      address_space = var.address_space
      app_subnet    = var.app_subnet_cidr
      db_subnet     = var.db_subnet_cidr
    }
    workloads = {
      postgres = {
        engine = "Azure Database for PostgreSQL Flexible Server"
        db_name = var.db_name
      }
      node_scale_set = {
        vm_size       = var.node_vm_size
        min_instances = var.node_min_instances
        max_instances = var.node_max_instances
      }
      container_cluster = {
        name = var.aks_cluster_name
        type = "AKS"
      }
    }
  }
}
