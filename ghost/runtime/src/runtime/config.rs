//! Runtime configuration

use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuntimeConfig {
    pub server_addr: String,
    pub max_concurrent_ghosts: usize,
    pub max_memory_per_ghost: u64,
    pub max_execution_time_ms: u64,
    pub wasm_cache_size: usize,
    pub ipfs_gateway: String,
    pub arweave_gateway: String,
    pub enable_payment_channels: bool,
    pub log_level: String,
}

impl RuntimeConfig {
    pub fn from_env() -> anyhow::Result<Self> {
        Ok(Self {
            server_addr: env::var("GHOST_RUNTIME_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".into()),
            max_concurrent_ghosts: env::var("MAX_CONCURRENT_GHOSTS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(100),
            max_memory_per_ghost: parse_memory(&env::var("MAX_MEMORY_PER_GHOST").unwrap_or_else(|_| "64MB".into()))?,
            max_execution_time_ms: parse_duration(&env::var("MAX_EXECUTION_TIME").unwrap_or_else(|_| "5s".into()))?,
            wasm_cache_size: env::var("WASM_CACHE_SIZE")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(1000),
            ipfs_gateway: env::var("IPFS_GATEWAY").unwrap_or_else(|_| "https://ipfs.io/ipfs".into()),
            arweave_gateway: env::var("ARWEAVE_GATEWAY").unwrap_or_else(|_| "https://arweave.net".into()),
            enable_payment_channels: env::var("ENABLE_PAYMENT_CHANNELS")
                .ok()
                .map(|s| s == "true" || s == "1")
                .unwrap_or(true),
            log_level: env::var("LOG_LEVEL").unwrap_or_else(|_| "info".into()),
        })
    }

    pub fn default() -> Self {
        Self {
            server_addr: "0.0.0.0:8080".into(),
            max_concurrent_ghosts: 100,
            max_memory_per_ghost: 64 * 1024 * 1024,
            max_execution_time_ms: 5000,
            wasm_cache_size: 1000,
            ipfs_gateway: "https://ipfs.io/ipfs".into(),
            arweave_gateway: "https://arweave.net".into(),
            enable_payment_channels: true,
            log_level: "info".into(),
        }
    }
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
        _ => anyhow::bail!("Unknown memory unit: {}", unit),
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
        _ => anyhow::bail!("Unknown duration unit: {}", unit),
    };

    Ok(num * multiplier)
}
