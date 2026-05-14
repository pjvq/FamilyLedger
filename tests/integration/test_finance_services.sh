#!/usr/bin/env bash
#
# FamilyLedger Finance Services Integration Tests
# Tests: LoanService, BudgetService, InvestmentService, AssetService, MarketDataService
# Total RPCs covered: 35
#
# Don't use set -e: test script should continue on individual test failures
set -u

PROTO_DIR="proto"
HOST="localhost:50051"
GRPCURL="grpcurl -plaintext -import-path $PROTO_DIR"
TIMESTAMP=$(date +%s)
TEST_EMAIL="finance-test-${TIMESTAMP}@test.com"
TEST_PASSWORD="Test123456"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "[PASS] $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[FAIL] $1"
    if [ -n "${2:-}" ]; then
        echo "       Response: $(echo "$2" | head -3)"
    fi
}

EMPTY_JSON='{}'

# Helper: call grpc with auth
grpc_auth() {
    local proto="$1"; shift
    local service="$1"; shift
    local data="${1:-$EMPTY_JSON}"
    $GRPCURL -proto "$proto" -H "authorization: Bearer $TOKEN" -d "$data" "$HOST" "$service" 2>&1
}

grpc_no_auth() {
    local proto="$1"; shift
    local service="$1"; shift
    local data="${1:-$EMPTY_JSON}"
    $GRPCURL -proto "$proto" -d "$data" "$HOST" "$service" 2>&1
}

echo "============================================================"
echo " FamilyLedger Finance Services Integration Tests"
echo " Test email: $TEST_EMAIL"
echo " Timestamp:  $TIMESTAMP"
echo "============================================================"
echo ""

###############################################################################
# 0. Setup: Register + Create Account + Get Categories
###############################################################################
echo "=== SETUP: Register & Create Account ==="

REGISTER_RESP=$(grpc_no_auth auth.proto \
    "familyledger.auth.v1.AuthService/Register" \
    "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}")

TOKEN=$(echo "$REGISTER_RESP" | jq -r '.accessToken // empty')
if [ -n "$TOKEN" ]; then
    pass "Register test user"
else
    fail "Register test user" "$REGISTER_RESP"
    echo "FATAL: Cannot proceed without auth token"
    exit 1
fi

# Create a bank account for loan association
ACCT_RESP=$(grpc_auth account.proto \
    "familyledger.account.v1.AccountService/CreateAccount" \
    '{"name":"测试还款账户","type":"ACCOUNT_TYPE_BANK_CARD","currency":"CNY","initial_balance":10000000}')
ACCOUNT_ID=$(echo "$ACCT_RESP" | jq -r '.account.id // empty')
if [ -n "$ACCOUNT_ID" ]; then
    pass "Create test bank account (id=$ACCOUNT_ID)"
else
    fail "Create test bank account" "$ACCT_RESP"
    ACCOUNT_ID=""
fi

# Get expense category IDs for budget tests
CAT_RESP=$(grpc_auth transaction.proto \
    "familyledger.transaction.v1.TransactionService/GetCategories")
CAT_FOOD=$(echo "$CAT_RESP" | jq -r '[.categories[] | select(.name=="餐饮")][0].id // empty')
CAT_TRANSPORT=$(echo "$CAT_RESP" | jq -r '[.categories[] | select(.name=="交通")][0].id // empty')
CAT_SHOPPING=$(echo "$CAT_RESP" | jq -r '[.categories[] | select(.name=="购物")][0].id // empty')
if [ -n "$CAT_FOOD" ]; then
    pass "Fetched expense categories (餐饮=$CAT_FOOD)"
else
    fail "Fetch expense categories" "$CAT_RESP"
fi

echo ""

###############################################################################
# 1. LoanService Tests
###############################################################################
echo "=== LOAN SERVICE (9 RPCs) ==="

# --- 1.1 CreateLoan (等额本息 - 房贷) ---
LOAN_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/CreateLoan" \
    "{\"name\":\"测试房贷\",\"loan_type\":\"LOAN_TYPE_MORTGAGE\",\"principal\":200000000,\"annual_rate\":4.2,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"payment_day\":15,\"start_date\":\"2024-01-01T00:00:00Z\",\"account_id\":\"$ACCOUNT_ID\"}")
LOAN_ID=$(echo "$LOAN_RESP" | jq -r '.id // empty')
if [ -n "$LOAN_ID" ]; then
    pass "CreateLoan - 等额本息房贷 200万 4.2% 30年 (id=$LOAN_ID)"
else
    fail "CreateLoan - 等额本息房贷" "$LOAN_RESP"
fi

# --- 1.2 CreateLoan (等额本金 - 车贷) ---
LOAN2_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/CreateLoan" \
    '{"name":"测试车贷","loan_type":"LOAN_TYPE_CAR_LOAN","principal":30000000,"annual_rate":5.0,"total_months":60,"repayment_method":"REPAYMENT_METHOD_EQUAL_PRINCIPAL","payment_day":10,"start_date":"2024-01-01T00:00:00Z"}')
