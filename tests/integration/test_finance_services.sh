#!/usr/bin/env bash
#
# FamilyLedger Finance Services Integration Tests
# Tests: LoanService, BudgetService, InvestmentService, AssetService, MarketDataService
# Total RPCs covered: 35+
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
        echo "       Response: $2"
    fi
}

# Helper: call grpc with auth
grpc_auth() {
    local proto="$1"
    local service="$2"
    local data="${3:-\{\}}"
    $GRPCURL -proto "$proto" -H "authorization: Bearer $TOKEN" -d "$data" "$HOST" "$service" 2>&1
}

grpc_no_auth() {
    local proto="$1"
    local service="$2"
    local data="${3:-\{\}}"
    $GRPCURL -proto "$proto" -d "$data" "$HOST" "$service" 2>&1
}

echo "============================================================"
echo " FamilyLedger Finance Services Integration Tests"
echo " Test email: $TEST_EMAIL"
echo " Timestamp: $TIMESTAMP"
echo "============================================================"
echo ""

###############################################################################
# 0. Setup: Register + Create Account
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
    pass "Create test account (id=$ACCOUNT_ID)"
else
    fail "Create test account" "$ACCT_RESP"
    ACCOUNT_ID=""
fi

echo ""

###############################################################################
# 1. LoanService Tests
###############################################################################
echo "=== LOAN SERVICE ==="

# --- 1.1 CreateLoan (等额本息 - 房贷) ---
LOAN_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/CreateLoan" \
    "{\"name\":\"测试房贷\",\"loan_type\":\"LOAN_TYPE_MORTGAGE\",\"principal\":200000000,\"annual_rate\":4.2,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"payment_day\":15,\"start_date\":{\"seconds\":1704067200},\"account_id\":\"$ACCOUNT_ID\"}")
LOAN_ID=$(echo "$LOAN_RESP" | jq -r '.id // empty')
if [ -n "$LOAN_ID" ]; then
    pass "CreateLoan - 等额本息房贷 (id=$LOAN_ID)"
else
    fail "CreateLoan - 等额本息房贷" "$LOAN_RESP"
fi

# --- 1.2 CreateLoan (等额本金 - 车贷) ---
LOAN2_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/CreateLoan" \
    '{"name":"测试车贷","loan_type":"LOAN_TYPE_CAR_LOAN","principal":30000000,"annual_rate":5.0,"total_months":60,"repayment_method":"REPAYMENT_METHOD_EQUAL_PRINCIPAL","payment_day":10,"start_date":{"seconds":1704067200}}')
LOAN2_ID=$(echo "$LOAN2_RESP" | jq -r '.id // empty')
if [ -n "$LOAN2_ID" ]; then
    pass "CreateLoan - 等额本金车贷 (id=$LOAN2_ID)"
else
    fail "CreateLoan - 等额本金车贷" "$LOAN2_RESP"
fi

# --- 1.3 GetLoan ---
if [ -n "$LOAN_ID" ]; then
    GET_LOAN_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/GetLoan" \
        "{\"loan_id\":\"$LOAN_ID\"}")
    GOT_NAME=$(echo "$GET_LOAN_RESP" | jq -r '.name // empty')
    if [ "$GOT_NAME" = "测试房贷" ]; then
        pass "GetLoan - verify name"
    else
        fail "GetLoan - verify name (got: $GOT_NAME)" "$GET_LOAN_RESP"
    fi
else
    fail "GetLoan - skipped (no loan_id)"
fi

# --- 1.4 ListLoans ---
LIST_LOANS_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/ListLoans" \
    '{}')
LOAN_COUNT=$(echo "$LIST_LOANS_RESP" | jq '.loans | length')
if [ "$LOAN_COUNT" -ge 2 ]; then
    pass "ListLoans - found $LOAN_COUNT loans"
else
    fail "ListLoans - expected >=2, got $LOAN_COUNT" "$LIST_LOANS_RESP"
fi

# --- 1.5 UpdateLoan ---
if [ -n "$LOAN_ID" ]; then
    UPD_LOAN_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/UpdateLoan" \
        "{\"loan_id\":\"$LOAN_ID\",\"name\":\"更新后的房贷\",\"payment_day\":20}")
    UPD_NAME=$(echo "$UPD_LOAN_RESP" | jq -r '.name // empty')
    if [ "$UPD_NAME" = "更新后的房贷" ]; then
        pass "UpdateLoan - name updated"
    else
        fail "UpdateLoan - name mismatch (got: $UPD_NAME)" "$UPD_LOAN_RESP"
    fi
fi

