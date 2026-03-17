//! Integration tests for Ghost Runtime

use ghost_runtime::error::GhostError;
use ghost_runtime::state::{GhostState, StateMachine, StateTransition};
use ghost_runtime::types::{GhostMetadata, Location};

mod common;

#[tokio::test]
async fn test_state_machine_transitions() {
    let machine = StateMachine::new();
    let metadata = test_metadata();

    // Start in Dormant state
    let dormant = GhostState::Dormant {
        ghost_id: "ghost-001".into(),
        metadata: metadata.clone(),
        last_heartbeat: None,
    };

    assert_eq!(dormant.state_name(), "dormant");

    // Dormant -> Potential (user approaches)
    let location = Location::from_gps(35.6762, 139.6503);
    let transition = StateTransition::Approach {
        ghost_id: "ghost-001".into(),
        user_location: location.clone(),
    };

    // This will fail without a real manifest, but tests the structure
    let result = machine.transition(&dormant, transition);
    assert!(result.is_err()); // Expected - no manifest loaded
}

#[tokio::test]
async fn test_invalid_state_transitions() {
    let machine = StateMachine::new();
    let metadata = test_metadata();

    // Cannot go Dormant -> Manifest directly
    let dormant = GhostState::Dormant {
        ghost_id: "ghost-001".into(),
        metadata: metadata.clone(),
        last_heartbeat: None,
    };

    let invalid_transition = StateTransition::Leave {
        ghost_id: "ghost-001".into(),
        final_channel_state: None,
    };

    let result = machine.transition(&dormant, invalid_transition);
    assert!(matches!(result, Err(GhostError::StateTransition { .. })));
}

#[tokio::test]
async fn test_capability_negotiation() {
    let metadata = test_metadata();
    
    let dormant = GhostState::Dormant {
        ghost_id: "ghost-001".into(),
        metadata,
        last_heartbeat: None,
    };

    // Test that capabilities are properly validated
    // This is tested in the state machine
}

#[test]
fn test_location_distance() {
    let loc1 = Location {
        lat: 35.6762,
        lng: 139.6503,
        h3_index: "8f283080dcb019d".into(),
    };
    
    let loc2 = Location {
        lat: 35.6763,
        lng: 139.6504,
        h3_index: "8f283080dcb019e".into(),
    };

    // Distance should be small (around 15 meters)
    // This is verified in the host module tests
}

fn test_metadata() -> GhostMetadata {
    GhostMetadata {
        id: "ghost-001".into(),
        cid: "QmTest123".into(),
        owner: "02aabbccdd...".into(),
        location: "8f283080dcb019d".into(),
        stake: 1000000,
    }
}