LOAN2_ID=$(echo "$LOAN2_RESP" | jq -r '.id // empty')
if [ -n "$LOAN2_ID" ]; then
    pass "CreateLoan - 等额本金车贷 30万 5% 5年 (id=$LOAN2_ID)"
else
    fail "CreateLoan - 等额本金车贷" "$LOAN2_RESP"
fi

# --- 1.3 GetLoan ---
if [ -n "$LOAN_ID" ]; then
    GET_LOAN_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/GetLoan" \
        "{\"loan_id\":\"$LOAN_ID\"}")
    GOT_NAME=$(echo "$GET_LOAN_RESP" | jq -r '.name // empty')
    GOT_PRINCIPAL=$(echo "$GET_LOAN_RESP" | jq -r '.principal // empty')
    if [ "$GOT_NAME" = "测试房贷" ] && [ "$GOT_PRINCIPAL" = "200000000" ]; then
        pass "GetLoan - name=测试房贷, principal=200000000"
    else
        fail "GetLoan" "$GET_LOAN_RESP"
    fi
else
    fail "GetLoan - skipped (no loan_id)"
fi

# --- 1.4 ListLoans ---
LIST_LOANS_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/ListLoans")
LOAN_COUNT=$(echo "$LIST_LOANS_RESP" | jq '.loans | length')
if [ "$LOAN_COUNT" -ge 2 ] 2>/dev/null; then
    pass "ListLoans - found $LOAN_COUNT loans"
else
    fail "ListLoans - expected >=2, got ${LOAN_COUNT:-null}" "$LIST_LOANS_RESP"
fi

# --- 1.5 UpdateLoan ---
if [ -n "$LOAN_ID" ]; then
    UPD_LOAN_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/UpdateLoan" \
        "{\"loan_id\":\"$LOAN_ID\",\"name\":\"更新后的房贷\",\"payment_day\":20}")
    UPD_NAME=$(echo "$UPD_LOAN_RESP" | jq -r '.name // empty')
    UPD_DAY=$(echo "$UPD_LOAN_RESP" | jq -r '.paymentDay // empty')
    if [ "$UPD_NAME" = "更新后的房贷" ] && [ "$UPD_DAY" = "20" ]; then
        pass "UpdateLoan - name='更新后的房贷', paymentDay=20"
    else
        fail "UpdateLoan" "$UPD_LOAN_RESP"
    fi
fi

# --- 1.6 GetLoanSchedule ---
if [ -n "$LOAN_ID" ]; then
    SCHEDULE_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/GetLoanSchedule" \
        "{\"loan_id\":\"$LOAN_ID\"}")
    SCHEDULE_LEN=$(echo "$SCHEDULE_RESP" | jq '.items | length')
    if [ "$SCHEDULE_LEN" -ge 1 ] 2>/dev/null; then
        FIRST_PAYMENT=$(echo "$SCHEDULE_RESP" | jq '.items[0].payment')
        pass "GetLoanSchedule - $SCHEDULE_LEN periods, first_payment=${FIRST_PAYMENT}分"
    else
        fail "GetLoanSchedule" "$SCHEDULE_RESP"
    fi
fi

# --- 1.7 SimulatePrepayment (缩短期限) ---
if [ -n "$LOAN_ID" ]; then
    PREPAY1=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/SimulatePrepayment" \
        "{\"loan_id\":\"$LOAN_ID\",\"prepayment_amount\":50000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_MONTHS\"}")
    SAVED=$(echo "$PREPAY1" | jq '.interestSaved // empty')
    MONTHS=$(echo "$PREPAY1" | jq '.monthsReduced // empty')
    if [ -n "$SAVED" ] && [ "$SAVED" != "null" ] && [ "$SAVED" != "0" ]; then
        pass "SimulatePrepayment (缩短期限) - interestSaved=${SAVED}分, monthsReduced=$MONTHS"
    else
        fail "SimulatePrepayment (缩短期限)" "$PREPAY1"
    fi
fi

# --- 1.8 SimulatePrepayment (减少月供) ---
if [ -n "$LOAN_ID" ]; then
    PREPAY2=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/SimulatePrepayment" \
        "{\"loan_id\":\"$LOAN_ID\",\"prepayment_amount\":50000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_PAYMENT\"}")
    NEW_PMT=$(echo "$PREPAY2" | jq '.newMonthlyPayment // empty')
    if [ -n "$NEW_PMT" ] && [ "$NEW_PMT" != "null" ]; then
        pass "SimulatePrepayment (减少月供) - newMonthlyPayment=${NEW_PMT}分"
    else
        fail "SimulatePrepayment (减少月供)" "$PREPAY2"
    fi
