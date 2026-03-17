//! HTTP API handlers

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::sync::Arc;

use crate::error::GhostError;
use crate::runtime::GhostRuntime;
use crate::types::{InvocationRequest, Location};

// ===== Request/Response Types =====

#[derive(Debug, Deserialize)]
pub struct InvokeRequest {
    pub user_pubkey: String,
    pub user_location: LocationInput,
    pub action: String,
    #[serde(default)]
    pub payload: serde_json::Value,
    #[serde(default)]
    pub capabilities_requested: Vec<String>,
    #[serde(default)]
    pub payment_deposit: Option<u64>,
}

#[derive(Debug, Deserialize)]
pub struct LocationInput {
    pub lat: f64,
    pub lng: f64,
}

#[derive(Debug, Serialize)]
pub struct InvokeResponse {
    pub ghost_id: String,
    pub instance_id: String,
    pub result: serde_json::Value,
    pub payment_charged: u64,
    pub execution_time_ms: u64,
}

#[derive(Debug, Serialize)]
pub struct GhostStateResponse {
    pub ghost_id: String,
    pub state: String,
    pub capabilities: Vec<String>,
    pub resource_usage: ResourceUsageResponse,
}

#[derive(Debug, Serialize, Default)]
pub struct ResourceUsageResponse {
    pub memory_bytes: u64,
    pub cpu_time_ms: u64,
}

#[derive(Debug, Serialize)]
pub struct RuntimeStatsResponse {
    pub invocations: u64,
    pub dormant_count: usize,
    pub potential_count: usize,
    pub manifest_count: usize,
}

#[derive(Debug, Deserialize)]
pub struct OpenChannelRequest {
    pub ghost_id: String,
    pub user_pubkey: String,
    pub funding_amount: u64,
}

// ===== Handlers =====

/// Health check endpoint
pub async fn health_check() -> Json<serde_json::Value> {
    Json(json!({
        "status": "healthy",
        "service": "ghost-runtime",
        "version": env!("CARGO_PKG_VERSION"),
    }))
}

/// Invoke a ghost
pub async fn invoke_ghost(
    State(runtime): State<Arc<GhostRuntime>>,
    Path(ghost_id): Path<String>,
    Json(req): Json<InvokeRequest>,
) -> Result<Json<InvokeResponse>, (StatusCode, Json<serde_json::Value>)> {
    let location = Location::from_gps(req.user_location.lat, req.user_location.lng);

    let invocation = InvocationRequest {
        ghost_id: ghost_id.clone(),
        user_pubkey: req.user_pubkey,
        user_location: location,
        action: req.action,
        payload: serde_json::to_vec(&req.payload).unwrap_or_default(),
        capabilities_requested: req.capabilities_requested,
        payment_deposit: req.payment_deposit,
        nonce: 0, // TODO: Generate properly
    };

    match runtime.invoke(invocation).await {
        Ok(response) => {
            let result: serde_json::Value = serde_json::from_slice(&response.result)
                .unwrap_or_else(|_| json!({"raw": hex::encode(&response.result)}));

            Ok(Json(InvokeResponse {
                ghost_id: response.ghost_id,
                instance_id: response.instance_id,
                result,
                payment_charged: response.payment_charged,
                execution_time_ms: response.execution_time_ms,
            }))
        }
        Err(e) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )),
    }
}

/// User leaving ghost location
pub async fn leave_ghost(
    State(runtime): State<Arc<GhostRuntime>>,
    Path(ghost_id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match runtime.leave(&ghost_id).await {
        Ok(()) => Ok(Json(json!({"status": "left", "ghost_id": ghost_id}))),
        Err(e) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"error": e.to_string()})),
        )),
    }
}

/// Get ghost state
pub async fn get_ghost_state(
    State(runtime): State<Arc<GhostRuntime>>,
    Path(ghost_id): Path<String>,
) -> Result<Json<GhostStateResponse>, (StatusCode, Json<serde_json::Value>)> {
    // TODO: Implement state retrieval
    Ok(Json(GhostStateResponse {
        ghost_id,
        state: "dormant".into(),
        capabilities: vec![],
        resource_usage: ResourceUsageResponse::default(),
    }))
}

/// List active ghosts
pub async fn list_ghosts(
    State(_runtime): State<Arc<GhostRuntime>>,
) -> Json<serde_json::Value> {
    // TODO: Implement ghost listing
    Json(json!({
        "ghosts": [],
        "total": 0,
    }))
}

/// Get runtime statistics
pub async fn get_stats(
    State(runtime): State<Arc<GhostRuntime>>,
) -> Json<RuntimeStatsResponse> {
    let stats = runtime.get_stats().await;
    
    Json(RuntimeStatsResponse {
        invocations: stats.invocations,
        dormant_count: stats.dormant_count,
        potential_count: stats.potential_count,
        manifest_count: stats.manifest_count,
    })
}

/// Open payment channel
pub async fn open_channel(
    State(_runtime): State<Arc<GhostRuntime>>,
    Json(_req): Json<OpenChannelRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    // TODO: Implement payment channel opening
    Ok(Json(json!({
        "channel_id": "chan-001",
        "status": "opened",
    })))
}

/// Get payment channel state
pub async fn get_channel(
    State(_runtime): State<Arc<GhostRuntime>>,
    Path(channel_id): Path<String>,
) -> Json<serde_json::Value> {
    // TODO: Implement channel retrieval
    Json(json!({
        "channel_id": channel_id,
        "status": "open",
        "user_balance": 10000,
        "ghost_balance": 0,
    }))
}

/// Close payment channel
pub async fn close_channel(
    State(_runtime): State<Arc<GhostRuntime>>,
    Path(channel_id): Path<String>,
) -> Json<serde_json::Value> {
    // TODO: Implement channel closing
    Json(json!({
        "channel_id": channel_id,
        "status": "closed",
    }))
}
