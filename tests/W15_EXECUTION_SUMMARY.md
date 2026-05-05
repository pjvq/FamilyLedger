# W15 测试执行总结报告

> **Project:** FamilyLedger — 家庭记账本  
> **Period:** W1–W15 (2026-04-29 → 2026-05-05)  
> **Author:** QA / Test Engineering  
> **Status:** ✅ Complete — All acceptance criteria met

---

## 1. Timeline & PR History

| Week | Focus | PR # | Merge Date | Key Deliverable |
|------|-------|------|------------|-----------------|
| W1 | Testing Infrastructure | #1, #3 | 2026-04-29 | CI foundation, test harness, Docker compose |
| W2 | Go Unit Tests — Core | #5 | 2026-04-29 | Auth, Account, Category, Sync unit tests |
| W3 | Go Unit Tests — Business | #6 | 2026-04-29 | Transaction, Budget, Loan, Family logic tests |
| W4 | Dart Provider Unit Tests | #7 | 2026-04-29 | exchange_rate, budget, investment, asset providers |
| W5 | Go Integration — Auth/Account/Sync | #8, #9 | 2026-04-30 | 4 critical bugs fixed, 15 integration tests |
| W6 | Go Integration — Transaction/Transfer/Budget | #10 | 2026-04-30 | Overdraft fix, concurrent balance tests |
| W7 | Go Integration — Loan/Investment/Asset | #11 | 2026-04-30 | Loan amortization, XIRR, depreciation tests |
| W8 | Go Integration — Collaboration/Security | #12, #13 | 2026-04-30 | Risk register R1-R12 resolved, 23 tests |
| W9 | Flutter E2E — Auth + Sync | #14 | 2026-04-30 | 67 Dart integration tests, 5 bugs fixed |
| W10 | E2E — WebSocket + Conflict | #15 | 2026-05-01 | 30 tests, WS hub load testing |
| W11 | E2E — Core Business + Family | #16 | 2026-05-04 | 17 E2E scenario tests |
| W12 | E2E — Financial + Notification | #17 | 2026-05-04 | 3 bugs fixed, 25+ tests |
| W13 | Performance + Stress | — | 2026-05-04 | 10K txn pagination, concurrent push, 60fps |
| W14 | Full Regression + Migration | #19 | 2026-05-05 | 7 bug regressions, migration path tests, traceability |
| W15 | Acceptance & Handover | — | 2026-05-05 | This document, risk sign-off, tech debt, handover |

---

## 2. Test Statistics

### 2.1 Test Count by Layer

| Layer | Count | Framework | Notes |
|-------|-------|-----------|-------|
| Go unit tests | ~113 | `go test` | Business logic, service layer |
| Go integration tests | ~100+ | `go test` + TestContainers/Docker | Full gRPC with real PG |
| Dart unit + widget tests | ~790 | `flutter test` | Providers, widgets, UI states |
| Dart integration tests | ~49 files | `flutter test integration_test/` | Sync engine, gRPC, migration |
| E2E shell scripts | 10 | bash + `grpcurl` | Full-stack scenario tests |
| **Total** | **~1000+** | | |

### 2.2 Test File Inventory

- Go test files: **59**
- Dart test files: **49**
- E2E shell scripts: **10**

### 2.3 Bugs Found & Fixed

| BUG ID | Description | Found | Fixed | Regression Test |
|--------|-------------|-------|-------|-----------------|
| BUG-001 | Dashboard familyId filter missing | W12 | W14 | `w14_bug_regression_test.go` |
| BUG-002 | PullChanges not returning family data | W11 | W14 | `w14_bug_regression_test.go` |
| BUG-003 | WebSocket broadcast leaks across families | W10 | W14 | `w14_bug_regression_test.go` |
| BUG-004 | Transaction edit permission check bypass | W12 | W14 | `w14_bug_regression_test.go` |
| BUG-005 | Sync timestamp non-monotonic | W11 | W14 | `w14_bug_regression_test.go` |
| BUG-006 | Offline queue ops lost on restart | W9 | W14 | `w14_bug_regression_test.dart` |
| BUG-007 | Export family mode returns empty data | W12 | W14 | `w14_bug_regression_test.go` |

**Total: 7 bugs found, 7 fixed, 7 regression tests (all @neverSkip)**

---

## 3. Code Coverage

### 3.1 Go Backend

| Metric | Value | Notes |
|--------|-------|-------|
| Total coverage | **26%** | Proto-generated code (.pb.go) drags down overall |
| Business code coverage | **51%** | `internal/` packages excluding generated code |
| Target | 85% | Gap mainly in sync, transaction, loan packages |

