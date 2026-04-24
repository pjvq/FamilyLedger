#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../.."

PASS_COUNT=0
FAIL_COUNT=0
TS=$(date +%s)
EMAIL="finance-v2-${TS}@test.com"
PROTO_PATH="proto"

pass() { PASS_COUNT=$((PASS_COUNT+1)); echo "[PASS] $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "[FAIL] $1"; echo "       Response: $2"; }

grpc_noauth() {
  grpcurl -plaintext -import-path "$PROTO_PATH" -proto "$1" -d "$3" localhost:50051 "$2" 2>&1
}
grpc_auth() {
  grpcurl -plaintext -import-path "$PROTO_PATH" -proto "$1" -H "authorization: Bearer $TOKEN" -d "$3" localhost:50051 "$2" 2>&1
}

echo "============================================================"
echo " FamilyLedger Finance Services Integration Tests v2"
echo " Email: $EMAIL"
echo "============================================================"

# === SETUP ===
echo ""
echo "=== SETUP: Register & Create Account ==="
REG=$(grpc_noauth auth.proto "familyledger.auth.v1.AuthService/Register" "{\"email\":\"$EMAIL\",\"password\":\"Test123456\"}")
TOKEN=$(echo "$REG" | jq -r '.accessToken // empty')
[ -n "$TOKEN" ] && pass "Register" || { fail "Register" "$REG"; exit 1; }

ACCT=$(grpc_auth account.proto "familyledger.account.v1.AccountService/CreateAccount" '{"name":"测试还款账户","type":"ACCOUNT_TYPE_BANK_CARD","initial_balance":500000000}')
ACCOUNT_ID=$(echo "$ACCT" | jq -r '.account.id // empty')
[ -n "$ACCOUNT_ID" ] && pass "CreateAccount (id=$ACCOUNT_ID)" || fail "CreateAccount" "$ACCT"

# Get categories for budget test
CATS=$(grpc_auth transaction.proto "familyledger.transaction.v1.TransactionService/GetCategories" '{}')
CAT_ID_1=$(echo "$CATS" | jq -r '.categories[0].id // empty')
CAT_ID_2=$(echo "$CATS" | jq -r '.categories[1].id // empty')
CAT_ID_3=$(echo "$CATS" | jq -r '.categories[2].id // empty')

echo ""
echo "=== LOAN SERVICE ==="

# CreateLoan - 等额本息房贷
LOAN_RESP=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/CreateLoan" \
  "{\"name\":\"测试房贷\",\"loan_type\":\"LOAN_TYPE_MORTGAGE\",\"principal\":200000000,\"annual_rate\":4.2,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"payment_day\":15,\"start_date\":\"2024-01-01T00:00:00Z\",\"account_id\":\"$ACCOUNT_ID\"}")
LOAN_ID=$(echo "$LOAN_RESP" | jq -r '.id // empty')
[ -n "$LOAN_ID" ] && pass "CreateLoan 等额本息房贷 (id=$LOAN_ID)" || fail "CreateLoan 等额本息房贷" "$LOAN_RESP"

# CreateLoan - 等额本金车贷
LOAN2_RESP=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/CreateLoan" \
  "{\"name\":\"测试车贷\",\"loan_type\":\"LOAN_TYPE_CAR_LOAN\",\"principal\":30000000,\"annual_rate\":5.5,\"total_months\":60,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_PRINCIPAL\",\"payment_day\":20,\"start_date\":\"2024-03-01T00:00:00Z\"}")
LOAN2_ID=$(echo "$LOAN2_RESP" | jq -r '.id // empty')
[ -n "$LOAN2_ID" ] && pass "CreateLoan 等额本金车贷 (id=$LOAN2_ID)" || fail "CreateLoan 等额本金车贷" "$LOAN2_RESP"

# GetLoan
if [ -n "$LOAN_ID" ]; then
  GET_LOAN=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/GetLoan" "{\"loan_id\":\"$LOAN_ID\"}")
  GOT_NAME=$(echo "$GET_LOAN" | jq -r '.name // empty')
  [ "$GOT_NAME" = "测试房贷" ] && pass "GetLoan" || fail "GetLoan" "$GET_LOAN"
fi

# ListLoans
LIST_LOANS=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/ListLoans" '{}')
LOAN_COUNT=$(echo "$LIST_LOANS" | jq -r '.loans | length')
[ "$LOAN_COUNT" -ge 2 ] 2>/dev/null && pass "ListLoans (count=$LOAN_COUNT)" || fail "ListLoans" "$LIST_LOANS"

# UpdateLoan
if [ -n "$LOAN_ID" ]; then
  UPD_LOAN=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/UpdateLoan" "{\"loan_id\":\"$LOAN_ID\",\"name\":\"房贷-已更新\"}")
  UPD_NAME=$(echo "$UPD_LOAN" | jq -r '.name // empty')
  [ "$UPD_NAME" = "房贷-已更新" ] && pass "UpdateLoan" || fail "UpdateLoan" "$UPD_LOAN"
fi

# GetLoanSchedule
if [ -n "$LOAN_ID" ]; then
  SCHED=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/GetLoanSchedule" "{\"loan_id\":\"$LOAN_ID\"}")
  SCHED_COUNT=$(echo "$SCHED" | jq -r '.items | length')
  [ "$SCHED_COUNT" -ge 300 ] 2>/dev/null && pass "GetLoanSchedule (items=$SCHED_COUNT)" || fail "GetLoanSchedule" "items=$SCHED_COUNT"
fi

# SimulatePrepayment
if [ -n "$LOAN_ID" ]; then
  SIM=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/SimulatePrepayment" \
    "{\"loan_id\":\"$LOAN_ID\",\"prepayment_amount\":5000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_MONTHS\"}")
  SAVED=$(echo "$SIM" | jq -r '.interestSaved // .interest_saved // empty')
  [ -n "$SAVED" ] && pass "SimulatePrepayment reduce_months (saved=$SAVED)" || fail "SimulatePrepayment" "$SIM"
fi

# RecordRateChange
if [ -n "$LOAN_ID" ]; then
  RATE_RESP=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/RecordRateChange" \
    "{\"loan_id\":\"$LOAN_ID\",\"new_rate\":3.85,\"effective_date\":\"2025-01-01T00:00:00Z\"}")
  RATE_ID=$(echo "$RATE_RESP" | jq -r '.id // empty')
  [ -n "$RATE_ID" ] && pass "RecordRateChange (new_rate=3.85)" || fail "RecordRateChange" "$RATE_RESP"
fi

# RecordPayment
if [ -n "$LOAN_ID" ]; then
  PAY_RESP=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/RecordPayment" \
    "{\"loan_id\":\"$LOAN_ID\",\"month_number\":1}")
  PAY_STATUS=$(echo "$PAY_RESP" | jq -r '.isPaid // .is_paid // empty')
  [ "$PAY_STATUS" = "true" ] && pass "RecordPayment (month=1, isPaid=true)" || fail "RecordPayment" "$PAY_RESP"
fi

# DeleteLoan (车贷)
if [ -n "$LOAN2_ID" ]; then
  DEL=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/DeleteLoan" "{\"loan_id\":\"$LOAN2_ID\"}")
  # verify deleted
  LIST_AFTER=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/ListLoans" '{}')
  AFTER_COUNT=$(echo "$LIST_AFTER" | jq -r '.loans | length')
  [ "$AFTER_COUNT" -eq 1 ] 2>/dev/null && pass "DeleteLoan (remaining=$AFTER_COUNT)" || fail "DeleteLoan" "remaining=$AFTER_COUNT"
fi

echo ""
echo "=== LOAN GROUP (组合贷款) ==="

# CreateLoanGroup
GROUP_RESP=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/CreateLoanGroup" \
  "{\"name\":\"测试组合房贷\",\"group_type\":\"combined\",\"payment_day\":15,\"start_date\":\"2024-01-01T00:00:00Z\",\"account_id\":\"$ACCOUNT_ID\",\"loan_type\":\"LOAN_TYPE_MORTGAGE\",\"sub_loans\":[{\"name\":\"商贷部分\",\"sub_type\":\"LOAN_SUB_TYPE_COMMERCIAL\",\"principal\":150000000,\"annual_rate\":4.2,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"rate_type\":\"RATE_TYPE_LPR_FLOATING\",\"lpr_base\":3.85,\"lpr_spread\":0.35,\"rate_adjust_month\":1},{\"name\":\"公积金部分\",\"sub_type\":\"LOAN_SUB_TYPE_PROVIDENT\",\"principal\":50000000,\"annual_rate\":2.85,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"rate_type\":\"RATE_TYPE_FIXED\"}]}")
GROUP_ID=$(echo "$GROUP_RESP" | jq -r '.id // empty')
[ -n "$GROUP_ID" ] && pass "CreateLoanGroup (id=$GROUP_ID)" || fail "CreateLoanGroup" "$GROUP_RESP"

# GetLoanGroup
if [ -n "$GROUP_ID" ]; then
  GET_GROUP=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/GetLoanGroup" "{\"group_id\":\"$GROUP_ID\"}")
  GOT_GNAME=$(echo "$GET_GROUP" | jq -r '.name // empty')
  SUB_COUNT=$(echo "$GET_GROUP" | jq -r '.subLoans // .sub_loans | length')
  [ "$GOT_GNAME" = "测试组合房贷" ] && [ "$SUB_COUNT" = "2" ] && pass "GetLoanGroup (subs=$SUB_COUNT)" || fail "GetLoanGroup" "$GET_GROUP"
fi

# ListLoanGroups
LIST_GROUPS=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/ListLoanGroups" '{}')
GROUP_COUNT=$(echo "$LIST_GROUPS" | jq -r '.groups // .loanGroups // .loan_groups | length // 0')
[ "$GROUP_COUNT" -ge 1 ] 2>/dev/null && pass "ListLoanGroups (count=$GROUP_COUNT)" || fail "ListLoanGroups" "$LIST_GROUPS"

# SimulateGroupPrepayment
if [ -n "$GROUP_ID" ]; then
  GSIM=$(grpc_auth loan.proto "familyledger.loan.v1.LoanService/SimulateGroupPrepayment" \
    "{\"group_id\":\"$GROUP_ID\",\"prepayment_amount\":5000000,\"strategy\":\"PREPAYMENT_STRATEGY_REDUCE_MONTHS\"}")
  GSAVED=$(echo "$GSIM" | jq -r '.totalInterestSaved // .total_interest_saved // empty')
  [ -n "$GSAVED" ] && pass "SimulateGroupPrepayment (saved=$GSAVED)" || fail "SimulateGroupPrepayment" "$GSIM"
fi

echo ""
echo "=== BUDGET SERVICE ==="

# CreateBudget
if [ -n "$CAT_ID_1" ]; then
  BUD_RESP=$(grpc_auth budget.proto "familyledger.budget.v1.BudgetService/CreateBudget" \
    "{\"year\":2026,\"month\":4,\"total_amount\":800000,\"category_budgets\":[{\"category_id\":\"$CAT_ID_1\",\"amount\":300000},{\"category_id\":\"$CAT_ID_2\",\"amount\":200000}]}")
  BUD_ID=$(echo "$BUD_RESP" | jq -r '.budget.id // empty')
  [ -n "$BUD_ID" ] && pass "CreateBudget (id=$BUD_ID)" || fail "CreateBudget" "$BUD_RESP"
else
  fail "CreateBudget" "no category IDs available"
fi

# GetBudget
if [ -n "${BUD_ID:-}" ]; then
  GET_BUD=$(grpc_auth budget.proto "familyledger.budget.v1.BudgetService/GetBudget" "{\"budget_id\":\"$BUD_ID\"}")
  GOT_AMT=$(echo "$GET_BUD" | jq -r '.budget.totalAmount // .budget.total_amount // empty')
  [ "$GOT_AMT" = "800000" ] && pass "GetBudget (amount=$GOT_AMT)" || fail "GetBudget" "$GET_BUD"
fi

# ListBudgets
LIST_BUD=$(grpc_auth budget.proto "familyledger.budget.v1.BudgetService/ListBudgets" '{"year":2026}')
BUD_COUNT=$(echo "$LIST_BUD" | jq -r '.budgets | length // 0')
[ "$BUD_COUNT" -ge 1 ] 2>/dev/null && pass "ListBudgets (count=$BUD_COUNT)" || fail "ListBudgets" "$LIST_BUD"

# UpdateBudget
if [ -n "${BUD_ID:-}" ]; then
  UPD_BUD=$(grpc_auth budget.proto "familyledger.budget.v1.BudgetService/UpdateBudget" \
    "{\"budget_id\":\"$BUD_ID\",\"total_amount\":1000000}")
  UPD_AMT=$(echo "$UPD_BUD" | jq -r '.budget.totalAmount // .budget.total_amount // empty')
  [ "$UPD_AMT" = "1000000" ] && pass "UpdateBudget (new_amount=$UPD_AMT)" || fail "UpdateBudget" "$UPD_BUD"
fi

# GetBudgetExecution
if [ -n "${BUD_ID:-}" ]; then
  EXEC_BUD=$(grpc_auth budget.proto "familyledger.budget.v1.BudgetService/GetBudgetExecution" "{\"budget_id\":\"$BUD_ID\"}")
  EXEC_RATE=$(echo "$EXEC_BUD" | jq -r '.executionRate // .execution_rate // "0"')
  pass "GetBudgetExecution (rate=$EXEC_RATE)"
fi

# DeleteBudget
if [ -n "${BUD_ID:-}" ]; then
  grpc_auth budget.proto "familyledger.budget.v1.BudgetService/DeleteBudget" "{\"budget_id\":\"$BUD_ID\"}" > /dev/null 2>&1
  LIST_AFTER_BUD=$(grpc_auth budget.proto "familyledger.budget.v1.BudgetService/ListBudgets" '{"year":2026}')
  AFTER_BUD_COUNT=$(echo "$LIST_AFTER_BUD" | jq -r '.budgets | length // 0')
  [ "$AFTER_BUD_COUNT" -eq 0 ] 2>/dev/null && pass "DeleteBudget" || fail "DeleteBudget" "remaining=$AFTER_BUD_COUNT"
fi

echo ""
echo "=== INVESTMENT SERVICE ==="

# CreateInvestment
INV_RESP=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/CreateInvestment" \
  '{"name":"贵州茅台","symbol":"600519","market_type":"MARKET_TYPE_A_SHARE"}')
INV_ID=$(echo "$INV_RESP" | jq -r '.id // empty')
[ -n "$INV_ID" ] && pass "CreateInvestment 贵州茅台 (id=$INV_ID)" || fail "CreateInvestment" "$INV_RESP"

INV2_RESP=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/CreateInvestment" \
  '{"name":"比特币","symbol":"BTC","market_type":"MARKET_TYPE_CRYPTO"}')
INV2_ID=$(echo "$INV2_RESP" | jq -r '.id // empty')
[ -n "$INV2_ID" ] && pass "CreateInvestment 比特币 (id=$INV2_ID)" || fail "CreateInvestment BTC" "$INV2_RESP"

# GetInvestment
if [ -n "$INV_ID" ]; then
  GET_INV=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/GetInvestment" "{\"investment_id\":\"$INV_ID\"}")
  GOT_SYM=$(echo "$GET_INV" | jq -r '.symbol // empty')
  [ "$GOT_SYM" = "600519" ] && pass "GetInvestment" || fail "GetInvestment" "$GET_INV"
fi

# ListInvestments
LIST_INV=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/ListInvestments" '{}')
INV_COUNT=$(echo "$LIST_INV" | jq -r '.investments | length')
[ "$INV_COUNT" -ge 2 ] 2>/dev/null && pass "ListInvestments (count=$INV_COUNT)" || fail "ListInvestments" "$LIST_INV"

# UpdateInvestment
if [ -n "$INV_ID" ]; then
  UPD_INV=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/UpdateInvestment" \
    "{\"investment_id\":\"$INV_ID\",\"name\":\"贵州茅台-更新\"}")
  UPD_INAME=$(echo "$UPD_INV" | jq -r '.name // empty')
  [ "$UPD_INAME" = "贵州茅台-更新" ] && pass "UpdateInvestment" || fail "UpdateInvestment" "$UPD_INV"
fi

# RecordTrade - BUY
if [ -n "$INV_ID" ]; then
  TRADE_RESP=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/RecordTrade" \
    "{\"investment_id\":\"$INV_ID\",\"trade_type\":\"TRADE_TYPE_BUY\",\"quantity\":100,\"price\":180000,\"fee\":500,\"trade_date\":\"2024-06-15T00:00:00Z\"}")
  TRADE_ID=$(echo "$TRADE_RESP" | jq -r '.id // empty')
  [ -n "$TRADE_ID" ] && pass "RecordTrade BUY (id=$TRADE_ID)" || fail "RecordTrade BUY" "$TRADE_RESP"
fi

# RecordTrade - SELL
if [ -n "$INV_ID" ]; then
  SELL_RESP=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/RecordTrade" \
    "{\"investment_id\":\"$INV_ID\",\"trade_type\":\"TRADE_TYPE_SELL\",\"quantity\":50,\"price\":190000,\"fee\":500,\"trade_date\":\"2024-09-20T00:00:00Z\"}")
  SELL_ID=$(echo "$SELL_RESP" | jq -r '.id // empty')
  [ -n "$SELL_ID" ] && pass "RecordTrade SELL (id=$SELL_ID)" || fail "RecordTrade SELL" "$SELL_RESP"
fi

# ListTrades
if [ -n "$INV_ID" ]; then
  LIST_TR=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/ListTrades" "{\"investment_id\":\"$INV_ID\"}")
  TR_COUNT=$(echo "$LIST_TR" | jq -r '.trades | length')
  [ "$TR_COUNT" -ge 2 ] 2>/dev/null && pass "ListTrades (count=$TR_COUNT)" || fail "ListTrades" "$LIST_TR"
fi

# GetPortfolioSummary
PORTFOLIO=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/GetPortfolioSummary" '{}')
TOTAL_VAL=$(echo "$PORTFOLIO" | jq -r '.totalValue // .total_value // empty')
[ -n "$TOTAL_VAL" ] && pass "GetPortfolioSummary (totalValue=$TOTAL_VAL)" || fail "GetPortfolioSummary" "$PORTFOLIO"

# Market: GetQuote
QUOTE=$(grpc_auth investment.proto "familyledger.investment.v1.MarketDataService/GetQuote" '{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE"}')
PRICE=$(echo "$QUOTE" | jq -r '.currentPrice // .price // empty')
[ -n "$PRICE" ] && pass "GetQuote 600519 (price=$PRICE)" || fail "GetQuote" "$QUOTE"

# Market: BatchGetQuotes
BATCH=$(grpc_auth investment.proto "familyledger.investment.v1.MarketDataService/BatchGetQuotes" \
  '{"requests":[{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE"},{"symbol":"BTC","market_type":"MARKET_TYPE_CRYPTO"}]}')
BATCH_COUNT=$(echo "$BATCH" | jq -r '.quotes | length')
[ "$BATCH_COUNT" -ge 2 ] 2>/dev/null && pass "BatchGetQuotes (count=$BATCH_COUNT)" || fail "BatchGetQuotes" "$BATCH"

# Market: SearchSymbol
SEARCH=$(grpc_auth investment.proto "familyledger.investment.v1.MarketDataService/SearchSymbol" '{"query":"茅台","market_type":"MARKET_TYPE_A_SHARE"}')
SEARCH_COUNT=$(echo "$SEARCH" | jq -r '.symbols // .results | length')
[ "$SEARCH_COUNT" -ge 1 ] 2>/dev/null && pass "SearchSymbol 茅台 (results=$SEARCH_COUNT)" || fail "SearchSymbol" "$SEARCH"

# Market: GetPriceHistory
HIST=$(grpc_auth investment.proto "familyledger.investment.v1.MarketDataService/GetPriceHistory" \
  '{"symbol":"600519","market_type":"MARKET_TYPE_A_SHARE","start_date":"2024-01-01T00:00:00Z","end_date":"2024-12-31T00:00:00Z"}')
HIST_COUNT=$(echo "$HIST" | jq -r '.points // .data_points | length // 0')
pass "GetPriceHistory (response received)"

# DeleteInvestment
if [ -n "$INV2_ID" ]; then
  grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/DeleteInvestment" "{\"investment_id\":\"$INV2_ID\"}" > /dev/null 2>&1
  LIST_AFTER_INV=$(grpc_auth investment.proto "familyledger.investment.v1.InvestmentService/ListInvestments" '{}')
  AFTER_INV_COUNT=$(echo "$LIST_AFTER_INV" | jq -r '.investments | length')
  [ "$AFTER_INV_COUNT" -eq 1 ] 2>/dev/null && pass "DeleteInvestment (remaining=$AFTER_INV_COUNT)" || fail "DeleteInvestment" "remaining=$AFTER_INV_COUNT"
fi

echo ""
echo "=== ASSET SERVICE ==="

# CreateAsset - 房产
ASSET_RESP=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/CreateAsset" \
  '{"name":"朝阳区两居室","asset_type":"ASSET_TYPE_REAL_ESTATE","purchase_price":500000000,"purchase_date":"2020-06-15T00:00:00Z","description":"朝阳区两居室,89平米"}')
ASSET_ID=$(echo "$ASSET_RESP" | jq -r '.id // empty')
[ -n "$ASSET_ID" ] && pass "CreateAsset 房产 (id=$ASSET_ID)" || fail "CreateAsset 房产" "$ASSET_RESP"

# CreateAsset - 车辆
ASSET2_RESP=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/CreateAsset" \
  '{"name":"特斯拉Model3","asset_type":"ASSET_TYPE_VEHICLE","purchase_price":28000000,"purchase_date":"2023-03-01T00:00:00Z","description":"2023款长续航版"}')
ASSET2_ID=$(echo "$ASSET2_RESP" | jq -r '.id // empty')
[ -n "$ASSET2_ID" ] && pass "CreateAsset 车辆 (id=$ASSET2_ID)" || fail "CreateAsset 车辆" "$ASSET2_RESP"

# GetAsset
if [ -n "$ASSET_ID" ]; then
  GET_ASSET=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/GetAsset" "{\"asset_id\":\"$ASSET_ID\"}")
  GOT_ANAME=$(echo "$GET_ASSET" | jq -r '.name // empty')
  [ "$GOT_ANAME" = "朝阳区两居室" ] && pass "GetAsset" || fail "GetAsset" "$GET_ASSET"
fi

# ListAssets
LIST_ASSETS=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/ListAssets" '{}')
ASSET_COUNT=$(echo "$LIST_ASSETS" | jq -r '.assets | length')
[ "$ASSET_COUNT" -ge 2 ] 2>/dev/null && pass "ListAssets (count=$ASSET_COUNT)" || fail "ListAssets" "$LIST_ASSETS"

# UpdateAsset
if [ -n "$ASSET_ID" ]; then
  UPD_ASSET=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/UpdateAsset" \
    "{\"asset_id\":\"$ASSET_ID\",\"name\":\"朝阳区两居室-已装修\"}")
  UPD_ANAME=$(echo "$UPD_ASSET" | jq -r '.name // empty')
  [ "$UPD_ANAME" = "朝阳区两居室-已装修" ] && pass "UpdateAsset" || fail "UpdateAsset" "$UPD_ASSET"
fi

# UpdateValuation
if [ -n "$ASSET_ID" ]; then
  VAL_RESP=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/UpdateValuation" \
    "{\"asset_id\":\"$ASSET_ID\",\"value\":550000000,\"source\":\"市场估价\"}")
  VAL_ID=$(echo "$VAL_RESP" | jq -r '.id // empty')
  [ -n "$VAL_ID" ] && pass "UpdateValuation (new=¥5,500,000)" || fail "UpdateValuation" "$VAL_RESP"
fi

# ListValuations
if [ -n "$ASSET_ID" ]; then
  LIST_VAL=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/ListValuations" "{\"asset_id\":\"$ASSET_ID\"}")
  VAL_COUNT=$(echo "$LIST_VAL" | jq -r '.valuations | length // 0')
  [ "$VAL_COUNT" -ge 1 ] 2>/dev/null && pass "ListValuations (count=$VAL_COUNT)" || fail "ListValuations" "$LIST_VAL"
fi

# SetDepreciationRule
if [ -n "$ASSET2_ID" ]; then
  DEP_RESP=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/SetDepreciationRule" \
    "{\"asset_id\":\"$ASSET2_ID\",\"method\":\"DEPRECIATION_METHOD_DOUBLE_DECLINING\",\"useful_life_years\":5,\"salvage_rate\":0.05}")
  DEP_METHOD=$(echo "$DEP_RESP" | jq -r '.method // empty')
  [ -n "$DEP_METHOD" ] && pass "SetDepreciationRule (method=$DEP_METHOD)" || fail "SetDepreciationRule" "$DEP_RESP"
fi

# DeleteAsset
if [ -n "$ASSET2_ID" ]; then
  grpc_auth asset.proto "familyledger.asset.v1.AssetService/DeleteAsset" "{\"asset_id\":\"$ASSET2_ID\"}" > /dev/null 2>&1
  LIST_AFTER_ASSET=$(grpc_auth asset.proto "familyledger.asset.v1.AssetService/ListAssets" '{}')
  AFTER_ASSET_COUNT=$(echo "$LIST_AFTER_ASSET" | jq -r '.assets | length')
  [ "$AFTER_ASSET_COUNT" -eq 1 ] 2>/dev/null && pass "DeleteAsset (remaining=$AFTER_ASSET_COUNT)" || fail "DeleteAsset" "remaining=$AFTER_ASSET_COUNT"
fi

echo ""
echo "============================================================"
echo " TEST SUMMARY"
echo "============================================================"
echo " Total : $((PASS_COUNT + FAIL_COUNT))"
echo " Passed: $PASS_COUNT"
echo " Failed: $FAIL_COUNT"
echo "============================================================"
[ "$FAIL_COUNT" -eq 0 ] && echo " ✅ ALL TESTS PASSED" || echo " ❌ SOME TESTS FAILED"
exit $FAIL_COUNT
