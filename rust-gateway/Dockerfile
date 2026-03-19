# ==============================================================================
# Multi-stage Dockerfile for the Noise Protocol Gateway
# Stages: build, dev, prod
# ==============================================================================

# ==============================================================================
# Stage: build — compile the release binary
# ==============================================================================
FROM rustlang/rust:nightly AS build

WORKDIR /usr/src/app

RUN apt-get update && \
    apt-get install -y protobuf-compiler && \
    rm -rf /var/lib/apt/lists/*

# Copy manifests first for layer caching
COPY Cargo.toml Cargo.lock ./
COPY build.rs ./
COPY proto ./proto

# Copy source and build
COPY src ./src

RUN cargo build --release

# ==============================================================================
# Stage: dev — development image with full toolchain
# ==============================================================================
FROM rustlang/rust:nightly AS dev

WORKDIR /usr/src/app

RUN apt-get update && \
    apt-get install -y protobuf-compiler ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# Install cargo-watch for hot-reload during development
RUN cargo install cargo-watch

COPY Cargo.toml Cargo.lock ./
COPY build.rs ./
COPY proto ./proto
COPY src ./src

EXPOSE 8443 50051

CMD ["cargo", "watch", "-x", "run"]

# ==============================================================================
# Stage: prod — minimal runtime image
# ==============================================================================
FROM debian:bookworm-slim AS prod

RUN apt-get update && \
    apt-get install -y ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 noise && \
    mkdir -p /var/run/noise-gateway && \
    chown noise:noise /var/run/noise-gateway

WORKDIR /app

COPY --from=build /usr/src/app/target/release/noise-gateway /app/noise-gateway

USER noise

EXPOSE 8443 50051

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8443/gateway/health || exit 1

CMD ["/app/noise-gateway"]
