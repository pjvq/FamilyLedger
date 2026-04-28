# PRD → Test Case Traceability Matrix

> **Purpose**: Map every PRD requirement to its corresponding test case(s).
> **Updated**: Weekly (each W1-W15 delivery adds rows)
> **Completion target**: 100% by W14

## Legend
- ✅ Covered (test exists + passes)
- 🟡 Partial (test exists, not all paths)
- ❌ Not covered
- 🚫 N/A (feature descoped/deferred)
- ⏳ Blocked by dev (risk register item)

## Auth Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| User registration (email+password) | A-001, A-002, A-003, A-004, A-005 | ⏳ |
| Login | A-010, A-011, A-012, A-013 | ⏳ |
| Token refresh | A-020, A-021, A-022, A-023, A-052, A-053 | ⏳ |
| OAuth (WeChat + Apple) | A-030~A-035 | ⏳ |
| SQL injection protection | A-006 | ⏳ |

## Account Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| CRUD + 7 types | AC-001~AC-005 | ⏳ |
| Balance atomic update | AC-006 | ⏳ |
| Soft delete | AC-007 | ⏳ |
| Family account | AC-008 | ⏳ |

## Transaction Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| CRUD | T-001~T-005 | ⏳ |
| Multi-currency | T-010~T-012 | ⏳ |
| Pagination | T-020~T-022 | ⏳ |
| Balance linkage | T-030~T-032 | ⏳ |
| Tags + Images | T-040~T-041 | ⏳ |

## Transfer Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| Basic transfer | TF-001~TF-003 | ⏳ |
| Concurrent safety | TF-005 | ⏳ |
| Cross-currency | TF-006 | ⏳ |

## Sync Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| Push operations | S-001~S-005 | ⏳ |
| Pull changes | S-010~S-016 | ⏳ |
| Delete tombstone | S-013 | ⏳ (R9) |
| Idempotency | S-004 | ⏳ (expected failure) |
| Family sync | S-012, S-016 | ⏳ (R10) |
| Exponential backoff | S-024 | ⏳ |
| Failed ops handling | S-025, S-025b | ⏳ (R7) |

## WebSocket Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| Connection + auth | WS-001, WS-002 | ⏳ |
| Family broadcast | WS-003 | ⏳ (断言待确认) |
| Heartbeat | WS-004, WS-005 | ⏳ |
| Reconnection | WS-006, WS-007 | ⏳ |
| Multi-device | WS-010 | ⏳ |

## Family Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| Create + invite | F-001~F-004 | ⏳ |
| Join + leave | F-005~F-007 | ⏳ |
| Permissions | F-008~F-010 | ⏳ |
|退出成员可见性 | F-011 | ⏳ |

## Loan Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| Equal installment | L-001 | ⏳ |
| Equal principal | L-002 | ⏳ |
| Combined loan | L-003~L-005 | ⏳ |
| LPR adjustment | L-006 | ⏳ |
| Early repayment | L-007~L-008 | ⏳ |

## Budget Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| CRUD + unique | B-001~B-003 | ⏳ |
| Execution rate | B-004~B-005 | ⏳ |
| Category budget | B-006 | ⏳ |

## Investment Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| Buy/Sell | I-001~I-004 | ⏳ |
| XIRR | I-005~I-006 | ⏳ |
| Sell > holdings | I-007 | ⏳ |
| Full sell | I-008 | ⏳ |

## Dashboard Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| Net worth | D-001 | ⏳ |
| Monthly summary | D-002 | ⏳ |
| Family filter | D-003, D-004 | ⏳ |
| Trend | D-006 | ⏳ |
| Empty state | D-007 | ⏳ |

## Export Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| CSV | EX-001 | ⏳ |
| Excel | EX-002 | ⏳ |
| PDF | EX-003 | ⏳ (R8) |
| Family export | EX-004 | ⏳ |
| JSON backup | EX-005, EX-008 | ⏳ |

## Security Module

| PRD Requirement | Test Case IDs | Status |
|---|---|---|
| SQL injection | SEC-001 | ⏳ |
| JWT tampering | SEC-002~SEC-004 | ⏳ |
| Horizontal privilege | SEC-005 | ⏳ |
| gRPC reflection | SEC-006 | ⏳ |

---

> **Note**: This matrix is updated as tests are implemented.
> Current fill rate: 0% (W1 skeleton only)