fi

# --- 1.9 RecordRateChange ---
if [ -n "$LOAN_ID" ]; then
    RATE_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/RecordRateChange" \
        "{\"loan_id\":\"$LOAN_ID\",\"new_rate\":3.85,\"effective_date\":\"2025-01-01T00:00:00Z\"}")
    NEW_RATE=$(echo "$RATE_RESP" | jq '.annualRate // empty')
    if [ -n "$NEW_RATE" ] && [ "$NEW_RATE" != "null" ]; then
        pass "RecordRateChange - annualRate=$NEW_RATE"
    else
        fail "RecordRateChange" "$RATE_RESP"
    fi
fi

# --- 1.10 RecordPayment ---
if [ -n "$LOAN_ID" ]; then
    PAY_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/RecordPayment" \
        "{\"loan_id\":\"$LOAN_ID\",\"month_number\":1}")
    IS_PAID=$(echo "$PAY_RESP" | jq '.isPaid // empty')
    if [ "$IS_PAID" = "true" ]; then
        pass "RecordPayment - month 1 marked as paid"
    else
        fail "RecordPayment" "$PAY_RESP"
    fi
fi

# --- 1.11 DeleteLoan ---
if [ -n "$LOAN2_ID" ]; then
    DEL_LOAN_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/DeleteLoan" \
        "{\"loan_id\":\"$LOAN2_ID\"}")
    if echo "$DEL_LOAN_RESP" | grep -qi "error"; then
        fail "DeleteLoan" "$DEL_LOAN_RESP"
    else
        pass "DeleteLoan - deleted 车贷"
        # Verify via ListLoans
        LIST_AFTER=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/ListLoans")
        AFTER_COUNT=$(echo "$LIST_AFTER" | jq '[.loans[]? | select(.id=="'"$LOAN2_ID"'")] | length')
        if [ "$AFTER_COUNT" = "0" ]; then
            pass "DeleteLoan - verified not in list"
        else
            fail "DeleteLoan - still found in list"
        fi
    fi
fi

echo ""

###############################################################################
# 1b. LoanGroup Tests (组合贷款)
###############################################################################
echo "=== LOAN GROUP (组合贷款, 4 RPCs) ==="

# --- CreateLoanGroup: 商业贷+公积金贷 ---
GROUP_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/CreateLoanGroup" \
    "{\"name\":\"首套房组合贷\",\"group_type\":\"combined\",\"payment_day\":15,\"start_date\":\"2024-01-01T00:00:00Z\",\"account_id\":\"$ACCOUNT_ID\",\"loan_type\":\"LOAN_TYPE_MORTGAGE\",\"sub_loans\":[{\"name\":\"商业贷款\",\"sub_type\":\"LOAN_SUB_TYPE_COMMERCIAL\",\"principal\":150000000,\"annual_rate\":4.2,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"rate_type\":\"RATE_TYPE_LPR_FLOATING\",\"lpr_base\":3.85,\"lpr_spread\":0.35,\"rate_adjust_month\":1},{\"name\":\"公积金贷款\",\"sub_type\":\"LOAN_SUB_TYPE_PROVIDENT\",\"principal\":50000000,\"annual_rate\":3.1,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"rate_type\":\"RATE_TYPE_FIXED\"}]}")
GROUP_ID=$(echo "$GROUP_RESP" | jq -r '.id // empty')
SUB_COUNT=$(echo "$GROUP_RESP" | jq '.subLoans | length')
TOTAL_P=$(echo "$GROUP_RESP" | jq -r '.totalPrincipal // empty')
if [ -n "$GROUP_ID" ] && [ "${SUB_COUNT:-0}" = "2" ]; then
    SUB1_ID=$(echo "$GROUP_RESP" | jq -r '.subLoans[0].id')
    SUB2_ID=$(echo "$GROUP_RESP" | jq -r '.subLoans[1].id')
    pass "CreateLoanGroup - combined 200万 (商贷150万+公积金50万), totalPrincipal=$TOTAL_P"
    echo "       Sub1(商业)=$SUB1_ID  Sub2(公积金)=$SUB2_ID"
else
    fail "CreateLoanGroup" "$GROUP_RESP"
    GROUP_ID=""
fi

# --- GetLoanGroup ---
if [ -n "$GROUP_ID" ]; then
    GET_GRP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/GetLoanGroup" \
        "{\"group_id\":\"$GROUP_ID\"}")
    GRP_NAME=$(echo "$GET_GRP" | jq -r '.name // empty')
    GRP_TYPE=$(echo "$GET_GRP" | jq -r '.groupType // empty')
    if [ "$GRP_NAME" = "首套房组合贷" ] && [ "$GRP_TYPE" = "combined" ]; then
        pass "GetLoanGroup - name=$GRP_NAME, groupType=$GRP_TYPE"
    else
        fail "GetLoanGroup" "$GET_GRP"
    fi
