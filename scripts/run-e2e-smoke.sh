#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# FamilyLedger E2E Smoke Test Runner
#
# Spins up Docker Compose (DB + Server), runs 5 golden-path E2E tests,
# then tears everything down.
#
# Usage:
#   ./scripts/run-e2e-smoke.sh          # Full cycle: up → test → down
#   ./scripts/run-e2e-smoke.sh --up     # Start services only (for interactive dev)
#   ./scripts/run-e2e-smoke.sh --down   # Stop services only
#   ./scripts/run-e2e-smoke.sh --test   # Run tests only (assumes services running)
#
# Exit codes:
#   0 — all tests passed (or skipped gracefully)
#   1 — test failures
#   2 — infrastructure failure (Docker/server didn't start)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()  { printf "${BLUE}[E2E]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[E2E]${NC} ✅ %s\n" "$*"; }
warn() { printf "${YELLOW}[E2E]${NC} ⚠️  %s\n" "$*"; }
err()  { printf "${RED}[E2E]${NC} ❌ %s\n" "$*"; }

# ─── Ensure .env exists ──────────────────────────────────────────────────────
ensure_env() {
  local env_file="$PROJECT_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    log "Creating .env with test defaults..."
    cat > "$env_file" <<'EOF'
# Auto-generated for E2E testing. DO NOT use in production.
DB_USER=familyledger
DB_PASSWORD=e2e_test_password
DB_NAME=familyledger
JWT_SECRET=e2e-test-secret-must-be-at-least-32-characters-long
OAUTH_MODE=mock
EOF
  fi
}

# ─── Start Services ──────────────────────────────────────────────────────────
services_up() {
  log "Starting Docker Compose services..."
  ensure_env

  cd "$PROJECT_DIR"
  docker compose -f "$COMPOSE_FILE" up -d --build --wait 2>&1 | while read -r line; do
    printf "  %s\n" "$line"
  done

  # Wait for gRPC port to be accepting connections
  local max_wait=60
  local elapsed=0
  log "Waiting for gRPC server (port 50051)..."
  while ! nc -z 127.0.0.1 50051 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [[ $elapsed -ge $max_wait ]]; then
      err "Server did not start within ${max_wait}s"
      docker compose -f "$COMPOSE_FILE" logs server | tail -20
      return 2
    fi
  done
  ok "gRPC server ready (${elapsed}s)"

  # Verify WebSocket port
  if nc -z 127.0.0.1 8080 2>/dev/null; then
    ok "WebSocket server ready"
  else
    warn "WebSocket port 8080 not responding (non-fatal for smoke tests)"
  fi
}

# ─── Stop Services ───────────────────────────────────────────────────────────
services_down() {
  log "Stopping Docker Compose services..."
  cd "$PROJECT_DIR"
  docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>&1 | while read -r line; do
    printf "  %s\n" "$line"
  done
  ok "Services stopped"
}

# ─── Run Tests ───────────────────────────────────────────────────────────────
run_tests() {
  log "Running E2E smoke tests (5 golden paths, 19 tests)..."
  cd "$PROJECT_DIR/app"

  local exit_code=0
  flutter test test/integration_test/e2e_smoke_test.dart \
    --reporter compact \
    --timeout 30s \
    --concurrency 1 || exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    ok "All E2E smoke tests passed"
  else
    err "E2E smoke tests failed (exit code: $exit_code)"
  fi
  return $exit_code
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  local mode="${1:-full}"

  case "$mode" in
    --up)
      services_up
      ;;
    --down)
      services_down
      ;;
    --test)
      run_tests
      ;;
    full|*)
      # Full cycle: up → test → down (with cleanup on failure)
      trap 'services_down' EXIT

      services_up || exit 2
      run_tests
      ;;
  esac
}

main "$@"