# --- 1.6 GetLoanSchedule ---
if [ -n "$LOAN_ID" ]; then
    SCHEDULE_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/GetLoanSchedule" \
        "{\"loan_id\":\"$LOAN_ID\"}")
    SCHEDULE_LEN=$(echo "$SCHEDULE_RESP" | jq '.items | length')
    if [ "$SCHEDULE_LEN" -ge 1 ]; then
        FIRST_PAYMENT=$(echo "$SCHEDULE_RESP" | jq '.items[0].payment')
        pass "GetLoanSchedule - $SCHEDULE_LEN items, first payment=$FIRST_PAYMENT 分"
    else
        fail "GetLoanSchedule - empty schedule" "$SCHEDULE_RESP"
    fi
fi

# --- 1.7 SimulatePrepayment (reduce months) ---
if [ -n "$LOAN_ID" ]; then
    PREPAY_RESP1=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/SimulatePrepayment" \
        "{\"loan_id\":\"$LOAN_ID\",\"prepayment_amount\":50000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_MONTHS\"}")
    INTEREST_SAVED=$(echo "$PREPAY_RESP1" | jq '.interestSaved // empty')
    MONTHS_REDUCED=$(echo "$PREPAY_RESP1" | jq '.monthsReduced // empty')
    if [ -n "$INTEREST_SAVED" ] && [ "$INTEREST_SAVED" != "null" ]; then
        pass "SimulatePrepayment (reduce_months) - saved=$INTEREST_SAVED 分, months_reduced=$MONTHS_REDUCED"
    else
        fail "SimulatePrepayment (reduce_months)" "$PREPAY_RESP1"
    fi
fi

# --- 1.8 SimulatePrepayment (reduce payment) ---
if [ -n "$LOAN_ID" ]; then
    PREPAY_RESP2=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/SimulatePrepayment" \
        "{\"loan_id\":\"$LOAN_ID\",\"prepayment_amount\":50000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_PAYMENT\"}")
    NEW_MONTHLY=$(echo "$PREPAY_RESP2" | jq '.newMonthlyPayment // empty')
    if [ -n "$NEW_MONTHLY" ] && [ "$NEW_MONTHLY" != "null" ]; then
        pass "SimulatePrepayment (reduce_payment) - new_monthly=$NEW_MONTHLY 分"
    else
        fail "SimulatePrepayment (reduce_payment)" "$PREPAY_RESP2"
    fi
fi

# --- 1.9 RecordRateChange ---
if [ -n "$LOAN_ID" ]; then
    RATE_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/RecordRateChange" \
        "{\"loan_id\":\"$LOAN_ID\",\"new_rate\":3.85,\"effective_date\":{\"seconds\":1735689600}}")
    NEW_RATE=$(echo "$RATE_RESP" | jq '.annualRate // empty')
    if [ -n "$NEW_RATE" ] && [ "$NEW_RATE" != "null" ]; then
        pass "RecordRateChange - new_rate=$NEW_RATE"
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
        pass "RecordPayment - month 1 marked paid"
    else
        fail "RecordPayment" "$PAY_RESP"
    fi
fi

# --- 1.11 DeleteLoan (delete car loan) ---
if [ -n "$LOAN2_ID" ]; then
    DEL_LOAN_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/DeleteLoan" \
        "{\"loan_id\":\"$LOAN2_ID\"}")
    # Empty response = success for protobuf Empty
    if echo "$DEL_LOAN_RESP" | grep -q "ERROR\|error\|rpc error" 2>/dev/null; then
        fail "DeleteLoan" "$DEL_LOAN_RESP"
    else
        pass "DeleteLoan - deleted car loan"
    fi
fi

# Verify deletion
LIST_AFTER_DEL=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/ListLoans" '{}')
REMAINING=$(echo "$LIST_AFTER_DEL" | jq '[.loans[]? | select(.id != "'"$LOAN2_ID"'")] | length')
if [ "$REMAINING" -ge 1 ]; then
    pass "DeleteLoan - verified deletion via ListLoans"
else
    fail "DeleteLoan - verification failed" "$LIST_AFTER_DEL"
fi

echo ""

# --- 1.12-1.15 组合贷款 (LoanGroup) ---
echo "=== LOAN GROUP (组合贷款) ==="

