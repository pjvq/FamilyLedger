# W15 交接文档 — Test Maintenance Guide

> **Project:** FamilyLedger — 家庭记账本  
> **Date:** 2026-05-05  
> **Purpose:** Guide for maintaining and extending the test suite in future iterations

---

## 1. 项目测试架构总览

```
FamilyLedger/
├── .github/workflows/          # CI configuration
│   ├── ci.yml                  # Orchestrator (parallel 3-job)
│   ├── go.yml                  # Go unit + integration
│   ├── flutter.yml             # Dart unit + widget
│   └── e2e.yml                 # Full-stack E2E
├── server/
│   ├── internal/               # Business logic (test target)
│   │   ├── auth/
│   │   ├── sync/
│   │   ├── transaction/
│   │   ├── migration/
│   │   │   └── migration_test.go
│   │   └── ...
│   ├── migrations/             # SQL migrations (001-040)
│   │   ├── 001_create_users.up.sql
│   │   ├── 001_create_users.down.sql
│   │   └── ...040
│   └── ws/                     # WebSocket hub
│       ├── hub_test.go
│       └── hub_load_test.go
├── proto/                      # gRPC proto definitions
│   ├── sync.proto
│   ├── transaction.proto
│   └── ...
├── test/                       # Dart test files
│   ├── *_test.dart             # Unit + widget tests (~790 tests)
│   └── integration_test/       # Dart integration tests
├── tests/                      # Test documentation & E2E
│   ├── integration/            # E2E shell scripts
│   │   ├── e2e-grpc-test.sh
│   │   ├── test_basic_services.sh
│   │   └── ...
│   ├── risks/                  # Risk verification docs
│   ├── TRACEABILITY_MATRIX.md
│   ├── FLAKY_POLICY.md
│   ├── W15_EXECUTION_SUMMARY.md
│   ├── W15_RISK_REGISTER_FINAL.md
│   ├── W15_TECH_DEBT.md
│   └── W15_HANDOVER.md         # ← This file
└── integration_test/           # Go integration tests
    ├── w5_complete_test.go
    ├── w6_transaction_test.go
    ├── w7_financial_test.go
    ├── w8_collaboration_test.go
    ├── w8_p1_fixes_test.go
    ├── w8_supplement_test.go
    ├── w13_performance_test.go
    ├── w14_migration_test.go
    ├── w14_bug_regression_test.go
    └── ...
```

---

## 2. 如何为新模块添加测试

### 2.1 Go 单元测试

1. Create test file alongside source: `server/internal/<module>/<module>_test.go`
2. Use table-driven tests:

```go
func TestMyModule_NewFeature(t *testing.T) {
    tests := []struct {
        name    string
        input   *pb.MyRequest
        want    *pb.MyResponse
        wantErr codes.Code
    }{
        {name: "happy path", input: &pb.MyRequest{...}, want: &pb.MyResponse{...}},
        {name: "invalid input", input: &pb.MyRequest{}, wantErr: codes.InvalidArgument},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // test implementation
        })
    }
}
```

3. Run: `go test ./server/internal/<module>/...`

### 2.2 Go 集成测试

1. Create file in `integration_test/` directory: `w<N>_<feature>_test.go`
2. Use the existing test helpers for gRPC client setup:

```go
func TestW16_NewFeature(t *testing.T) {
    // Use existing helpers for auth, client setup
    ctx, client := setupTestClient(t)
    defer cleanup(t)
    
    // Register + login to get auth token
    token := registerAndLogin(t, ctx, client)
    
    // Test your feature
    resp, err := client.NewFeatureRPC(
        metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token),
        &pb.NewFeatureRequest{...},
    )
    require.NoError(t, err)
    assert.Equal(t, expected, resp.Field)
}
```

3. Run: `go test ./integration_test/ -run TestW16 -v`

### 2.3 Dart 单元/Widget 测试

1. Create in `test/` directory: `<feature>_test.dart`
2. Follow existing patterns:

```dart
void main() {
  group('NewFeature', () {
    test('should do X when Y', () {
      // Arrange
      final provider = NewFeatureProvider();
      // Act
      final result = provider.calculate(input);
      // Assert
      expect(result, equals(expected));
    });
  });
}
```

3. Run: `flutter test test/<feature>_test.dart`

### 2.4 Dart 集成测试

1. Create in `test/integration_test/`: `<feature>_integration_test.dart`
2. Run: `flutter test test/integration_test/<feature>_integration_test.dart`

---

