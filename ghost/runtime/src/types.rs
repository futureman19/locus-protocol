//! Core types for Ghost Runtime

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Ghost metadata from blockchain UTXO
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GhostMetadata {
    pub id: String,
    pub cid: String,              // IPFS/Arweave CID
    pub owner: String,            // Public key
    pub location: String,         // H3 index
    pub stake: u64,               // Satoshis staked
}

/// Geographic location
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Location {
    pub lat: f64,
    pub lng: f64,
    pub h3_index: String,         // H3 hex index
}

impl Location {
    /// Create location from lat/lng at H3 resolution 12 (~3m precision)
    pub fn from_gps(lat: f64, lng: f64) -> Self {
        // TODO: Use h3o to convert to H3 index
        Self {
            lat,
            lng,
            h3_index: format!("{:016x}", ((lat as i64) << 32) | (lng as i64)),
        }
    }

    /// Get parent H3 index at lower resolution
    pub fn parent_at_resolution(&self, _res: u8) -> String {
        // TODO: Implement with h3o
        self.h3_index.clone()
    }
}

/// Ghost invocation request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InvocationRequest {
    pub ghost_id: String,
    pub user_pubkey: String,
    pub user_location: Location,
    pub action: String,           // Function to call
    pub payload: Vec<u8>,         // Serialized parameters
    pub capabilities_requested: Vec<String>,
    pub payment_deposit: Option<u64>,
    pub nonce: u64,               // Anti-replay
}

/// Ghost invocation response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InvocationResponse {
    pub ghost_id: String,
    pub instance_id: String,
    pub result: Vec<u8>,
    pub payment_charged: u64,
    pub execution_time_ms: u64,
    pub resource_usage: ResourceUsage,
}

/// Resource usage statistics
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ResourceUsage {
    pub memory_bytes: u64,
    pub cpu_time_ms: u64,
    pub storage_bytes: u64,
    pub syscalls: u32,
    pub network_requests: u32,
}

/// Payment channel update
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaymentChannelUpdate {
    pub channel_id: String,
    pub ghost_balance: u64,
    pub user_balance: u64,
    pub sequence: u64,
    pub signature: Vec<u8>,       // User signature
}

/// Capability request/response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapabilityRequest {
    pub capability: String,
    pub params: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapabilityResponse {
    pub capability: String,
    pub granted: bool,
    pub reason: Option<String>,
    pub data: Option<serde_json::Value>,
}

/// Ghost execution context passed to WASM
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionContext {
    pub ghost_id: String,
    pub user_pubkey: String,
    pub invocation_id: String,
    pub timestamp: u64,
    pub block_height: u32,
    pub capabilities: Vec<String>,
    pub limits: ExecutionLimits,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionLimits {
    pub max_memory: u64,
    pub max_execution_time_ms: u64,
    pub max_storage: u64,
    pub max_syscalls: u32,
    pub max_network_requests: u32,
}

impl Default for ExecutionLimits {
    fn default() -> Self {
        Self {
            max_memory: 64 * 1024 * 1024,      // 64 MB
            max_execution_time_ms: 5000,       // 5 seconds
            max_storage: 10 * 1024 * 1024,     // 10 MB
            max_syscalls: 1000,
            max_network_requests: 10,
        }
    }
}

/// Runtime status information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuntimeStatus {
    pub version: String,
    pub uptime_seconds: u64,
    pub active_ghosts: usize,
    pub total_invocations: u64,
    pub total_fees_collected: u64,
    pub memory_usage_bytes: u64,
}

/// Error response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorResponse {
    pub code: String,
    pub message: String,
    pub details: Option<serde_json::Value>,
}
