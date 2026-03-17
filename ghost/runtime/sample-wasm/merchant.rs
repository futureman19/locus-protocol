//! Sample Ghost: Merchant
//! 
//! A merchant ghost that accepts payments for digital goods.
//! Demonstrates payment channel capabilities.

#![no_std]
#![no_main]

extern "C" {
    fn host_log(level: i32, ptr: *const u8, len: usize);
    fn host_get_current_time() -> i64;
    fn host_payment_request(amount: u64, desc_ptr: *const u8, desc_len: usize) -> i32;
    fn host_payment_channel_balance() -> u64;
}

fn log(level: i32, msg: &str) {
    unsafe {
        host_log(level, msg.as_ptr(), msg.len());
    }
}

#[no_mangle]
pub extern "C" fn get_catalog() -> i32 {
    log(2, "Merchant: Catalog requested");
    
    // Check payment channel balance
    let balance = unsafe { host_payment_channel_balance() };
    let msg = format!("Channel balance: {} sats", balance);
    log(2, &msg);
    
    0
}

#[no_mangle]
pub extern "C" fn purchase_item(item_id_ptr: *const u8, item_id_len: usize) -> i32 {
    let item_id = unsafe {
        core::str::from_utf8_unchecked(core::slice::from_raw_parts(item_id_ptr, item_id_len))
    };
    
    log(2, &format!("Purchase request for item: {}", item_id));
    
    // Request payment of 1000 sats
    let desc = format!("Purchase of item {}", item_id);
    let result = unsafe {
        host_payment_request(1000, desc.as_ptr(), desc.len())
    };
    
    if result == 0 {
        log(2, "Payment successful, delivering item...");
        // Deliver digital good
    } else {
        log(0, "Payment failed!");
    }
    
    result
}

#[cfg(not(test))]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
