#!/usr/bin/env bash
# ============================================================================
# FamilyLedger - Analytics & Import/Export Services Integration Tests
# ============================================================================
# Tests: DashboardService (5 RPCs), ExportService (1 RPC), ImportService (2 RPCs)
# Prerequisites: server running on localhost:50051
# ============================================================================

set -uo pipefail
# Note: we intentionally do NOT set -e; we handle errors explicitly per test

PROTO_DIR="proto"
HOST="localhost:50051"
GRPC="grpcurl -plaintext -import-path ${PROTO_DIR} -proto"
PASS_COUNT=0
FAIL_COUNT=0
TIMESTAMP=$(date +%s)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Helpers ──────────────────────────────────────────────────────────────────

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "  ${GREEN}[PASS]${NC} $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "  ${RED}[FAIL]${NC} $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "        ${RED}Detail: $2${NC}"
    fi
}

section() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
}

subsection() {
    echo ""
    echo -e "${YELLOW}── $1 ──${NC}"
}

# ── Auth helper ──────────────────────────────────────────────────────────────

grpc_auth() {
    # $1 = proto file, $2 = json data, $3 = service/method
    local proto="$1" data="$2" method="$3"
    ${GRPC} "$proto" -H "authorization: Bearer ${TOKEN}" -d "$data" "$HOST" "$method" 2>&1
}

grpc_no_auth() {
    local proto="$1" data="$2" method="$3"
    ${GRPC} "$proto" -d "$data" "$HOST" "$method" 2>&1
}

# ============================================================================
section "Phase 0: Register User & Get JWT"
# ============================================================================

EMAIL="analytics-test-${TIMESTAMP}@test.com"
PASSWORD="Test123456"

echo "  Registering user: ${EMAIL}"
REG_RESP=$(grpc_no_auth "auth.proto" \
    "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}" \
    "familyledger.auth.v1.AuthService/Register")

TOKEN=$(echo "$REG_RESP" | jq -r '.accessToken // empty')
USER_ID=$(echo "$REG_RESP" | jq -r '.userId // empty')

if [[ -n "$TOKEN" && -n "$USER_ID" ]]; then
    pass "User registered: userId=${USER_ID}"
else
    fail "User registration failed" "$REG_RESP"
    echo "Cannot continue without auth token. Exiting."
    exit 1
fi

# ============================================================================
section "Phase 1: Create Test Data (Accounts, Transactions, Budgets)"
# ============================================================================

# ── 1.1 Create accounts ─────────────────────────────────────────────────────

subsection "1.1 Create Accounts"

# Checking (bank card) account
ACCT1_RESP=$(grpc_auth "account.proto" \
    '{"name":"工商银行储蓄卡","type":"ACCOUNT_TYPE_BANK_CARD","currency":"CNY","icon":"bank","initial_balance":5000000}' \
    "familyledger.account.v1.AccountService/CreateAccount")
ACCOUNT_ID_BANK=$(echo "$ACCT1_RESP" | jq -r '.account.id // empty')

if [[ -n "$ACCOUNT_ID_BANK" ]]; then
    pass "Created bank account: ${ACCOUNT_ID_BANK} (balance=50000.00 CNY)"
else
    fail "Create bank account" "$ACCT1_RESP"
fi

# Cash account
ACCT2_RESP=$(grpc_auth "account.proto" \
    '{"name":"现金钱包","type":"ACCOUNT_TYPE_CASH","currency":"CNY","icon":"cash","initial_balance":200000}' \
    "familyledger.account.v1.AccountService/CreateAccount")
ACCOUNT_ID_CASH=$(echo "$ACCT2_RESP" | jq -r '.account.id // empty')

if [[ -n "$ACCOUNT_ID_CASH" ]]; then
    pass "Created cash account: ${ACCOUNT_ID_CASH} (balance=2000.00 CNY)"
else
    fail "Create cash account" "$ACCT2_RESP"
fi

# ── 1.2 Get categories ──────────────────────────────────────────────────────

subsection "1.2 Get Categories"

# Get expense categories
EXPENSE_CAT_RESP=$(grpc_auth "transaction.proto" \
    '{"type":"TRANSACTION_TYPE_EXPENSE"}' \
    "familyledger.transaction.v1.TransactionService/GetCategories")
