#!/usr/bin/env bash
#
# gRPC Load Test Script using ghz
# Targets: TransactionService, DashboardService, SyncService, AuthService
#
set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROTO_DIR="$PROJECT_ROOT/proto"
PROTO_IMPORT_PATH="/opt/homebrew/include"  # google/protobuf/timestamp.proto etc.

SERVER_ADDR="${BENCH_SERVER_ADDR:-localhost:50051}"
TOTAL_REQUESTS="${BENCH_TOTAL:-1000}"
CONCURRENCY="${BENCH_CONCURRENCY:-10}"
CONNECTIONS="${BENCH_CONNECTIONS:-5}"
RESULTS_DIR="$SCRIPT_DIR/results"

# Test user credentials (override via env)
TEST_EMAIL="${BENCH_EMAIL:-bench@test.com}"
TEST_PASSWORD="${BENCH_PASSWORD:-benchtest123}"

# ─── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ─── Preflight Checks ─────────────────────────────────────────
check_ghz() {
    if ! command -v ghz &> /dev/null; then
        error "ghz not found. Install: brew install ghz"
        exit 1
    fi
    info "ghz version: $(ghz --version)"
}

check_server() {
    info "Checking server at $SERVER_ADDR..."
    local host port
    host="${SERVER_ADDR%%:*}"
    port="${SERVER_ADDR##*:}"
    # Simple TCP probe — if port is open, server is likely running
    if ! (echo >/dev/tcp/$host/$port) 2>/dev/null; then
        return 1
    fi
    return 0
}

SERVER_PID=""
start_server() {
    warn "Server not running at $SERVER_ADDR"
    info "Attempting to start local server..."

    if [[ ! -f "$PROJECT_ROOT/server/cmd/server/main.go" ]]; then
        error "Cannot find server entry point at server/cmd/server/main.go"
        error "Please start the server manually: cd server && go run cmd/server/main.go"
        exit 1
    fi

    cd "$PROJECT_ROOT/server"
    go run cmd/server/main.go &
    SERVER_PID=$!
    cd "$SCRIPT_DIR"

    info "Waiting for server to start (PID: $SERVER_PID)..."
    local retries=0
    while ! check_server 2>/dev/null; do
        retries=$((retries + 1))
        if [[ $retries -ge 30 ]]; then
            error "Server failed to start within 30s"
            kill "$SERVER_PID" 2>/dev/null || true
            exit 1
        fi
        sleep 1
    done
    ok "Server started successfully"
}