## 3. 如何扩展 E2E 测试

### 3.1 Go Test Helpers

The integration test directory contains reusable helpers. To add a new E2E scenario:

1. Add to existing `w<N>_*_test.go` file, or create a new one
2. Use these established patterns:
   - `setupTestClient(t)` — creates gRPC connection with test server
   - `registerAndLogin(t, ...)` — handles auth flow, returns JWT
   - `createTestFamily(t, ...)` — sets up family with invite flow
   - Metadata context: `metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token)`

### 3.2 Dart Integration Harness

1. Dart integration tests use mocked or real gRPC backends
2. For sync tests, use `FakeSyncEngine` or real gRPC with `GrpcTestServer`
3. Database tests use in-memory Drift databases

### 3.3 E2E Shell Scripts

Location: `tests/integration/`

```bash
#!/bin/bash
# test_new_feature.sh
set -euo pipefail
source "$(dirname "$0")/e2e-grpc-test.sh"  # Common helpers

# Setup
start_server
TOKEN=$(register_and_login "test@example.com" "password123")

# Test
RESPONSE=$(grpcurl -plaintext \
  -H "authorization: Bearer $TOKEN" \
  -d '{"field": "value"}' \
  localhost:50051 familyledger.v1.NewService/NewRPC)

# Assert
echo "$RESPONSE" | jq -e '.result == "expected"' || fail "Unexpected response"

echo "✅ New feature test passed"
```

---

## 4. CI 配置指南

### 4.1 Workflow 修改时机

| When you... | Modify... |
|-------------|-----------|
| Add Go tests | `go.yml` — usually no change needed (runs all `./...`) |
| Add Dart tests | `flutter.yml` — usually no change needed |
| Add E2E shell scripts | `e2e.yml` — add script to test matrix |
| Add new service dependency (Redis, etc.) | `ci.yml` — add to Docker services |
| Change test timeout | Individual workflow file |

### 4.2 Parallel Job Structure

```yaml
# ci.yml orchestrates 3 parallel jobs:
jobs:
  unit-tests:        # Job A: go test + flutter test (unit)    < 5 min
  integration-tests: # Job B: go test (integration, needs PG)  < 8 min
  e2e-tests:         # Job C: full-stack E2E scripts           < 12 min
```

### 4.3 Adding a New CI Job

If tests grow beyond 15 min wall time, split a job:

1. Create new job in `ci.yml`
2. Add appropriate `services:` (PostgreSQL, etc.)
3. Set `needs:` dependencies if ordering matters
4. Update the performance budget in `W15_EXECUTION_SUMMARY.md`

---

## 5. 如何添加新的 Migration

### 5.1 Go Backend (PostgreSQL)

1. Create migration files in `server/migrations/`:
   ```
   041_<description>.up.sql
   041_<description>.down.sql
   ```

2. **Numbering**: Sequential, 3-digit padded. Check `ls server/migrations/ | tail -2` for the latest number.

3. **Up migration** (`.up.sql`):
   ```sql
   -- 041_add_recurring_transactions.up.sql
   CREATE TABLE recurring_transactions (
       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
       user_id UUID NOT NULL REFERENCES users(id),
       ...
   );
   ```

4. **Down migration** (`.down.sql`):
   ```sql
   -- 041_add_recurring_transactions.down.sql
   DROP TABLE IF EXISTS recurring_transactions;
   ```

5. **Test**: Add to `w14_migration_test.go` pattern:
   ```go
   func TestMigration_041_RecurringTransactions(t *testing.T) {
       // Migrate up to 041
       // Verify table exists + constraints
       // Insert test data
       // Migrate down
       // Verify table dropped
   }
   ```

### 5.2 Dart Frontend (Drift)

1. Add new schema version in Drift database class
2. Create migration step:
   ```dart
   // In database migration onUpgrade:
   if (from < 13) {
     await m.createTable(recurringTransactions);
   }
   ```
3. Test: Add to `w14_database_migration_full_test.dart` pattern
4. Bump schema version number

---

## 6. 如何添加 @neverSkip Bug 回归测试

When a new bug is found:

### 6.1 Go Side

Add to `integration_test/w14_bug_regression_test.go` (or create `w16_bug_regression_test.go` for future iterations):

```go
// TestBUG008_Description documents and guards against regression of BUG-008.
// @neverSkip — This test must never be skipped or deleted.
// Bug: [description of the bug]
// Fix: [what was changed to fix it]
// PR: #XX
func TestBUG008_Description(t *testing.T) {
    // Setup: reproduce the exact conditions that triggered the bug
    // Action: perform the operation that was buggy
    // Assert: verify the correct behavior (not the buggy behavior)
}
```

