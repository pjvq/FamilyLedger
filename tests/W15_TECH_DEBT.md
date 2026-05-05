# W15 技术债清单

> **Project:** FamilyLedger — 家庭记账本  
> **Date:** 2026-05-05  
> **Scope:** Issues discovered during W1–W15 testing that are deferred to future iterations  
> **Status:** Catalogued for next sprint planning

---

## Priority Legend

| Priority | Definition | Action |
|----------|-----------|--------|
| **P0** | Critical — blocks release | Must fix before release |
| **P1** | High — security or correctness issue | Fix in next iteration |
| **P2** | Medium — feature gap or test gap | Schedule when capacity allows |

---

## P0 — Critical

**None.** All P0 issues discovered during testing have been fixed.

---

## P1 — High Priority

### ~~P1-1: Token Refresh Rotation Missing (A-023)~~ — ✅ FIXED in W15

| Field | Value |
|-------|-------|
| **Status** | ✅ **Fixed** — migration 041 + revoked_tokens table + SHA-256 blacklist |
| **Test** | `w15_p1_fixes_test.go` → `TestW15_P1_1_RefreshToken_Rotation` |

---

### ~~P1-2: Push Unknown entity_type Silently Accepted (S-018)~~ — ✅ FIXED in W15

| Field | Value |
|-------|-------|
| **Status** | ✅ **Fixed** — `applyOperation` returns error for unknown types, op goes to `FailedIds` |
| **Test** | `w15_p1_fixes_test.go` → `TestW15_P1_2_PushOperations_UnknownEntityType_Rejected` |

---

### ~~P1-3: gRPC Reflection Enabled in Production Config (SEC-006)~~ — ✅ FIXED in W15

| Field | Value |
|-------|-------|
| **Status** | ✅ **Fixed** — gated behind `ENABLE_GRPC_REFLECTION` env var (default off) |
| **Test** | `w15_p1_fixes_test.go` → `TestW15_P1_3_GrpcReflection_EnvGating` |

---

### P1-4: Code Coverage Below Target

| Field | Value |
|-------|-------|
| **Req ID** | — |
| **Category** | Test Quality |
| **Description** | Go business code coverage is at 51% (target: 85%). Key gaps in `internal/sync`, `internal/transaction`, and `internal/loan` packages. |
| **Impact** | Untested code paths may harbor latent bugs. Particularly risky in sync conflict resolution and financial calculation edge cases. |
| **Current State** | 51% business code, 26% overall (proto-generated code drags down). |
| **Remediation** | Focused unit test effort: <br>1. `internal/sync/` — conflict resolution, retry logic, cursor management <br>2. `internal/transaction/` — edge cases (negative amounts, currency conversion rounding) <br>3. `internal/loan/` — prepayment recalculation, rate change mid-term <br>4. Add coverage gates in CI: fail if business code drops below 60% (ratchet up over time) |
| **Files Affected** | `server/internal/sync/`, `server/internal/transaction/`, `server/internal/loan/` |
| **Effort** | ~5 days |

---

## P2 — Medium Priority

### P2-1: Export JSON Full Backup Not Implemented (EX-008)

| Field | Value |
|-------|-------|
| **Req ID** | EX-008 |
| **Category** | Feature Gap |
| **Description** | Proto definition for JSON full-backup export is not yet implemented. CSV and Excel exports work, but JSON format (useful for data portability and backup/restore) is missing. |
| **Impact** | Users cannot create a full JSON backup for migration or disaster recovery. |
| **Current State** | Proto message defined but handler returns `Unimplemented`. |
| **Remediation** | Implement `ExportJSON` RPC handler. Include all entities (accounts, transactions, categories, budgets, loans, investments, assets, families). Add round-trip test: export → import → verify data integrity. |
| **Effort** | ~3 days |

---

### P2-2: Deep Link Handling Untested on Real Devices (W-009)

| Field | Value |
|-------|-------|
| **Req ID** | W-009 |
| **Category** | Test Gap |
| **Description** | Deep link handling (family invite links, shared transaction links) is only tested in widget tests with mocked GoRouter. No real-device testing with actual URL schemes. |
| **Impact** | Deep links may fail on specific OS versions or when app is in background/killed state. |
| **Current State** | Widget tests pass with mock navigation. |
| **Remediation** | Add manual test checklist for deep links on iOS + Android. Consider `integration_test` with `flutter_driver` for basic deep link verification. |
| **Effort** | ~2 days |

---

### P2-3: Lottie Animation on Transaction Success Untested (W-008)

| Field | Value |
|-------|-------|
| **Req ID** | W-008 |
| **Category** | Test Gap |
| **Description** | Transaction creation success shows a Lottie animation. This is not tested — animation rendering and completion callback are not verified. |
| **Impact** | Low — cosmetic only. Animation may fail to render on low-end devices or if Lottie file is corrupted. |
| **Current State** | No test coverage. |
| **Remediation** | Add widget test that verifies `LottieBuilder` widget is present and `onLoaded` callback fires. Test with `tester.pump()` to advance animation frames. |
| **Effort** | ~0.5 day |

---

## Summary Table

| Priority | Count | Items |
|----------|-------|-------|
| P0 | 0 | — |
| P1 | 1 | Coverage gap (ongoing) |
| P1 (Fixed) | 3 | ~~Token rotation~~, ~~unknown entity_type~~, ~~gRPC reflection~~ |
| P2 | 3 | JSON export, deep link testing, Lottie animation |
| **Total** | **4 open** | |

---

## Recommended Sprint Plan

**Next iteration (suggested 2-week sprint):**

1. ✅ P1-2: Push unknown entity_type validation (0.5 day)
2. ✅ P1-3: Disable gRPC reflection in prod (0.5 day)
3. ✅ P1-1: Token refresh rotation (2 days)
4. 🔄 P1-4: Coverage improvement — sync + transaction packages (5 days, can be split across sprints)

**Backlog:**
- P2-1: JSON export (3 days)
- P2-2: Deep link real-device testing (2 days)
- P2-3: Lottie animation test (0.5 day)
