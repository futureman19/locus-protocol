//! Common test utilities

use ghost_runtime::runtime::config::RuntimeConfig;

pub fn test_config() -> RuntimeConfig {
    RuntimeConfig {
        server_addr: "127.0.0.1:0".into(),
        max_concurrent_ghosts: 10,
        max_memory_per_ghost: 16 * 1024 * 1024, // 16 MB
        max_execution_time_ms: 1000,
        wasm_cache_size: 100,
        ipfs_gateway: "http://localhost:5001".into(),
        arweave_gateway: "http://localhost:1984".into(),
        enable_payment_channels: true,
        log_level: "debug".into(),
    }
}

/// Helper to create a test ghost metadata
pub fn test_metadata() -> ghost_runtime::types::GhostMetadata {
    ghost_runtime::types::GhostMetadata {
        id: "ghost-001".into(),
        cid: "QmTest123".into(),
        owner: "02aabbccdd...".into(),
        location: "8f283080dcb019d".into(),
        stake: 1000000,
    }
}

/// Helper to create a test location
pub fn test_location() -> ghost_runtime::types::Location {
    ghost_runtime::types::Location::from_gps(35.6762, 139.6503)
}
