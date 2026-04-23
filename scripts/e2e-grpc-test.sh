#!/usr/bin/env bash
# FamilyLedger — E2E gRPC Test Script (Phase 1b focused)
set -uo pipefail

PROTO_PATH="$(cd "$(dirname "$0")/../proto" && pwd)"
HOST="localhost:50051"
PASS=0; FAIL=0; ERRORS=()
TOKEN=""

grpc() {
  local proto_file="$1" method="$2" data="$3"
  if [[ -n "$TOKEN" ]]; then
    grpcurl -plaintext -import-path "$PROTO_PATH" -proto "$proto_file" \
      -H "authorization: Bearer $TOKEN" -d "$data" "$HOST" "$method"
  else
    grpcurl -plaintext -import-path "$PROTO_PATH" -proto "$proto_file" \
      -d "$data" "$HOST" "$method"
  fi
}

ok() {
  ((PASS++)); printf "  ✅ %s\n" "$1"
}
fail() {
  ((FAIL++)); ERRORS+=("$1"); printf "  ❌ %s\n" "$1"
}
check() {
  local desc="$1" output="$2" expected="$3"
  echo "$output" | grep -q "$expected" && ok "$desc" || fail "$desc — expected: $expected"
}
check_not() {
  local desc="$1" output="$2" unexpected="$3"
  echo "$output" | grep -q "$unexpected" && fail "$desc — found unexpected: $unexpected" || ok "$desc"
}
check_eq() {
  local desc="$1" actual="$2" expected="$3"
  [[ "$actual" == "$expected" ]] && ok "$desc" || fail "$desc — expected: $expected, got: $actual"
}
get_balance() {
  local resp
  resp=$(grpc "account.proto" "familyledger.account.v1.AccountService/ListAccounts" "{}" 2>&1)
  local bal
  bal=$(echo "$resp" | grep '"balance"' | head -1 | sed 's/.*"balance": *"\{0,1\}\(-\{0,1\}[0-9]*\)"\{0,1\}.*/\1/')
  # protobuf omits zero-value fields, so empty = 0
  echo "${bal:-0}"
}

SUFFIX=$(date +%s)
EMAIL="e2e-$SUFFIX@test.com"

echo "🔧 Phase 0: Register + Setup"
echo "═══════════════════════════════════════"
RESP=$(grpc "auth.proto" "familyledger.auth.v1.AuthService/Register" \
  "{\"email\":\"$EMAIL\",\"password\":\"TestPass123!\"}" 2>&1)
TOKEN=$(echo "$RESP" | grep '"accessToken"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
check "Register" "$RESP" "accessToken"
echo "   email=$EMAIL"

ACCTS=$(grpc "account.proto" "familyledger.account.v1.AccountService/ListAccounts" "{}" 2>&1)
ACCT_ID=$(echo "$ACCTS" | grep '"id"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
check "Default account" "$ACCTS" "id"

CATS=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/GetCategories" "{}" 2>&1)
EXP_CAT=$(echo "$CATS" | grep -B5 "EXPENSE" | grep '"id"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
INC_CAT=$(echo "$CATS" | grep -B5 "INCOME" | grep '"id"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
check "Categories loaded" "$CATS" "EXPENSE"
echo "   expense_cat=$EXP_CAT  income_cat=$INC_CAT"

echo ""
echo "💰 Phase 1: CreateTransaction"
echo "═══════════════════════════════════════"
CR=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/CreateTransaction" \
  "{\"account_id\":\"$ACCT_ID\",\"category_id\":\"$EXP_CAT\",\"amount\":\"15000\",\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"e2e午餐\"}" 2>&1)
TXN_ID=$(echo "$CR" | grep '"id"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
check "CreateTransaction ¥150" "$CR" "$TXN_ID"
BAL=$(get_balance)
check_eq "Balance = -15000" "$BAL" "-15000"

echo ""
echo "📝 Phase 2: UpdateTransaction"
echo "═══════════════════════════════════════"
UR=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/UpdateTransaction" \
  "{\"transaction_id\":\"$TXN_ID\",\"amount\":\"25000\",\"note\":\"修改-晚餐\"}" 2>&1)
check "Update amount→25000" "$UR" "25000"
check "Update note" "$UR" "修改-晚餐"

UCNY=$(echo "$UR" | grep '"amountCny"' | head -1 | sed 's/.*: *"\{0,1\}\([0-9]*\)"\{0,1\}.*/\1/')
check_eq "amountCny synced to 25000" "$UCNY" "25000"

BAL2=$(get_balance)
check_eq "Balance = -25000 after update" "$BAL2" "-25000"

echo ""
echo "  Change type: expense→income"
UR2=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/UpdateTransaction" \
  "{\"transaction_id\":\"$TXN_ID\",\"category_id\":\"$INC_CAT\",\"type\":\"TRANSACTION_TYPE_INCOME\"}" 2>&1)
check "Update type→income" "$UR2" "INCOME"
BAL3=$(get_balance)
check_eq "Balance = +25000 after type change" "$BAL3" "25000"

echo ""
echo "🔒 Phase 3: Permission Checks"
echo "═══════════════════════════════════════"
RESP2=$(grpc "auth.proto" "familyledger.auth.v1.AuthService/Register" \
  "{\"email\":\"e2e-other-$SUFFIX@test.com\",\"password\":\"TestPass123!\"}" 2>&1)
SAVED_TOKEN="$TOKEN"
TOKEN=$(echo "$RESP2" | grep '"accessToken"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

PR=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/UpdateTransaction" \
  "{\"transaction_id\":\"$TXN_ID\",\"note\":\"hacked\"}" 2>&1)
check "Update PERMISSION_DENIED for other user" "$PR" "PermissionDenied"

DR=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/DeleteTransaction" \
  "{\"transaction_id\":\"$TXN_ID\"}" 2>&1)
check "Delete PERMISSION_DENIED for other user" "$DR" "PermissionDenied"
TOKEN="$SAVED_TOKEN"

echo ""
echo "🗑️  Phase 4: DeleteTransaction"
echo "═══════════════════════════════════════"
DEL=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/DeleteTransaction" \
  "{\"transaction_id\":\"$TXN_ID\"}" 2>&1)
check_not "Delete success (no error)" "$DEL" "ERROR"

LIST=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/ListTransactions" \
  "{\"account_id\":\"$ACCT_ID\"}" 2>&1)
check_not "Deleted txn not in list" "$LIST" "$TXN_ID"

BAL4=$(get_balance)
check_eq "Balance = 0 after delete" "$BAL4" "0"

echo ""
echo "⚠️  Phase 5: Edge Cases"
echo "═══════════════════════════════════════"
NF=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/UpdateTransaction" \
  "{\"transaction_id\":\"00000000-0000-0000-0000-000000000000\",\"note\":\"nope\"}" 2>&1)
check "Update NOT_FOUND for fake ID" "$NF" "NotFound"

NF2=$(grpc "transaction.proto" "familyledger.transaction.v1.TransactionService/DeleteTransaction" \
  "{\"transaction_id\":\"00000000-0000-0000-0000-000000000000\"}" 2>&1)
check "Delete NOT_FOUND for fake ID" "$NF2" "NotFound"

echo ""
echo "═══════════════════════════════════════"
echo "📊 Results: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && { printf "❌ Failures:\n"; for e in "${ERRORS[@]}"; do echo "   - $e"; done; exit 1; }
echo "🎉 All tests passed!"
