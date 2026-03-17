//! Sample Ghost: Oracle
//! 
//! An oracle ghost that fetches external data (weather, prices, etc.)
//! Demonstrates network capability with whitelist.

#![no_std]
#![no_main]

extern "C" {
    fn host_log(level: i32, ptr: *const u8, len: usize);
    fn host_get_current_time() -> i64;
    fn host_fetch_url(url_ptr: *const u8, url_len: usize, out_ptr: *mut u8, out_len: usize) -> i32;
}

fn log(level: i32, msg: &str) {
    unsafe {
        host_log(level, msg.as_ptr(), msg.len());
    }
}

#[no_mangle]
pub extern "C" fn get_weather() -> i32 {
    log(2, "Oracle: Fetching weather data...");
    
    // This URL must be in the whitelist
    let url = "https://api.weather.com/v1/current";
    
    let mut response_buf = [0u8; 4096];
    let result = unsafe {
        host_fetch_url(
            url.as_ptr(),
            url.len(),
            response_buf.as_mut_ptr(),
            response_buf.len(),
        )
    };
    
    if result >= 0 {
        log(2, "Weather data fetched successfully");
        // Parse and return weather data
    } else {
        log(0, "Failed to fetch weather data");
    }
    
    result
}

#[no_mangle]
pub extern "C" fn get_price(ticker_ptr: *const u8, ticker_len: usize) -> i32 {
    let ticker = unsafe {
        core::str::from_utf8_unchecked(core::slice::from_raw_parts(ticker_ptr, ticker_len))
    };
    
    log(2, &format!("Oracle: Getting price for {}", ticker));
    
    // Fetch price from whitelisted API
    // ...
    
    0
}

#[cfg(not(test))]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