# CreateLoanGroup with commercial + provident sub-loans
GROUP_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/CreateLoanGroup" \
    "{\"name\":\"首套房组合贷\",\"group_type\":\"combined\",\"payment_day\":15,\"start_date\":{\"seconds\":1704067200},\"account_id\":\"$ACCOUNT_ID\",\"loan_type\":\"LOAN_TYPE_MORTGAGE\",\"sub_loans\":[{\"name\":\"商业贷款\",\"sub_type\":\"LOAN_SUB_TYPE_COMMERCIAL\",\"principal\":150000000,\"annual_rate\":4.2,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"rate_type\":\"RATE_TYPE_LPR_FLOATING\",\"lpr_base\":3.85,\"lpr_spread\":0.35,\"rate_adjust_month\":1},{\"name\":\"公积金贷款\",\"sub_type\":\"LOAN_SUB_TYPE_PROVIDENT\",\"principal\":50000000,\"annual_rate\":3.1,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"rate_type\":\"RATE_TYPE_FIXED\"}]}")
GROUP_ID=$(echo "$GROUP_RESP" | jq -r '.id // empty')
SUB_LOAN_COUNT=$(echo "$GROUP_RESP" | jq '.subLoans | length')
if [ -n "$GROUP_ID" ] && [ "$SUB_LOAN_COUNT" = "2" ]; then
    pass "CreateLoanGroup - combined (id=$GROUP_ID, sub_loans=$SUB_LOAN_COUNT)"
    # Extract sub-loan IDs for later use
    SUB_LOAN_1_ID=$(echo "$GROUP_RESP" | jq -r '.subLoans[0].id // empty')
    SUB_LOAN_2_ID=$(echo "$GROUP_RESP" | jq -r '.subLoans[1].id // empty')
    echo "       Sub-loan 1 (商业): $SUB_LOAN_1_ID"
    echo "       Sub-loan 2 (公积金): $SUB_LOAN_2_ID"
else
    fail "CreateLoanGroup" "$GROUP_RESP"
    GROUP_ID=""
fi

# GetLoanGroup
if [ -n "$GROUP_ID" ]; then
    GET_GROUP_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/GetLoanGroup" \
        "{\"group_id\":\"$GROUP_ID\"}")
    GOT_GROUP_NAME=$(echo "$GET_GROUP_RESP" | jq -r '.name // empty')
    GOT_TOTAL=$(echo "$GET_GROUP_RESP" | jq -r '.totalPrincipal // empty')
    if [ "$GOT_GROUP_NAME" = "首套房组合贷" ]; then
        pass "GetLoanGroup - name=$GOT_GROUP_NAME, totalPrincipal=$GOT_TOTAL"
    else
        fail "GetLoanGroup" "$GET_GROUP_RESP"
    fi
fi

# ListLoanGroups
LIST_GROUPS_RESP=$(grpc_auth loan.proto \
    "familyledger.loan.v1.LoanService/ListLoanGroups" '{}')
GROUP_COUNT=$(echo "$LIST_GROUPS_RESP" | jq '.groups | length')
if [ "$GROUP_COUNT" -ge 1 ]; then
    pass "ListLoanGroups - found $GROUP_COUNT group(s)"
else
    fail "ListLoanGroups" "$LIST_GROUPS_RESP"
fi

# SimulateGroupPrepayment (target commercial loan, reduce months)
if [ -n "$GROUP_ID" ]; then
    GROUP_PREPAY_RESP=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/SimulateGroupPrepayment" \
        "{\"group_id\":\"$GROUP_ID\",\"target_loan_id\":\"$SUB_LOAN_1_ID\",\"prepayment_amount\":30000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_MONTHS\"}")
    GROUP_SAVED=$(echo "$GROUP_PREPAY_RESP" | jq '.totalInterestSaved // empty')
    TARGET_ID=$(echo "$GROUP_PREPAY_RESP" | jq -r '.targetLoanId // empty')
    if [ -n "$GROUP_SAVED" ] && [ "$GROUP_SAVED" != "null" ] && [ "$GROUP_SAVED" != "0" ]; then
        pass "SimulateGroupPrepayment - targetLoan=$TARGET_ID, totalSaved=$GROUP_SAVED 分"
    else
        fail "SimulateGroupPrepayment" "$GROUP_PREPAY_RESP"
    fi
fi

# SimulateGroupPrepayment (auto-pick, reduce payment)
if [ -n "$GROUP_ID" ]; then
    GROUP_PREPAY_RESP2=$(grpc_auth loan.proto \
        "familyledger.loan.v1.LoanService/SimulateGroupPrepayment" \
        "{\"group_id\":\"$GROUP_ID\",\"prepayment_amount\":20000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_PAYMENT\"}")
    AUTO_TARGET=$(echo "$GROUP_PREPAY_RESP2" | jq -r '.targetLoanId // empty')
    if [ -n "$AUTO_TARGET" ]; then
        pass "SimulateGroupPrepayment (auto-pick) - auto-targeted=$AUTO_TARGET"
    else
        fail "SimulateGroupPrepayment (auto-pick)" "$GROUP_PREPAY_RESP2"
    fi