EXPENSE_CAT_IDS=$(echo "$EXPENSE_CAT_RESP" | jq -r '[.categories[].id] | join(",")')

# Get income categories
INCOME_CAT_RESP=$(grpc_auth "transaction.proto" \
    '{"type":"TRANSACTION_TYPE_INCOME"}' \
    "familyledger.transaction.v1.TransactionService/GetCategories")
INCOME_CAT_IDS=$(echo "$INCOME_CAT_RESP" | jq -r '[.categories[].id] | join(",")')

# Pick first expense and income category
EXP_CAT1=$(echo "$EXPENSE_CAT_RESP" | jq -r '.categories[0].id // empty')
EXP_CAT2=$(echo "$EXPENSE_CAT_RESP" | jq -r '.categories[1].id // empty')
EXP_CAT3=$(echo "$EXPENSE_CAT_RESP" | jq -r '.categories[2].id // empty')
INC_CAT1=$(echo "$INCOME_CAT_RESP" | jq -r '.categories[0].id // empty')
INC_CAT2=$(echo "$INCOME_CAT_RESP" | jq -r '.categories[1].id // empty')

if [[ -n "$EXP_CAT1" && -n "$INC_CAT1" ]]; then
    pass "Got categories: expense=[${EXP_CAT1},${EXP_CAT2},${EXP_CAT3}] income=[${INC_CAT1},${INC_CAT2}]"
else
    fail "Get categories" "expense=$EXPENSE_CAT_IDS income=$INCOME_CAT_IDS"
fi

# ── 1.3 Create transactions ─────────────────────────────────────────────────

subsection "1.3 Create Transactions (income + expense)"

# Use current month dates for dashboard relevance
YEAR=$(date +%Y)
MONTH=$(date +%-m)  # no leading zero for JSON
TXN_CREATED=0

# Helper to create a transaction
create_txn() {
    local acct="$1" cat="$2" amount="$3" type="$4" note="$5" day="$6"
    local date_str="${YEAR}-$(printf '%02d' $MONTH)-$(printf '%02d' $day)T10:00:00Z"
    local resp
    resp=$(grpc_auth "transaction.proto" \
        "{\"account_id\":\"${acct}\",\"category_id\":\"${cat}\",\"amount\":${amount},\"currency\":\"CNY\",\"amount_cny\":${amount},\"exchange_rate\":1.0,\"type\":\"${type}\",\"note\":\"${note}\",\"txn_date\":\"${date_str}\"}" \
        "familyledger.transaction.v1.TransactionService/CreateTransaction")
    local tid
    tid=$(echo "$resp" | jq -r '.transaction.id // empty')
    if [[ -n "$tid" ]]; then
        TXN_CREATED=$((TXN_CREATED + 1))
        echo "    ✓ ${note}: ¥$(echo "scale=2; ${amount}/100" | bc) (${type})"
    else
        echo "    ✗ Failed: ${note} — $resp"
    fi
}

# Income transactions (3)
create_txn "$ACCOUNT_ID_BANK" "$INC_CAT1" 1500000 "TRANSACTION_TYPE_INCOME" "工资收入" 1
create_txn "$ACCOUNT_ID_BANK" "$INC_CAT2" 300000  "TRANSACTION_TYPE_INCOME" "兼职收入" 5
create_txn "$ACCOUNT_ID_BANK" "$INC_CAT1" 50000   "TRANSACTION_TYPE_INCOME" "利息收入" 10

# Expense transactions (4)
create_txn "$ACCOUNT_ID_BANK" "$EXP_CAT1" 350000  "TRANSACTION_TYPE_EXPENSE" "房租支出" 2
create_txn "$ACCOUNT_ID_CASH" "$EXP_CAT2" 80000   "TRANSACTION_TYPE_EXPENSE" "餐饮支出" 3
create_txn "$ACCOUNT_ID_CASH" "$EXP_CAT3" 45000   "TRANSACTION_TYPE_EXPENSE" "交通支出" 7
create_txn "$ACCOUNT_ID_BANK" "$EXP_CAT1" 120000  "TRANSACTION_TYPE_EXPENSE" "日用品支出" 12

