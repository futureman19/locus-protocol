# Ghost WASM Runtime Makefile

.PHONY: build test clean run docker docker-compose proto fmt lint

# Default target
all: build

# Build the runtime
build:
	cargo build --release

# Build for development
dev:
	cargo build

# Run tests
test:
	cargo test --all

test-verbose:
	cargo test --all -- --nocapture

# Run the runtime
run:
	cargo run

# Run with debug logging
run-debug:
	RUST_LOG=debug cargo run

# Clean build artifacts
clean:
	cargo clean
	rm -rf target/

# Format code
fmt:
	cargo fmt

# Run linter
lint:
	cargo clippy --all-targets --all-features -- -D warnings

# Generate protobuf code
proto:
	cargo build --features proto

# Build Docker image
docker:
	docker build -t ghost-runtime:latest .

# Run with Docker Compose
docker-compose:
	docker-compose up -d

# Stop Docker Compose
docker-down:
	docker-compose down

# View logs
docker-logs:
	docker-compose logs -f ghost-runtime

# Build sample WASM modules
samples:
	cd sample-wasm/greeter && cargo build --target wasm32-wasi --release
	cd sample-wasm/merchant && cargo build --target wasm32-wasi --release
	cd sample-wasm/oracle && cargo build --target wasm32-wasi --release

# Install required Rust targets
setup:
	rustup target add wasm32-wasi
	cargo install cargo-watch cargo-expand

# Benchmark
bench:
	cargo bench

# Security audit
audit:
	cargo audit

# Generate documentation
docs:
	cargo doc --no-deps --open

# CI pipeline
ci: fmt lint test build
	@echo "CI checks passed!"
