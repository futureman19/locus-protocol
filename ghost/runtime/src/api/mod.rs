//! API module - gRPC and HTTP endpoints for ghost invocation

pub mod server;
mod handlers;

use axum::{
    routing::{get, post},
    Router,
};
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;

use crate::runtime::GhostRuntime;
use crate::runtime::config::RuntimeConfig;

/// Combined gRPC and HTTP API server
pub struct ApiServer {
    runtime: Arc<GhostRuntime>,
    config: RuntimeConfig,
}

impl ApiServer {
    pub fn new(runtime: Arc<GhostRuntime>, config: RuntimeConfig) -> Self {
        Self { runtime, config }
    }

    pub async fn run(self, addr: SocketAddr) -> anyhow::Result<()> {
        // Build HTTP router
        let http_app = self.build_http_router();
        
        // Start server
        let listener = tokio::net::TcpListener::bind(addr).await?;
        axum::serve(listener, http_app).await?;
        
        Ok(())
    }

    fn build_http_router(&self) -> Router {
        let runtime = self.runtime.clone();

        Router::new()
            // Health check
            .route("/health", get(handlers::health_check))
            
            // Ghost invocation
            .route("/api/v1/invoke/:ghost_id", post(handlers::invoke_ghost))
            .route("/api/v1/ghosts/:ghost_id/leave", post(handlers::leave_ghost))
            
            // Ghost state
            .route("/api/v1/ghosts/:ghost_id/state", get(handlers::get_ghost_state))
            .route("/api/v1/ghosts", get(handlers::list_ghosts))
            
            // Runtime stats
            .route("/api/v1/stats", get(handlers::get_stats))
            
            // Payment channels
            .route("/api/v1/channels", post(handlers::open_channel))
            .route("/api/v1/channels/:channel_id", get(handlers::get_channel))
            .route("/api/v1/channels/:channel_id/close", post(handlers::close_channel))
            
            // Add middleware
            .layer(CorsLayer::permissive())
            .layer(TraceLayer::new_for_http())
            .with_state(runtime)
    }
}