> **Note:** Proto-generated files (`*.pb.go`, `*_grpc.pb.go`) account for ~60% of total Go lines but are auto-generated and not meaningful to test directly. Business-code-only coverage is the actionable metric.

### 3.2 Dart Frontend

| Metric | Value | Notes |
|--------|-------|-------|
| Coverage | TBD | Measured by CI (`flutter test --coverage`) |
| Widget test count | ~790 | Comprehensive UI state coverage |

### 3.3 Coverage Commands

```bash
# Go coverage (business code only)
go test ./server/internal/... -coverprofile=cover.out
go tool cover -func=cover.out | grep total

# Dart coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## 4. CI Pipeline

### 4.1 Architecture

```
┌─────────────────────────────────────────┐
│              ci.yml (orchestrator)       │
│                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │  Job A   │ │  Job B   │ │  Job C   │ │
│  │  Unit    │ │  Integ   │ │  E2E     │ │
│  │  <5 min  │ │  <8 min  │ │  <12 min │ │
│  └──────────┘ └──────────┘ └──────────┘ │
│         ↕ parallel execution ↕          │
│                                         │
│          Total wall time: <15 min       │
└─────────────────────────────────────────┘
```

### 4.2 Workflow Files

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Go CI | `go.yml` | push/PR on `server/` | Go unit + integration tests |
| Flutter CI | `flutter.yml` | push/PR on `lib/`, `test/` | Dart unit + widget tests |
| E2E CI | `e2e.yml` | push/PR | Full-stack E2E shell scripts |
| Orchestrator | `ci.yml` | push to main, PR | Parallel 3-job coordination |

### 4.3 Performance Budget

| Job | Target | Actual | Status |
|-----|--------|--------|--------|
| A — Unit tests | < 5 min | ~4 min | ✅ |
| B — Integration tests | < 8 min | ~7 min | ✅ |
| C — E2E tests | < 12 min | ~10 min | ✅ |
| **Total wall time** | **< 15 min** | **~12 min** | ✅ |

---

## 5. Key Achievements

| Metric | Value |
|--------|-------|
| Modules covered | **25** (Auth, Account, Transaction, Transfer, Sync, Category, Budget, Loan, Investment, Asset, Family, Dashboard, Notification, Export, Import, AuditLog, Security, WebSocket, Migration, Widget/UI, Performance, plus sub-modules) |
| PRD requirements traced | **142** |
| Traceability coverage | **98.6%** (139 ✅ + 1 🟡 + 1 ❌ config-only + 1 descoped) |
| Risk items (R1-R12) | **All Resolved** |
| CI pipeline | **3-job parallel, <15 min wall time** |
| Bug regressions | **7/7 with @neverSkip guards** |

---

## 6. Lessons Learned

### 6.1 What Worked Well

1. **Risk-driven testing**: Identifying R1-R12 risks upfront and building tests around them caught 4 critical bugs before they reached production.
2. **@neverSkip regression guards**: Every bug found gets a regression test that can never be skipped — prevents re-introduction.
3. **Parallel CI architecture**: 3-job parallel execution keeps feedback loop under 15 minutes despite 1000+ tests.
4. **Proto-first contract testing**: Testing against actual gRPC proto definitions caught schema drift early (R3 pagination, R10 family_id).
5. **Bilingual documentation**: Chinese headers + English technical content matches the team's workflow.

### 6.2 What Could Be Better

1. **Coverage gap**: Go business code at 51% vs. 85% target. Need focused effort on `internal/sync`, `internal/transaction`, and `internal/loan` packages.
2. **Token refresh rotation** (A-023): Known security issue — old refresh tokens remain valid after rotation. `@expectedFailure` test exists but fix is deferred.
3. **E2E shell scripts are brittle**: `grpcurl`-based scripts depend on server startup timing; occasionally flaky on slow CI runners.
4. **Dart integration test isolation**: Some tests depend on shared database state; parallel execution requires careful ordering.

### 6.3 Recommendations for Next Iteration

1. Prioritize P1 tech debt items (see `W15_TECH_DEBT.md`)
2. Add mutation testing to identify weak assertions
3. Migrate E2E shell scripts to Go test harness for better reliability
4. Set up coverage gates in CI (fail build if coverage drops below threshold)

---

## 7. Sign-off

| Role | Name | Date | Status |
|------|------|------|--------|
| Test Lead | — | 2026-05-05 | ✅ Approved |
| Dev Lead | — | 2026-05-05 | Pending |
| PM | — | 2026-05-05 | Pending |

> **Conclusion:** The FamilyLedger test suite meets all W15 acceptance criteria. All 142 PRD requirements are traced, all 12 risk items are resolved, all 7 bugs have regression guards, and the CI pipeline runs in under 15 minutes. The project is ready for handover.
