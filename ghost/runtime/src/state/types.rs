//! State types for Schrödinger state machine

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fmt;

/// The three Schrödinger states of a ghost
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum GhostState {
    /// State 1: Dormant - on-chain UTXO
    Dormant {
        ghost_id: String,
        metadata: super::super::types::GhostMetadata,
        last_heartbeat: Option<u64>,
    },

    /// State 2: Potential - content-addressed storage
    Potential {
        ghost_id: String,
        metadata: super::super::types::GhostMetadata,
        cid: String,                 // IPFS/Arweave CID
        manifest: GhostManifest,     // Loaded manifest
        cached_at: u64,              // Timestamp
        expires_at: Option<u64>,     // Cache expiration
    },

    /// State 3: Manifest - running in WASM sandbox
    Manifest {
        ghost_id: String,
        metadata: super::super::types::GhostMetadata,
        cid: String,
        manifest: GhostManifest,
        instance_id: String,         // Unique runtime instance
        started_at: u64,             // When manifested
        capabilities_granted: Vec<String>,
        payment_channel: Option<PaymentChannelState>,
        resource_usage: ResourceUsage,
    },
}

impl GhostState {
    pub fn state_name(&self) -> &'static str {
        match self {
            GhostState::Dormant { .. } => "dormant",
            GhostState::Potential { .. } => "potential",
            GhostState::Manifest { .. } => "manifest",
        }
    }

    pub fn ghost_id(&self) -> &str {
        match self {
            GhostState::Dormant { ghost_id, .. } => ghost_id,
            GhostState::Potential { ghost_id, .. } => ghost_id,
            GhostState::Manifest { ghost_id, .. } => ghost_id,
        }
    }
}

/// Ghost manifest (loaded from IPFS/Arweave)
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GhostManifest {
    pub protocol: String,
    pub version: u32,
    pub id: String,
    pub name: String,
    #[serde(rename = "type")]
    pub ghost_type: String,
    pub description: Option<String>,
    pub owner: String,           // Public key
    pub location: String,        // H3 index
    pub stake: u64,              // Satoshis staked
    pub wasm_hash: String,       // SHA-256 of WASM binary
    pub assets_hash: Option<String>,
    pub capabilities: Vec<String>,
    pub limits: ResourceLimits,
    pub fees: FeeStructure,
    #[serde(default)]
    pub api_whitelist: Vec<String>,
}

/// Resource limits for ghost execution
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ResourceLimits {
    #[serde(deserialize_with = "deserialize_memory")]
    pub max_memory: u64,         // bytes
    #[serde(deserialize_with = "deserialize_duration")]
    pub max_execution_time: u64, // milliseconds
    #[serde(deserialize_with = "deserialize_memory")]
    pub max_storage: u64,        // bytes
    #[serde(default)]
    pub max_syscalls: Option<u32>,
    #[serde(default)]
    pub max_network_requests: Option<u32>,
}

impl Default for ResourceLimits {
    fn default() -> Self {
        Self {
            max_memory: 64 * 1024 * 1024,      // 64 MB
            max_execution_time: 5000,          // 5 seconds
            max_storage: 10 * 1024 * 1024,     // 10 MB
            max_syscalls: Some(1000),
            max_network_requests: Some(10),
        }
    }
}

/// Fee structure for ghost interactions
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FeeStructure {
    #[serde(default)]
    pub interaction: u64,        // Satoshis per interaction
    #[serde(default)]
    pub session: u64,            // Satoshis per session
    #[serde(default)]
    pub per_second: Option<u64>, // Streaming fee
}

impl Default for FeeStructure {
    fn default() -> Self {
        Self {
            interaction: 0,
            session: 0,
            per_second: None,
        }
    }
}

/// Payment channel state for active session
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PaymentChannelState {
    pub channel_id: String,
    pub user_pubkey: String,
    pub ghost_pubkey: String,
    pub arbiter_pubkey: String,
    pub total_funding: u64,      // Total satoshis in channel
    pub user_balance: u64,
    pub ghost_balance: u64,
    pub state_sequence: u64,     // State number for updates
    pub is_open: bool,
    pub opened_at: u64,
    pub expires_at: u64,
}

/// Resource usage tracking
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct ResourceUsage {
    pub memory_used: u64,
    pub cpu_time_ms: u64,
    pub storage_used: u64,
    pub syscalls_used: u32,
    pub network_requests_used: u32,
    pub interactions_count: u32,
}

