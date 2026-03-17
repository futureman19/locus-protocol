//! Sample Ghost: Greeter
//! 
//! A simple WASM ghost that greets users based on their location.
//! Compile with: `cargo build --target wasm32-wasi --release`

// No std for minimal WASM
#![no_std]
#![no_main]

// Import host functions
extern "C" {
    fn host_log(level: i32, ptr: *const u8, len: usize);
    fn host_get_current_time() -> i64;
    fn host_get_distance_to_ghost() -> f64;
    fn host_storage_write(key_ptr: *const u8, key_len: usize, value_ptr: *const u8, value_len: usize);
    fn host_storage_read(key_ptr: *const u8, key_len: usize, out_ptr: *mut u8, out_len: usize) -> i32;
}

// Helper to log messages
fn log(level: i32, msg: &str) {
    unsafe {
        host_log(level, msg.as_ptr(), msg.len());
    }
}

// Main entry point
#[no_mangle]
pub extern "C" fn handle_interaction() -> i32 {
    log(2, "Greeter ghost activated!");
    
    // Get distance to user
    let distance = unsafe { host_get_distance_to_ghost() };
    
    // Log the distance
    let dist_msg = format!("Distance to user: {} meters", distance);
    log(2, &dist_msg);
    
    // Get current time
    let time = unsafe { host_get_current_time() };
    let time_msg = format!("Current time: {}", time);
    log(2, &time_msg);
    
    // Store interaction count
    let count_key = b"interaction_count";
    let count_value = b"1";
    unsafe {
        host_storage_write(
            count_key.as_ptr(),
            count_key.len(),
            count_value.as_ptr(),
            count_value.len(),
        );
    }
    
    // Return success
    0
}

// Custom panic handler for no_std
#[cfg(not(test))]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
