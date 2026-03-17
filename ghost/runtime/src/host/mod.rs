//! Host functions for WASM ghosts
//!
//! Provides capability-based access to:
//! - Location services
//! - Time services  
//! - Payment channels
//! - Ephemeral storage
//! - Network (whitelisted)
//! - Randomness

use crate::types::Location;
use std::collections::HashMap;

/// Host functions available to WASM ghosts
#[derive(Debug, Clone)]
pub struct HostFunctions {
    capabilities: Vec<String>,
    user_location: Location,
    ghost_location: Location,
    ephemeral_storage: HashMap<String, Vec<u8>>,
}

impl HostFunctions {
    pub fn new(capabilities: Vec<String>, user_location: Location) -> Self {
        // Default ghost location (would come from manifest)
        let ghost_location = Location {
            lat: 35.6762,
            lng: 139.6503,
            h3_index: "8f283080dcb019d".into(),
        };

        Self {
            capabilities,
            user_location,
            ghost_location,
            ephemeral_storage: HashMap::new(),
        }
    }

    /// Check if a capability is granted
    fn has_capability(&self, cap: &str) -> bool {
        self.capabilities.contains(&cap.to_string())
    }

    // ===== Logging =====

    pub fn log(&self, level: LogLevel, message: &str) {
        match level {
            LogLevel::Error => tracing::error!("[GHOST] {}", message),
            LogLevel::Warn => tracing::warn!("[GHOST] {}", message),
            LogLevel::Info => tracing::info!("[GHOST] {}", message),
            LogLevel::Debug => tracing::debug!("[GHOST] {}", message),
        }
    }

    // ===== Storage (ephemeral, per-session) =====

    pub fn storage_read(&self, key: &str) -> Option<Vec<u8>> {
        if !self.has_capability("storage") {
            tracing::warn!("Storage capability denied");
            return None;
        }
        self.ephemeral_storage.get(key).cloned()
    }

    pub fn storage_write(&mut self, key: &str, value: &[u8]) {
        if !self.has_capability("storage") {
            tracing::warn!("Storage capability denied");
            return;
        }
        self.ephemeral_storage.insert(key.to_string(), value.to_vec());
    }

    // ===== Location =====

    pub fn get_user_location(&self) -> Option<Location> {
        if !self.has_capability("location") {
            tracing::warn!("Location capability denied");
            return None;
        }
        Some(self.user_location.clone())
    }

    pub fn get_distance_to_ghost(&self) -> f64 {
        if !self.has_capability("location") {
            return f64::MAX;
        }
        calculate_distance(&self.user_location, &self.ghost_location)
    }

    // ===== Time =====

    pub fn get_current_time(&self) -> u64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs()
    }

    pub fn get_block_height(&self) -> u32 {
        // TODO: Get from blockchain
        800000
    }

    // ===== Payments =====

    pub fn payment_request(&self, amount: u64, description: &str) -> PaymentResult {
        if !self.has_capability("payment") {
            return PaymentResult::Denied;
        }
        // TODO: Implement payment channel update
        tracing::info!("Payment request: {} sats for '{}'", amount, description);
        PaymentResult::Pending { amount }
    }

    pub fn payment_channel_balance(&self) -> u64 {
        if !self.has_capability("payment") {
            return 0;
        }
        // TODO: Return actual channel balance
        10000
    }

    // ===== Random =====

    pub fn secure_random(&self) -> [u8; 32] {
        // Use system randomness - deterministic per-block could be added
        let mut buf = [0u8; 32];
        getrandom::getrandom(&mut buf).unwrap_or_default();
        buf
    }

    // ===== Network (whitelisted) =====

    pub async fn fetch_url(&self, url: &str) -> Result<Vec<u8>, NetworkError> {
        if !self.has_capability("network") {
            return Err(NetworkError::CapabilityDenied);
        }

        // TODO: Check whitelist
        // let whitelist = ["https://api.weather.com/*", "https://api.example.com/*"];
        
        // TODO: Implement actual fetch with reqwest
        tracing::info!("Fetch URL: {}", url);
        Ok(vec![])
    }

    // ===== Response =====

    pub fn respond(&self, data: &[u8]) {
        tracing::info!("Ghost response: {} bytes", data.len());
        // TODO: Store response for returning to caller
    }
}

#[derive(Debug, Clone, Copy)]
pub enum LogLevel {
    Error = 0,
    Warn = 1,
    Info = 2,
    Debug = 3,
}

#[derive(Debug, Clone)]
pub enum PaymentResult {
    Success { txid: String },
    Pending { amount: u64 },
    Denied,
    InsufficientFunds,
}

#[derive(Debug, Clone)]
pub enum NetworkError {
    CapabilityDenied,
    NotWhitelisted,
    RequestFailed(String),
    Timeout,
}

/// Calculate distance between two GPS coordinates using Haversine formula
fn calculate_distance(a: &Location, b: &Location) -> f64 {
    const R: f64 = 6371000.0; // Earth's radius in meters

    let lat1 = a.lat.to_radians();
    let lat2 = b.lat.to_radians();
    let dlat = (b.lat - a.lat).to_radians();
    let dlon = (b.lng - a.lng).to_radians();

    let a = (dlat / 2.0).sin().powi(2)
        + lat1.cos() * lat2.cos() * (dlon / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());

    R * c
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_distance_calculation() {
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

        let dist = calculate_distance(&loc1, &loc2);
        assert!(dist > 0.0);
        assert!(dist < 20.0); // Should be ~15 meters
    }

    #[test]
    fn test_capability_check() {
        let host = HostFunctions::new(
            vec!["storage".into(), "location".into()],
            Location::from_gps(35.6762, 139.6503),
        );

        assert!(host.has_capability("storage"));
        assert!(host.has_capability("location"));
        assert!(!host.has_capability("payment"));
    }
}
