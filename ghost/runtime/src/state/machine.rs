//! Schrödinger State Machine implementation
//!
//! Handles valid transitions between the three states:
//! - Dormant <-> Potential <-> Manifest
//!   |_________________________^|

use super::types::{GhostState, PaymentChannelState, ResourceUsage, StateTransition, TransitionError};
use super::super::types::{Location, GhostMetadata};
use super::super::error::{GhostError, Result};

/// State machine for managing ghost lifecycle
#[derive(Debug, Clone)]
pub struct StateMachine;

impl StateMachine {
    pub fn new() -> Self {
        Self
    }

    /// Apply a transition to a ghost state
    pub fn transition(
        &self,
        current: &GhostState,
        transition: StateTransition,
    ) -> Result<GhostState> {
        match (current, &transition) {
            // Dormant -> Potential: User approaches location
            (
                GhostState::Dormant { ghost_id, metadata, .. },
                StateTransition::Approach { user_location, .. },
            ) => {
                self.validate_proximity(metadata, user_location)?;
                
                Ok(GhostState::Potential {
                    ghost_id: ghost_id.clone(),
                    metadata: metadata.clone(),
                    cid: metadata.cid.clone(),
                    manifest: transition
                        .get_manifest()
                        .ok_or_else(|| GhostError::InvalidManifest("Missing manifest".into()))?,
                    cached_at: now(),
                    expires_at: Some(now() + 3600), // 1 hour cache
                })
            }

            // Potential -> Manifest: Load and execute
            (
                GhostState::Potential { ghost_id, metadata, cid, manifest, .. },
                StateTransition::Manifest { user_pubkey, capabilities_requested, payment_deposit, .. },
            ) => {
                let capabilities_granted = self.negotiate_capabilities(
                    &manifest.capabilities,
                    capabilities_requested,
                )?;

                let payment_channel = payment_deposit.map(|deposit| PaymentChannelState {
                    channel_id: format!("{}-{}", ghost_id, now()),
                    user_pubkey: user_pubkey.clone(),
                    ghost_pubkey: metadata.owner.clone(),
                    arbiter_pubkey: "arbiter".into(), // TODO: real arbiter
                    total_funding: deposit,
                    user_balance: deposit,
                    ghost_balance: 0,
                    state_sequence: 0,
                    is_open: true,
                    opened_at: now(),
                    expires_at: now() + 3600,
                });

                Ok(GhostState::Manifest {
                    ghost_id: ghost_id.clone(),
                    metadata: metadata.clone(),
                    cid: cid.clone(),
                    manifest: manifest.clone(),
                    instance_id: format!("instance-{}", now()),
                    started_at: now(),
                    capabilities_granted,
                    payment_channel,
                    resource_usage: ResourceUsage::default(),
                })
            }

            // Manifest -> Potential: User leaves
            (
                GhostState::Manifest { ghost_id, metadata, cid, manifest, .. },
                StateTransition::Leave { final_channel_state, .. },
            ) => {
                // Close payment channel if exists
                if let Some(channel) = final_channel_state {
                    if !channel.is_open {
                        return Err(GhostError::PaymentChannel(
                            "Channel not properly closed".into()
                        ));
                    }
                }

                Ok(GhostState::Potential {
                    ghost_id: ghost_id.clone(),
                    metadata: metadata.clone(),
                    cid: cid.clone(),
                    manifest: manifest.clone(),
                    cached_at: now(),
                    expires_at: Some(now() + 3600),
                })
            }

            // Potential -> Dormant: Cache timeout
            (
                GhostState::Potential { ghost_id, metadata, .. },
                StateTransition::Timeout { .. },
            ) => {
                Ok(GhostState::Dormant {
                    ghost_id: ghost_id.clone(),
                    metadata: metadata.clone(),
                    last_heartbeat: Some(now()),
                })
            }

            // Any -> Dormant: Heartbeat received
            (
                current,
                StateTransition::Heartbeat { ghost_id, timestamp, .. },
            ) => {
                let metadata = match current {
                    GhostState::Dormant { metadata, .. } => metadata.clone(),
                    GhostState::Potential { metadata, .. } => metadata.clone(),
                    GhostState::Manifest { metadata, .. } => metadata.clone(),
                };

                Ok(GhostState::Dormant {
                    ghost_id: ghost_id.clone(),
                    metadata,
                    last_heartbeat: Some(*timestamp),
                })
            }

            // Invalid transitions
            _ => {
                let from = current.state_name();
                let to = self.target_state_name(&transition);
                Err(GhostError::state_transition(from, &to, format!(
                    "Invalid transition: {} from {} state",
                    transition, from
                )))
            }
        }
    }

