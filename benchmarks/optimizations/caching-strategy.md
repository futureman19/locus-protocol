# Caching Strategy Recommendations

## 1. Cache Hit Rate Targets
- **Static Assets/Metadata**: > 95%
- **City State (Aggregate Data)**: > 85%
- **User Presence (Heartbeats)**: > 70%

## 2. Redis Integration Approaches
To achieve the targets and offload the Postgres database during read-heavy operations:

### City State Caching
- **Pattern**: Write-Through Cache.
- **Keys**: `city:{id}:state`
- **Invalidation**: Whenever a transaction mutates the city state, update the Redis key synchronously alongside persisting to the database.

### Spatial Query Caching
- **Pattern**: Time-To-Live (TTL) / Geohash Bucketing.
- **Implementation**: Map query bounding boxes or coordinates to H3 resolution 4 or 5 indices. Cache the list of city IDs residing in that H3 index in Redis (`h3:{index}:cities`).
- **TTL**: 5 minutes, as new city creation is relatively infrequent compared to read loads.

### Heartbeat Debouncing
- **Problem**: Storing every heartbeat directly to the database overwhelms the IO.
- **Solution**: Store the latest heartbeat timestamp per citizen directly in Redis (`citizen:{id}:last_hb`). Only flush the update to PostgreSQL if `current_time - last_hb > 5 minutes`. Use Redis to serve real-time presence checks.
