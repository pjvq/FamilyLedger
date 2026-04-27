# FamilyLedger — Unified Test Runner
# Usage: make <target>

.PHONY: test test-backend test-frontend test-all test-integration test-e2e bench bench-grpc clean help

# ─── Quick (daily dev) ─────────────────────────────────────────
test: test-backend test-frontend ## Run unit tests (no Docker needed)

test-backend: ## Go unit tests (fast, no Docker)
	cd server && go test ./... -count=1 -race

test-frontend: ## Flutter widget + unit tests
	cd app && flutter test --reporter compact

# ─── Full (pre-merge) ──────────────────────────────────────────
test-all: test test-integration test-e2e ## Run everything (needs Docker)

test-integration: ## Go integration tests (testcontainers + real PostgreSQL)
	@docker info > /dev/null 2>&1 || (echo "❌ Docker not running" && exit 1)
	cd server && go test ./internal/integration/... ./internal/benchmark/... \
		-tags=integration -count=1 -timeout=120s -v

test-e2e: ## gRPC end-to-end bash tests (needs running server + Docker)
	@grpcurl -plaintext localhost:50051 list >/dev/null 2>&1 || \
		grpcurl -plaintext localhost:50051 list 2>&1 | grep -q "Unauthenticated" || \
		(echo "❌ gRPC server not running on localhost:50051" && exit 1)
	@echo "\n🧪 Running E2E bash test suites..."
	@PASS=0; FAIL=0; \
	for f in tests/integration/test_*.sh; do \
		echo "\n━━━ $$(basename $$f) ━━━"; \
		if bash "$$f"; then \
			PASS=$$((PASS+1)); \
		else \
			FAIL=$$((FAIL+1)); \
		fi; \
	done; \
	echo "\n══════════════════════════════════════"; \
	echo "  E2E Summary: $$PASS passed, $$FAIL failed"; \
	echo "══════════════════════════════════════"; \
	test $$FAIL -eq 0

# ─── Benchmark ─────────────────────────────────────────────────
bench: ## Run Go benchmarks (needs Docker for real DB)
	@docker info > /dev/null 2>&1 || (echo "❌ Docker not running" && exit 1)
	cd server && go test ./internal/benchmark/... \
		-tags=integration -bench=. -benchtime=3s -count=1 \
		| tee benchmark-results.txt
	@echo "📊 Results saved to server/benchmark-results.txt"

bench-compare: ## Compare benchmark against saved baseline
	@test -f server/benchmark-baseline.txt || (echo "No baseline. Run 'make bench-save' first" && exit 1)
	cd server && go test ./internal/benchmark/... \
		-tags=integration -bench=. -benchtime=3s -count=5 \
		| tee benchmark-latest.txt
	@which benchstat > /dev/null 2>&1 || go install golang.org/x/perf/cmd/benchstat@latest
	benchstat server/benchmark-baseline.txt server/benchmark-latest.txt

bench-save: bench ## Save current benchmark as baseline
	cp server/benchmark-results.txt server/benchmark-baseline.txt
	@echo "✅ Baseline saved"

bench-grpc: ## Run gRPC end-to-end load tests with ghz
	bash server/bench/grpc-load-test.sh

# ─── Coverage ──────────────────────────────────────────────────
coverage-backend: ## Go coverage report
	cd server && go test ./... -coverprofile=coverage.out -covermode=atomic
	cd server && go tool cover -func=coverage.out | tail -1
	@echo "HTML: cd server && go tool cover -html=coverage.out"

coverage-frontend: ## Flutter coverage report
	cd app && flutter test --coverage
	@echo "📄 Coverage: app/coverage/lcov.info"

# ─── Flutter Performance ───────────────────────────────────────
bench-flutter: ## Run Flutter performance tests (needs device/simulator)
	cd app && flutter test integration_test/ --profile

bench-flutter-startup: ## Run Flutter startup benchmark only
	cd app && flutter test integration_test/app_performance_test.dart --profile

# ─── Helpers ───────────────────────────────────────────────────
db-migrate: ## Run database migrations (needs Docker)
	@docker exec familyledger-db psql -U familyledger -d familyledger -c "SELECT 1" > /dev/null 2>&1 || \
		(echo "❌ familyledger-db container not running" && exit 1)
	@echo "🔄 Running migrations..."
	@for f in server/migrations/*.up.sql; do \
		echo "  → $$(basename $$f)"; \
		docker exec -i familyledger-db psql -U familyledger -d familyledger < "$$f" 2>&1 | grep -v "already exists" || true; \
	done
	@echo "✅ Migrations complete"

clean: ## Remove test artifacts
	rm -f server/coverage.out server/benchmark-results.txt server/benchmark-latest.txt
	rm -rf app/coverage/

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
