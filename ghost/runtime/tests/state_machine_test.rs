//! State machine unit tests

use ghost_runtime::state::types::*;
use ghost_runtime::state::StateMachine;

#[test]
fn test_parse_memory_units() {
    assert_eq!(parse_memory("64MB").unwrap(), 64 * 1024 * 1024);
    assert_eq!(parse_memory("10 MB").unwrap(), 10 * 1024 * 1024);
    assert_eq!(parse_memory("1024").unwrap(), 1024);
    assert_eq!(parse_memory("2GB").unwrap(), 2 * 1024 * 1024 * 1024);
}

#[test]
fn test_parse_duration_units() {
    assert_eq!(parse_duration("5s").unwrap(), 5000);
    assert_eq!(parse_duration("5000ms").unwrap(), 5000);
    assert_eq!(parse_duration("1m").unwrap(), 60000);
}

#[test]
fn test_resource_limits_default() {
    let limits = ResourceLimits::default();
    assert_eq!(limits.max_memory, 64 * 1024 * 1024);
    assert_eq!(limits.max_execution_time, 5000);
}

#[test]
fn test_fee_structure_default() {
    let fees = FeeStructure::default();
    assert_eq!(fees.interaction, 0);
    assert_eq!(fees.session, 0);
    assert_eq!(fees.per_second, None);
}

#[test]
fn test_ghost_state_serialization() {
    use ghost_runtime::types::GhostMetadata;
    
    let metadata = GhostMetadata {
        id: "test".into(),
        cid: "QmTest".into(),
        owner: "02abc".into(),
        location: "8f283080dcb019d".into(),
        stake: 1000000,
    };

    let state = GhostState::Dormant {
        ghost_id: "test".into(),
        metadata,
        last_heartbeat: Some(1234567890),
    };

    let json = serde_json::to_string(&state).unwrap();
    assert!(json.contains("dormant"));
    assert!(json.contains("test"));
}