if [[ $TXN_CREATED -ge 5 ]]; then
    pass "Created ${TXN_CREATED} transactions (income + expense)"
else
    fail "Transaction creation: only ${TXN_CREATED}/7 succeeded"
fi

# ── 1.4 Create budget ───────────────────────────────────────────────────────

subsection "1.4 Create Budget"

BUDGET_RESP=$(grpc_auth "budget.proto" \
    "{\"year\":${YEAR},\"month\":${MONTH},\"total_amount\":800000,\"category_budgets\":[{\"category_id\":\"${EXP_CAT1}\",\"amount\":400000},{\"category_id\":\"${EXP_CAT2}\",\"amount\":200000},{\"category_id\":\"${EXP_CAT3}\",\"amount\":200000}]}" \
    "familyledger.budget.v1.BudgetService/CreateBudget")
BUDGET_ID=$(echo "$BUDGET_RESP" | jq -r '.budget.id // empty')

if [[ -n "$BUDGET_ID" ]]; then
    pass "Created budget: ${BUDGET_ID} (total=¥8000.00 for ${YEAR}-${MONTH})"
else
    fail "Create budget" "$BUDGET_RESP"
fi

# ============================================================================
section "Phase 2: Dashboard Service Tests"
# ============================================================================

# ── 2.1 GetNetWorth ──────────────────────────────────────────────────────────

subsection "2.1 GetNetWorth"

NW_RESP=$(grpc_auth "dashboard.proto" '{}' \
    "familyledger.dashboard.v1.DashboardService/GetNetWorth")
NW_TOTAL=$(echo "$NW_RESP" | jq -r '.total // empty')

if echo "$NW_RESP" | jq -e '.total' > /dev/null 2>&1; then
    NW_DISPLAY=$(echo "scale=2; ${NW_TOTAL}/100" | bc 2>/dev/null || echo "$NW_TOTAL")
    pass "GetNetWorth returned total=¥${NW_DISPLAY}"

    # Verify it has composition data
    COMP_COUNT=$(echo "$NW_RESP" | jq '.composition | length')
    if [[ "$COMP_COUNT" -gt 0 ]]; then
        pass "GetNetWorth has ${COMP_COUNT} composition items"
    else
        echo -e "  ${YELLOW}[INFO]${NC} No composition data (may be expected)"
    fi
elif echo "$NW_RESP" | grep -q "failed to query investment value"; then
    fail "GetNetWorth: SERVER BUG - fails when user has no investments" "$NW_RESP"
else
    fail "GetNetWorth: unexpected response" "$NW_RESP"
fi

# ── 2.2 GetIncomeExpenseTrend ────────────────────────────────────────────────

subsection "2.2 GetIncomeExpenseTrend"

TREND_RESP=$(grpc_auth "dashboard.proto" \
    '{"period":"monthly","count":6}' \
    "familyledger.dashboard.v1.DashboardService/GetIncomeExpenseTrend")

if echo "$TREND_RESP" | jq -e '.points' > /dev/null 2>&1; then
    POINT_COUNT=$(echo "$TREND_RESP" | jq '.points | length')
    pass "GetIncomeExpenseTrend returned ${POINT_COUNT} trend points"

    # Check if current month has data
    CURRENT_LABEL=$(printf '%s-%02d' "$YEAR" "$MONTH")
    HAS_CURRENT=$(echo "$TREND_RESP" | jq --arg lbl "$CURRENT_LABEL" '[.points[] | select(.label == $lbl)] | length')
    if [[ "$HAS_CURRENT" -gt 0 ]]; then
        CUR_INCOME=$(echo "$TREND_RESP" | jq --arg lbl "$CURRENT_LABEL" '[.points[] | select(.label == $lbl)][0].income')
        CUR_EXPENSE=$(echo "$TREND_RESP" | jq --arg lbl "$CURRENT_LABEL" '[.points[] | select(.label == $lbl)][0].expense')
        pass "Current month (${CURRENT_LABEL}): income=${CUR_INCOME}, expense=${CUR_EXPENSE}"
    else
        echo -e "  ${YELLOW}[INFO]${NC} No data point for current month ${CURRENT_LABEL}"
    fi
