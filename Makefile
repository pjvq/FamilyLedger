# FamilyLedger — Unified Test Runner
# Usage: make <target>

.PHONY: test test-backend test-frontend test-all test-integration bench clean help

# ─── Quick (daily dev) ─────────────────────────────────────────
test: test-backend test-frontend ## Run unit tests (no Docker needed)

test-backend: ## Go unit tests (fast, no Docker)
	cd server && go test ./... -count=1 -race

test-frontend: ## Flutter widget + unit tests
	cd app && flutter test --reporter compact

# ─── Full (pre-merge) ──────────────────────────────────────────
test-all: test test-integration ## Run everything (needs Docker)

test-integration: ## Go integration tests (testcontainers + real PostgreSQL)
	@docker info > /dev/null 2>&1 || (echo "❌ Docker not running" && exit 1)
	cd server && go test ./internal/integration/... ./internal/benchmark/... \
		-tags=integration -count=1 -timeout=120s -v

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

# ─── Coverage ──────────────────────────────────────────────────
coverage-backend: ## Go coverage report
	cd server && go test ./... -coverprofile=coverage.out -covermode=atomic
	cd server && go tool cover -func=coverage.out | tail -1
	@echo "HTML: cd server && go tool cover -html=coverage.out"

coverage-frontend: ## Flutter coverage report
	cd app && flutter test --coverage
	@echo "📄 Coverage: app/coverage/lcov.info"

# ─── Helpers ───────────────────────────────────────────────────
clean: ## Remove test artifacts
	rm -f server/coverage.out server/benchmark-results.txt server/benchmark-latest.txt
	rm -rf app/coverage/

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
