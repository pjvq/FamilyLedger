# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

### Quick (daily dev, no Docker)

```bash
make test                # Run both backend + frontend unit tests
make test-backend        # cd server && go test ./... -count=1 -race
make test-frontend       # cd app && flutter test --reporter compact
```

### Single test targeting

```bash
# Go — single package
cd server && go test ./internal/loan/... -count=1 -run TestPrepayment

# Flutter — single file
cd app && flutter test test/sync/sync_engine_test.dart
```

### Integration & E2E (requires Docker)

```bash
make test-integration    # Go + testcontainers + real PostgreSQL
make test-e2e            # gRPC bash E2E tests (needs running server on :50051)
```

### Server development

```bash
docker compose up -d postgres          # Start DB only
cd server && make migrate-up           # Run migrations
cd server && make run                  # Build + run (gRPC :50051, WS :8080)
cd server && make proto                # Regenerate Go proto stubs
```

### Flutter development

```bash
cd app && flutter pub get
cd app && flutter run -d iphone        # or -d android
cd app && dart run build_runner build   # Regenerate Drift/Riverpod code
```

### Coverage gates (CI enforced)

- Go: >= 80%
- Flutter: >= 40%

## Architecture

**Monorepo**: Flutter mobile client (`app/`) + Go gRPC backend (`server/`) + shared protobuf definitions (`proto/`).

### Server — Go + gRPC + PostgreSQL

- Entry point: `server/cmd/server/main.go`
- 19 business packages under `server/internal/` (one per domain: transaction, loan, investment, etc.)
- **Pipeline pattern** for transaction creation: ordered stages implementing `Stage` interface (`server/internal/transaction/pipeline.go`). Add new concern = implement Stage + register.
- **Sync engine**: `server/internal/sync/` — incremental gRPC sync + WebSocket real-time push via `pkg/ws/` Hub
- DB mocks: `pgxmock` (no codegen — satisfies `db.Pool` interface directly)
- Integration tests: `server/internal/integration/` using testcontainers-go
- 46 sequential SQL migrations in `server/migrations/`

### Client — Flutter + Riverpod + Drift

- Clean Architecture with DIP: `features/` (UI) → `domain/` (pure Dart logic + interfaces) → `data/` (Drift DB + gRPC)
- State management: Riverpod with code generation (`riverpod_generator`)
- Local DB: Drift (SQLite) — offline-first, data persists without server
- Sync state machine: `app/lib/sync/` — formal states (offline/pending/syncing/synced/failed), pure-function transitions
- Generated proto stubs: `app/lib/generated/proto/`
- Server address config: `app/lib/core/constants/app_constants.dart`

### Proto layer

13 `.proto` files in `proto/` shared between client and server. Go stubs go to `server/proto/<service>/`, Dart stubs to `app/lib/generated/proto/`.

## Key Patterns

- **Soft-delete**: all entities use `deleted_at` column; queries must filter `WHERE deleted_at IS NULL`
- **Family permissions**: 5-dimension permission model checked via `pkg/permission/`; most gRPC handlers call permission checks
- **LWW conflict resolution**: sync uses last-writer-wins with server timestamp
- **Entity ops**: `server/internal/sync/entity_ops.go` handles 7 entity types for incremental sync

## Environment

Server reads config from env vars (see `.env.example`). Key ones: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`, `GRPC_PORT` (50051), `WS_PORT` (8080), `OAUTH_MODE` (mock/production).

## China Dev Proxies

```bash
export GOPROXY=https://goproxy.cn,direct
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## Agent skills

### Issue tracker

Issues live in GitHub Issues (pjvq/FamilyLedger). See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — one `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.
