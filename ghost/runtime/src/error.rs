//! Error types for Ghost Runtime

use thiserror::Error;

pub type Result<T> = std::result::Result<T, GhostError>;

#[derive(Error, Debug)]
pub enum GhostError {
    #[error("WASM execution error: {0}")]
    WasmExecution(String),

    #[error("State transition error: from={from}, to={to}, reason={reason}")]
    StateTransition { from: String, to: String, reason: String },

    #[error("Invalid state: expected={expected}, actual={actual}")]
    InvalidState { expected: String, actual: String },

    #[error("Capability denied: {capability}")]
    CapabilityDenied { capability: String },

    #[error("Resource limit exceeded: {resource} = {used}/{limit}")]
    ResourceLimit { resource: String, used: u64, limit: u64 },

    #[error("Payment channel error: {0}")]
    PaymentChannel(String),

    #[error("CID loading failed: {cid} - {reason}")]
    CidLoading { cid: String, reason: String },

    #[error("Invalid manifest: {0}")]
    InvalidManifest(String),

    #[error("Timeout: {operation} exceeded {duration_ms}ms")]
    Timeout { operation: String, duration_ms: u64 },

    #[error("Cryptographic error: {0}")]
    Crypto(String),

    #[error("Location verification failed: {0}")]
    LocationVerification(String),

    #[error("Storage error: {0}")]
    Storage(String),

    #[error("Network error: {0}")]
    Network(String),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error(transparent)]
    Io(#[from] std::io::Error),

    #[error(transparent)]
    Wasmtime(#[from] wasmtime::Error),

    #[error(transparent)]
    Serialization(#[from] serde_json::Error),
}

impl GhostError {
    pub fn wasm(msg: impl Into<String>) -> Self {
        Self::WasmExecution(msg.into())
    }

    pub fn state_transition(from: &str, to: &str, reason: impl Into<String>) -> Self {
        Self::StateTransition {
            from: from.to_string(),
            to: to.to_string(),
            reason: reason.into(),
        }
    }

    pub fn capability(capability: impl Into<String>) -> Self {
        Self::CapabilityDenied {
            capability: capability.into(),
        }
    }

    pub fn resource(resource: impl Into<String>, used: u64, limit: u64) -> Self {
        Self::ResourceLimit {
            resource: resource.into(),
            used,
            limit,
        }
    }
}
