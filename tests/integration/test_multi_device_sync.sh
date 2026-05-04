#!/usr/bin/env bash
#
# FamilyLedger — 多设备同步端到端 gRPC 集成测试
# 验证 Device A 创建/修改/删除的数据在 Device B 上可见
#
# 覆盖场景:
#   1. 交易 CRUD 跨设备同步 (Create → Read → Update → Read → Delete → Read)
#   2. 账户创建跨设备同步
#
# 用法: bash tests/integration/test_multi_device_sync.sh
#
set -uo pipefail

##############################################################################
# 配置
##############################################################################
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROTO_DIR="$PROJECT_DIR/proto"
HOST="localhost:50051"
GRPCURL="grpcurl -plaintext -import-path $PROTO_DIR"

PASS_COUNT=0
FAIL_COUNT=0
TEST_NUM=0
FAILURES=""

# 每次运行唯一后缀，避免冲突
UNIQUE=$(date +%s%N | tail -c 10)

# 已知的餐饮分类 UUID
CATEGORY_ID="95d6dc66-12c4-5f2b-bf9b-1d439a9c8100"

##############################################################################
# 辅助函数
##############################################################################
pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "  [PASS] $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILURES="$FAILURES\n  - $1: $2"
  echo "  [FAIL] $1 — $2"
}

run_test() {
  TEST_NUM=$((TEST_NUM + 1))
  echo ""
  echo "=== Test #$TEST_NUM: $1 ==="
}

# 调用 grpcurl，返回 stdout；如果失败把 stderr 也捞出来
grpc_call() {
  local proto="$1"; shift
  local method="${@: -1}"
  local args=("${@:1:$#-1}")
  $GRPCURL -proto "$proto" "${args[@]}" "$HOST" "$method" 2>&1
}

grpc_call_auth() {
  local proto="$1"; local token="$2"; shift 2
  local method="${@: -1}"
  local args=("${@:1:$#-1}")
  $GRPCURL -proto "$proto" -H "authorization: Bearer $token" "${args[@]}" "$HOST" "$method" 2>&1
}

json_field_from() {
  echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$2',''))"
}

json_array_len() {
  echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('$2',[])))"
}

json_nested() {
  echo "$1" | python3 -c "
import sys,json
d=json.load(sys.stdin)
keys='$2'.split('.')
for k in keys:
    if isinstance(d,dict):
        d=d.get(k,'')
    else:
        d=''
        break
print(d)
"
}

# 在 JSON 数组中按字段值查找对象，返回整个对象的 JSON
# 用法: json_find_in_array "$JSON" "arrayKey" "fieldName" "fieldValue"
json_find_in_array() {
  echo "$1" | python3 -c "
import sys,json
d=json.load(sys.stdin)
arr=d.get('$2',[])
for item in arr:
    if str(item.get('$3','')) == '$4':
        print(json.dumps(item))
        sys.exit(0)
print('')
"
}

# 在 JSON 数组中按字段值查找，返回指定字段
# 用法: json_find_field_in_array "$JSON" "arrayKey" "matchField" "matchValue" "returnField"
json_find_field_in_array() {
  echo "$1" | python3 -c "
import sys,json
d=json.load(sys.stdin)
arr=d.get('$2',[])
for item in arr:
    if str(item.get('$3','')) == '$4':
        print(item.get('$5',''))
        sys.exit(0)
print('')
"
}

contains_error() {
  echo "$1" | grep -qi "error\|ERROR\|rpc error" && return 0 || return 1
}

##############################################################################
# ==================== 准备: 注册用户 & 双设备登录 ====================
##############################################################################
echo "============================================================"
echo "  多设备同步测试 — Setup"
echo "============================================================"

EMAIL="sync_user_${UNIQUE}@test.com"
PASSWD="Test123456"

# --- 注册用户 ---
run_test "注册测试用户"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
USER_ID=$(json_field_from "$RESP" "userId")
if [[ -n "$USER_ID" ]]; then
  pass "注册成功 userId=$USER_ID"
else
  fail "Register" "返回异常: $RESP"
  echo "无法继续测试，退出"
  exit 1
fi

# --- Device A 登录 ---
run_test "Device A 登录"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Login")
TOKEN_A=$(json_field_from "$RESP" "accessToken")
if [[ -n "$TOKEN_A" ]]; then
  pass "Device A 获得 token"
else
  fail "Login-A" "无 token: $RESP"
  echo "无法继续测试，退出"
  exit 1
fi

# --- Device B 登录 (同一用户，不同 session) ---
run_test "Device B 登录 (同一用户)"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Login")
TOKEN_B=$(json_field_from "$RESP" "accessToken")
if [[ -n "$TOKEN_B" ]]; then
  pass "Device B 获得 token"
else
  fail "Login-B" "无 token: $RESP"
  echo "无法继续测试，退出"
  exit 1
fi

# --- 创建带初始余额的测试账户 ---
run_test "创建测试账户 (via Device A)"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d '{"name":"同步测试账户","type":"ACCOUNT_TYPE_CASH","currency":"CNY","initial_balance":"10000000"}' \
  "familyledger.account.v1.AccountService/CreateAccount")
