# System Bottlenecks & Analysis

## 1. Core Elixir/Erlang Bottlenecks
- **Transaction Validation**: Cryptographic signature verification is highly CPU-bound. Processing thousands of incoming blocks or transactions may choke the Erlang scheduler.
  - *Recommendation*: Offload signature verification to a NIF (Rustler) for parallel batch verification or implement secp256k1 validation in a dedicated worker pool.
- **State Synchronization**: Mnesia or ETS state sync under heavy load can delay consensus.
  - *Recommendation*: Shard state by territory hex grids (H3) to minimize cross-node messaging and maintain strict boundaries for state updates.

## 2. Indexer (Node.js/PostgreSQL) Bottlenecks
- **Heartbeat Ingestion Rate**: Inserting millions of heartbeats per minute will lock tables or cause heavy WAL writes in Postgres.
  - *Recommendation*: Use Redis streams or Kafka for an ingestion buffer, and batch-insert into PostgreSQL using `COPY` commands or unlogged tables for ephemeral presence data.
- **Event Parsing**: Parsing raw chain blocks in TypeScript can bottleneck the main event loop.
  - *Recommendation*: Maintain a dedicated block-parsing worker pool using Node.js `worker_threads` to parse and format block transactions asynchronously.

## 3. WASM Runtime Bottlenecks
- **Cold Starts**: Compiling WASM modules and allocating isolated memory regions upon first invocation takes time.
  - *Recommendation*: Pre-warm runtime instances for highly active ghosts, or utilize module caching natively via Wasmtime's `Module::deserialize` to bypass compilation.
- **Memory Footprint**: Keeping too many concurrent WASM memory instances active can exhaust host RAM.
  - *Recommendation*: Implement an aggressive eviction policy (LRU) for dormant ghosts and enforce strict memory limits (e.g., max 2MB per instance) unless extended via specific stake tiers.