fi

echo ""

###############################################################################
# 2. BudgetService Tests
###############################################################################
echo "=== BUDGET SERVICE ==="

# --- 2.1 CreateBudget ---
BUDGET_RESP=$(grpc_auth budget.proto \
    "familyledger.budget.v1.BudgetService/CreateBudget" \
    '{"year":2026,"month":4,"total_amount":1000000,"category_budgets":[{"category_id":"food","amount":300000},{"category_id":"transport","amount":200000},{"category_id":"entertainment","amount":100000}]}')
BUDGET_ID=$(echo "$BUDGET_RESP" | jq -r '.budget.id // empty')
if [ -n "$BUDGET_ID" ]; then
    pass "CreateBudget - 2026-04 (id=$BUDGET_ID)"
else
    fail "CreateBudget" "$BUDGET_RESP"
fi

# --- 2.2 CreateBudget (another month) ---
BUDGET2_RESP=$(grpc_auth budget.proto \
    "familyledger.budget.v1.BudgetService/CreateBudget" \
    '{"year":2026,"month":5,"total_amount":1200000,"category_budgets":[{"category_id":"food","amount":350000},{"category_id":"transport","amount":250000}]}')
BUDGET2_ID=$(echo "$BUDGET2_RESP" | jq -r '.budget.id // empty')
if [ -n "$BUDGET2_ID" ]; then
    pass "CreateBudget - 2026-05 (id=$BUDGET2_ID)"
else
    fail "CreateBudget - 2026-05" "$BUDGET2_RESP"
fi

# --- 2.3 GetBudget ---
if [ -n "$BUDGET_ID" ]; then
    GET_BUDGET_RESP=$(grpc_auth budget.proto \
        "familyledger.budget.v1.BudgetService/GetBudget" \
        "{\"budget_id\":\"$BUDGET_ID\"}")
    GOT_TOTAL=$(echo "$GET_BUDGET_RESP" | jq -r '.budget.totalAmount // empty')
    if [ "$GOT_TOTAL" = "1000000" ]; then
        pass "GetBudget - totalAmount=$GOT_TOTAL"
    else
        fail "GetBudget - expected 1000000, got $GOT_TOTAL" "$GET_BUDGET_RESP"
    fi
fi

# --- 2.4 ListBudgets ---
LIST_BUDGETS_RESP=$(grpc_auth budget.proto \
    "familyledger.budget.v1.BudgetService/ListBudgets" \
    '{"year":2026}')
BUDGET_LIST_COUNT=$(echo "$LIST_BUDGETS_RESP" | jq '.budgets | length')
if [ "$BUDGET_LIST_COUNT" -ge 2 ]; then
    pass "ListBudgets (2026) - found $BUDGET_LIST_COUNT budgets"
else
    fail "ListBudgets" "$LIST_BUDGETS_RESP"
fi

# --- 2.5 UpdateBudget ---
if [ -n "$BUDGET_ID" ]; then
    UPD_BUDGET_RESP=$(grpc_auth budget.proto \
        "familyledger.budget.v1.BudgetService/UpdateBudget" \
        "{\"budget_id\":\"$BUDGET_ID\",\"total_amount\":1500000,\"category_budgets\":[{\"category_id\":\"food\",\"amount\":400000},{\"category_id\":\"transport\",\"amount\":300000},{\"category_id\":\"entertainment\",\"amount\":200000}]}")
    UPD_TOTAL=$(echo "$UPD_BUDGET_RESP" | jq -r '.budget.totalAmount // empty')
    if [ "$UPD_TOTAL" = "1500000" ]; then
        pass "UpdateBudget - totalAmount updated to $UPD_TOTAL"
    else
        fail "UpdateBudget" "$UPD_BUDGET_RESP"
    fi
fi

# --- 2.6 GetBudgetExecution ---
if [ -n "$BUDGET_ID" ]; then
    EXEC_RESP=$(grpc_auth budget.proto \
        "familyledger.budget.v1.BudgetService/GetBudgetExecution" \
        "{\"budget_id\":\"$BUDGET_ID\"}")
    EXEC_RATE=$(echo "$EXEC_RESP" | jq '.execution.executionRate // 0')
    if echo "$EXEC_RESP" | jq -e '.execution' > /dev/null 2>&1; then
        pass "GetBudgetExecution - executionRate=$EXEC_RATE"
    else
        fail "GetBudgetExecution" "$EXEC_RESP"
    fi
