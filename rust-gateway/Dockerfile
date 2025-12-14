# Build stage
FROM rust:1.75 as builder

WORKDIR /usr/src/app

# Copy manifests
COPY Cargo.toml Cargo.lock ./
COPY build.rs ./
COPY proto ./proto

# Copy source
COPY src ./src

# Build release binary
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -u 1000 noise && \
    mkdir -p /var/run/noise-gateway && \
    chown noise:noise /var/run/noise-gateway

WORKDIR /app

# Copy binary from builder
COPY --from=builder /usr/src/app/target/release/noise-gateway /app/noise-gateway

# Switch to app user
USER noise

# Expose ports
EXPOSE 8443 50051

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8443/gateway/health || exit 1

# Run
CMD ["/app/noise-gateway"]