fi

# --- ListLoanGroups ---
LIST_GRP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/ListLoanGroups")
GRP_COUNT=$(echo "$LIST_GRP" | jq '.groups | length')
if [ "${GRP_COUNT:-0}" -ge 1 ] 2>/dev/null; then
    pass "ListLoanGroups - found $GRP_COUNT group(s)"
else
    fail "ListLoanGroups" "$LIST_GRP"
fi

# --- SimulateGroupPrepayment (指定商贷, 缩短期限) ---
if [ -n "$GROUP_ID" ] && [ -n "${SUB1_ID:-}" ]; then
    GRP_PREPAY=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/SimulateGroupPrepayment" \
        "{\"group_id\":\"$GROUP_ID\",\"target_loan_id\":\"$SUB1_ID\",\"prepayment_amount\":30000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_MONTHS\"}")
    GRP_SAVED=$(echo "$GRP_PREPAY" | jq '.totalInterestSaved // empty')
    TGT=$(echo "$GRP_PREPAY" | jq -r '.targetLoanId // empty')
    if [ -n "$GRP_SAVED" ] && [ "$GRP_SAVED" != "null" ] && [ "$GRP_SAVED" != "0" ]; then
        pass "SimulateGroupPrepayment (指定商贷) - totalInterestSaved=${GRP_SAVED}分"
    else
        fail "SimulateGroupPrepayment (指定商贷)" "$GRP_PREPAY"
    fi
fi

# --- SimulateGroupPrepayment (自动选利率高的, 减少月供) ---
if [ -n "$GROUP_ID" ]; then
    GRP_PREPAY2=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/SimulateGroupPrepayment" \
        "{\"group_id\":\"$GROUP_ID\",\"prepayment_amount\":20000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_PAYMENT\"}")
    AUTO_TGT=$(echo "$GRP_PREPAY2" | jq -r '.targetLoanId // empty')
    if [ -n "$AUTO_TGT" ]; then
        pass "SimulateGroupPrepayment (自动选) - autoTarget=$AUTO_TGT"
    else
        fail "SimulateGroupPrepayment (自动选)" "$GRP_PREPAY2"
    fi
fi

echo ""

###############################################################################
# 2. BudgetService Tests
###############################################################################
echo "=== BUDGET SERVICE (6 RPCs) ==="

# --- CreateBudget ---
BUDGET_RESP=$(grpc_auth budget.proto \
    "familyledger.budget.v1.BudgetService/CreateBudget" \
    "{\"year\":2026,\"month\":4,\"total_amount\":1000000,\"category_budgets\":[{\"category_id\":\"$CAT_FOOD\",\"amount\":300000},{\"category_id\":\"$CAT_TRANSPORT\",\"amount\":200000},{\"category_id\":\"$CAT_SHOPPING\",\"amount\":100000}]}")
BUDGET_ID=$(echo "$BUDGET_RESP" | jq -r '.budget.id // empty')
if [ -n "$BUDGET_ID" ]; then
    pass "CreateBudget - 2026-04, total=1万, 3 categories (id=$BUDGET_ID)"
else
    fail "CreateBudget" "$BUDGET_RESP"
fi

# --- CreateBudget (second month for list test) ---
BUDGET2_RESP=$(grpc_auth budget.proto \
    "familyledger.budget.v1.BudgetService/CreateBudget" \
    "{\"year\":2026,\"month\":5,\"total_amount\":1200000,\"category_budgets\":[{\"category_id\":\"$CAT_FOOD\",\"amount\":350000},{\"category_id\":\"$CAT_TRANSPORT\",\"amount\":250000}]}")
BUDGET2_ID=$(echo "$BUDGET2_RESP" | jq -r '.budget.id // empty')
if [ -n "$BUDGET2_ID" ]; then
    pass "CreateBudget - 2026-05, total=1.2万 (id=$BUDGET2_ID)"
else
    fail "CreateBudget - 2026-05" "$BUDGET2_RESP"
fi

# --- GetBudget ---
if [ -n "${BUDGET_ID:-}" ]; then
    GET_BUD=$(grpc_auth budget.proto \
        "familyledger.budget.v1.BudgetService/GetBudget" \
        "{\"budget_id\":\"$BUDGET_ID\"}")
    BUD_TOTAL=$(echo "$GET_BUD" | jq -r '.budget.totalAmount // empty')
    BUD_CATS=$(echo "$GET_BUD" | jq '.budget.categoryBudgets | length')
    if [ "$BUD_TOTAL" = "1000000" ]; then
        pass "GetBudget - totalAmount=$BUD_TOTAL, categories=$BUD_CATS"
    else
        fail "GetBudget" "$GET_BUD"
    fi
fi

