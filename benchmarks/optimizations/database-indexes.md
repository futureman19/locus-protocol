# Database Index Optimization Recommendations

## 1. Spatial Indexes (PostGIS)
To ensure fast performance for `/cities/nearby` and territory bound lookups, utilize PostGIS indexing features:

```sql
-- Core spatial index for fast distance-based bounding box queries
CREATE INDEX idx_cities_geom ON cities USING GIST (location);

-- Optional: Cluster the table based on the spatial index for sequential disk reads on geographically grouped cities
CLUSTER cities USING idx_cities_geom;
```

## 2. Heartbeat & Temporal Data
For heartbeat ingestion and time-series queries (which are append-only and heavily timestamp-reliant):

```sql
-- BRIN (Block Range Index) is highly efficient for append-only time-series data
CREATE INDEX idx_heartbeats_timestamp ON heartbeats USING BRIN (created_at);

-- Composite index for fast citizen presence tracking and history lookups
CREATE INDEX idx_heartbeats_citizen_time ON heartbeats (citizen_id, created_at DESC);
```

## 3. Core Lookups (B-Tree)
High-frequency queries must have proper standard B-Tree indexes:

```sql
-- Unique constraint lookups
CREATE UNIQUE INDEX idx_cities_founder ON cities (founder_pubkey);
CREATE INDEX idx_transactions_txid ON transactions (tx_id);
CREATE INDEX idx_citizens_city ON citizens (city_id);
```