### 6.2 Dart Side

Add to `test/w14_bug_regression_test.dart` (or new file):

```dart
// @neverSkip — BUG-008 regression guard
test('BUG-008: description of the bug', () {
  // Reproduce conditions → verify fix holds
});
```

### 6.3 Update Traceability

Add the new bug to `tests/TRACEABILITY_MATRIX.md` in the **Bug Regressions** section.

---

## 7. 测试文件命名规范

### Go Test Files

| Pattern | Location | Purpose |
|---------|----------|---------|
| `*_test.go` | `server/internal/<pkg>/` | Unit tests (same package) |
| `w<N>_<feature>_test.go` | `integration_test/` | Integration tests by week |
| `w<N>_bug_regression_test.go` | `integration_test/` | Bug regression tests |
| `w<N>_migration_test.go` | `integration_test/` | Migration path tests |
| `w<N>_performance_test.go` | `integration_test/` | Performance/stress tests |

### Dart Test Files

| Pattern | Location | Purpose |
|---------|----------|---------|
| `<feature>_test.dart` | `test/` | Unit + widget tests |
| `<feature>_w<N>_test.dart` | `test/` | Week-specific feature tests |
| `w<N>_*_test.dart` | `test/` | Week-specific regression tests |
| `*_integration_test.dart` | `test/integration_test/` | Integration tests |

### Shell Scripts

| Pattern | Location | Purpose |
|---------|----------|---------|
| `test_<feature>.sh` | `tests/integration/` | E2E scenario scripts |
| `e2e-grpc-test.sh` | `tests/integration/` | Shared helpers (source this) |

---

## 8. Key File Locations

| Category | Path |
|----------|------|
| **Go unit tests** | `server/internal/*/` |
| **Go integration tests** | `integration_test/` |
| **Dart unit + widget** | `test/` |
| **Dart integration** | `test/integration_test/` |
| **E2E shell scripts** | `tests/integration/` |
| **CI workflows** | `.github/workflows/` |
| **SQL migrations** | `server/migrations/` (001–040) |
| **Migration logic** | `server/internal/migration/` |
| **Proto definitions** | `proto/` |
| **Risk docs** | `tests/risks/` |
| **Traceability matrix** | `tests/TRACEABILITY_MATRIX.md` |
| **Flaky test policy** | `tests/FLAKY_POLICY.md` |
| **Tech debt** | `tests/W15_TECH_DEBT.md` |
| **WebSocket tests** | `server/ws/` |

---

## 9. Coverage 测量命令

### Go Coverage

```bash
# Full coverage (includes generated code)
cd server && go test ./... -coverprofile=cover.out
go tool cover -func=cover.out | grep total

# Business code only (excludes proto-generated)
go test ./internal/... -coverprofile=cover_biz.out
go tool cover -func=cover_biz.out | grep total

# HTML report
go tool cover -html=cover.out -o coverage.html

# Per-package breakdown
go tool cover -func=cover.out | sort -k 3 -t $'\t' -rn
```

### Dart Coverage

```bash
# Generate coverage
flutter test --coverage

# HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Summary
lcov --summary coverage/lcov.info
```

### Coverage Targets

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Go total | 26% | — | Proto-generated skew |
| Go business | 51% | 85% | 34% gap |
| Dart | TBD | 80% | Measured by CI |

---

## 10. 常见维护场景 Quick Reference

| Scenario | Steps |
|----------|-------|
| **New gRPC endpoint** | 1. Update proto 2. `protoc` regenerate 3. Add Go handler 4. Add integration test 5. Update traceability matrix |
| **New Dart provider** | 1. Create provider 2. Add `<provider>_test.dart` 3. Add to existing widget test if UI involved |
| **Bug report** | 1. Write failing test first 2. Fix the bug 3. Mark test as `@neverSkip` 4. Add to traceability matrix Bug Regression section |
| **Proto field added** | 1. Update `.proto` 2. Regenerate both Go + Dart 3. Update affected tests 4. Check traceability for related PRD requirements |
| **New SQL migration** | 1. Create `NNN_desc.up.sql` + `.down.sql` 2. Test up + down + data integrity 3. Update Drift schema version if Dart-side table |
| **Flaky test** | See `tests/FLAKY_POLICY.md` for quarantine procedure |