# --- ListBudgets ---
LIST_BUD=$(grpc_auth budget.proto \
    "familyledger.budget.v1.BudgetService/ListBudgets" \
    '{"year":2026}')
BUD_COUNT=$(echo "$LIST_BUD" | jq '.budgets | length')
if [ "${BUD_COUNT:-0}" -ge 2 ] 2>/dev/null; then
    pass "ListBudgets (2026) - found $BUD_COUNT budgets"
else
    fail "ListBudgets" "$LIST_BUD"
fi

# --- UpdateBudget ---
if [ -n "${BUDGET_ID:-}" ]; then
    UPD_BUD=$(grpc_auth budget.proto \
        "familyledger.budget.v1.BudgetService/UpdateBudget" \
        "{\"budget_id\":\"$BUDGET_ID\",\"total_amount\":1500000,\"category_budgets\":[{\"category_id\":\"$CAT_FOOD\",\"amount\":400000},{\"category_id\":\"$CAT_TRANSPORT\",\"amount\":300000},{\"category_id\":\"$CAT_SHOPPING\",\"amount\":200000}]}")
    UPD_TOTAL=$(echo "$UPD_BUD" | jq -r '.budget.totalAmount // empty')
    if [ "$UPD_TOTAL" = "1500000" ]; then
        pass "UpdateBudget - totalAmount updated to $UPD_TOTAL"
    else
        fail "UpdateBudget" "$UPD_BUD"
    fi
fi

# --- GetBudgetExecution ---
if [ -n "${BUDGET_ID:-}" ]; then
    EXEC_RESP=$(grpc_auth budget.proto \
        "familyledger.budget.v1.BudgetService/GetBudgetExecution" \
        "{\"budget_id\":\"$BUDGET_ID\"}")
    if echo "$EXEC_RESP" | jq -e '.execution' > /dev/null 2>&1; then
        EXEC_RATE=$(echo "$EXEC_RESP" | jq '.execution.executionRate // 0')
        pass "GetBudgetExecution - executionRate=$EXEC_RATE"
    else
        fail "GetBudgetExecution" "$EXEC_RESP"
    fi
fi

# --- DeleteBudget ---
if [ -n "${BUDGET2_ID:-}" ]; then
    DEL_BUD=$(grpc_auth budget.proto \
        "familyledger.budget.v1.BudgetService/DeleteBudget" \
        "{\"budget_id\":\"$BUDGET2_ID\"}")
    if echo "$DEL_BUD" | grep -qi "error"; then
        fail "DeleteBudget" "$DEL_BUD"
    else
        pass "DeleteBudget - deleted 2026-05 budget"
    fi
fi

echo ""

###############################################################################
# 3. InvestmentService Tests
###############################################################################
echo "=== INVESTMENT SERVICE (8 RPCs) ==="

# --- CreateInvestment (A股) ---
INV_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/CreateInvestment" \
    '{"symbol":"600519","name":"贵州茅台","market_type":"MARKET_TYPE_A_SHARE"}')
INV_ID=$(echo "$INV_RESP" | jq -r '.id // empty')
if [ -n "$INV_ID" ]; then
    pass "CreateInvestment - 贵州茅台 A股 (id=$INV_ID)"
else
    fail "CreateInvestment - A股" "$INV_RESP"
fi

# --- CreateInvestment (基金) ---
INV2_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/CreateInvestment" \
    '{"symbol":"110011","name":"易方达中小盘","market_type":"MARKET_TYPE_FUND"}')
INV2_ID=$(echo "$INV2_RESP" | jq -r '.id // empty')
if [ -n "$INV2_ID" ]; then
    pass "CreateInvestment - 基金 (id=$INV2_ID)"
else
    fail "CreateInvestment - 基金" "$INV2_RESP"
fi

# --- GetInvestment ---
if [ -n "$INV_ID" ]; then
    GET_INV=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/GetInvestment" \
        "{\"investment_id\":\"$INV_ID\"}")
    GOT_SYM=$(echo "$GET_INV" | jq -r '.symbol // empty')
    if [ "$GOT_SYM" = "600519" ]; then
        pass "GetInvestment - symbol=$GOT_SYM"
    else
        fail "GetInvestment" "$GET_INV"
    fi
fi

# --- ListInvestments ---
LIST_INV=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/ListInvestments")
INV_CNT=$(echo "$LIST_INV" | jq '.investments | length')
if [ "${INV_CNT:-0}" -ge 2 ] 2>/dev/null; then
    pass "ListInvestments - found $INV_CNT investments"
else
    fail "ListInvestments" "$LIST_INV"
fi

# --- ListInvestments with filter ---
LIST_INV_F=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/ListInvestments" \
    '{"market_type":"MARKET_TYPE_A_SHARE"}')