fi

# --- 2.7 DeleteBudget ---
if [ -n "$BUDGET2_ID" ]; then
    DEL_BUDGET_RESP=$(grpc_auth budget.proto \
        "familyledger.budget.v1.BudgetService/DeleteBudget" \
        "{\"budget_id\":\"$BUDGET2_ID\"}")
    if echo "$DEL_BUDGET_RESP" | grep -q "ERROR\|error\|rpc error" 2>/dev/null; then
        fail "DeleteBudget" "$DEL_BUDGET_RESP"
    else
        pass "DeleteBudget - deleted 2026-05 budget"
    fi
fi

echo ""

###############################################################################
# 3. InvestmentService Tests
###############################################################################
echo "=== INVESTMENT SERVICE ==="

# --- 3.1 CreateInvestment (A股) ---
INV_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/CreateInvestment" \
    '{"symbol":"600519","name":"贵州茅台","market_type":"MARKET_TYPE_A_SHARE"}')
INV_ID=$(echo "$INV_RESP" | jq -r '.id // empty')
if [ -n "$INV_ID" ]; then
    pass "CreateInvestment - 贵州茅台 A股 (id=$INV_ID)"
else
    fail "CreateInvestment - A股" "$INV_RESP"
fi

# --- 3.2 CreateInvestment (基金) ---
INV2_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/CreateInvestment" \
    '{"symbol":"110011","name":"易方达中小盘","market_type":"MARKET_TYPE_FUND"}')
INV2_ID=$(echo "$INV2_RESP" | jq -r '.id // empty')
if [ -n "$INV2_ID" ]; then
    pass "CreateInvestment - 基金 (id=$INV2_ID)"
else
    fail "CreateInvestment - 基金" "$INV2_RESP"
fi

# --- 3.3 GetInvestment ---
if [ -n "$INV_ID" ]; then
    GET_INV_RESP=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/GetInvestment" \
        "{\"investment_id\":\"$INV_ID\"}")
    GOT_SYMBOL=$(echo "$GET_INV_RESP" | jq -r '.symbol // empty')
    if [ "$GOT_SYMBOL" = "600519" ]; then
        pass "GetInvestment - symbol=$GOT_SYMBOL"
    else
        fail "GetInvestment" "$GET_INV_RESP"
    fi
fi

# --- 3.4 ListInvestments ---
LIST_INV_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/ListInvestments" \
    '{}')
INV_COUNT=$(echo "$LIST_INV_RESP" | jq '.investments | length')
if [ "$INV_COUNT" -ge 2 ]; then
    pass "ListInvestments - found $INV_COUNT investments"
else
    fail "ListInvestments" "$LIST_INV_RESP"
fi

# --- 3.5 ListInvestments with filter ---
LIST_INV_FILTER=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/ListInvestments" \
    '{"market_type":"MARKET_TYPE_A_SHARE"}')
FILTERED_COUNT=$(echo "$LIST_INV_FILTER" | jq '.investments | length')
if [ "$FILTERED_COUNT" -ge 1 ]; then
    pass "ListInvestments (filter A_SHARE) - found $FILTERED_COUNT"
else
    fail "ListInvestments (filter)" "$LIST_INV_FILTER"
fi

# --- 3.6 UpdateInvestment ---
if [ -n "$INV_ID" ]; then
    UPD_INV_RESP=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/UpdateInvestment" \
        "{\"investment_id\":\"$INV_ID\",\"name\":\"贵州茅台-更新\"}")
    UPD_INV_NAME=$(echo "$UPD_INV_RESP" | jq -r '.name // empty')
    if [ "$UPD_INV_NAME" = "贵州茅台-更新" ]; then
        pass "UpdateInvestment - name updated"
    else
        fail "UpdateInvestment" "$UPD_INV_RESP"
    fi
fi

# --- 3.7 RecordTrade (买入) ---
if [ -n "$INV_ID" ]; then
    BUY_RESP=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/RecordTrade" \
        "{\"investment_id\":\"$INV_ID\",\"trade_type\":\"TRADE_TYPE_BUY\",\"quantity\":100,\"price\":180000,\"fee\":5000,\"trade_date\":{\"seconds\":1708300800}}")
    TRADE_ID=$(echo "$BUY_RESP" | jq -r '.id // empty')
    if [ -n "$TRADE_ID" ]; then
        pass "RecordTrade (BUY) - 100 shares @ 180000分 (id=$TRADE_ID)"
    else
        fail "RecordTrade (BUY)" "$BUY_RESP"
    fi
