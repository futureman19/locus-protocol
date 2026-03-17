//! Resource limiting for WASM execution

/// Resource limiter for WASM store
pub struct ResourceLimiter {
    max_memory: u64,
}

impl ResourceLimiter {
    pub fn new(max_memory: u64) -> Self {
        Self { max_memory }
    }
}

impl wasmtime::ResourceLimiter for ResourceLimiter {
    fn memory_growing(
        &mut self,
        current: usize,
        desired: usize,
        _maximum: Option<usize>,
    ) -> bool {
        desired as u64 <= self.max_memory
    }

    fn table_growing(
        &mut self,
        _current: usize,
        _desired: usize,
        _maximum: Option<usize>,
    ) -> bool {
        true
    }

    fn memory_grow_failed(&mut self, _error: anyhow::Error) {
        tracing::error!("Memory growth failed");
    }

    fn table_grow_failed(&mut self, _error: anyhow::Error) {
        tracing::error!("Table growth failed");
    }
}