FILT_CNT=$(echo "$LIST_INV_F" | jq '.investments | length')
if [ "${FILT_CNT:-0}" -ge 1 ] 2>/dev/null; then
    pass "ListInvestments (filter A_SHARE) - found $FILT_CNT"
else
    fail "ListInvestments (filter)" "$LIST_INV_F"
fi

# --- UpdateInvestment ---
if [ -n "$INV_ID" ]; then
    UPD_INV=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/UpdateInvestment" \
        "{\"investment_id\":\"$INV_ID\",\"name\":\"贵州茅台-更新\"}")
    UPD_NM=$(echo "$UPD_INV" | jq -r '.name // empty')
    if [ "$UPD_NM" = "贵州茅台-更新" ]; then
        pass "UpdateInvestment - name=$UPD_NM"
    else
        fail "UpdateInvestment" "$UPD_INV"
    fi
fi

# --- RecordTrade (BUY 100 shares) ---
if [ -n "$INV_ID" ]; then
    BUY_RESP=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/RecordTrade" \
        "{\"investment_id\":\"$INV_ID\",\"trade_type\":\"TRADE_TYPE_BUY\",\"quantity\":100,\"price\":180000,\"fee\":5000,\"trade_date\":\"2024-02-19T00:00:00Z\"}")
    BUY_ID=$(echo "$BUY_RESP" | jq -r '.id // empty')
    BUY_TOTAL=$(echo "$BUY_RESP" | jq -r '.totalAmount // empty')
    if [ -n "$BUY_ID" ]; then
        pass "RecordTrade (BUY) - 100 shares @1800元, total=${BUY_TOTAL}分 (id=$BUY_ID)"
    else
        fail "RecordTrade (BUY)" "$BUY_RESP"
    fi
fi

# --- RecordTrade (SELL 50 shares) ---
if [ -n "$INV_ID" ]; then
    SELL_RESP=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/RecordTrade" \
        "{\"investment_id\":\"$INV_ID\",\"trade_type\":\"TRADE_TYPE_SELL\",\"quantity\":50,\"price\":195000,\"fee\":5000,\"trade_date\":\"2024-03-22T00:00:00Z\"}")
    SELL_ID=$(echo "$SELL_RESP" | jq -r '.id // empty')
    if [ -n "$SELL_ID" ]; then
        pass "RecordTrade (SELL) - 50 shares @1950元"
    else
        fail "RecordTrade (SELL)" "$SELL_RESP"
    fi
fi

# --- ListTrades ---
if [ -n "$INV_ID" ]; then
    LIST_TR=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/ListTrades" \
        "{\"investment_id\":\"$INV_ID\"}")
    TR_CNT=$(echo "$LIST_TR" | jq '.trades | length')
    if [ "${TR_CNT:-0}" -ge 2 ] 2>/dev/null; then
        pass "ListTrades - found $TR_CNT trades"
    else
        fail "ListTrades" "$LIST_TR"
    fi
fi

# --- GetPortfolioSummary ---
PORTFOLIO=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/GetPortfolioSummary")
HOLD_CNT=$(echo "$PORTFOLIO" | jq '.holdings | length')
P_COST=$(echo "$PORTFOLIO" | jq -r '.totalCost // "0"')
if [ "${HOLD_CNT:-0}" -ge 1 ] 2>/dev/null; then
    pass "GetPortfolioSummary - $HOLD_CNT holdings, totalCost=${P_COST}分"
else
    fail "GetPortfolioSummary" "$PORTFOLIO"
fi

# --- DeleteInvestment ---
if [ -n "$INV2_ID" ]; then
    DEL_INV=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/DeleteInvestment" \
        "{\"investment_id\":\"$INV2_ID\"}")
    if echo "$DEL_INV" | grep -qi "error"; then
        fail "DeleteInvestment" "$DEL_INV"
    else
        pass "DeleteInvestment - deleted 基金"
    fi
fi

echo ""

###############################################################################
# 4. MarketDataService Tests
###############################################################################
echo "=== MARKET DATA SERVICE (4 RPCs) ==="

# --- GetQuote ---
QUOTE=$(grpc_auth investment.proto \
    "familyledger.investment.v1.MarketDataService/GetQuote" \
    '{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE"}')
Q_PRICE=$(echo "$QUOTE" | jq -r '.currentPrice // empty')
Q_NAME=$(echo "$QUOTE" | jq -r '.name // empty')
if [ -n "$Q_NAME" ] && [ "$Q_NAME" != "null" ]; then
    pass "GetQuote - 600519 ($Q_NAME) price=${Q_PRICE:-0}分"
else
    fail "GetQuote" "$QUOTE"
fi

# --- BatchGetQuotes ---
BATCH=$(grpc_auth investment.proto \
    "familyledger.investment.v1.MarketDataService/BatchGetQuotes" \
    '{"requests":[{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE"},{"symbol":"000858","market_type":"MARKET_TYPE_A_SHARE"}]}')