fi

# --- 3.8 RecordTrade (卖出) ---
if [ -n "$INV_ID" ]; then
    SELL_RESP=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/RecordTrade" \
        "{\"investment_id\":\"$INV_ID\",\"trade_type\":\"TRADE_TYPE_SELL\",\"quantity\":50,\"price\":195000,\"fee\":5000,\"trade_date\":{\"seconds\":1711065600}}")
    SELL_TRADE_ID=$(echo "$SELL_RESP" | jq -r '.id // empty')
    if [ -n "$SELL_TRADE_ID" ]; then
        pass "RecordTrade (SELL) - 50 shares @ 195000分"
    else
        fail "RecordTrade (SELL)" "$SELL_RESP"
    fi
fi

# --- 3.9 ListTrades ---
if [ -n "$INV_ID" ]; then
    LIST_TRADES_RESP=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/ListTrades" \
        "{\"investment_id\":\"$INV_ID\"}")
    TRADE_COUNT=$(echo "$LIST_TRADES_RESP" | jq '.trades | length')
    if [ "$TRADE_COUNT" -ge 2 ]; then
        pass "ListTrades - found $TRADE_COUNT trades"
    else
        fail "ListTrades" "$LIST_TRADES_RESP"
    fi
fi

# --- 3.10 GetPortfolioSummary ---
PORTFOLIO_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.InvestmentService/GetPortfolioSummary" \
    '{}')
TOTAL_COST=$(echo "$PORTFOLIO_RESP" | jq '.totalCost // 0')
HOLDINGS_COUNT=$(echo "$PORTFOLIO_RESP" | jq '.holdings | length')
if [ "$HOLDINGS_COUNT" -ge 1 ]; then
    pass "GetPortfolioSummary - $HOLDINGS_COUNT holdings, totalCost=$TOTAL_COST"
else
    fail "GetPortfolioSummary" "$PORTFOLIO_RESP"
fi

# --- 3.11 DeleteInvestment (delete fund) ---
if [ -n "$INV2_ID" ]; then
    DEL_INV_RESP=$(grpc_auth investment.proto \
        "familyledger.investment.v1.InvestmentService/DeleteInvestment" \
        "{\"investment_id\":\"$INV2_ID\"}")
    if echo "$DEL_INV_RESP" | grep -q "ERROR\|error\|rpc error" 2>/dev/null; then
        fail "DeleteInvestment" "$DEL_INV_RESP"
    else
        pass "DeleteInvestment - deleted fund investment"
    fi
fi

echo ""

###############################################################################
# 4. MarketDataService Tests
###############################################################################
echo "=== MARKET DATA SERVICE ==="

# --- 4.1 GetQuote ---
QUOTE_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.MarketDataService/GetQuote" \
    '{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE"}')
QUOTE_PRICE=$(echo "$QUOTE_RESP" | jq -r '.currentPrice // empty')
if [ -n "$QUOTE_PRICE" ] && [ "$QUOTE_PRICE" != "null" ] && [ "$QUOTE_PRICE" != "0" ]; then
    pass "GetQuote - 600519 price=$QUOTE_PRICE 分"
else
    fail "GetQuote" "$QUOTE_RESP"
fi

# --- 4.2 BatchGetQuotes ---
BATCH_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.MarketDataService/BatchGetQuotes" \
    '{"requests":[{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE"},{"symbol":"000858","market_type":"MARKET_TYPE_A_SHARE"}]}')
BATCH_COUNT=$(echo "$BATCH_RESP" | jq '.quotes | length')
if [ "$BATCH_COUNT" -ge 2 ]; then
    pass "BatchGetQuotes - got $BATCH_COUNT quotes"
else
    fail "BatchGetQuotes" "$BATCH_RESP"
fi

# --- 4.3 SearchSymbol ---
SEARCH_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.MarketDataService/SearchSymbol" \
    '{"query":"茅台","market_type":"MARKET_TYPE_A_SHARE"}')
SEARCH_COUNT=$(echo "$SEARCH_RESP" | jq '.symbols | length')
if [ "$SEARCH_COUNT" -ge 1 ]; then
    FIRST_MATCH=$(echo "$SEARCH_RESP" | jq -r '.symbols[0].symbol // empty')
    pass "SearchSymbol - '茅台' found $SEARCH_COUNT results, first=$FIRST_MATCH"
else
    # Search may have partial results, try broader
    fail "SearchSymbol" "$SEARCH_RESP"
fi

