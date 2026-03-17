//! Storage module for CID loading from IPFS/Arweave

pub mod cid_loader;

use crate::error::{GhostError, Result};
use crate::state::types::GhostManifest;
use crate::state::GhostState;

/// Content storage backends
#[derive(Debug, Clone)]
pub enum StorageBackend {
    Ipfs { gateway: String },
    Arweave { gateway: String },
}

impl StorageBackend {
    /// Create URL for fetching content
    pub fn url_for(&self, cid: &str) -> String {
        match self {
            StorageBackend::Ipfs { gateway } => format!("{}/{}", gateway, cid),
            StorageBackend::Arweave { gateway } => format!("{}/{}", gateway, cid),
        }
    }

    /// Detect backend from CID format
    pub fn detect(cid: &str) -> Option<Self> {
        if cid.starts_with("Qm") || cid.starts_with("bafy") {
            Some(StorageBackend::Ipfs {
                gateway: "https://ipfs.io/ipfs".into(),
            })
        } else if cid.len() == 43 && cid.chars().all(|c| c.is_alphanumeric() || c == '-' || c == '_') {
            // Arweave transaction IDs are 43 characters
            Some(StorageBackend::Arweave {
                gateway: "https://arweave.net".into(),
            })
        } else {
            None
        }
    }
}

/// Cache entry with expiration
#[derive(Debug, Clone)]
struct CacheEntry {
    data: Vec<u8>,
    cached_at: std::time::Instant,
    ttl: std::time::Duration,
}

impl CacheEntry {
    fn is_expired(&self) -> bool {
        self.cached_at.elapsed() > self.ttl
    }
}

/// LRU cache for WASM modules and manifests
pub struct ContentCache {
    cache: std::collections::HashMap<String, CacheEntry>,
    max_size: usize,
    default_ttl: std::time::Duration,
}

impl ContentCache {
    pub fn new(max_size: usize, default_ttl_secs: u64) -> Self {
        Self {
            cache: std::collections::HashMap::with_capacity(max_size),
            max_size,
            default_ttl: std::time::Duration::from_secs(default_ttl_secs),
        }
    }

    pub fn get(&self, key: &str) -> Option<Vec<u8>> {
        self.cache.get(key).and_then(|entry| {
            if entry.is_expired() {
                None
            } else {
                Some(entry.data.clone())
            }
        })
    }

    pub fn put(&mut self, key: String, data: Vec<u8>) {
        // Simple eviction: remove expired entries if at capacity
        if self.cache.len() >= self.max_size {
            self.evict_expired();
        }

        // If still at capacity, remove oldest
        if self.cache.len() >= self.max_size {
            if let Some(oldest) = self.cache
                .iter()
                .min_by_key(|(_, v)| v.cached_at)
                .map(|(k, _)| k.clone())
            {
                self.cache.remove(&oldest);
            }
        }

        self.cache.insert(key, CacheEntry {
            data,
            cached_at: std::time::Instant::now(),
            ttl: self.default_ttl,
        });
    }

    fn evict_expired(&mut self) {
        let expired: Vec<String> = self
            .cache
            .iter()
            .filter(|(_, entry)| entry.is_expired())
            .map(|(k, _)| k.clone())
            .collect();
        
        for key in expired {
            self.cache.remove(&key);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_storage_backend_detection() {
        // IPFS CIDv0
        let ipfs_cid = "QmXxxx";
        assert!(matches!(
            StorageBackend::detect(ipfs_cid),
            Some(StorageBackend::Ipfs { .. })
        ));

        // IPFS CIDv1
        let ipfs_cid_v1 = "bafybeixxx";
        assert!(matches!(
            StorageBackend::detect(ipfs_cid_v1),
            Some(StorageBackend::Ipfs { .. })
        ));

        // Arweave
        let ar_tx = "a".repeat(43);
        assert!(matches!(
            StorageBackend::detect(&ar_tx),
            Some(StorageBackend::Arweave { .. })
        ));
    }

    #[test]
    fn test_content_cache() {
        let mut cache = ContentCache::new(2, 3600);
        
        cache.put("key1".into(), vec![1, 2, 3]);
        cache.put("key2".into(), vec![4, 5, 6]);
        
        assert_eq!(cache.get("key1"), Some(vec![1, 2, 3]));
        
        // Add third item, should evict oldest
        cache.put("key3".into(), vec![7, 8, 9]);
        
        // key1 or key2 should be evicted
        let count = [cache.get("key1"), cache.get("key2")]
            .iter()
            .filter(|x| x.is_some())
            .count();
        assert!(count <= 1);
        
        assert_eq!(cache.get("key3"), Some(vec![7, 8, 9]));
    }
}
