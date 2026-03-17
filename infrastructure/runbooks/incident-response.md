# Incident Response

## Trigger Conditions

- Public indexer health checks fail for more than 2 minutes.
- Internal ghost or node health checks fail for more than 3 minutes.
- RDS alarms fire for storage, CPU saturation, or replica lag.
- Secrets rotation or deploy fails mid-flight.

## First 15 Minutes

1. Confirm blast radius.
   - Run `bash infrastructure/scripts/backup.sh --provider aws --environment prod --wait`.
   - Check ALB target health, ECS service events, ASG instance health, and RDS status in AWS.
2. Freeze further writes.
   - Disable automated deployments.
   - Pause non-essential maintenance jobs.
3. Classify the incident.
   - `indexer-only`: API unavailable, nodes healthy.
   - `runtime-only`: ghost runtime degraded, indexer still serving.
   - `node-cluster`: internal node load balancer unhealthy.
   - `database`: RDS unavailable, replica lagging, or restore required.

## Service-Specific Response

### Indexer

- Force a new deployment of the ECS service.
- Run the indexer migration task if schema drift is suspected.
- Verify the database connection secret points at the intended host.

### Ghost Runtime

- Force a new deployment of the ghost ECS service.
- Confirm the internal ALB health target is `200` on `/health`.
- Check runtime container logs for outbound storage gateway failures.

### Node Cluster

- Inspect the node ASG instance refresh history.
- Confirm the arc credentials secret contains the current endpoint and API key.
- Start a fresh instance refresh if a secret change or bad image rollout caused the outage.

### Database

- If primary is degraded but reachable, restore service from the read replica if possible.
- If primary is unrecoverable, run `bash infrastructure/scripts/restore.sh --provider aws --environment prod --snapshot-id <snapshot-id>`.

## Exit Criteria

- Public indexer endpoint healthy.
- Internal ghost and node target groups healthy.
- RDS primary available and replica lag below alert threshold.
- Monitoring stable for at least 30 minutes.
