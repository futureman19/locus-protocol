# Locus Protocol Performance Benchmarks

## 1. Transaction Throughput
Target metrics for core protocol transactions and capacity.

| Metric | Target (tx/s) | Actual (tx/s) | p95 Latency | Status |
|---|---|---|---|---|
| City Founding | 100 | TBD | < 200ms | Pending |
| Citizen Join Burst | 500 | TBD | < 500ms | Pending |
| Heartbeat Ingestion | 5000 | TBD | < 50ms | Pending |

## 2. Query Performance
Database and API query performance indicators.

| Metric | Target | Actual | p95 Latency | Status |
|---|---|---|---|---|
| Spatial Query (`/cities/nearby`) | 1000 req/s | TBD | < 100ms | Pending |
| City State Retrieval | 2000 req/s | TBD | < 20ms | Pending |
| Cache Hit Rate | > 85% | TBD | N/A | Pending |

## 3. WASM Runtime (Ghost)
Execution limits and WASM machine targets.

| Metric | Target | Actual | Status |
|---|---|---|---|
| Ghost Cold Start (Dormant -> Manifest) | < 100ms | TBD | Pending |
| Concurrent Executions Limits | 10k instances | TBD | Pending |
| Memory Usage per Ghost Type | < 2MB | TBD | Pending |
| Payment Channel Throughput | 500 tx/s | TBD | Pending |

## Execution
We use `k6` for load testing. Install dependencies in the `benchmarks` directory, then run the npm scripts:

```bash
cd benchmarks
npm run bench:all
```