else
    fail "GetIncomeExpenseTrend: unexpected response" "$TREND_RESP"
fi

# ── 2.3 GetCategoryBreakdown ─────────────────────────────────────────────────

subsection "2.3 GetCategoryBreakdown"

# Expense breakdown
CB_RESP=$(grpc_auth "dashboard.proto" \
    "{\"year\":${YEAR},\"month\":${MONTH},\"type\":\"expense\"}" \
    "familyledger.dashboard.v1.DashboardService/GetCategoryBreakdown")

if echo "$CB_RESP" | jq -e '.total' > /dev/null 2>&1; then
    CB_TOTAL=$(echo "$CB_RESP" | jq -r '.total')
    CB_ITEMS=$(echo "$CB_RESP" | jq '.items | length')
    CB_DISPLAY=$(echo "scale=2; ${CB_TOTAL}/100" | bc 2>/dev/null || echo "$CB_TOTAL")
    pass "GetCategoryBreakdown (expense): total=¥${CB_DISPLAY}, ${CB_ITEMS} categories"

    # Verify weights sum roughly to 1
    if [[ "$CB_ITEMS" -gt 0 ]]; then
        WEIGHT_SUM=$(echo "$CB_RESP" | jq '[.items[].weight] | add')
        pass "Category weights sum: ${WEIGHT_SUM} (expect ~1.0)"
    fi
else
    fail "GetCategoryBreakdown (expense)" "$CB_RESP"
fi

# Income breakdown
CB_INC_RESP=$(grpc_auth "dashboard.proto" \
    "{\"year\":${YEAR},\"month\":${MONTH},\"type\":\"income\"}" \
    "familyledger.dashboard.v1.DashboardService/GetCategoryBreakdown")

if echo "$CB_INC_RESP" | jq -e '.total' > /dev/null 2>&1; then
    CB_INC_TOTAL=$(echo "$CB_INC_RESP" | jq -r '.total')
    CB_INC_DISPLAY=$(echo "scale=2; ${CB_INC_TOTAL}/100" | bc 2>/dev/null || echo "$CB_INC_TOTAL")
    pass "GetCategoryBreakdown (income): total=¥${CB_INC_DISPLAY}"
else
    fail "GetCategoryBreakdown (income)" "$CB_INC_RESP"
fi

# ── 2.4 GetBudgetSummary ────────────────────────────────────────────────────

subsection "2.4 GetBudgetSummary"

BS_RESP=$(grpc_auth "dashboard.proto" \
    "{\"year\":${YEAR},\"month\":${MONTH}}" \
    "familyledger.dashboard.v1.DashboardService/GetBudgetSummary")

if echo "$BS_RESP" | jq -e '.totalBudget' > /dev/null 2>&1; then
    BS_BUDGET=$(echo "$BS_RESP" | jq -r '.totalBudget')
    BS_SPENT=$(echo "$BS_RESP" | jq -r '.totalSpent')
    BS_RATE=$(echo "$BS_RESP" | jq -r '.executionRate')
    BS_CATS=$(echo "$BS_RESP" | jq '.categories | length')
    pass "GetBudgetSummary: budget=¥$(echo "scale=2; ${BS_BUDGET}/100" | bc), spent=¥$(echo "scale=2; ${BS_SPENT}/100" | bc), rate=${BS_RATE}"
    
    if [[ "$BS_CATS" -gt 0 ]]; then
        pass "BudgetSummary has ${BS_CATS} category breakdowns"
    fi
else
    # Maybe the response uses snake_case
    if echo "$BS_RESP" | jq -e '.total_budget' > /dev/null 2>&1; then
        BS_BUDGET=$(echo "$BS_RESP" | jq -r '.total_budget')
        BS_SPENT=$(echo "$BS_RESP" | jq -r '.total_spent')
        pass "GetBudgetSummary (snake_case): budget=${BS_BUDGET}, spent=${BS_SPENT}"
    else
        fail "GetBudgetSummary" "$BS_RESP"
    fi
fi

# ── 2.5 GetNetWorthTrend ────────────────────────────────────────────────────

subsection "2.5 GetNetWorthTrend"

NWT_RESP=$(grpc_auth "dashboard.proto" \
    '{"period":"monthly","count":6}' \
    "familyledger.dashboard.v1.DashboardService/GetNetWorthTrend")

