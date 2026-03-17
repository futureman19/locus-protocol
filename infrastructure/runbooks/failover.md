# Failover

## Database Failover

1. Identify the latest good snapshot or point-in-time restore target.
2. Execute:
   - `bash infrastructure/scripts/restore.sh --provider aws --environment prod --snapshot-id <snapshot-id>`
3. Wait for the restore to complete and verify:
   - the restored DB instance is `available`
   - the `indexer-db-connection` secret has been updated
   - the indexer ECS service has been force-redeployed
4. Validate:
   - `GET /health` returns `200`
   - indexer resumes from the expected block height
5. Reconcile Terraform state after the incident window.
   - The restore flow intentionally prioritizes service recovery over immediate IaC convergence.

## Node Cluster Failover

1. Confirm the internal node ALB target group is unhealthy.
2. Start an ASG instance refresh.
3. If the active image is bad, redeploy with the previous `release_version`.
4. If ARC credentials changed, run `bash infrastructure/scripts/rotate-keys.sh --provider aws --environment prod --target arc`.

## Ghost Runtime Failover

1. Force a new ECS deployment.
2. If the container image is bad, re-run deployment with the previous release tag.
3. If the internal ALB is healthy but invocation latency remains high, scale the ECS service first and inspect runtime logs second.