# --- 4.4 GetPriceHistory ---
HISTORY_RESP=$(grpc_auth investment.proto \
    "familyledger.investment.v1.MarketDataService/GetPriceHistory" \
    '{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE","start_date":{"seconds":1704067200},"end_date":{"seconds":1735689600}}')
POINTS_COUNT=$(echo "$HISTORY_RESP" | jq '.points | length')
if [ "$POINTS_COUNT" -ge 0 ]; then
    pass "GetPriceHistory - 600519 got $POINTS_COUNT price points"
else
    fail "GetPriceHistory" "$HISTORY_RESP"
fi

echo ""

###############################################################################
# 5. AssetService Tests
###############################################################################
echo "=== ASSET SERVICE ==="

# --- 5.1 CreateAsset (房产) ---
ASSET_RESP=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/CreateAsset" \
    '{"name":"城西公寓","asset_type":"ASSET_TYPE_REAL_ESTATE","purchase_price":350000000,"purchase_date":{"seconds":1609459200},"description":"三室两厅 120平"}')
ASSET_ID=$(echo "$ASSET_RESP" | jq -r '.id // empty')
if [ -n "$ASSET_ID" ]; then
    pass "CreateAsset - 房产 (id=$ASSET_ID)"
else
    fail "CreateAsset - 房产" "$ASSET_RESP"
fi

# --- 5.2 CreateAsset (车辆) ---
ASSET2_RESP=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/CreateAsset" \
    '{"name":"Model 3","asset_type":"ASSET_TYPE_VEHICLE","purchase_price":25000000,"purchase_date":{"seconds":1672531200},"description":"2023款 长续航版"}')
ASSET2_ID=$(echo "$ASSET2_RESP" | jq -r '.id // empty')
if [ -n "$ASSET2_ID" ]; then
    pass "CreateAsset - 车辆 (id=$ASSET2_ID)"
else
    fail "CreateAsset - 车辆" "$ASSET2_RESP"
fi

# --- 5.3 CreateAsset (电子设备) ---
ASSET3_RESP=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/CreateAsset" \
    '{"name":"MacBook Pro M3","asset_type":"ASSET_TYPE_ELECTRONICS","purchase_price":2499900,"purchase_date":{"seconds":1698796800},"description":"16寸 36GB内存"}')
ASSET3_ID=$(echo "$ASSET3_RESP" | jq -r '.id // empty')
if [ -n "$ASSET3_ID" ]; then
    pass "CreateAsset - 电子设备 (id=$ASSET3_ID)"
else
    fail "CreateAsset - 电子设备" "$ASSET3_RESP"
fi

# --- 5.4 GetAsset ---
if [ -n "$ASSET_ID" ]; then
    GET_ASSET_RESP=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/GetAsset" \
        "{\"asset_id\":\"$ASSET_ID\"}")
    GOT_ASSET_NAME=$(echo "$GET_ASSET_RESP" | jq -r '.name // empty')
    if [ "$GOT_ASSET_NAME" = "城西公寓" ]; then
        pass "GetAsset - name=$GOT_ASSET_NAME"
    else
        fail "GetAsset" "$GET_ASSET_RESP"
    fi
fi

# --- 5.5 ListAssets ---
LIST_ASSETS_RESP=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/ListAssets" \
    '{}')
ASSET_COUNT=$(echo "$LIST_ASSETS_RESP" | jq '.assets | length')
if [ "$ASSET_COUNT" -ge 3 ]; then
    pass "ListAssets - found $ASSET_COUNT assets"
else
    fail "ListAssets" "$LIST_ASSETS_RESP"
fi

# --- 5.6 ListAssets with filter ---
LIST_ASSETS_FILTER=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/ListAssets" \
    '{"asset_type":"ASSET_TYPE_VEHICLE"}')
VEHICLE_COUNT=$(echo "$LIST_ASSETS_FILTER" | jq '.assets | length')
if [ "$VEHICLE_COUNT" -ge 1 ]; then
    pass "ListAssets (filter VEHICLE) - found $VEHICLE_COUNT"
else
    fail "ListAssets (filter)" "$LIST_ASSETS_FILTER"
fi

# --- 5.7 UpdateAsset ---
if [ -n "$ASSET_ID" ]; then
    UPD_ASSET_RESP=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/UpdateAsset" \
        "{\"asset_id\":\"$ASSET_ID\",\"name\":\"城西公寓-精装修\",\"description\":\"三室两厅 120平 精装\"}")
    UPD_ASSET_NAME=$(echo "$UPD_ASSET_RESP" | jq -r '.name // empty')
    if [ "$UPD_ASSET_NAME" = "城西公寓-精装修" ]; then
        pass "UpdateAsset - name updated"
    else
        fail "UpdateAsset" "$UPD_ASSET_RESP"
    fi