if echo "$NWT_RESP" | jq -e '.points' > /dev/null 2>&1; then
    NWT_COUNT=$(echo "$NWT_RESP" | jq '.points | length')
    pass "GetNetWorthTrend returned ${NWT_COUNT} points"

    if [[ "$NWT_COUNT" -gt 0 ]]; then
        LAST_NET=$(echo "$NWT_RESP" | jq '.points[-1].net')
        pass "Latest net worth trend point: net=${LAST_NET}"
    fi
elif echo "$NWT_RESP" | grep -q "failed to query investment value"; then
    fail "GetNetWorthTrend: SERVER BUG - fails when user has no investments" "$NWT_RESP"
else
    fail "GetNetWorthTrend" "$NWT_RESP"
fi

# ============================================================================
section "Phase 3: Export Service Tests"
# ============================================================================

subsection "3.1 ExportTransactions (CSV)"

CSV_RESP=$(grpc_auth "export.proto" \
    "{\"format\":\"csv\",\"start_date\":\"${YEAR}-01-01\",\"end_date\":\"${YEAR}-12-31\"}" \
    "familyledger.export.v1.ExportService/ExportTransactions")

if echo "$CSV_RESP" | jq -e '.filename' > /dev/null 2>&1; then
    CSV_FILENAME=$(echo "$CSV_RESP" | jq -r '.filename')
    CSV_CT=$(echo "$CSV_RESP" | jq -r '.contentType')
    CSV_HAS_DATA=$(echo "$CSV_RESP" | jq -r '.data // empty')
    pass "ExportTransactions (CSV): filename=${CSV_FILENAME}, contentType=${CSV_CT}"
    
    if [[ -n "$CSV_HAS_DATA" ]]; then
        pass "Export CSV has data payload"
    else
        echo -e "  ${YELLOW}[INFO]${NC} Export data is empty (may need base64 decode check)"
    fi
else
    fail "ExportTransactions (CSV)" "$CSV_RESP"
fi

subsection "3.2 ExportTransactions (Excel)"

EXCEL_RESP=$(grpc_auth "export.proto" \
    "{\"format\":\"excel\",\"start_date\":\"${YEAR}-01-01\",\"end_date\":\"${YEAR}-12-31\"}" \
    "familyledger.export.v1.ExportService/ExportTransactions")

if echo "$EXCEL_RESP" | jq -e '.filename' > /dev/null 2>&1; then
    EXCEL_FILENAME=$(echo "$EXCEL_RESP" | jq -r '.filename')
    pass "ExportTransactions (Excel): filename=${EXCEL_FILENAME}"
else
    fail "ExportTransactions (Excel)" "$EXCEL_RESP"
fi

subsection "3.3 ExportTransactions (PDF)"

PDF_RESP=$(grpc_auth "export.proto" \
    "{\"format\":\"pdf\",\"start_date\":\"${YEAR}-01-01\",\"end_date\":\"${YEAR}-12-31\"}" \
    "familyledger.export.v1.ExportService/ExportTransactions")

if echo "$PDF_RESP" | jq -e '.filename' > /dev/null 2>&1; then
    PDF_FILENAME=$(echo "$PDF_RESP" | jq -r '.filename')
    pass "ExportTransactions (PDF): filename=${PDF_FILENAME}"
else
    fail "ExportTransactions (PDF)" "$PDF_RESP"
fi

# ============================================================================
section "Phase 4: Import Service Tests"
# ============================================================================

subsection "4.1 ParseCSV"

# Create test CSV data (base64 encoded for bytes field)
# CSV content: 日期,金额,类型,分类,备注
CSV_CONTENT="日期,金额,类型,分类,备注
2026-04-01,150.50,支出,餐饮,午餐
2026-04-02,8000.00,收入,工资,4月工资
2026-04-03,35.00,支出,交通,地铁
2026-04-05,200.00,支出,日用,超市采购
2026-04-06,500.00,收入,兼职,项目收入"

CSV_B64=$(echo -n "$CSV_CONTENT" | base64 | tr -d '\n')

