//! Ghost WASM Runtime
//! 
//! A minimal WASM runtime that:
//! - Loads WASM modules from IPFS/Arweave CIDs
//! - Provides capability-based host functions
//! - Implements Schrödinger state transitions
//! - Handles payment channel state for ghost invocations
//! - Exposes gRPC/HTTP API for invoking ghosts

mod api;
mod error;
mod host;
mod runtime;
mod state;
mod storage;

use std::net::SocketAddr;
use std::sync::Arc;
use tracing::{info, warn};

use crate::api::server::ApiServer;
use crate::runtime::config::RuntimeConfig;
use crate::runtime::GhostRuntime;
use crate::storage::cid_loader::CidLoader;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    info!("🌙 Ghost WASM Runtime starting...");

    // Load configuration
    let config = RuntimeConfig::from_env()?;
    info!("Configuration loaded: {:?}", config);

    // Initialize CID loader for IPFS/Arweave
    let cid_loader = Arc::new(CidLoader::new(&config)?);
    info!("CID loader initialized");

    // Initialize the Ghost Runtime
    let runtime = Arc::new(GhostRuntime::new(config.clone(), cid_loader.clone()).await?);
    info!("Ghost runtime initialized");

    // Start the API server (gRPC + HTTP)
    let addr: SocketAddr = config.server_addr.parse()?;
    let server = ApiServer::new(runtime.clone(), config);
    
    info!("🚀 Ghost Runtime ready at http://{}", addr);
    info!("   gRPC endpoint: http://{}/grpc", addr);
    info!("   HTTP endpoint: http://{}/api", addr);
    info!("   Health check:  http://{}/health", addr);

    server.run(addr).await?;

    warn!("Ghost Runtime shutting down...");
    Ok(())
}
