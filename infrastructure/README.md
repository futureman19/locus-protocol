# Mainnet Infrastructure

Production infrastructure for deploying Locus Protocol on BSV mainnet.

## Layout

- `terraform/` provider-specific Terraform roots and shared modules.
- `config/environments/` environment-scoped Terraform variables, deploy env examples, and genesis documents.
- `config/monitoring/` Prometheus alert rules and Grafana dashboard JSON.
- `scripts/` deploy, backup, restore, and key-rotation automation.
- `runbooks/` operational guides for incidents, failover, and scaling.

## Deployment Model

- AWS is the primary production path in this repository.
- The indexer runs on ECS/Fargate behind a public load balancer.
- The ghost WASM runtime runs on ECS/Fargate behind an internal load balancer.
- Elixir reference nodes run in an auto-scaling group behind an internal health-checked load balancer.
- PostgreSQL uses an encrypted Multi-AZ primary with a read replica for read-heavy indexer workloads.
- Secrets live in AWS Secrets Manager and are injected into workloads at runtime.

## Configuration Flow

1. Copy the relevant `mainnet.env.example` into a real `mainnet.env` file outside version control.
2. Review the provider tfvars under `config/environments/<env>/`.
3. Edit the environment genesis document before launch.
4. Run `bash infrastructure/scripts/deploy-mainnet.sh --provider aws --environment prod`.

## Notes

- The Terraform expects image builds from the repository-local Dockerfiles for `indexer/`, `ghost/runtime/`, and `node/`.
- The deploy script bootstraps container registries, pushes images, syncs secrets, applies Terraform, and runs the indexer migration task.
- The restore flow deliberately updates the application-facing database connection secret instead of mutating the Terraform-managed database resource in place.
