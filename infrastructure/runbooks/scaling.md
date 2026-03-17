# Scaling

## Indexer

- Horizontal scaling is handled through ECS target tracking on CPU.
- Increase `indexer_desired_count`, `indexer_cpu`, or `indexer_memory` in the environment tfvars when sustained load exceeds the current auto-scaling envelope.
- If read queries dominate, move expensive reads to the replica before increasing primary instance size.

## Ghost Runtime

- Scale horizontally through ECS desired count and target tracking.
- Increase task memory before CPU if runtime failures show WASM memory exhaustion.
- Keep the ghost service behind the internal ALB only; do not expose it publicly without an explicit API policy review.

## Node Cluster

- The node ASG uses rolling instance refresh.
- Increase `node_max_size` before changing `node_desired_capacity` during event traffic spikes.
- Keep at least three nodes in production to preserve quorum-style operational redundancy.

## Database

- Use storage autoscaling for predictable growth.
- Increase the primary instance class when write throughput or connection count becomes the bottleneck.
- Add or resize replicas when indexer read pressure grows.

## Change Process

1. Update the relevant tfvars.
2. Run `bash infrastructure/scripts/deploy-mainnet.sh --provider aws --environment <env> --skip-build`.
3. Watch CloudWatch alarms and the Grafana dashboard for at least one scaling window before making another change.
