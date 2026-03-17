# Ghost WASM Runtime - Docker Container
# Multi-stage build for minimal runtime image

# ===== Build Stage =====
FROM rust:1.75-slim-bookworm as builder

WORKDIR /usr/src/ghost-runtime

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Copy Cargo files first for better layer caching
COPY Cargo.toml build.rs ./

# Copy source code
COPY src ./src
COPY sample-wasm ./sample-wasm

# Build release binary
RUN cargo build --release

# ===== Runtime Stage =====
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r ghost && useradd -r -g ghost ghost

# Copy binary from builder
COPY --from=builder /usr/src/ghost-runtime/target/release/ghost-runtime /app/ghost-runtime

# Copy sample WASM modules (optional)
COPY --from=builder /usr/src/ghost-runtime/sample-wasm ./sample-wasm

# Set ownership
RUN chown -R ghost:ghost /app

# Switch to non-root user
USER ghost

# Expose ports
# 8080 - HTTP/gRPC API
# 8081 - Metrics/Health
EXPOSE 8080 8081

# Environment variables with defaults
ENV GHOST_RUNTIME_ADDR=0.0.0.0:8080 \
    MAX_CONCURRENT_GHOSTS=100 \
    MAX_MEMORY_PER_GHOST=64MB \
    MAX_EXECUTION_TIME=5s \
    WASM_CACHE_SIZE=1000 \
    IPFS_GATEWAY=https://ipfs.io/ipfs \
    ARWEAVE_GATEWAY=https://arweave.net \
    ENABLE_PAYMENT_CHANNELS=true \
    LOG_LEVEL=info \
    RUST_LOG=info

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the runtime
ENTRYPOINT ["/app/ghost-runtime"]