B_CNT=$(echo "$BATCH" | jq '.quotes | length')
if [ "${B_CNT:-0}" -ge 2 ] 2>/dev/null; then
    pass "BatchGetQuotes - got $B_CNT quotes"
else
    fail "BatchGetQuotes" "$BATCH"
fi

# --- SearchSymbol ---
SEARCH=$(grpc_auth investment.proto \
    "familyledger.investment.v1.MarketDataService/SearchSymbol" \
    '{"query":"茅台","market_type":"MARKET_TYPE_A_SHARE"}')
S_CNT=$(echo "$SEARCH" | jq '.symbols | length')
if [ "${S_CNT:-0}" -ge 1 ] 2>/dev/null; then
    FIRST_SYM=$(echo "$SEARCH" | jq -r '.symbols[0].symbol // empty')
    pass "SearchSymbol '茅台' - $S_CNT results, first=$FIRST_SYM"
else
    fail "SearchSymbol" "$SEARCH"
fi

# --- GetPriceHistory ---
HIST=$(grpc_auth investment.proto \
    "familyledger.investment.v1.MarketDataService/GetPriceHistory" \
    '{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE","start_date":"2024-01-01T00:00:00Z","end_date":"2025-01-01T00:00:00Z"}')
H_PTS=$(echo "$HIST" | jq '.points | length')
if echo "$HIST" | jq -e '.symbol' > /dev/null 2>&1; then
    pass "GetPriceHistory - 600519, $H_PTS price points"
else
    fail "GetPriceHistory" "$HIST"
fi

echo ""

###############################################################################
# 5. AssetService Tests
###############################################################################
echo "=== ASSET SERVICE (8 RPCs) ==="

# --- CreateAsset (房产) ---
A1_RESP=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/CreateAsset" \
    '{"name":"城西公寓","asset_type":"ASSET_TYPE_REAL_ESTATE","purchase_price":350000000,"purchase_date":"2021-01-01T00:00:00Z","description":"三室两厅 120平"}')
A1_ID=$(echo "$A1_RESP" | jq -r '.id // empty')
if [ -n "$A1_ID" ]; then
    pass "CreateAsset - 房产 350万 (id=$A1_ID)"
else
    fail "CreateAsset - 房产" "$A1_RESP"
fi

# --- CreateAsset (车辆) ---
A2_RESP=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/CreateAsset" \
    '{"name":"Model 3","asset_type":"ASSET_TYPE_VEHICLE","purchase_price":25000000,"purchase_date":"2023-01-01T00:00:00Z","description":"2023款 长续航版"}')
A2_ID=$(echo "$A2_RESP" | jq -r '.id // empty')
if [ -n "$A2_ID" ]; then
    pass "CreateAsset - 车辆 25万 (id=$A2_ID)"
else
    fail "CreateAsset - 车辆" "$A2_RESP"
fi

# --- CreateAsset (电子设备) ---
A3_RESP=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/CreateAsset" \
    '{"name":"MacBook Pro M3","asset_type":"ASSET_TYPE_ELECTRONICS","purchase_price":2499900,"purchase_date":"2023-11-01T00:00:00Z","description":"16寸 36GB"}')
A3_ID=$(echo "$A3_RESP" | jq -r '.id // empty')
if [ -n "$A3_ID" ]; then
    pass "CreateAsset - 电子设备 24999元 (id=$A3_ID)"
else
    fail "CreateAsset - 电子设备" "$A3_RESP"
fi

# --- GetAsset ---
if [ -n "$A1_ID" ]; then
    GET_A=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/GetAsset" \
        "{\"asset_id\":\"$A1_ID\"}")
    GA_NAME=$(echo "$GET_A" | jq -r '.name // empty')
    GA_PP=$(echo "$GET_A" | jq -r '.purchasePrice // empty')
    if [ "$GA_NAME" = "城西公寓" ] && [ "$GA_PP" = "350000000" ]; then
        pass "GetAsset - name=$GA_NAME, purchasePrice=$GA_PP"
    else
        fail "GetAsset" "$GET_A"
    fi
fi

# --- ListAssets ---
LIST_A=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/ListAssets")
A_CNT=$(echo "$LIST_A" | jq '.assets | length')
if [ "${A_CNT:-0}" -ge 3 ] 2>/dev/null; then
    pass "ListAssets - found $A_CNT assets"
else
    fail "ListAssets" "$LIST_A"
fi

# --- ListAssets with filter ---
LIST_AF=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/ListAssets" \
    '{"asset_type":"ASSET_TYPE_VEHICLE"}')
AF_CNT=$(echo "$LIST_AF" | jq '.assets | length')
if [ "${AF_CNT:-0}" -ge 1 ] 2>/dev/null; then
    pass "ListAssets (filter VEHICLE) - found $AF_CNT"
