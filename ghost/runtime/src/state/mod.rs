//! Schrödinger State Machine for Ghost Lifecycle
//!
//! Three states:
//! - Dormant: On-chain UTXO (minimal state)
//! - Potential: Off-chain, content-addressed (IPFS/Arweave)
//! - Manifest: Running locally in WASM sandbox

mod machine;
mod types;

pub use machine::StateMachine;
pub use types::{GhostState, StateTransition, TransitionError};

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// State manager for tracking multiple ghost instances
#[derive(Debug, Clone)]
pub struct StateManager {
    states: Arc<RwLock<HashMap<String, GhostState>>>,
}

impl StateManager {
    pub fn new() -> Self {
        Self {
            states: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Get current state of a ghost
    pub async fn get_state(&self, ghost_id: &str) -> Option<GhostState> {
        let states = self.states.read().await;
        states.get(ghost_id).cloned()
    }

    /// Register a new ghost in Dormant state
    pub async fn register_ghost(&self, ghost_id: String, metadata: super::types::GhostMetadata) {
        let mut states = self.states.write().await;
        states.insert(
            ghost_id.clone(),
            GhostState::Dormant {
                ghost_id,
                metadata,
                last_heartbeat: None,
            },
        );
    }

    /// Update state for a ghost
    pub async fn update_state(&self, ghost_id: &str, new_state: GhostState) {
        let mut states = self.states.write().await;
        states.insert(ghost_id.to_string(), new_state);
    }

    /// Remove ghost from tracking
    pub async fn unregister_ghost(&self, ghost_id: &str) {
        let mut states = self.states.write().await;
        states.remove(ghost_id);
    }

    /// Get all ghosts in Manifest state (active)
    pub async fn get_manifest_ghosts(&self) -> Vec<GhostState> {
        let states = self.states.read().await;
        states
            .values()
            .filter(|s| matches!(s, GhostState::Manifest { .. }))
            .cloned()
            .collect()
    }

    /// Get count by state
    pub async fn count_by_state(&self) -> HashMap<String, usize> {
        let states = self.states.read().await;
        let mut counts = HashMap::new();
        
        for state in states.values() {
            let key = match state {
                GhostState::Dormant { .. } => "dormant",
                GhostState::Potential { .. } => "potential",
                GhostState::Manifest { .. } => "manifest",
            };
            *counts.entry(key.to_string()).or_insert(0) += 1;
        }
        
        counts
    }
}

impl Default for StateManager {
    fn default() -> Self {
        Self::new()
    }
}
