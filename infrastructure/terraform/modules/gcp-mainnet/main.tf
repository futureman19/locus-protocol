locals {
  blueprint = {
    provider = "gcp"
    project  = var.gcp_project_id
    region   = var.gcp_region
    network = {
      cidr       = var.network_cidr
      subnetwork = var.subnetwork_cidr
    }
    workloads = {
      postgres = {
        engine = "Cloud SQL PostgreSQL"
        db_name = var.db_name
      }
      node_group = {
        machine_type = var.node_machine_type
        min_replicas = var.node_min_replicas
        max_replicas = var.node_max_replicas
      }
      container_cluster = {
        name  = var.cluster_name
        zones = var.zones
      }
    }
  }
}