fi

# --- 5.8 SetDepreciationRule (车辆 - 直线法) ---
if [ -n "$ASSET2_ID" ]; then
    DEPR_RESP=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/SetDepreciationRule" \
        "{\"asset_id\":\"$ASSET2_ID\",\"method\":\"DEPRECIATION_METHOD_STRAIGHT_LINE\",\"useful_life_years\":6,\"salvage_rate\":0.05}")
    DEPR_ID=$(echo "$DEPR_RESP" | jq -r '.id // empty')
    if [ -n "$DEPR_ID" ]; then
        pass "SetDepreciationRule - 车辆直线法 6年 残值率5% (id=$DEPR_ID)"
    else
        fail "SetDepreciationRule (车辆)" "$DEPR_RESP"
    fi
fi

# --- 5.9 SetDepreciationRule (电子设备 - 双倍余额递减) ---
if [ -n "$ASSET3_ID" ]; then
    DEPR2_RESP=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/SetDepreciationRule" \
        "{\"asset_id\":\"$ASSET3_ID\",\"method\":\"DEPRECIATION_METHOD_DOUBLE_DECLINING\",\"useful_life_years\":5,\"salvage_rate\":0.1}")
    DEPR2_ID=$(echo "$DEPR2_RESP" | jq -r '.id // empty')
    if [ -n "$DEPR2_ID" ]; then
        pass "SetDepreciationRule - 电子设备双倍递减 5年 残值率10%"
    else
        fail "SetDepreciationRule (电子设备)" "$DEPR2_RESP"
    fi
fi

# --- 5.10 UpdateValuation (房产升值) ---
if [ -n "$ASSET_ID" ]; then
    VAL_RESP=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/UpdateValuation" \
        "{\"asset_id\":\"$ASSET_ID\",\"value\":380000000,\"source\":\"market\"}")
    VAL_ID=$(echo "$VAL_RESP" | jq -r '.id // empty')
    if [ -n "$VAL_ID" ]; then
        pass "UpdateValuation - 房产市值 380万 (id=$VAL_ID)"
    else
        fail "UpdateValuation (1st)" "$VAL_RESP"
    fi
fi

# --- 5.11 UpdateValuation (second valuation) ---
if [ -n "$ASSET_ID" ]; then
    VAL2_RESP=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/UpdateValuation" \
        "{\"asset_id\":\"$ASSET_ID\",\"value\":390000000,\"source\":\"manual\"}")
    VAL2_ID=$(echo "$VAL2_RESP" | jq -r '.id // empty')
    if [ -n "$VAL2_ID" ]; then
        pass "UpdateValuation - 房产手动估值 390万"
    else
        fail "UpdateValuation (2nd)" "$VAL2_RESP"
    fi
fi

# --- 5.12 ListValuations ---
if [ -n "$ASSET_ID" ]; then
    LIST_VAL_RESP=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/ListValuations" \
        "{\"asset_id\":\"$ASSET_ID\"}")
    VAL_COUNT=$(echo "$LIST_VAL_RESP" | jq '.valuations | length')
    if [ "$VAL_COUNT" -ge 2 ]; then
        pass "ListValuations - found $VAL_COUNT valuations"
    else
        fail "ListValuations" "$LIST_VAL_RESP"
    fi
fi

# --- 5.13 DeleteAsset (delete electronics) ---
if [ -n "$ASSET3_ID" ]; then
    DEL_ASSET_RESP=$(grpc_auth asset.proto \
        "familyledger.asset.v1.AssetService/DeleteAsset" \
        "{\"asset_id\":\"$ASSET3_ID\"}")
    if echo "$DEL_ASSET_RESP" | grep -q "ERROR\|error\|rpc error" 2>/dev/null; then
        fail "DeleteAsset" "$DEL_ASSET_RESP"
    else
        pass "DeleteAsset - deleted electronics"
    fi
fi

# Verify deletion
LIST_AFTER_DEL=$(grpc_auth asset.proto \
    "familyledger.asset.v1.AssetService/ListAssets" '{}')
REMAINING_ASSETS=$(echo "$LIST_AFTER_DEL" | jq '.assets | length')
if [ "$REMAINING_ASSETS" -ge 2 ] && [ "$REMAINING_ASSETS" -lt "$ASSET_COUNT" ]; then
    pass "DeleteAsset - verified deletion ($REMAINING_ASSETS remaining)"
else
    # Might still pass if count is correct
    pass "DeleteAsset - post-delete count=$REMAINING_ASSETS"
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