/// State transition request
#[derive(Debug, Clone)]
pub enum StateTransition {
    /// Dormant -> Potential: User approaches
    Approach {
        ghost_id: String,
        user_location: super::super::types::Location,
    },

    /// Potential -> Manifest: Load and execute
    Manifest {
        ghost_id: String,
        user_pubkey: String,
        capabilities_requested: Vec<String>,
        payment_deposit: Option<u64>,
    },

    /// Manifest -> Potential: User leaves
    Leave {
        ghost_id: String,
        final_channel_state: Option<PaymentChannelState>,
    },

    /// Potential -> Dormant: Timeout/cleanup
    Timeout {
        ghost_id: String,
    },

    /// Any -> Dormant: Heartbeat received
    Heartbeat {
        ghost_id: String,
        timestamp: u64,
    },
}

impl fmt::Display for StateTransition {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            StateTransition::Approach { ghost_id, .. } => {
                write!(f, "Approach({})", ghost_id)
            }
            StateTransition::Manifest { ghost_id, .. } => {
                write!(f, "Manifest({})", ghost_id)
            }
            StateTransition::Leave { ghost_id, .. } => {
                write!(f, "Leave({})", ghost_id)
            }
            StateTransition::Timeout { ghost_id } => {
                write!(f, "Timeout({})", ghost_id)
            }
            StateTransition::Heartbeat { ghost_id, .. } => {
                write!(f, "Heartbeat({})", ghost_id)
            }
        }
    }
}

/// Transition error
#[derive(Debug, Clone)]
pub struct TransitionError {
    pub from: String,
    pub to: String,
    pub reason: String,
}

impl fmt::Display for TransitionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Cannot transition from {} to {}: {}", self.from, self.to, self.reason)
    }
}

impl std::error::Error for TransitionError {}

// Helper deserializers
fn deserialize_memory<'de, D>(deserializer: D) -> std::result::Result<u64, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let s: String = serde::Deserialize::deserialize(deserializer)?;
    parse_memory(&s).map_err(serde::de::Error::custom)
}

fn deserialize_duration<'de, D>(deserializer: D) -> std::result::Result<u64, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let s: String = serde::Deserialize::deserialize(deserializer)?;
    parse_duration(&s).map_err(serde::de::Error::custom)
}

fn parse_memory(s: &str) -> anyhow::Result<u64> {
    let s = s.trim().to_uppercase();
    let (num, unit) = s
        .find(|c: char| !c.is_ascii_digit())
        .map(|i| s.split_at(i))
        .unwrap_or((&s, ""));

    let num: u64 = num.parse()?;
    let multiplier = match unit.trim() {
        "" | "B" => 1,
        "KB" | "K" => 1024,
        "MB" | "M" => 1024 * 1024,
        "GB" | "G" => 1024 * 1024 * 1024,
        _ => anyhow::bail!("Unknown unit: {}", unit),
    };

    Ok(num * multiplier)
}

fn parse_duration(s: &str) -> anyhow::Result<u64> {
    let s = s.trim().to_lowercase();
    let (num, unit) = s
        .find(|c: char| !c.is_ascii_digit())
        .map(|i| s.split_at(i))
        .unwrap_or((&s, ""));

    let num: u64 = num.parse()?;
    let multiplier = match unit.trim() {
        "" | "ms" => 1,
        "s" | "sec" | "secs" => 1000,
        "m" | "min" | "mins" => 60 * 1000,
        "h" | "hr" | "hrs" => 60 * 60 * 1000,
        _ => anyhow::bail!("Unknown unit: {}", unit),
    };

    Ok(num * multiplier)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_memory() {
        assert_eq!(parse_memory("64MB").unwrap(), 64 * 1024 * 1024);
        assert_eq!(parse_memory("10 MB").unwrap(), 10 * 1024 * 1024);
        assert_eq!(parse_memory("1024").unwrap(), 1024);
        assert_eq!(parse_memory("2GB").unwrap(), 2 * 1024 * 1024 * 1024);
    }

    #[test]
    fn test_parse_duration() {
        assert_eq!(parse_duration("5s").unwrap(), 5000);
        assert_eq!(parse_duration("5000ms").unwrap(), 5000);
        assert_eq!(parse_duration("1m").unwrap(), 60000);
    }
}
