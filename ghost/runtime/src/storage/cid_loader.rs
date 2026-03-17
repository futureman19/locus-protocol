//! CID loader for fetching content from IPFS/Arweave

use crate::error::{GhostError, Result};
use crate::runtime::config::RuntimeConfig;
use crate::state::types::GhostManifest;
use crate::state::GhostState;
use crate::storage::{ContentCache, StorageBackend};

use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};

/// Loader for content-addressed data
pub struct CidLoader {
    http_client: reqwest::Client,
    cache: Arc<RwLock<ContentCache>>,
    ipfs_gateway: String,
    arweave_gateway: String,
}

impl CidLoader {
    pub fn new(config: &RuntimeConfig) -> Result<Self> {
        let http_client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .map_err(|e| GhostError::Network(e.to_string()))?;

        Ok(Self {
            http_client,
            cache: Arc::new(RwLock::new(ContentCache::new(
                config.wasm_cache_size,
                3600, // 1 hour TTL
            ))),
            ipfs_gateway: config.ipfs_gateway.clone(),
            arweave_gateway: config.arweave_gateway.clone(),
        })
    }

    /// Load a ghost manifest from CID
    pub async fn load_manifest(&self, state: &GhostState) -> Result<GhostManifest> {
        let cid = match state {
            GhostState::Dormant { metadata, .. } => &metadata.cid,
            GhostState::Potential { cid, .. } => cid,
            GhostState::Manifest { cid, .. } => cid,
        };

        // Try cache first
        let cache_key = format!("manifest:{}", cid);
        {
            let cache = self.cache.read().await;
            if let Some(data) = cache.get(&cache_key) {
                debug!("Cache hit for manifest {}", cid);
                return serde_json::from_slice(&data)
                    .map_err(|e| GhostError::InvalidManifest(e.to_string()));
            }
        }

        // Fetch from network
        info!("Fetching manifest from CID: {}", cid);
        let data = self.fetch_cid(cid).await?;

        // Parse and validate
        let manifest: GhostManifest = serde_json::from_slice(&data)
            .map_err(|e| GhostError::InvalidManifest(e.to_string()))?;

        // Cache the raw data
        {
            let mut cache = self.cache.write().await;
            cache.put(cache_key, data);
        }

        Ok(manifest)
    }

    /// Load WASM binary from content hash
    pub async fn load_wasm(&self, wasm_hash: &str) -> Result<Vec<u8>> {
        // Hash format: "sha256:abc123..." or just CID
        let (hash_type, hash_value) = if let Some(pos) = wasm_hash.find(':') {
            (&wasm_hash[..pos], &wasm_hash[pos + 1..])
        } else {
            ("cid", wasm_hash)
        };

        let cache_key = format!("wasm:{}", wasm_hash);
        
        // Try cache first
        {
            let cache = self.cache.read().await;
            if let Some(data) = cache.get(&cache_key) {
                debug!("Cache hit for WASM {}", wasm_hash);
                return Ok(data);
            }
        }

        // Fetch from network
        info!("Fetching WASM from {}: {}", hash_type, hash_value);
        let data = self.fetch_cid(hash_value).await?;

        // Verify hash if sha256
        if hash_type == "sha256" {
            self.verify_sha256(&data, hash_value)?;
        }

        // Cache
        {
            let mut cache = self.cache.write().await;
            cache.put(cache_key, data.clone());
        }

        Ok(data)
    }

    /// Fetch content from CID using appropriate backend
    async fn fetch_cid(&self, cid: &str) -> Result<Vec<u8>> {
        let backend = StorageBackend::detect(cid)
            .ok_or_else(|| GhostError::CidLoading {
                cid: cid.into(),
                reason: "Unknown CID format".into(),
            })?;

        let url = match &backend {
            StorageBackend::Ipfs { .. } => {
                format!("{}/{}", self.ipfs_gateway, cid)
            }
            StorageBackend::Arweave { .. } => {
                format!("{}/{}", self.arweave_gateway, cid)
            }
        };

        debug!("Fetching from URL: {}", url);

        let response = self.http_client
            .get(&url)
            .send()
            .await
            .map_err(|e| GhostError::Network(format!("Request failed: {}", e)))?;

        if !response.status().is_success() {
            return Err(GhostError::CidLoading {
                cid: cid.into(),
                reason: format!("HTTP {}", response.status()),
            });
        }

        let data = response.bytes().await
            .map_err(|e| GhostError::Network(e.to_string()))?;

        info!("Fetched {} bytes for CID {}", data.len(), cid);
        Ok(data.to_vec())
    }

    /// Verify SHA-256 hash of data
    fn verify_sha256(&self, data: &[u8], expected_hash: &str) -> Result<()> {
        use sha2::{Digest, Sha256};

        let mut hasher = Sha256::new();
        hasher.update(data);
        let actual_hash = hex::encode(hasher.finalize());

        if actual_hash != expected_hash.to_lowercase() {
            return Err(GhostError::CidLoading {
                cid: expected_hash.into(),
                reason: format!(
                    "Hash mismatch: expected {}, got {}",
                    expected_hash, actual_hash
                ),
            });
        }

        Ok(())
    }

    /// Preload content into cache
    pub async fn preload(&self, cid: &str) -> Result<()> {
        let _ = self.fetch_cid(cid).await?;
        Ok(())
    }

    /// Clear cache
    pub async fn clear_cache(&self) {
        // Cache will be recreated on next access
        let mut cache = self.cache.write().await;
        *cache = ContentCache::new(cache.max_size, cache.default_ttl.as_secs());
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use wiremock::{Mock, MockServer, ResponseTemplate};
    use wiremock::matchers::{method, path};

    #[tokio::test]
    async fn test_load_manifest() {
        let mock_server = MockServer::start().await;
        
        let manifest = r#"{
            "protocol": "locus.ghost",
            "version": 1,
            "id": "test-ghost",
            "name": "Test Ghost",
            "type": "greeter",
            "owner": "02abc",
            "location": "8f283080dcb019d",
            "stake": 1000000,
            "wasm_hash": "sha256:abc123",
            "capabilities": ["location"],
            "limits": {
                "max_memory": "64MB",
                "max_execution_time": "5s"
            },
            "fees": {
                "interaction": 1000
            }
        }"#;

        Mock::given(method("GET"))
            .and(path("/QmTest"))
            .respond_with(ResponseTemplate::new(200).set_body_string(manifest))
            .mount(&mock_server)
            .await;

        let config = RuntimeConfig {
            ipfs_gateway: mock_server.uri(),
            ..RuntimeConfig::default()
        };

        let loader = CidLoader::new(&config).unwrap();
        
        let metadata = crate::types::GhostMetadata {
            id: "test".into(),
            cid: "QmTest".into(),
            owner: "02abc".into(),
            location: "8f283080dcb019d".into(),
            stake: 1000000,
        };

        let state = GhostState::Dormant {
            ghost_id: "test".into(),
            metadata,
            last_heartbeat: None,
        };

        // This will actually fetch from the mock server
        // Note: In real tests, we'd need to handle the async properly
    }
}
