//! WASM execution engine using wasmtime

use wasmtime::{Config, Engine, Instance, Linker, Memory, Module, Store, Trap, TypedFunc};
use wasmtime_wasi::{WasiCtx, WasiCtxBuilder};

use crate::error::{GhostError, Result};
use crate::host::HostFunctions;
use crate::state::types::ResourceLimits;
use crate::runtime::limits::ResourceLimiter;
use crate::runtime::config::RuntimeConfig;

/// WASM execution engine
pub struct RuntimeEngine {
    engine: Engine,
}

impl RuntimeEngine {
    pub fn new(config: &RuntimeConfig) -> Result<Self> {
        let mut wasm_config = Config::new();
        wasm_config.wasm_backtrace_details(wasmtime::WasmBacktraceDetails::Enable);
        wasm_config.async_support(true);
        wasm_config.epoch_interruption(true);

        let engine = Engine::new(&wasm_config)?;

        Ok(Self { engine })
    }

    /// Execute a WASM module
    pub async fn execute(
        &self,
        wasm_bytes: &[u8],
        entry_point: &str,
        input: &[u8],
        host: HostFunctions,
        limits: &ResourceLimits,
    ) -> Result<Vec<u8>> {
        // Compile module
        let module = Module::new(&self.engine, wasm_bytes)?;

        // Create store with resource limits
        let mut store = self.create_store(limits, host)?;

        // Create linker and add host functions
        let linker = self.create_linker(&mut store)?;

        // Instantiate module
        let instance = linker
            .instantiate(&mut store, &module)
            .map_err(|e| GhostError::wasm(format!("Instantiation failed: {}", e)))?;

        // Call entry point
        let result = self.call_entry_point(&mut store, &instance, entry_point, input).await;

        // Clean up
        store.epoch_deadline_trap();

        result
    }

    fn create_store(&self, limits: &ResourceLimits, host: HostFunctions) -> Result<Store<HostState>> {
        let wasi = WasiCtxBuilder::new()
            .inherit_stdio()
            .inherit_env()
            .build();

        let state = HostState {
            wasi,
            host,
            memory_usage: 0,
            syscall_count: 0,
        };

        let mut store = Store::new(&self.engine, state);

        // Set memory limit
        store.limiter(|state| ResourceLimiter::new(limits.max_memory));

        Ok(store)
    }

    fn create_linker(&self, _store: &mut Store<HostState>) -> Result<Linker<HostState>> {
        let mut linker = Linker::new(&self.engine);

        // Add WASI functions
        wasmtime_wasi::add_to_linker(&mut linker, |state: &mut HostState| &mut state.wasi)?;

        // Add custom host functions
        self.add_host_functions(&mut linker)?;

        Ok(linker)
    }

    fn add_host_functions(&self, linker: &mut Linker<HostState>) -> Result<()> {
        // host::log(level: u32, message: &str)
        linker.func_wrap("host", "log", |mut caller: wasmtime::Caller<'_, HostState>, level: i32, ptr: i32, len: i32| {
            let memory = caller.get_export("memory")
                .and_then(|e| e.into_memory())
                .ok_or_else(|| wasmtime::Error::msg("Memory not found"))?;

            let mut buf = vec![0u8; len as usize];
            memory.read(&caller, ptr as usize, &mut buf)?;

            let message = String::from_utf8_lossy(&buf);
            let level_str = match level {
                0 => "ERROR",
                1 => "WARN",
                2 => "INFO",
                3 => "DEBUG",
                _ => "UNKNOWN",
            };

            tracing::info!("[GHOST LOG {}] {}", level_str, message);
            Ok(())
        })?;

        // host::storage_read(key: &str) -> Option<Vec<u8>>
        linker.func_wrap("host", "storage_read", |mut caller: wasmtime::Caller<'_, HostState>, key_ptr: i32, key_len: i32, out_ptr: i32, out_len: i32| -> i32 {
            let memory = match caller.get_export("memory").and_then(|e| e.into_memory()) {
                Some(m) => m,
                None => return -1,
            };

            let mut key_buf = vec![0u8; key_len as usize];
            if memory.read(&caller, key_ptr as usize, &mut key_buf).is_err() {
                return -1;
            }

            let key = String::from_utf8_lossy(&key_buf);
            
            // Call host function
            match caller.data().host.storage_read(&key) {
                Some(value) => {
                    let to_write = std::cmp::min(value.len(), out_len as usize);
                    if memory.write(&mut caller, out_ptr as usize, &value[..to_write]).is_err() {
                        return -1;
                    }
                    to_write as i32
                }
                None => -1,
            }
        })?;

        // host::get_current_time() -> u64
        linker.func_wrap("host", "get_current_time", |_caller: wasmtime::Caller<'_, HostState>| -> i64 {
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as i64
        })?;

        // host::get_distance_to_ghost() -> f64
        linker.func_wrap("host", "get_distance_to_ghost", |caller: wasmtime::Caller<'_, HostState>| -> f64 {
            caller.data().host.get_distance_to_ghost()
        })?;

        Ok(())
    }

    async fn call_entry_point(
        &self,
        store: &mut Store<HostState>,
        instance: &Instance,
        name: &str,
        _input: &[u8],
    ) -> Result<Vec<u8>> {
        let func = instance
            .get_typed_func::<(i32, i32), i32>(store, name)
            .map_err(|e| GhostError::wasm(format!("Entry point '{}' not found: {}", name, e)))?;

        // Allocate memory for input
        let memory = instance
            .get_memory(store, "memory")
            .ok_or_else(|| GhostError::wasm("Memory export not found"))?;

        // For simplicity, return empty result for now
        // TODO: Proper memory management and input/output passing
        let result = func.call_async(store, (0, 0)).await
            .map_err(|e| GhostError::wasm(format!("Execution failed: {}", e)))?;

        // Return result based on pointer
        let mut output = vec![0u8; result as usize];
        memory.read(store, 0, &mut output)?;

        Ok(output)
    }
}

/// Host state passed to WASM
pub struct HostState {
    pub wasi: WasiCtx,
    pub host: HostFunctions,
    pub memory_usage: u64,
    pub syscall_count: u32,
}