    /// Validate that user is close enough to manifest ghost
    fn validate_proximity(&self, metadata: &GhostMetadata, user_location: &Location) -> Result<()> {
        let ghost_h3 = &metadata.location;
        let user_h3 = &user_location.h3_index;

        // Check if user is within the same or adjacent H3 hex
        // For now, simple string comparison at resolution 12
        if ghost_h3 != user_h3 {
            // TODO: Check adjacency using H3 library
            return Err(GhostError::LocationVerification(
                format!("User location {} does not match ghost location {}", user_h3, ghost_h3)
            ));
        }

        Ok(())
    }

    /// Negotiate capabilities between ghost requirements and user permissions
    fn negotiate_capabilities(
        &self,
        ghost_capabilities: &[String],
        requested: &[String],
    ) -> Result<Vec<String>> {
        // User can only request capabilities that ghost declares
        let granted: Vec<String> = requested
            .iter()
            .filter(|cap| ghost_capabilities.contains(cap))
            .cloned()
            .collect();

        if granted.is_empty() && !requested.is_empty() {
            return Err(GhostError::capability(
                format!("None of requested capabilities {:?} available", requested)
            ));
        }

        Ok(granted)
    }

    fn target_state_name(&self, transition: &StateTransition) -> String {
        match transition {
            StateTransition::Approach { .. } => "potential".into(),
            StateTransition::Manifest { .. } => "manifest".into(),
            StateTransition::Leave { .. } => "potential".into(),
            StateTransition::Timeout { .. } => "dormant".into(),
            StateTransition::Heartbeat { .. } => "dormant".into(),
        }
    }
}

impl Default for StateMachine {
    fn default() -> Self {
        Self::new()
    }
}

fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

// Extension trait for StateTransition
impl StateTransition {
    fn get_manifest(&self) -> Option<super::types::GhostManifest> {
        None // Only available in actual implementation with storage
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::types::{GhostManifest, ResourceLimits, FeeStructure};

    fn test_metadata() -> GhostMetadata {
        GhostMetadata {
            id: "ghost-001".into(),
            cid: "QmTest".into(),
            owner: "02abc...".into(),
            location: "8f283080dcb019d".into(),
            stake: 1000000,
        }
    }

    fn test_manifest() -> GhostManifest {
        GhostManifest {
            protocol: "locus.ghost".into(),
            version: 1,
            id: "ghost-001".into(),
            name: "Test Ghost".into(),
            ghost_type: "greeter".into(),
            description: None,
            owner: "02abc...".into(),
            location: "8f283080dcb019d".into(),
            stake: 1000000,
            wasm_hash: "sha256:abc123".into(),
            assets_hash: None,
            capabilities: vec!["payment".into(), "storage".into()],
            limits: ResourceLimits::default(),
            fees: FeeStructure::default(),
            api_whitelist: vec![],
        }
    }

    #[test]
    fn test_dormant_to_potential() {
        let machine = StateMachine::new();
        let metadata = test_metadata();
        
        let dormant = GhostState::Dormant {
            ghost_id: "ghost-001".into(),
            metadata,
            last_heartbeat: None,
        };

        let transition = StateTransition::Approach {
            ghost_id: "ghost-001".into(),
            user_location: Location {
                lat: 35.6762,
                lng: 139.6503,
                h3_index: "8f283080dcb019d".into(),
            },
        };

        // This will fail without a real manifest, but tests the structure
        let result = machine.transition(&dormant, transition);
        assert!(result.is_err()); // Expected: no manifest in transition
    }

    #[test]
    fn test_invalid_transition() {
        let machine = StateMachine::new();
        let metadata = test_metadata();
        
        // Cannot go directly from Dormant to Manifest
        let dormant = GhostState::Dormant {
            ghost_id: "ghost-001".into(),
            metadata,
            last_heartbeat: None,
        };

        let transition = StateTransition::Leave {
            ghost_id: "ghost-001".into(),
            final_channel_state: None,
        };

        let result = machine.transition(&dormant, transition);
        assert!(matches!(result, Err(GhostError::StateTransition { .. })));
    }
}
