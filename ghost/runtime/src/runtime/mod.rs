//! Core Ghost Runtime - WASM execution environment

mod config;
mod engine;
mod limits;

pub use config::RuntimeConfig;
pub use engine::RuntimeEngine;
pub use limits::ResourceLimiter;

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info, instrument, warn};

use crate::error::{GhostError, Result};
use crate::host::HostFunctions;
use crate::state::{GhostState, StateMachine, StateManager, StateTransition};
use crate::storage::cid_loader::CidLoader;
use crate::types::{GhostMetadata, InvocationRequest, InvocationResponse, ResourceUsage};

/// The main Ghost Runtime that manages WASM execution
#[derive(Debug)]
pub struct GhostRuntime {
    config: RuntimeConfig,
    engine: Arc<RuntimeEngine>,
    state_manager: StateManager,
    state_machine: StateMachine,
    cid_loader: Arc<CidLoader>,
    invocation_count: Arc<RwLock<u64>>,
}

impl GhostRuntime {
    pub async fn new(config: RuntimeConfig, cid_loader: Arc<CidLoader>) -> Result<Self> {
        let engine = Arc::new(RuntimeEngine::new(&config)?);
        
        Ok(Self {
            config,
            engine,
            state_manager: StateManager::new(),
            state_machine: StateMachine::new(),
            cid_loader,
            invocation_count: Arc::new(RwLock::new(0)),
        })
    }

    /// Invoke a ghost - main entry point
    #[instrument(skip(self, request))]
    pub async fn invoke(&self, request: InvocationRequest) -> Result<InvocationResponse> {
        info!("Invoking ghost {} for user {}", request.ghost_id, request.user_pubkey);

        // 1. Get or create ghost state
        let state = self.get_or_load_ghost_state(&request.ghost_id).await?;

        // 2. Transition: Dormant -> Potential -> Manifest
        let manifest_state = self.manifest_ghost(state, &request).await?;

        // 3. Execute WASM
        let execution_result = self.execute_wasm(&manifest_state, &request).await;

        // 4. Update resource usage
        self.update_resource_usage(&request.ghost_id, &manifest_state).await;

        // 5. Build response
        let response = match execution_result {
            Ok(result) => InvocationResponse {
                ghost_id: request.ghost_id.clone(),
                instance_id: self.get_instance_id(&manifest_state),
                result,
                payment_charged: self.calculate_payment(&manifest_state, &request),
                execution_time_ms: 0, // TODO: track
                resource_usage: ResourceUsage::default(), // TODO: track
            },
            Err(e) => {
                error!("WASM execution failed: {}", e);
                return Err(e);
            }
        };

        // 6. Increment invocation counter
        let mut count = self.invocation_count.write().await;
        *count += 1;

        info!("Ghost {} invocation completed", request.ghost_id);
        Ok(response)
    }

    /// Load ghost state or initialize from blockchain
    async fn get_or_load_ghost_state(&self, ghost_id: &str) -> Result<GhostState> {
        // Check if already tracked
        if let Some(state) = self.state_manager.get_state(ghost_id).await {
            debug!("Found existing state for ghost {}", ghost_id);
            return Ok(state);
        }

        // Load from blockchain/storage
        info!("Loading ghost {} from storage", ghost_id);
        let metadata = self.load_ghost_metadata(ghost_id).await?;

        // Register in Dormant state
        self.state_manager
            .register_ghost(ghost_id.to_string(), metadata)
            .await;

        self.state_manager
            .get_state(ghost_id)
            .await
            .ok_or_else(|| GhostError::wasm("Failed to load ghost state"))
    }

    /// Transition ghost to Manifest state
    async fn manifest_ghost(
        &self,
        state: GhostState,
        request: &InvocationRequest,
    ) -> Result<GhostState> {
        let ghost_id = request.ghost_id.clone();

        // Step 1: Dormant -> Potential (if needed)
        let potential_state = match state {
            GhostState::Dormant { .. } => {
                info!("Transitioning ghost {} from Dormant to Potential", ghost_id);
                
                // Load manifest from CID
                let manifest = self.cid_loader.load_manifest(&state).await?;
                
                let transition = StateTransition::Approach {
                    ghost_id: ghost_id.clone(),
                    user_location: request.user_location.clone(),
                };

                // Manually create Potential state
                GhostState::Potential {
                    ghost_id: ghost_id.clone(),
                    metadata: self.extract_metadata(&state),
                    cid: self.extract_cid(&state),
                    manifest,
                    cached_at: now(),
                    expires_at: Some(now() + 3600),
                }
            }
            GhostState::Potential { .. } => state,
            GhostState::Manifest { .. } => return Ok(state),
        };

        // Step 2: Potential -> Manifest
        let manifest_state = match potential_state {
            GhostState::Potential { .. } => {
                info!("Transitioning ghost {} from Potential to Manifest", ghost_id);
                
                let transition = StateTransition::Manifest {
                    ghost_id: ghost_id.clone(),
                    user_pubkey: request.user_pubkey.clone(),
                    capabilities_requested: request.capabilities_requested.clone(),
                    payment_deposit: request.payment_deposit,
                };

                self.state_machine.transition(&potential_state, transition)?
            }
            _ => potential_state,
        };

        // Update state manager
        self.state_manager
            .update_state(&ghost_id, manifest_state.clone())
            .await;

        Ok(manifest_state)
    }