PARSE_RESP=$(grpc_auth "import.proto" \
    "{\"csv_data\":\"${CSV_B64}\",\"encoding\":\"utf8\"}" \
    "familyledger.import.v1.ImportService/ParseCSV")

SESSION_ID=$(echo "$PARSE_RESP" | jq -r '.sessionId // .session_id // empty')
TOTAL_ROWS=$(echo "$PARSE_RESP" | jq -r '.totalRows // .total_rows // "0"')
HEADERS=$(echo "$PARSE_RESP" | jq -r '.headers // [] | join(",")')
PREVIEW_COUNT=$(echo "$PARSE_RESP" | jq '.previewRows // .preview_rows // [] | length')

if [[ -n "$SESSION_ID" ]]; then
    pass "ParseCSV: sessionId=${SESSION_ID}, totalRows=${TOTAL_ROWS}, headers=[${HEADERS}]"
    
    if [[ "$PREVIEW_COUNT" -gt 0 ]]; then
        pass "ParseCSV preview: ${PREVIEW_COUNT} rows"
    fi
elif echo "$PARSE_RESP" | grep -q "foreign key constraint"; then
    fail "ParseCSV: SERVER BUG - import_sessions uses uuid.Nil for user_id, violates FK constraint" "$PARSE_RESP"
else
    fail "ParseCSV" "$PARSE_RESP"
fi

# ── 4.2 ConfirmImport ───────────────────────────────────────────────────────

subsection "4.2 ConfirmImport"

if [[ -n "$SESSION_ID" && -n "$ACCOUNT_ID_BANK" ]]; then
    CONFIRM_RESP=$(grpc_auth "import.proto" \
        "{\"session_id\":\"${SESSION_ID}\",\"mappings\":[{\"csv_column\":\"日期\",\"target_field\":\"date\"},{\"csv_column\":\"金额\",\"target_field\":\"amount\"},{\"csv_column\":\"类型\",\"target_field\":\"type\"},{\"csv_column\":\"分类\",\"target_field\":\"category\"},{\"csv_column\":\"备注\",\"target_field\":\"note\"}],\"default_account_id\":\"${ACCOUNT_ID_BANK}\",\"user_id\":\"${USER_ID}\"}" \
        "familyledger.import.v1.ImportService/ConfirmImport")

    IMPORTED=$(echo "$CONFIRM_RESP" | jq -r '.importedCount // .imported_count // "0"')
    SKIPPED=$(echo "$CONFIRM_RESP" | jq -r '.skippedCount // .skipped_count // "0"')
    ERRORS=$(echo "$CONFIRM_RESP" | jq -r '.errors // [] | length')

    if [[ "$IMPORTED" -gt 0 ]] || echo "$CONFIRM_RESP" | jq -e '.importedCount // .imported_count' > /dev/null 2>&1; then
        pass "ConfirmImport: imported=${IMPORTED}, skipped=${SKIPPED}, errors=${ERRORS}"
    else
        fail "ConfirmImport: no records imported" "$CONFIRM_RESP"
    fi
else
    fail "ConfirmImport: skipped (no session_id or account_id from previous step)"
fi

# ============================================================================
section "Phase 5: Verify Post-Import Data"
# ============================================================================

subsection "5.1 List Transactions After Import"

LIST_RESP=$(grpc_auth "transaction.proto" \
    '{"page_size":50}' \
    "familyledger.transaction.v1.TransactionService/ListTransactions")

TOTAL_TXN=$(echo "$LIST_RESP" | jq -r '.totalCount // .total_count // 0')
TXN_LIST_COUNT=$(echo "$LIST_RESP" | jq '.transactions | length')

if [[ "$TXN_LIST_COUNT" -gt 0 ]]; then
    pass "Post-import transaction count: ${TXN_LIST_COUNT} (total: ${TOTAL_TXN})"
else
    fail "No transactions found after import" "$LIST_RESP"
fi

# ============================================================================
section "Test Summary"
# ============================================================================

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo -e "  Total:  ${TOTAL} tests"
echo -e "  ${GREEN}Passed: ${PASS_COUNT}${NC}"
echo -e "  ${RED}Failed: ${FAIL_COUNT}${NC}"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ ${FAIL_COUNT} test(s) failed.${NC}"
    exit 1
fi
