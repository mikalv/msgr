#!/bin/bash
# Start all services for Noise Gateway integration testing

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_DIR="$SCRIPT_DIR/backend"
RUST_GATEWAY_DIR="$SCRIPT_DIR/rust-gateway"
FLUTTER_DIR="$SCRIPT_DIR/flutter_frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if PostgreSQL is running
check_postgres() {
    log_info "Checking PostgreSQL..."
    if ! pg_isready -h localhost -p 5432 &>/dev/null; then
        log_error "PostgreSQL is not running on localhost:5432"
        log_info "Start PostgreSQL with: brew services start postgresql@14"
        exit 1
    fi
    log_success "PostgreSQL is running"
}

# Start Elixir backend
start_elixir() {
    log_info "Starting Elixir backend..."

    cd "$BACKEND_DIR"

    # Check if database exists
    if ! psql -U postgres -lqt | cut -d \| -f 1 | grep -qw msgr_dev; then
        log_warning "Database msgr_dev does not exist, creating..."
        mix ecto.create
    fi

    # Run migrations
    log_info "Running database migrations..."
    mix ecto.migrate

    # Start Phoenix in background
    log_info "Starting Phoenix server..."
    export PORT=4000
    export RUST_GATEWAY_HOST=localhost
    export RUST_GATEWAY_GRPC_PORT=50051
    export RUST_GATEWAY_SERVER_PORT=50052

    # Start in background
    iex -S mix phx.server &
    ELIXIR_PID=$!

    log_success "Elixir backend starting (PID: $ELIXIR_PID)"

    # Wait for Elixir to be ready
    log_info "Waiting for Elixir to start..."
    for i in {1..30}; do
        if curl -s http://localhost:4000/api/health &>/dev/null; then
            log_success "Elixir backend is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Elixir backend failed to start"
            kill $ELIXIR_PID 2>/dev/null || true
            exit 1
        fi
        sleep 1
    done
}

# Start Rust Gateway
start_rust() {
    log_info "Starting Rust Gateway..."

    cd "$RUST_GATEWAY_DIR"

    # Check .env exists
    if [ ! -f .env ]; then
        log_error ".env file not found in $RUST_GATEWAY_DIR"
        exit 1
    fi

    # Build in release mode
    log_info "Building Rust Gateway (release mode)..."
    cargo build --release

    # Start in background
    log_info "Starting Rust Gateway..."
    ./target/release/rust-gateway &
    RUST_PID=$!

    log_success "Rust Gateway starting (PID: $RUST_PID)"

    # Wait for Rust to be ready
    log_info "Waiting for Rust Gateway to start..."
    for i in {1..30}; do
        if curl -s http://localhost:8443/gateway/health &>/dev/null; then
            log_success "Rust Gateway is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Rust Gateway failed to start"
            kill $RUST_PID 2>/dev/null || true
            kill $ELIXIR_PID 2>/dev/null || true
            exit 1
        fi
        sleep 1
    done
}

# Test basic connectivity
test_connectivity() {
    log_info "Testing connectivity..."

    # Test Rust Gateway health
    if curl -s http://localhost:8443/gateway/health | grep -q "ok"; then
        log_success "Rust Gateway health check passed"
    else
        log_error "Rust Gateway health check failed"
        return 1
    fi

    # Test Elixir backend (through Rust proxy)
    if curl -s http://localhost:8443/api/health &>/dev/null; then
        log_success "Elixir backend (via Rust proxy) health check passed"
    else
        log_error "Elixir backend health check failed"
        return 1
    fi
}

# Show instructions
show_instructions() {
    echo ""
    log_success "=== All services started successfully! ==="
    echo ""
    log_info "Services running:"
    echo "  - Elixir Backend:  http://localhost:4000 (PID: $ELIXIR_PID)"
    echo "  - Rust Gateway:    http://localhost:8443 (PID: $RUST_PID)"
    echo "  - Elixir gRPC:     localhost:50052"
    echo "  - Rust gRPC:       localhost:50051"
    echo ""
    log_info "To run integration tests:"
    echo ""
    echo "  # Terminal 1 (Alice):"
    echo "  cd $FLUTTER_DIR/packages/libmsgr"
    echo "  dart test/integration/noise_gateway_test.dart --alice"
    echo ""
    echo "  # Terminal 2 (Bob):"
    echo "  cd $FLUTTER_DIR/packages/libmsgr"
    echo "  dart test/integration/noise_gateway_test.dart --bob"
    echo ""
    log_info "To stop all services:"
    echo "  kill $ELIXIR_PID $RUST_PID"
    echo ""
    log_warning "Press Ctrl+C to stop all services and exit"
    echo ""

    # Wait for user interrupt
    trap "cleanup" INT TERM

    wait
}

# Cleanup on exit
cleanup() {
    echo ""
    log_info "Shutting down services..."

    if [ ! -z "$RUST_PID" ]; then
        log_info "Stopping Rust Gateway (PID: $RUST_PID)..."
        kill $RUST_PID 2>/dev/null || true
    fi

    if [ ! -z "$ELIXIR_PID" ]; then
        log_info "Stopping Elixir backend (PID: $ELIXIR_PID)..."
        kill $ELIXIR_PID 2>/dev/null || true
    fi

    log_success "All services stopped"
    exit 0
}

# Main execution
main() {
    log_info "=== Starting Noise Gateway Integration Test Environment ==="
    echo ""

    check_postgres
    start_elixir
    start_rust
    test_connectivity
    show_instructions
}

main