    /// Execute the WASM module
    async fn execute_wasm(
        &self,
        state: &GhostState,
        request: &InvocationRequest,
    ) -> Result<Vec<u8>> {
        let GhostState::Manifest { manifest, capabilities_granted, .. } = state else {
            return Err(GhostError::InvalidState {
                expected: "manifest".into(),
                actual: state.state_name().into(),
            });
        };

        // Load WASM binary from CID
        let wasm_bytes = self.cid_loader.load_wasm(&manifest.wasm_hash).await?;

        // Create host functions with granted capabilities
        let host = HostFunctions::new(
            capabilities_granted.clone(),
            request.user_location.clone(),
        );

        // Execute in sandbox
        self.engine
            .execute(
                &wasm_bytes,
                &request.action,
                &request.payload,
                host,
                &manifest.limits,
            )
            .await
    }

    /// Handle user leaving - transition back to Potential/Dormant
    pub async fn leave(&self, ghost_id: &str) -> Result<()> {
        info!("User leaving ghost {}", ghost_id);

        let state = self
            .state_manager
            .get_state(ghost_id)
            .await
            .ok_or_else(|| GhostError::wasm("Ghost not found"))?;

        let transition = StateTransition::Leave {
            ghost_id: ghost_id.to_string(),
            final_channel_state: None, // TODO: get from state
        };

        let new_state = self.state_machine.transition(&state, transition)?;
        self.state_manager.update_state(ghost_id, new_state).await;

        Ok(())
    }

    /// Get runtime statistics
    pub async fn get_stats(&self) -> RuntimeStats {
        let invocations = *self.invocation_count.read().await;
        let state_counts = self.state_manager.count_by_state().await;

        RuntimeStats {
            invocations,
            dormant_count: state_counts.get("dormant").copied().unwrap_or(0),
            potential_count: state_counts.get("potential").copied().unwrap_or(0),
            manifest_count: state_counts.get("manifest").copied().unwrap_or(0),
        }
    }

    // Helper methods

    async fn load_ghost_metadata(&self, ghost_id: &str) -> Result<GhostMetadata> {
        // TODO: Load from blockchain or local index
        Ok(GhostMetadata {
            id: ghost_id.to_string(),
            cid: format!("Qm{}", ghost_id),
            owner: "02abc".into(),
            location: "8f283080dcb019d".into(),
            stake: 1000000,
        })
    }

    fn extract_metadata(&self, state: &GhostState) -> GhostMetadata {
        match state {
            GhostState::Dormant { metadata, .. } => metadata.clone(),
            GhostState::Potential { metadata, .. } => metadata.clone(),
            GhostState::Manifest { metadata, .. } => metadata.clone(),
        }
    }

    fn extract_cid(&self, state: &GhostState) -> String {
        match state {
            GhostState::Dormant { metadata, .. } => metadata.cid.clone(),
            GhostState::Potential { cid, .. } => cid.clone(),
            GhostState::Manifest { cid, .. } => cid.clone(),
        }
    }

    fn get_instance_id(&self, state: &GhostState) -> String {
        match state {
            GhostState::Manifest { instance_id, .. } => instance_id.clone(),
            _ => "unknown".into(),
        }
    }

    fn calculate_payment(&self, state: &GhostState, request: &InvocationRequest) -> u64 {
        match state {
            GhostState::Manifest { manifest, .. } => {
                manifest.fees.interaction + request.payment_deposit.unwrap_or(0)
            }
            _ => 0,
        }
    }

    async fn update_resource_usage(&self, _ghost_id: &str, _state: &GhostState) {
        // TODO: Track resource usage
    }
}

/// Runtime statistics
#[derive(Debug, Clone)]
pub struct RuntimeStats {
    pub invocations: u64,
    pub dormant_count: usize,
    pub potential_count: usize,
    pub manifest_count: usize,
}

fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs()
}