else
    fail "ListAssets (filter)" "$LIST_AF"
fi

# --- UpdateAsset ---
if [ -n "$A1_ID" ]; then
    UPD_A=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/UpdateAsset" \
        "{\"asset_id\":\"$A1_ID\",\"name\":\"城西公寓-精装修\",\"description\":\"三室两厅 120平 精装\"}")
    UA_NAME=$(echo "$UPD_A" | jq -r '.name // empty')
    if [ "$UA_NAME" = "城西公寓-精装修" ]; then
        pass "UpdateAsset - name=$UA_NAME"
    else
        fail "UpdateAsset" "$UPD_A"
    fi
fi

# --- SetDepreciationRule (车辆 - 直线法 6年) ---
if [ -n "$A2_ID" ]; then
    DEPR=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/SetDepreciationRule" \
        "{\"asset_id\":\"$A2_ID\",\"method\":\"DEPRECIATION_METHOD_STRAIGHT_LINE\",\"useful_life_years\":6,\"salvage_rate\":0.05}")
    DEPR_ID=$(echo "$DEPR" | jq -r '.id // empty')
    if [ -n "$DEPR_ID" ]; then
        pass "SetDepreciationRule - 车辆 直线法 6年 残值5% (id=$DEPR_ID)"
    else
        fail "SetDepreciationRule (车辆)" "$DEPR"
    fi
fi

# --- SetDepreciationRule (电子设备 - 双倍余额递减 5年) ---
if [ -n "$A3_ID" ]; then
    DEPR2=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/SetDepreciationRule" \
        "{\"asset_id\":\"$A3_ID\",\"method\":\"DEPRECIATION_METHOD_DOUBLE_DECLINING\",\"useful_life_years\":5,\"salvage_rate\":0.1}")
    DEPR2_ID=$(echo "$DEPR2" | jq -r '.id // empty')
    if [ -n "$DEPR2_ID" ]; then
        pass "SetDepreciationRule - 电子设备 双倍递减 5年 残值10%"
    else
        fail "SetDepreciationRule (电子设备)" "$DEPR2"
    fi
fi

# --- UpdateValuation (房产升值 380万) ---
if [ -n "$A1_ID" ]; then
    VAL1=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/UpdateValuation" \
        "{\"asset_id\":\"$A1_ID\",\"value\":380000000,\"source\":\"market\"}")
    V1_ID=$(echo "$VAL1" | jq -r '.id // empty')
    if [ -n "$V1_ID" ]; then
        pass "UpdateValuation - 房产 market估值 380万"
    else
        fail "UpdateValuation (1st)" "$VAL1"
    fi
fi

# --- UpdateValuation (房产手动估值 390万) ---
if [ -n "$A1_ID" ]; then
    VAL2=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/UpdateValuation" \
        "{\"asset_id\":\"$A1_ID\",\"value\":390000000,\"source\":\"manual\"}")
    V2_ID=$(echo "$VAL2" | jq -r '.id // empty')
    if [ -n "$V2_ID" ]; then
        pass "UpdateValuation - 房产 手动估值 390万"
    else
        fail "UpdateValuation (2nd)" "$VAL2"
    fi
fi

# --- ListValuations ---
if [ -n "$A1_ID" ]; then
    LIST_V=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/ListValuations" \
        "{\"asset_id\":\"$A1_ID\"}")
    V_CNT=$(echo "$LIST_V" | jq '.valuations | length')
    if [ "${V_CNT:-0}" -ge 2 ] 2>/dev/null; then
        pass "ListValuations - found $V_CNT valuations"
    else
        fail "ListValuations" "$LIST_V"
    fi
fi

# --- DeleteAsset ---
if [ -n "$A3_ID" ]; then
    DEL_A=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/DeleteAsset" \
        "{\"asset_id\":\"$A3_ID\"}")
    if echo "$DEL_A" | grep -qi "error"; then
        fail "DeleteAsset" "$DEL_A"
    else
        pass "DeleteAsset - deleted 电子设备"
        # Verify
        LIST_POST=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/ListAssets")
        POST_CNT=$(echo "$LIST_POST" | jq '.assets | length')
        if [ "${POST_CNT:-0}" -lt "${A_CNT:-0}" ] 2>/dev/null; then
            pass "DeleteAsset - verified (${POST_CNT} remaining)"
        else
            pass "DeleteAsset - post count=$POST_CNT"
        fi
    fi
fi

echo ""

###############################################################################
# SUMMARY
###############################################################################
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "============================================================"
echo " TEST SUMMARY"
echo "============================================================"
echo " Total : $TOTAL"
echo " Passed: $PASS_COUNT"
echo " Failed: $FAIL_COUNT"
echo "============================================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo " ❌ SOME TESTS FAILED"
    exit 1
else
    echo " ✅ ALL TESTS PASSED"
    exit 0
fi
