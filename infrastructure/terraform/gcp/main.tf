module "mainnet" {
  source = "../modules/gcp-mainnet"

  project_name        = var.project_name
  environment         = var.environment
  gcp_project_id      = var.gcp_project_id
  gcp_region          = var.gcp_region
  zones               = var.zones
  network_cidr        = var.network_cidr
  subnetwork_cidr     = var.subnetwork_cidr
  db_name             = var.db_name
  cluster_name        = var.cluster_name
  node_machine_type   = var.node_machine_type
  node_min_replicas   = var.node_min_replicas
  node_max_replicas   = var.node_max_replicas
}