DEFAULT_ACCOUNT_ID=$(echo "$RESP" | python3 -c "
import sys,json
d=json.load(sys.stdin)
acct=d.get('account',{})
print(acct.get('id',''))
")
if [[ -n "$DEFAULT_ACCOUNT_ID" ]]; then
  pass "测试账户 id=$DEFAULT_ACCOUNT_ID"
else
  fail "GetDefaultAccount" "无账户: $RESP"
  echo "无法继续测试，退出"
  exit 1
fi

##############################################################################
# ==================== 1. 交易跨设备同步 ====================
##############################################################################
echo ""
echo "============================================================"
echo "  交易跨设备同步测试"
echo "============================================================"

TXN_NOTE="sync_test_txn_${UNIQUE}"
TXN_DATE_RFC3339=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- 1.1 Device A: 创建交易 ---
run_test "Device A: 创建交易 (50元餐饮)"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$DEFAULT_ACCOUNT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":5000,\"currency\":\"CNY\",\"amount_cny\":5000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"$TXN_NOTE\",\"txn_date\":\"$TXN_DATE_RFC3339\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
TXN_ID=$(json_nested "$RESP" "transaction.id")
if [[ -n "$TXN_ID" ]]; then
  pass "Device A 创建交易 id=$TXN_ID, note=$TXN_NOTE"
else
  fail "DeviceA-CreateTxn" "返回异常: $RESP"
fi

# --- 1.2 Device B: 列出交易，验证可见 ---
run_test "Device B: 列出交易 — 验证 Device A 创建的交易可见"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d '{"page_size":100}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
FOUND_NOTE=$(json_find_field_in_array "$RESP" "transactions" "note" "$TXN_NOTE" "note")
if [[ "$FOUND_NOTE" == "$TXN_NOTE" ]]; then
  pass "Device B 看到交易 note=$TXN_NOTE"
else
  fail "DeviceB-SeeTxn" "未找到 note=$TXN_NOTE 的交易: $RESP"
fi

# --- 1.3 Device A: 更新交易金额 (50元 → 80元) ---
run_test "Device A: 更新交易金额 → 8000 (80元)"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"transaction_id\":\"$TXN_ID\",\"amount\":8000}" \
  "familyledger.transaction.v1.TransactionService/UpdateTransaction")
UPD_AMOUNT=$(json_nested "$RESP" "transaction.amount")
if [[ "$UPD_AMOUNT" == "8000" ]]; then
  pass "Device A 更新金额成功 amount=8000"
elif ! contains_error "$RESP"; then
  pass "Device A UpdateTransaction 调用成功"
else
  fail "DeviceA-UpdateTxn" "返回异常: $RESP"
fi

# --- 1.4 Device B: 列出交易，验证金额已更新 ---
run_test "Device B: 列出交易 — 验证金额已更新为 8000"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d '{"page_size":100}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
FOUND_AMOUNT=$(json_find_field_in_array "$RESP" "transactions" "note" "$TXN_NOTE" "amount")
if [[ "$FOUND_AMOUNT" == "8000" ]]; then
  pass "Device B 看到更新后的金额 amount=8000"
else
  fail "DeviceB-SeeUpdatedTxn" "金额=$FOUND_AMOUNT, 期望 8000"
fi

# --- 1.5 Device A: 删除交易 ---
run_test "Device A: 删除交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"transaction_id\":\"$TXN_ID\"}" \
  "familyledger.transaction.v1.TransactionService/DeleteTransaction")
if ! contains_error "$RESP"; then
  pass "Device A 删除交易成功 id=$TXN_ID"
else
  fail "DeviceA-DeleteTxn" "返回异常: $RESP"
fi

# --- 1.6 Device B: 列出交易，验证已删除交易不可见 ---
run_test "Device B: 列出交易 — 验证已删除交易不再出现"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d '{"page_size":100}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
FOUND_NOTE=$(json_find_field_in_array "$RESP" "transactions" "note" "$TXN_NOTE" "note")
if [[ -z "$FOUND_NOTE" ]]; then
  pass "Device B 看不到已删除的交易 (soft-delete 生效)"
else
  fail "DeviceB-SeeDeletedTxn" "仍能看到 note=$FOUND_NOTE 的交易"
fi

##############################################################################
# ==================== 2. 账户跨设备同步 ====================
##############################################################################
echo ""
echo "============================================================"
echo "  账户跨设备同步测试"
echo "============================================================"

ACCT_NAME="sync_test_account_${UNIQUE}"

# --- 2.1 Device A: 创建账户 ---
run_test "Device A: 创建现金账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"name\":\"$ACCT_NAME\",\"type\":\"ACCOUNT_TYPE_CASH\",\"currency\":\"CNY\"}" \
  "familyledger.account.v1.AccountService/CreateAccount")
NEW_ACCT_ID=$(json_nested "$RESP" "account.id")
if [[ -n "$NEW_ACCT_ID" ]]; then
  pass "Device A 创建账户 id=$NEW_ACCT_ID, name=$ACCT_NAME"
else
  fail "DeviceA-CreateAccount" "返回异常: $RESP"
fi

# --- 2.2 Device B: 列出账户，验证新账户可见 ---
run_test "Device B: 列出账户 — 验证 Device A 创建的账户可见"
RESP=$(grpc_call_auth account.proto "$TOKEN_B" \
  -d '{}' \
  "familyledger.account.v1.AccountService/ListAccounts")
FOUND_ACCT=$(json_find_field_in_array "$RESP" "accounts" "name" "$ACCT_NAME" "name")
if [[ "$FOUND_ACCT" == "$ACCT_NAME" ]]; then
  pass "Device B 看到账户 name=$ACCT_NAME"
else
  fail "DeviceB-SeeAccount" "未找到 name=$ACCT_NAME 的账户: $RESP"
fi

##############################################################################
# 测试报告
##############################################################################
echo ""
echo "============================================================"
echo "  测试报告 — 多设备同步"
echo "============================================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo "  总计: $TOTAL 测试"
echo "  通过: $PASS_COUNT"
echo "  失败: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "  失败详情:"
  echo -e "$FAILURES"
  echo ""
  exit 1
else
  echo "  🎉 全部通过!"
  echo ""
  exit 0
fi