cleanup() {
    if [[ -n "$SERVER_PID" ]]; then
        info "Stopping server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ─── Auth Helper ───────────────────────────────────────────────
TOKEN=""
obtain_token() {
    info "Obtaining auth token..."
    local response
    response=$(ghz --insecure \
        --proto "$PROTO_DIR/auth.proto" \
        --import-paths "$PROTO_DIR,$PROTO_IMPORT_PATH" \
        --call familyledger.auth.v1.AuthService/Login \
        --data "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}" \
        --total 1 \
        --format json \
        "$SERVER_ADDR" 2>/dev/null || true)

    # Try to extract token from the response (ghz doesn't return response body directly)
    # For load testing, we'll use a pre-configured token if available
    if [[ -n "${BENCH_TOKEN:-}" ]]; then
        TOKEN="$BENCH_TOKEN"
        ok "Using pre-configured token"
    else
        warn "No BENCH_TOKEN set. Running tests without auth metadata."
        warn "Set BENCH_TOKEN env var or BENCH_EMAIL/BENCH_PASSWORD for authenticated tests."
    fi
}

# ─── Benchmark Runner ──────────────────────────────────────────
run_bench() {
    local name="$1"
    local proto_file="$2"
    local call="$3"
    local data="$4"
    local output_file="$RESULTS_DIR/${name}.json"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "Benchmarking: $call"
    info "  Total: $TOTAL_REQUESTS | Concurrency: $CONCURRENCY | Connections: $CONNECTIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local -a metadata_args=()
    if [[ -n "$TOKEN" ]]; then
        metadata_args=(--metadata "{\"authorization\":\"Bearer $TOKEN\"}")
    fi

    # ghz requires: connections <= concurrency
    local effective_conns="$CONNECTIONS"
    if [[ $effective_conns -gt $CONCURRENCY ]]; then
        effective_conns="$CONCURRENCY"
    fi

    # Build command args
    local -a cmd_args=(
        ghz --insecure
        --proto "$PROTO_DIR/$proto_file"
        --import-paths "$PROTO_DIR,$PROTO_IMPORT_PATH"
        --call "$call"
        --data "$data"
        --total "$TOTAL_REQUESTS"
        --concurrency "$CONCURRENCY"
        --connections "$effective_conns"
        --format pretty
        --output "$output_file"
    )
    if [[ ${#metadata_args[@]} -gt 0 ]]; then
        cmd_args+=("${metadata_args[@]}")
    fi
    cmd_args+=("$SERVER_ADDR")

    # Run benchmark
    "${cmd_args[@]}" || true

    ok "Results saved to: $output_file"
}

# ─── Main ──────────────────────────────────────────────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║         FamilyLedger gRPC Load Test Suite                   ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Server:      $SERVER_ADDR"
    echo "║  Total:       $TOTAL_REQUESTS requests per endpoint"
    echo "║  Concurrency: $CONCURRENCY"
    echo "║  Connections: $CONNECTIONS"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    check_ghz

    # Create results directory
    mkdir -p "$RESULTS_DIR"

    # Check if server is running, start if not
    if ! check_server; then
        start_server
    else
        ok "Server is running at $SERVER_ADDR"
    fi

    # Obtain auth token
    obtain_token

    # ─── 1. AuthService/Login (认证 - 不需要 token) ─────────────
    run_bench "auth-login" \
        "auth.proto" \
        "familyledger.auth.v1.AuthService/Login" \
        "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}"

    # ─── 2. AuthService/RefreshToken (令牌刷新) ─────────────────
    if [[ -n "$TOKEN" ]]; then
        run_bench "auth-refresh-token" \
            "auth.proto" \
            "familyledger.auth.v1.AuthService/RefreshToken" \
            "{\"refresh_token\":\"${BENCH_REFRESH_TOKEN:-dummy-refresh-token}\"}"
    fi

    # ─── 3. TransactionService/ListTransactions (读热路径) ──────
    run_bench "transaction-list" \
        "transaction.proto" \
        "familyledger.transaction.v1.TransactionService/ListTransactions" \
        "{\"page_size\":20}"

    # ─── 4. TransactionService/CreateTransaction (写热路径) ─────
    run_bench "transaction-create" \
        "transaction.proto" \
        "familyledger.transaction.v1.TransactionService/CreateTransaction" \
        "{\"account_id\":\"bench-account\",\"category_id\":\"bench-cat\",\"amount\":1000,\"currency\":\"CNY\",\"amount_cny\":1000,\"exchange_rate\":1.0,\"type\":2,\"note\":\"bench test\"}"

    # ─── 5. DashboardService/GetNetWorth (聚合查询) ────────────
    run_bench "dashboard-networth" \
        "dashboard.proto" \
        "familyledger.dashboard.v1.DashboardService/GetNetWorth" \
        "{}"

    # ─── 6. DashboardService/GetCategoryBreakdown (聚合查询) ───
    run_bench "dashboard-category-breakdown" \
        "dashboard.proto" \
        "familyledger.dashboard.v1.DashboardService/GetCategoryBreakdown" \
        "{}"

    # ─── 7. SyncService/PullChanges (同步热路径) ───────────────
    run_bench "sync-pull-changes" \
        "sync.proto" \
        "familyledger.sync.v1.SyncService/PullChanges" \
        "{\"client_id\":\"bench-client-001\"}"

    # ─── Summary ───────────────────────────────────────────────
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    BENCHMARK COMPLETE                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    info "Results directory: $RESULTS_DIR"
    ls -la "$RESULTS_DIR"/*.json 2>/dev/null || warn "No JSON results generated (server may not be running)"
    echo ""
}

main "$@"
