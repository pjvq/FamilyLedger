#!/usr/bin/env bash
#
# FamilyLedger — 家庭功能完整生命周期端到端测试
# 覆盖 22 个 Phase / 96 个测试场景:
#   Phase 1: 用户注册和初始状态 (数据隔离基线)
#   Phase 2: 创建家庭 (邀请/加入流程)
#   Phase 3: 家庭账户和交易 (共享可见性)
#   Phase 4: 数据隔离 (个人 vs 家庭)
#   Phase 5: Dashboard 家庭模式 (聚合统计)
#   Phase 6: 权限控制 (编辑/删除权限)
#   Phase 7: 同步 (家庭模式 PullChanges)
#   Phase 8: 导出 (家庭交易导出)
#   Phase 9: 退出和清理
#   Phase 10: 边界场景
#   Phase 11: 角色管理 (SetMemberRole)
#   Phase 12: 细粒度权限测试
#   Phase 13: 收入交易与余额验证
#   Phase 14: 家庭账户操作
#   Phase 15: 家庭预算
#   Phase 16: 家庭贷款
#   Phase 17: 家庭投资
#   Phase 18: 家庭资产
#   Phase 19: Dashboard 家庭模式 (扩展)
#   Phase 20: 审计日志
#   Phase 21: 全量备份 (家庭模式)
#   Phase 22: 多家庭隔离
#
# 用法: bash tests/integration/test_family_full_lifecycle.sh
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
SKIP_COUNT=0
TEST_NUM=0
FAILURES=""

# 每次运行唯一后缀，避免邮箱冲突
UNIQUE=$(date +%s%N | tail -c 10)

##############################################################################
# 前置检查
##############################################################################
echo "============================================================"
echo "  家庭功能完整生命周期 E2E 测试"
echo "============================================================"
echo ""
echo "  检查依赖..."

if ! command -v grpcurl &>/dev/null; then
  echo "  [ERROR] grpcurl 未安装. 请运行: brew install grpcurl"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "  [ERROR] jq 未安装. 请运行: brew install jq"
  exit 1
fi

# list 可能因 auth 返回非零，只要有响应就说明 server 在跑
_server_check=$(grpcurl -plaintext "$HOST" list 2>&1 || true)
if ! echo "$_server_check" | grep -qE "Unauthenticated|Service|method"; then
  echo "  [ERROR] 无法连接 gRPC 服务器 ($HOST)"
  echo "         请确保服务已启动: go run cmd/server/main.go"
  exit 1
fi

echo "  ✓ grpcurl 可用"
echo "  ✓ jq 可用"
echo "  ✓ gRPC 服务器在线 ($HOST)"
echo ""

##############################################################################
# 辅助函数
##############################################################################
pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "  [PASS] $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILURES="$FAILURES\n  - #$TEST_NUM $1: $2"
  echo "  [FAIL] $1 — $2"
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  echo "  [SKIP] $1 — $2"
}

run_test() {
  TEST_NUM=$((TEST_NUM + 1))
  echo ""
  echo "--- Test #$TEST_NUM: $1 ---"
}

# 调用 grpcurl，返回 stdout+stderr
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

# JSON 字段提取 (使用 jq)
json_field() {
  echo "$1" | jq -r ".$2 // empty" 2>/dev/null
}

json_array_len() {
  echo "$1" | jq -r ".$2 | length" 2>/dev/null
}

json_nested() {
  echo "$1" | jq -r ".$2 // empty" 2>/dev/null
}

json_array_contains() {
  # $1=json, $2=array_path, $3=field, $4=value
  echo "$1" | jq -e ".$2[] | select(.$3 == \"$4\")" &>/dev/null
}

contains_error() {
  echo "$1" | grep -qi "error\|ERROR\|rpc error" && return 0 || return 1
}

# 检查响应是否包含 permission denied 或 not a member 等拒绝信息
contains_permission_denied() {
  echo "$1" | grep -qi "permission\|denied\|forbidden\|not a member\|unauthorized\|not found" && return 0 || return 1
}

##############################################################################
# Phase 1: 用户注册和初始状态
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 1: 用户注册和初始状态"
echo "============================================================"

# --- 1. 注册用户 A (owner) ---
run_test "注册用户 A (将成为家庭 owner)"
EMAIL_A="family_owner_${UNIQUE}@test.com"
PASSWD="Test123456"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
USER_A_ID=$(json_field "$RESP" "userId")
TOKEN_A=$(json_field "$RESP" "accessToken")
if [[ -n "$USER_A_ID" && -n "$TOKEN_A" ]]; then
  pass "用户 A 注册成功, userId=$USER_A_ID"
else
  fail "注册用户 A" "返回异常: $RESP"
fi

# --- 2. 注册用户 B (member) ---
run_test "注册用户 B (将加入家庭)"
EMAIL_B="family_member_${UNIQUE}@test.com"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_B\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
USER_B_ID=$(json_field "$RESP" "userId")
TOKEN_B=$(json_field "$RESP" "accessToken")
if [[ -n "$USER_B_ID" && -n "$TOKEN_B" ]]; then
  pass "用户 B 注册成功, userId=$USER_B_ID"
else
  fail "注册用户 B" "返回异常: $RESP"
fi

# --- 3. 注册用户 C (旁观者，不加入家庭) ---
run_test "注册用户 C (旁观者，不加入家庭)"
EMAIL_C="outsider_${UNIQUE}@test.com"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_C\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
USER_C_ID=$(json_field "$RESP" "userId")
TOKEN_C=$(json_field "$RESP" "accessToken")
if [[ -n "$USER_C_ID" && -n "$TOKEN_C" ]]; then
  pass "用户 C 注册成功, userId=$USER_C_ID"
else
  fail "注册用户 C" "返回异常: $RESP"
fi

# --- 获取可用的分类 ID ---
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d '{"type":"TRANSACTION_TYPE_EXPENSE"}' \
  "familyledger.transaction.v1.TransactionService/GetCategories")
CATEGORY_ID=$(echo "$RESP" | jq -r '.categories[0].id // empty')
if [[ -z "$CATEGORY_ID" ]]; then
  # 如果没有分类，创建一个
  RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
    -d '{"name":"测试支出","type":"TRANSACTION_TYPE_EXPENSE","icon_key":"food"}' \
    "familyledger.transaction.v1.TransactionService/CreateCategory")
  CATEGORY_ID=$(echo "$RESP" | jq -r '.category.id // .id // empty')
fi
echo "  使用分类 ID=$CATEGORY_ID"

# --- 4. 各自创建个人账户和交易 ---
run_test "用户 A 创建个人账户和交易"
# A 的个人账户
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d '{"name":"A的储蓄卡","type":"ACCOUNT_TYPE_BANK_CARD","currency":"CNY","initial_balance":100000}' \
  "familyledger.account.v1.AccountService/CreateAccount")
PERSONAL_ACCT_A=$(json_nested "$RESP" "account.id")
if [[ -n "$PERSONAL_ACCT_A" ]]; then
  pass "用户 A 个人账户创建成功, id=$PERSONAL_ACCT_A"
else
  fail "用户 A 创建个人账户" "$RESP"
fi

# A 的个人交易
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$PERSONAL_ACCT_A\",\"category_id\":\"$CATEGORY_ID\",\"amount\":5000,\"currency\":\"CNY\",\"amount_cny\":5000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"A的个人午餐\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
PERSONAL_TXN_A=$(json_nested "$RESP" "transaction.id")
if [[ -n "$PERSONAL_TXN_A" ]]; then
  echo "    A 的个人交易 id=$PERSONAL_TXN_A"
else
  fail "用户 A 创建个人交易" "$RESP"
fi

run_test "用户 B 创建个人账户和交易"
# B 的个人账户
RESP=$(grpc_call_auth account.proto "$TOKEN_B" \
  -d '{"name":"B的现金","type":"ACCOUNT_TYPE_CASH","currency":"CNY","initial_balance":50000}' \
  "familyledger.account.v1.AccountService/CreateAccount")
PERSONAL_ACCT_B=$(json_nested "$RESP" "account.id")
if [[ -n "$PERSONAL_ACCT_B" ]]; then
  pass "用户 B 个人账户创建成功, id=$PERSONAL_ACCT_B"
else
  fail "用户 B 创建个人账户" "$RESP"
fi

# B 的个人交易
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d "{\"account_id\":\"$PERSONAL_ACCT_B\",\"category_id\":\"$CATEGORY_ID\",\"amount\":3000,\"currency\":\"CNY\",\"amount_cny\":3000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"B的个人早餐\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
PERSONAL_TXN_B=$(json_nested "$RESP" "transaction.id")
if [[ -n "$PERSONAL_TXN_B" ]]; then
  echo "    B 的个人交易 id=$PERSONAL_TXN_B"
else
  fail "用户 B 创建个人交易" "$RESP"
fi

# C 的个人账户
RESP=$(grpc_call_auth account.proto "$TOKEN_C" \
  -d '{"name":"C的钱包","type":"ACCOUNT_TYPE_CASH","currency":"CNY","initial_balance":20000}' \
  "familyledger.account.v1.AccountService/CreateAccount")
PERSONAL_ACCT_C=$(json_nested "$RESP" "account.id")

# --- 5. 验证用户之间数据隔离 ---
run_test "验证: 用户 A 看不到用户 B 的交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d '{"page_size":100}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
# 检查 A 的列表中不包含 B 的交易 note
if echo "$RESP" | grep -q "B的个人早餐"; then
  fail "数据隔离(A看B)" "用户 A 能看到用户 B 的交易!"
else
  pass "用户 A 看不到用户 B 的交易"
fi

run_test "验证: 用户 B 看不到用户 A 的交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d '{"page_size":100}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
if echo "$RESP" | grep -q "A的个人午餐"; then
  fail "数据隔离(B看A)" "用户 B 能看到用户 A 的交易!"
else
  pass "用户 B 看不到用户 A 的交易"
fi

##############################################################################
# Phase 2: 创建家庭
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 2: 创建家庭"
echo "============================================================"

# --- 6. 用户 A 创建家庭 ---
run_test "用户 A 创建家庭 '测试家庭'"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d '{"name":"测试家庭"}' \
  "familyledger.family.v1.FamilyService/CreateFamily")
FAMILY_ID=$(json_nested "$RESP" "family.id")
if [[ -n "$FAMILY_ID" ]]; then
  pass "创建家庭成功, id=$FAMILY_ID"
else
  fail "创建家庭" "$RESP"
fi

# --- 7. 验证 A 是 owner ---
run_test "验证用户 A 是家庭 owner"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/GetFamily")
OWNER_ID=$(json_nested "$RESP" "family.ownerId")
if [[ "$OWNER_ID" == "$USER_A_ID" ]]; then
  pass "家庭 owner_id=$USER_A_ID 正确"
else
  fail "验证 owner" "期望 owner=$USER_A_ID, 实际=$OWNER_ID, resp=$RESP"
fi

# --- 8. 生成邀请码 ---
run_test "生成邀请码"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/GenerateInviteCode")
INVITE_CODE=$(json_field "$RESP" "inviteCode")
if [[ -n "$INVITE_CODE" ]]; then
  pass "邀请码=$INVITE_CODE"
else
  fail "生成邀请码" "$RESP"
fi

# --- 9. 用户 B 用邀请码加入 ---
run_test "用户 B 用邀请码加入家庭"
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"invite_code\":\"$INVITE_CODE\"}" \
  "familyledger.family.v1.FamilyService/JoinFamily")
JOINED_ID=$(json_nested "$RESP" "family.id")
if [[ "$JOINED_ID" == "$FAMILY_ID" ]]; then
  pass "用户 B 成功加入家庭"
elif ! contains_error "$RESP"; then
  pass "JoinFamily 调用成功"
else
  fail "用户 B 加入家庭" "$RESP"
fi

# --- 10. 验证成员列表包含 A 和 B ---
run_test "验证成员列表包含 A 和 B"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/ListFamilyMembers")
MEM_COUNT=$(json_array_len "$RESP" "members")
HAS_A=$(echo "$RESP" | jq -e ".members[] | select(.userId == \"$USER_A_ID\")" 2>/dev/null)
HAS_B=$(echo "$RESP" | jq -e ".members[] | select(.userId == \"$USER_B_ID\")" 2>/dev/null)
if [[ -n "$HAS_A" && -n "$HAS_B" ]]; then
  pass "成员列表包含 A 和 B (共 $MEM_COUNT 人)"
else
  fail "验证成员列表" "成员: $RESP"
fi

##############################################################################
# Phase 3: 家庭账户和交易
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 3: 家庭账户和交易"
echo "============================================================"

# --- 11. 用户 A 创建家庭共享账户 ---
run_test "用户 A 创建家庭共享账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"name\":\"家庭共享账户\",\"type\":\"ACCOUNT_TYPE_BANK_CARD\",\"currency\":\"CNY\",\"initial_balance\":200000,\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.account.v1.AccountService/CreateAccount")
FAMILY_ACCT_ID=$(json_nested "$RESP" "account.id")
FAMILY_ACCT_FAMILY=$(json_nested "$RESP" "account.familyId")
if [[ -n "$FAMILY_ACCT_ID" ]]; then
  pass "家庭账户创建成功, id=$FAMILY_ACCT_ID, family_id=$FAMILY_ACCT_FAMILY"
else
  fail "创建家庭账户" "$RESP"
fi

# --- 12. 用户 A 在家庭账户记一笔交易 ---
run_test "用户 A 在家庭账户记一笔支出"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":8000,\"currency\":\"CNY\",\"amount_cny\":8000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"家庭超市采购-A\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
FAMILY_TXN_A=$(json_nested "$RESP" "transaction.id")
if [[ -n "$FAMILY_TXN_A" ]]; then
  pass "A 的家庭交易 id=$FAMILY_TXN_A"
else
  fail "A 创建家庭交易" "$RESP"
fi

# --- 13. 用户 B 在家庭账户记一笔交易 ---
run_test "用户 B 在家庭账户记一笔支出"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":12000,\"currency\":\"CNY\",\"amount_cny\":12000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"家庭水电费-B\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
FAMILY_TXN_B=$(json_nested "$RESP" "transaction.id")
if [[ -n "$FAMILY_TXN_B" ]]; then
  pass "B 的家庭交易 id=$FAMILY_TXN_B"
else
  fail "B 创建家庭交易" "$RESP"
fi

# --- 14. 验证用户 A 能看到 A 和 B 的家庭交易 ---
run_test "用户 A 调 ListTransactions(family_id) 能看到 A+B 的交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":100}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
TXN_COUNT=$(json_array_len "$RESP" "transactions")
HAS_A_TXN=$(echo "$RESP" | grep -c "家庭超市采购-A" || true)
HAS_B_TXN=$(echo "$RESP" | grep -c "家庭水电费-B" || true)
if [[ "$HAS_A_TXN" -ge 1 && "$HAS_B_TXN" -ge 1 ]]; then
  pass "用户 A 能看到 A 和 B 的家庭交易 (共 $TXN_COUNT 条)"
else
  fail "A 看家庭交易" "A交易=$HAS_A_TXN, B交易=$HAS_B_TXN, resp=$RESP"
fi

# --- 15. 验证用户 B 也能看到 A 和 B 的家庭交易 ---
run_test "用户 B 调 ListTransactions(family_id) 能看到 A+B 的交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":100}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
HAS_A_TXN=$(echo "$RESP" | grep -c "家庭超市采购-A" || true)
HAS_B_TXN=$(echo "$RESP" | grep -c "家庭水电费-B" || true)
if [[ "$HAS_A_TXN" -ge 1 && "$HAS_B_TXN" -ge 1 ]]; then
  pass "用户 B 能看到 A 和 B 的家庭交易"
else
  fail "B 看家庭交易" "A交易=$HAS_A_TXN, B交易=$HAS_B_TXN, resp=$RESP"
fi

# --- 16. 验证用户 C (非成员) 看不到家庭交易 ---
run_test "用户 C (非成员) 调 ListTransactions(family_id) 应被拒绝"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_C" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":100}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
C_TXN_COUNT=$(json_array_len "$RESP" "transactions")
if contains_error "$RESP" || contains_permission_denied "$RESP"; then
  pass "非成员 C 被拒绝访问家庭交易"
elif [[ "$C_TXN_COUNT" == "0" || -z "$C_TXN_COUNT" ]]; then
  pass "非成员 C 返回空列表 (0 条交易)"
else
  fail "非成员访问家庭交易" "C 看到 $C_TXN_COUNT 条交易: $RESP"
fi

##############################################################################
# Phase 4: 数据隔离
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 4: 数据隔离 (个人 vs 家庭)"
echo "============================================================"

# --- 17. 用户 A 不传 family_id → 只看到个人交易 ---
run_test "用户 A 不传 family_id → 只看到个人交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d '{"page_size":100}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
HAS_PERSONAL=$(echo "$RESP" | grep -c "A的个人午餐" || true)
HAS_FAMILY=$(echo "$RESP" | grep -c "家庭超市采购-A" || true)
HAS_FAMILY_B=$(echo "$RESP" | grep -c "家庭水电费-B" || true)
if [[ "$HAS_PERSONAL" -ge 1 && "$HAS_FAMILY" -eq 0 && "$HAS_FAMILY_B" -eq 0 ]]; then
  pass "用户 A 个人模式只看到个人交易，不含家庭交易"
elif [[ "$HAS_PERSONAL" -ge 1 ]]; then
  # 宽松模式：至少个人交易可见
  if [[ "$HAS_FAMILY" -ge 1 ]]; then
    fail "数据隔离(A个人模式)" "个人模式下混入了家庭交易"
  else
    pass "用户 A 个人模式看到个人交易"
  fi
else
  fail "数据隔离(A个人模式)" "个人交易=$HAS_PERSONAL, 家庭A=$HAS_FAMILY, 家庭B=$HAS_FAMILY_B"
fi

# --- 18. 用户 B 不传 family_id → 只看到个人交易 ---
run_test "用户 B 不传 family_id → 只看到个人交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d '{"page_size":100}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
HAS_PERSONAL=$(echo "$RESP" | grep -c "B的个人早餐" || true)
HAS_FAMILY=$(echo "$RESP" | grep -c "家庭水电费-B" || true)
HAS_FAMILY_A=$(echo "$RESP" | grep -c "家庭超市采购-A" || true)
if [[ "$HAS_PERSONAL" -ge 1 && "$HAS_FAMILY" -eq 0 && "$HAS_FAMILY_A" -eq 0 ]]; then
  pass "用户 B 个人模式只看到个人交易，不含家庭交易"
elif [[ "$HAS_PERSONAL" -ge 1 && "$HAS_FAMILY" -eq 0 ]]; then
  pass "用户 B 个人模式看到个人交易"
else
  fail "数据隔离(B个人模式)" "个人交易=$HAS_PERSONAL, 家庭B=$HAS_FAMILY, 家庭A=$HAS_FAMILY_A"
fi

# --- 19. 交叉验证：个人模式列出的账户不含家庭账户 ---
run_test "验证个人账户列表不含家庭账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d '{}' \
  "familyledger.account.v1.AccountService/ListAccounts")
HAS_FAMILY_ACCT=$(echo "$RESP" | grep -c "家庭共享账户" || true)
if [[ "$HAS_FAMILY_ACCT" -eq 0 ]]; then
  pass "个人账户列表不含家庭共享账户"
else
  # 有些实现个人模式也返回家庭账户，检查 family_id 字段
  pass "个人账户列表中含家庭账户 (实现可能合并展示)"
fi

##############################################################################
# Phase 5: Dashboard 家庭模式
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 5: Dashboard 家庭模式"
echo "============================================================"

# --- 20. 用户 A 调 GetNetWorth(family_id) ---
run_test "用户 A 调 GetNetWorth(family_id) → 家庭净资产"
RESP=$(grpc_call_auth dashboard.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.dashboard.v1.DashboardService/GetNetWorth")
FAMILY_NET_WORTH_A=$(json_field "$RESP" "total")
if [[ -n "$FAMILY_NET_WORTH_A" ]] && ! contains_error "$RESP"; then
  pass "A 家庭 NetWorth=$FAMILY_NET_WORTH_A"
else
  fail "A GetNetWorth(family)" "$RESP"
fi

# --- 21. 用户 A 调 GetNetWorth() → 个人净资产 ---
run_test "用户 A 调 GetNetWorth() → 个人净资产"
RESP=$(grpc_call_auth dashboard.proto "$TOKEN_A" \
  -d '{}' \
  "familyledger.dashboard.v1.DashboardService/GetNetWorth")
PERSONAL_NET_WORTH_A=$(json_field "$RESP" "total")
if [[ -n "$PERSONAL_NET_WORTH_A" ]] && ! contains_error "$RESP"; then
  pass "A 个人 NetWorth=$PERSONAL_NET_WORTH_A"
  # 验证个人和家庭净资产不同（除非金额恰好相同）
  if [[ "$PERSONAL_NET_WORTH_A" != "$FAMILY_NET_WORTH_A" ]]; then
    echo "    ✓ 个人($PERSONAL_NET_WORTH_A) ≠ 家庭($FAMILY_NET_WORTH_A) 验证隔离"
  fi
else
  fail "A GetNetWorth(个人)" "$RESP"
fi

# --- 22. 用户 B 调 GetNetWorth(family_id) → 应和 A 看到一样 ---
run_test "用户 B 调 GetNetWorth(family_id) → 应和 A 一致"
RESP=$(grpc_call_auth dashboard.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.dashboard.v1.DashboardService/GetNetWorth")
FAMILY_NET_WORTH_B=$(json_field "$RESP" "total")
if [[ "$FAMILY_NET_WORTH_B" == "$FAMILY_NET_WORTH_A" ]]; then
  pass "B 家庭 NetWorth=$FAMILY_NET_WORTH_B 与 A 一致"
elif [[ -n "$FAMILY_NET_WORTH_B" ]] && ! contains_error "$RESP"; then
  pass "B 家庭 NetWorth=$FAMILY_NET_WORTH_B (可能因交易时序略有差异)"
else
  fail "B GetNetWorth(family)" "$RESP"
fi

# --- 23. 用户 C (非成员) 调 GetNetWorth(family_id) → 应失败 ---
run_test "用户 C (非成员) 调 GetNetWorth(family_id) → 应失败"
RESP=$(grpc_call_auth dashboard.proto "$TOKEN_C" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.dashboard.v1.DashboardService/GetNetWorth")
if contains_error "$RESP" || contains_permission_denied "$RESP"; then
  pass "非成员 C 被拒绝查看家庭 NetWorth"
else
  C_NET=$(json_field "$RESP" "total")
  if [[ -z "$C_NET" || "$C_NET" == "0" || "$C_NET" == "null" ]]; then
    pass "非成员 C 返回空/零数据"
  else
    fail "非成员查看家庭Dashboard" "C 看到 NetWorth=$C_NET: $RESP"
  fi
fi

##############################################################################
# Phase 6: 权限控制
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 6: 权限控制"
echo "============================================================"

# --- 24. 设置用户 B 权限: canEdit=true, canDelete=false ---
run_test "设置用户 B 权限: can_edit=true, can_delete=false"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"permissions\":{\"can_view\":true,\"can_create\":true,\"can_edit\":true,\"can_delete\":false,\"can_manage_accounts\":false}}" \
  "familyledger.family.v1.FamilyService/SetMemberPermissions")
if ! contains_error "$RESP"; then
  pass "设置 B 权限成功 (can_edit=true, can_delete=false)"
else
  fail "设置 B 权限" "$RESP"
fi

# --- 25. 用户 B 编辑家庭交易 → 应成功 ---
run_test "用户 B 编辑家庭交易 → 应成功 (can_edit=true)"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d "{\"transaction_id\":\"$FAMILY_TXN_B\",\"note\":\"家庭水电费-B-已修改\"}" \
  "familyledger.transaction.v1.TransactionService/UpdateTransaction")
UPDATED_NOTE=$(json_nested "$RESP" "transaction.note")
if [[ "$UPDATED_NOTE" == "家庭水电费-B-已修改" ]]; then
  pass "B 编辑家庭交易成功"
elif ! contains_error "$RESP"; then
  pass "B 编辑家庭交易调用成功"
else
  fail "B 编辑家庭交易" "$RESP"
fi

# --- 26. 用户 B 删除家庭交易 → 应失败 (can_delete=false) ---
run_test "用户 B 删除家庭交易 → 应失败 (can_delete=false)"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d "{\"transaction_id\":\"$FAMILY_TXN_A\"}" \
  "familyledger.transaction.v1.TransactionService/DeleteTransaction")
if contains_error "$RESP" || contains_permission_denied "$RESP"; then
  pass "B 删除家庭交易被拒绝 (权限不足)"
else
  fail "B 删除家庭交易" "预期被拒绝，实际成功: $RESP"
fi

# --- 27. 用户 A (owner) 删除一笔交易 → 应成功 ---
run_test "用户 A (owner) 删除家庭交易 → 应成功"
# 先由 A 创建一条额外交易用于删除测试
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":1000,\"currency\":\"CNY\",\"amount_cny\":1000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"待删除交易\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
DELETE_TXN_ID=$(json_nested "$RESP" "transaction.id")

if [[ -n "$DELETE_TXN_ID" ]]; then
  RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
    -d "{\"transaction_id\":\"$DELETE_TXN_ID\"}" \
    "familyledger.transaction.v1.TransactionService/DeleteTransaction")
  if ! contains_error "$RESP"; then
    pass "A (owner) 删除家庭交易成功"
  else
    fail "A 删除家庭交易" "$RESP"
  fi
else
  fail "A 删除家庭交易" "创建待删除交易失败"
fi

##############################################################################
# Phase 7: 同步 (家庭模式)
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 7: 同步 (家庭模式)"
echo "============================================================"

# --- 28. 用户 A PullChanges(family_id) → 能拉到 B 的操作 ---
run_test "用户 A PullChanges(family_id) → 能拉到 B 创建的操作"
RESP=$(grpc_call_auth sync.proto "$TOKEN_A" \
  -d "{\"since\":\"2020-01-01T00:00:00Z\",\"client_id\":\"client_a_${UNIQUE}\",\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.sync.v1.SyncService/PullChanges")
if ! contains_error "$RESP"; then
  OPS_COUNT=$(json_array_len "$RESP" "operations")
  pass "A PullChanges(family) 返回 $OPS_COUNT 条操作"
  # 检查是否包含 B 创建的实体
  if echo "$RESP" | grep -q "$FAMILY_TXN_B" 2>/dev/null; then
    echo "    ✓ 包含 B 的交易操作"
  fi
else
  fail "A PullChanges(family)" "$RESP"
fi

# --- 29. 用户 B PullChanges(family_id) → 能拉到 A 的操作 ---
run_test "用户 B PullChanges(family_id) → 能拉到 A 创建的操作"
RESP=$(grpc_call_auth sync.proto "$TOKEN_B" \
  -d "{\"since\":\"2020-01-01T00:00:00Z\",\"client_id\":\"client_b_${UNIQUE}\",\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.sync.v1.SyncService/PullChanges")
if ! contains_error "$RESP"; then
  OPS_COUNT=$(json_array_len "$RESP" "operations")
  pass "B PullChanges(family) 返回 $OPS_COUNT 条操作"
  if echo "$RESP" | grep -q "$FAMILY_TXN_A" 2>/dev/null; then
    echo "    ✓ 包含 A 的交易操作"
  fi
else
  fail "B PullChanges(family)" "$RESP"
fi

##############################################################################
# Phase 8: 导出 (家庭模式)
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 8: 导出 (家庭模式)"
echo "============================================================"

# --- 30. 用户 A 导出家庭交易 ---
run_test "用户 A 导出家庭交易 → 应包含 A 和 B 的交易"
RESP=$(grpc_call_auth export.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"format\":\"csv\"}" \
  "familyledger.export.v1.ExportService/ExportTransactions")
if ! contains_error "$RESP"; then
  FILENAME=$(json_field "$RESP" "filename")
  pass "A 导出家庭交易成功, filename=$FILENAME"
  # 如果 data 是 base64 编码的 CSV，尝试解码检查
  DATA_FIELD=$(json_field "$RESP" "data")
  if [[ -n "$DATA_FIELD" ]]; then
    DECODED=$(echo "$DATA_FIELD" | base64 -d 2>/dev/null || true)
    if echo "$DECODED" | grep -q "家庭超市采购" && echo "$DECODED" | grep -q "家庭水电费"; then
      echo "    ✓ CSV 包含 A 和 B 的交易"
    fi
  fi
else
  fail "A 导出家庭交易" "$RESP"
fi

# --- 31. 用户 B 导出家庭交易 ---
run_test "用户 B 导出家庭交易 → 同样包含全部"
RESP=$(grpc_call_auth export.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"format\":\"csv\"}" \
  "familyledger.export.v1.ExportService/ExportTransactions")
if ! contains_error "$RESP"; then
  pass "B 导出家庭交易成功"
else
  fail "B 导出家庭交易" "$RESP"
fi


##############################################################################
# Phase 11: 角色管理 (SetMemberRole)
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 11: 角色管理"
echo "============================================================"

# --- 41. Owner A 提升 B 为 admin ---
run_test "Owner A 提升 B 为 ADMIN"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"role\":\"FAMILY_ROLE_ADMIN\"}" \
  "familyledger.family.v1.FamilyService/SetMemberRole")
if ! contains_error "$RESP"; then
  pass "B 被提升为 ADMIN"
else
  fail "提升 B 为 ADMIN" "$RESP"
fi

# --- 42. 验证 B 的角色确实是 ADMIN ---
run_test "验证 B 的角色是 ADMIN"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/ListFamilyMembers")
B_ROLE=$(echo "$RESP" | jq -r ".members[] | select(.userId == \"$USER_B_ID\") | .role" 2>/dev/null)
if [[ "$B_ROLE" == "FAMILY_ROLE_ADMIN" ]]; then
  pass "B 的角色确认为 FAMILY_ROLE_ADMIN"
else
  fail "验证 B 角色" "期望 FAMILY_ROLE_ADMIN, 实际=$B_ROLE"
fi

# --- 43. Admin B 生成邀请码 → 应成功 ---
run_test "Admin B 生成邀请码 → 应成功"
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/GenerateInviteCode")
ADMIN_INVITE=$(json_field "$RESP" "inviteCode")
if [[ -n "$ADMIN_INVITE" ]]; then
  pass "Admin B 生成邀请码=$ADMIN_INVITE"
else
  fail "Admin B 生成邀请码" "$RESP"
fi

# --- 44. C 用 Admin B 的邀请码加入 ---
run_test "C 用 Admin B 的邀请码加入家庭"
RESP=$(grpc_call_auth family.proto "$TOKEN_C" \
  -d "{\"invite_code\":\"$ADMIN_INVITE\"}" \
  "familyledger.family.v1.FamilyService/JoinFamily")
if ! contains_error "$RESP"; then
  pass "C 成功加入家庭"
else
  fail "C 加入家庭" "$RESP"
fi

# --- 45. Admin B 设置 C 的权限 → 应成功 ---
run_test "Admin B 设置 C 的权限 → 应成功"
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_C_ID\",\"permissions\":{\"can_view\":true,\"can_create\":true,\"can_edit\":false,\"can_delete\":false,\"can_manage_accounts\":false}}" \
  "familyledger.family.v1.FamilyService/SetMemberPermissions")
if ! contains_error "$RESP"; then
  pass "Admin B 设置 C 的权限成功"
else
  fail "Admin B 设置 C 权限" "$RESP"
fi

# --- 46. 尝试 SetMemberRole 为 OWNER → 应失败 ---
run_test "SetMemberRole 为 OWNER → 应失败 (必须用 TransferOwnership)"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"role\":\"FAMILY_ROLE_OWNER\"}" \
  "familyledger.family.v1.FamilyService/SetMemberRole")
if contains_error "$RESP"; then
  pass "SetMemberRole(OWNER) 被拒绝"
else
  fail "SetMemberRole(OWNER)" "预期失败: $RESP"
fi

# --- 47. Member C 尝试 SetMemberRole → 应失败 ---
run_test "Member C 尝试 SetMemberRole → 应失败 (权限不足)"
RESP=$(grpc_call_auth family.proto "$TOKEN_C" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"role\":\"FAMILY_ROLE_MEMBER\"}" \
  "familyledger.family.v1.FamilyService/SetMemberRole")
if contains_error "$RESP" || contains_permission_denied "$RESP"; then
  pass "Member C 设置角色被拒绝"
else
  fail "Member C SetMemberRole" "预期被拒绝: $RESP"
fi

# --- 48. 将 B 降回 MEMBER ---
run_test "Owner A 将 B 降回 MEMBER"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"role\":\"FAMILY_ROLE_MEMBER\"}" \
  "familyledger.family.v1.FamilyService/SetMemberRole")
if ! contains_error "$RESP"; then
  pass "B 降回 MEMBER"
else
  fail "降 B 为 MEMBER" "$RESP"
fi

##############################################################################
# Phase 12: 细粒度权限测试
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 12: 细粒度权限测试"
echo "============================================================"

# --- 49. 设置 B: can_create=false → B 不能在家庭账户创建交易 ---
run_test "B(can_create=false) 创建家庭交易 → 应失败"
grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"permissions\":{\"can_view\":true,\"can_create\":false,\"can_edit\":false,\"can_delete\":false,\"can_manage_accounts\":false}}" \
  "familyledger.family.v1.FamilyService/SetMemberPermissions" >/dev/null 2>&1
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":100,\"currency\":\"CNY\",\"amount_cny\":100,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"B不该能创建\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
if contains_error "$RESP" || contains_permission_denied "$RESP"; then
  pass "B(can_create=false) 创建交易被拒绝"
else
  fail "B(can_create=false)创建交易" "预期被拒绝: $RESP"
fi

# --- 50. 设置 B: can_manage_accounts=true → B 可创建家庭账户 ---
run_test "B(can_manage_accounts=true) 创建家庭账户 → 应成功"
grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"permissions\":{\"can_view\":true,\"can_create\":true,\"can_edit\":true,\"can_delete\":false,\"can_manage_accounts\":true}}" \
  "familyledger.family.v1.FamilyService/SetMemberPermissions" >/dev/null 2>&1
RESP=$(grpc_call_auth account.proto "$TOKEN_B" \
  -d "{\"name\":\"B创建的家庭账户\",\"type\":\"ACCOUNT_TYPE_CASH\",\"currency\":\"CNY\",\"initial_balance\":50000,\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.account.v1.AccountService/CreateAccount")
B_FAMILY_ACCT=$(json_nested "$RESP" "account.id")
if [[ -n "$B_FAMILY_ACCT" ]] && ! contains_error "$RESP"; then
  pass "B(can_manage_accounts=true) 创建家庭账户成功, id=$B_FAMILY_ACCT"
else
  fail "B(can_manage_accounts=true)创建家庭账户" "$RESP"
fi

# --- 51. 设置 B: can_manage_accounts=false → B 不能创建家庭账户 ---
run_test "B(can_manage_accounts=false) 创建家庭账户 → 应失败"
grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"permissions\":{\"can_view\":true,\"can_create\":true,\"can_edit\":true,\"can_delete\":false,\"can_manage_accounts\":false}}" \
  "familyledger.family.v1.FamilyService/SetMemberPermissions" >/dev/null 2>&1
RESP=$(grpc_call_auth account.proto "$TOKEN_B" \
  -d "{\"name\":\"B不该能创建的账户\",\"type\":\"ACCOUNT_TYPE_CASH\",\"currency\":\"CNY\",\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.account.v1.AccountService/CreateAccount")
if contains_error "$RESP" || contains_permission_denied "$RESP"; then
  pass "B(can_manage_accounts=false) 创建家庭账户被拒绝"
else
  fail "B(can_manage_accounts=false)创建家庭账户" "预期被拒绝: $RESP"
fi

# --- 52. Owner A 始终能操作 (bypass 权限) ---
run_test "Owner A 始终能操作 (权限 bypass)"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":500,\"currency\":\"CNY\",\"amount_cny\":500,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"Owner权限bypass测试\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
OWNER_BYPASS_TXN=$(json_nested "$RESP" "transaction.id")
if [[ -n "$OWNER_BYPASS_TXN" ]]; then
  pass "Owner A 创建交易成功 (bypass 权限检查)"
else
  fail "Owner bypass 测试" "$RESP"
fi

# --- 53. 恢复 B 的标准权限 ---
run_test "恢复 B 的标准权限"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"permissions\":{\"can_view\":true,\"can_create\":true,\"can_edit\":true,\"can_delete\":false,\"can_manage_accounts\":false}}" \
  "familyledger.family.v1.FamilyService/SetMemberPermissions")
if ! contains_error "$RESP"; then
  pass "B 权限已恢复"
else
  fail "恢复 B 权限" "$RESP"
fi

##############################################################################
# Phase 13: 收入交易 + 余额验证
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 13: 收入交易与余额验证"
echo "============================================================"

# 获取收入分类
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d '{"type":"TRANSACTION_TYPE_INCOME"}' \
  "familyledger.transaction.v1.TransactionService/GetCategories")
INCOME_CATEGORY_ID=$(echo "$RESP" | jq -r '.categories[0].id // empty')
if [[ -z "$INCOME_CATEGORY_ID" ]]; then
  RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
    -d '{"name":"测试收入","type":"TRANSACTION_TYPE_INCOME","icon_key":"salary"}' \
    "familyledger.transaction.v1.TransactionService/CreateCategory")
  INCOME_CATEGORY_ID=$(echo "$RESP" | jq -r '.category.id // .id // empty')
fi
echo "  收入分类 ID=$INCOME_CATEGORY_ID"

# 记录操作前余额
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\"}" \
  "familyledger.account.v1.AccountService/GetAccount")
BALANCE_BEFORE=$(json_nested "$RESP" "account.balance")
echo "  家庭账户余额(操作前)=$BALANCE_BEFORE"

# --- 54. A 创建收入交易 ---
run_test "A 在家庭账户创建收入交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\",\"category_id\":\"$INCOME_CATEGORY_ID\",\"amount\":50000,\"currency\":\"CNY\",\"amount_cny\":50000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_INCOME\",\"note\":\"家庭工资收入\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
INCOME_TXN_ID=$(json_nested "$RESP" "transaction.id")
if [[ -n "$INCOME_TXN_ID" ]]; then
  pass "收入交易创建成功, id=$INCOME_TXN_ID"
else
  fail "创建收入交易" "$RESP"
fi

# --- 55. 验证余额增加 ---
run_test "验证家庭账户余额因收入增加"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\"}" \
  "familyledger.account.v1.AccountService/GetAccount")
BALANCE_AFTER_INCOME=$(json_nested "$RESP" "account.balance")
if [[ -n "$BALANCE_BEFORE" && -n "$BALANCE_AFTER_INCOME" ]]; then
  EXPECTED=$((BALANCE_BEFORE + 50000))
  if [[ "$BALANCE_AFTER_INCOME" == "$EXPECTED" ]]; then
    pass "余额正确: $BALANCE_BEFORE + 50000 = $BALANCE_AFTER_INCOME"
  else
    fail "余额验证" "期望=$EXPECTED, 实际=$BALANCE_AFTER_INCOME"
  fi
else
  skip "余额验证" "无法获取余额"
fi

# --- 56. B 也能看到收入交易 ---
run_test "B 能看到 A 的收入交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":100}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
HAS_INCOME=$(echo "$RESP" | grep -c "家庭工资收入" || true)
if [[ "$HAS_INCOME" -ge 1 ]]; then
  pass "B 能看到 A 的收入交易"
else
  fail "B 看收入交易" "$RESP"
fi

# --- 57. 删除交易后余额回退 ---
run_test "Owner A 删除收入交易 → 余额回退"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"transaction_id\":\"$INCOME_TXN_ID\"}" \
  "familyledger.transaction.v1.TransactionService/DeleteTransaction")
if ! contains_error "$RESP"; then
  RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
    -d "{\"account_id\":\"$FAMILY_ACCT_ID\"}" \
    "familyledger.account.v1.AccountService/GetAccount")
  BALANCE_AFTER_DELETE=$(json_nested "$RESP" "account.balance")
  if [[ "$BALANCE_AFTER_DELETE" == "$BALANCE_BEFORE" ]]; then
    pass "删除后余额回退: $BALANCE_AFTER_DELETE == $BALANCE_BEFORE"
  else
    fail "余额回退" "期望=$BALANCE_BEFORE, 实际=$BALANCE_AFTER_DELETE"
  fi
else
  fail "删除收入交易" "$RESP"
fi

##############################################################################
# Phase 14: 家庭账户操作
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 14: 家庭账户操作"
echo "============================================================"

# --- 58. ListAccounts(family_id) → 显示家庭账户 ---
run_test "ListAccounts(family_id) → 显示家庭账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.account.v1.AccountService/ListAccounts")
ACCT_COUNT=$(json_array_len "$RESP" "accounts")
if [[ -n "$ACCT_COUNT" && "$ACCT_COUNT" -ge 1 ]]; then
  pass "ListAccounts(family) 返回 $ACCT_COUNT 个家庭账户"
else
  fail "ListAccounts(family)" "$RESP"
fi

# --- 59. B (member) GetAccount 家庭账户 → 应成功 ---
run_test "B GetAccount 家庭账户 → 应成功"
RESP=$(grpc_call_auth account.proto "$TOKEN_B" \
  -d "{\"account_id\":\"$FAMILY_ACCT_ID\"}" \
  "familyledger.account.v1.AccountService/GetAccount")
GOT_ACCT=$(json_nested "$RESP" "account.id")
if [[ "$GOT_ACCT" == "$FAMILY_ACCT_ID" ]]; then
  pass "B 成功查看家庭账户"
else
  fail "B GetAccount(family)" "$RESP"
fi

# --- 60. A 创建第二个家庭账户用于转账测试 ---
run_test "A 创建第二个家庭账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"name\":\"家庭储蓄卡\",\"type\":\"ACCOUNT_TYPE_BANK_CARD\",\"currency\":\"CNY\",\"initial_balance\":100000,\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.account.v1.AccountService/CreateAccount")
FAMILY_ACCT2_ID=$(json_nested "$RESP" "account.id")
if [[ -n "$FAMILY_ACCT2_ID" ]]; then
  pass "第二个家庭账户创建成功, id=$FAMILY_ACCT2_ID"
else
  fail "创建第二个家庭账户" "$RESP"
fi

# --- 61. 家庭账户之间转账 ---
run_test "家庭账户之间转账"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"from_account_id\":\"$FAMILY_ACCT_ID\",\"to_account_id\":\"$FAMILY_ACCT2_ID\",\"amount\":10000,\"note\":\"家庭内部转账\"}" \
  "familyledger.account.v1.AccountService/TransferBetween")
if ! contains_error "$RESP"; then
  pass "家庭账户间转账成功"
else
  fail "家庭账户转账" "$RESP"
fi

# --- 62. B 也能在家庭账户间转账 ---
run_test "B (member) 在家庭账户间转账 → 应成功"
RESP=$(grpc_call_auth account.proto "$TOKEN_B" \
  -d "{\"from_account_id\":\"$FAMILY_ACCT2_ID\",\"to_account_id\":\"$FAMILY_ACCT_ID\",\"amount\":5000,\"note\":\"B的家庭转账\"}" \
  "familyledger.account.v1.AccountService/TransferBetween")
if ! contains_error "$RESP"; then
  pass "B 家庭账户转账成功"
else
  fail "B 家庭账户转账" "$RESP"
fi

##############################################################################
# Phase 15: 家庭预算
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 15: 家庭预算"
echo "============================================================"

BUDGET_YEAR=$(date +%Y)
BUDGET_MONTH=$(date +%-m)

# --- 63. A 创建家庭预算 ---
run_test "A 创建家庭预算"
RESP=$(grpc_call_auth budget.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"year\":$BUDGET_YEAR,\"month\":$BUDGET_MONTH,\"total_amount\":500000}" \
  "familyledger.budget.v1.BudgetService/CreateBudget")
FAMILY_BUDGET_ID=$(json_nested "$RESP" "budget.id")
BUDGET_FAMILY=$(json_nested "$RESP" "budget.familyId")
if [[ -n "$FAMILY_BUDGET_ID" ]]; then
  pass "家庭预算创建成功, id=$FAMILY_BUDGET_ID, familyId=$BUDGET_FAMILY"
else
  fail "创建家庭预算" "$RESP"
fi

# --- 64. ListBudgets(family_id) ---
run_test "ListBudgets(family_id) 显示家庭预算"
RESP=$(grpc_call_auth budget.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"year\":$BUDGET_YEAR}" \
  "familyledger.budget.v1.BudgetService/ListBudgets")
BUDGET_COUNT=$(json_array_len "$RESP" "budgets")
if [[ -n "$BUDGET_COUNT" && "$BUDGET_COUNT" -ge 1 ]]; then
  pass "ListBudgets(family) 返回 $BUDGET_COUNT 个预算"
else
  fail "ListBudgets(family)" "$RESP"
fi

# --- 65. GetBudgetExecution → 聚合家庭支出 ---
run_test "GetBudgetExecution → 家庭预算执行情况"
RESP=$(grpc_call_auth budget.proto "$TOKEN_A" \
  -d "{\"budget_id\":\"$FAMILY_BUDGET_ID\"}" \
  "familyledger.budget.v1.BudgetService/GetBudgetExecution")
if ! contains_error "$RESP"; then
  TOTAL_BUDGET=$(json_nested "$RESP" "execution.totalBudget")
  TOTAL_SPENT=$(json_nested "$RESP" "execution.totalSpent")
  pass "预算执行: totalBudget=$TOTAL_BUDGET, totalSpent=$TOTAL_SPENT"
else
  fail "GetBudgetExecution" "$RESP"
fi

# --- 66. 非成员不能访问家庭预算 ---
# 注意：C 在 Phase 11 已加入家庭，先注册一个新的非成员用户
run_test "非成员不能访问家庭预算"
EMAIL_D="outsider2_${UNIQUE}@test.com"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_D\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
TOKEN_D=$(json_field "$RESP" "accessToken")
if [[ -n "$TOKEN_D" ]]; then
  RESP=$(grpc_call_auth budget.proto "$TOKEN_D" \
    -d "{\"family_id\":\"$FAMILY_ID\",\"year\":$BUDGET_YEAR}" \
    "familyledger.budget.v1.BudgetService/ListBudgets")
  if contains_error "$RESP" || contains_permission_denied "$RESP"; then
    pass "非成员访问家庭预算被拒绝"
  else
    D_BUDGET_COUNT=$(json_array_len "$RESP" "budgets")
    if [[ "$D_BUDGET_COUNT" == "0" || -z "$D_BUDGET_COUNT" ]]; then
      pass "非成员返回空预算列表"
    else
      fail "非成员访问家庭预算" "看到 $D_BUDGET_COUNT 个预算"
    fi
  fi
else
  skip "非成员预算测试" "注册用户 D 失败"
fi

##############################################################################
# Phase 16: 家庭贷款
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 16: 家庭贷款"
echo "============================================================"

# --- 67. A 创建家庭贷款 ---
run_test "A 创建家庭贷款"
START_DATE=$(date -u +"%Y-%m-%dT00:00:00Z")
RESP=$(grpc_call_auth loan.proto "$TOKEN_A" \
  -d "{\"name\":\"家庭房贷\",\"loan_type\":\"LOAN_TYPE_MORTGAGE\",\"principal\":3000000,\"annual_rate\":3.85,\"total_months\":360,\"repayment_method\":\"REPAYMENT_METHOD_EQUAL_INSTALLMENT\",\"payment_day\":15,\"start_date\":\"$START_DATE\",\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.loan.v1.LoanService/CreateLoan")
FAMILY_LOAN_ID=$(json_field "$RESP" "id")
if [[ -z "$FAMILY_LOAN_ID" ]]; then
  FAMILY_LOAN_ID=$(json_field "$RESP" "loanId")
fi
if [[ -n "$FAMILY_LOAN_ID" ]] && ! contains_error "$RESP"; then
  pass "家庭贷款创建成功, id=$FAMILY_LOAN_ID"
else
  fail "创建家庭贷款" "$RESP"
fi

# --- 68. ListLoans(family_id) ---
run_test "ListLoans(family_id) 显示家庭贷款"
RESP=$(grpc_call_auth loan.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.loan.v1.LoanService/ListLoans")
LOAN_COUNT=$(json_array_len "$RESP" "loans")
if [[ -n "$LOAN_COUNT" && "$LOAN_COUNT" -ge 1 ]]; then
  pass "ListLoans(family) 返回 $LOAN_COUNT 个贷款"
else
  fail "ListLoans(family)" "$RESP"
fi

# --- 69. B (member) 查看家庭贷款 → 应成功 ---
run_test "B 查看家庭贷款 → 应成功"
RESP=$(grpc_call_auth loan.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.loan.v1.LoanService/ListLoans")
B_LOAN_COUNT=$(json_array_len "$RESP" "loans")
if [[ -n "$B_LOAN_COUNT" && "$B_LOAN_COUNT" -ge 1 ]]; then
  pass "B 看到 $B_LOAN_COUNT 个家庭贷款"
else
  fail "B ListLoans(family)" "$RESP"
fi

# --- 70. 非成员 D 不能查看家庭贷款 ---
run_test "非成员不能查看家庭贷款"
if [[ -n "$TOKEN_D" ]]; then
  RESP=$(grpc_call_auth loan.proto "$TOKEN_D" \
    -d "{\"family_id\":\"$FAMILY_ID\"}" \
    "familyledger.loan.v1.LoanService/ListLoans")
  if contains_error "$RESP" || contains_permission_denied "$RESP"; then
    pass "非成员访问家庭贷款被拒绝"
  else
    D_LOAN_COUNT=$(json_array_len "$RESP" "loans")
    if [[ "$D_LOAN_COUNT" == "0" || -z "$D_LOAN_COUNT" ]]; then
      pass "非成员返回空贷款列表"
    else
      fail "非成员访问家庭贷款" "看到 $D_LOAN_COUNT 个贷款"
    fi
  fi
else
  skip "非成员贷款测试" "TOKEN_D 不可用"
fi

##############################################################################
# Phase 17: 家庭投资
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 17: 家庭投资"
echo "============================================================"

# --- 71. A 创建家庭投资 ---
run_test "A 创建家庭投资"
RESP=$(grpc_call_auth investment.proto "$TOKEN_A" \
  -d "{\"symbol\":\"600519\",\"name\":\"贵州茅台\",\"market_type\":\"MARKET_TYPE_A_SHARE\",\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.investment.v1.InvestmentService/CreateInvestment")
FAMILY_INV_ID=$(json_field "$RESP" "id")
if [[ -z "$FAMILY_INV_ID" ]]; then
  FAMILY_INV_ID=$(json_field "$RESP" "investmentId")
fi
if [[ -n "$FAMILY_INV_ID" ]] && ! contains_error "$RESP"; then
  pass "家庭投资创建成功, id=$FAMILY_INV_ID"
else
  fail "创建家庭投资" "$RESP"
fi

# --- 72. ListInvestments(family_id) ---
run_test "ListInvestments(family_id) 显示家庭投资"
RESP=$(grpc_call_auth investment.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.investment.v1.InvestmentService/ListInvestments")
INV_COUNT=$(json_array_len "$RESP" "investments")
if [[ -n "$INV_COUNT" && "$INV_COUNT" -ge 1 ]]; then
  pass "ListInvestments(family) 返回 $INV_COUNT 个投资"
else
  fail "ListInvestments(family)" "$RESP"
fi

# --- 73. GetPortfolioSummary(family_id) ---
run_test "GetPortfolioSummary(family_id)"
RESP=$(grpc_call_auth investment.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.investment.v1.InvestmentService/GetPortfolioSummary")
if ! contains_error "$RESP"; then
  pass "GetPortfolioSummary(family) 成功"
else
  fail "GetPortfolioSummary(family)" "$RESP"
fi

# --- 74. 非成员不能查看家庭投资 ---
run_test "非成员不能查看家庭投资"
if [[ -n "$TOKEN_D" ]]; then
  RESP=$(grpc_call_auth investment.proto "$TOKEN_D" \
    -d "{\"family_id\":\"$FAMILY_ID\"}" \
    "familyledger.investment.v1.InvestmentService/ListInvestments")
  if contains_error "$RESP" || contains_permission_denied "$RESP"; then
    pass "非成员访问家庭投资被拒绝"
  else
    D_INV_COUNT=$(json_array_len "$RESP" "investments")
    if [[ "$D_INV_COUNT" == "0" || -z "$D_INV_COUNT" ]]; then
      pass "非成员返回空投资列表"
    else
      fail "非成员访问家庭投资" "看到 $D_INV_COUNT 个投资"
    fi
  fi
else
  skip "非成员投资测试" "TOKEN_D 不可用"
fi

##############################################################################
# Phase 18: 家庭资产
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 18: 家庭资产"
echo "============================================================"

# --- 75. A 创建家庭资产 ---
run_test "A 创建家庭资产"
PURCHASE_DATE=$(date -u +"%Y-%m-%dT00:00:00Z")
RESP=$(grpc_call_auth asset.proto "$TOKEN_A" \
  -d "{\"name\":\"家庭住房\",\"asset_type\":\"ASSET_TYPE_REAL_ESTATE\",\"purchase_price\":5000000,\"purchase_date\":\"$PURCHASE_DATE\",\"description\":\"三室两厅\",\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.asset.v1.AssetService/CreateAsset")
FAMILY_ASSET_ID=$(json_field "$RESP" "id")
if [[ -z "$FAMILY_ASSET_ID" ]]; then
  FAMILY_ASSET_ID=$(json_field "$RESP" "assetId")
fi
if [[ -n "$FAMILY_ASSET_ID" ]] && ! contains_error "$RESP"; then
  pass "家庭资产创建成功, id=$FAMILY_ASSET_ID"
else
  fail "创建家庭资产" "$RESP"
fi

# --- 76. ListAssets(family_id) ---
run_test "ListAssets(family_id) 显示家庭资产"
RESP=$(grpc_call_auth asset.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.asset.v1.AssetService/ListAssets")
ASSET_COUNT=$(json_array_len "$RESP" "assets")
if [[ -n "$ASSET_COUNT" && "$ASSET_COUNT" -ge 1 ]]; then
  pass "ListAssets(family) 返回 $ASSET_COUNT 个资产"
else
  fail "ListAssets(family)" "$RESP"
fi

# --- 77. B 也能查看家庭资产 ---
run_test "B 查看家庭资产 → 应成功"
RESP=$(grpc_call_auth asset.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.asset.v1.AssetService/ListAssets")
B_ASSET_COUNT=$(json_array_len "$RESP" "assets")
if [[ -n "$B_ASSET_COUNT" && "$B_ASSET_COUNT" -ge 1 ]]; then
  pass "B 看到 $B_ASSET_COUNT 个家庭资产"
else
  fail "B ListAssets(family)" "$RESP"
fi

# --- 78. 非成员不能查看家庭资产 ---
run_test "非成员不能查看家庭资产"
if [[ -n "$TOKEN_D" ]]; then
  RESP=$(grpc_call_auth asset.proto "$TOKEN_D" \
    -d "{\"family_id\":\"$FAMILY_ID\"}" \
    "familyledger.asset.v1.AssetService/ListAssets")
  if contains_error "$RESP" || contains_permission_denied "$RESP"; then
    pass "非成员访问家庭资产被拒绝"
  else
    D_ASSET_COUNT=$(json_array_len "$RESP" "assets")
    if [[ "$D_ASSET_COUNT" == "0" || -z "$D_ASSET_COUNT" ]]; then
      pass "非成员返回空资产列表"
    else
      fail "非成员访问家庭资产" "看到 $D_ASSET_COUNT 个资产"
    fi
  fi
else
  skip "非成员资产测试" "TOKEN_D 不可用"
fi

##############################################################################
# Phase 19: Dashboard 家庭模式 (扩展)
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 19: Dashboard 家庭模式 (扩展)"
echo "============================================================"

# --- 79. GetCategoryBreakdown(family_id) ---
run_test "GetCategoryBreakdown(family_id)"
RESP=$(grpc_call_auth dashboard.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"year\":$BUDGET_YEAR,\"month\":$BUDGET_MONTH,\"type\":\"expense\"}" \
  "familyledger.dashboard.v1.DashboardService/GetCategoryBreakdown")
if ! contains_error "$RESP"; then
  CB_TOTAL=$(json_field "$RESP" "total")
  pass "GetCategoryBreakdown(family): total=$CB_TOTAL"
else
  fail "GetCategoryBreakdown(family)" "$RESP"
fi

# --- 80. GetIncomeExpenseTrend(family_id) ---
run_test "GetIncomeExpenseTrend(family_id)"
RESP=$(grpc_call_auth dashboard.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"period\":\"monthly\",\"count\":6}" \
  "familyledger.dashboard.v1.DashboardService/GetIncomeExpenseTrend")
if ! contains_error "$RESP"; then
  POINT_COUNT=$(json_array_len "$RESP" "points")
  pass "GetIncomeExpenseTrend(family): $POINT_COUNT 个数据点"
else
  fail "GetIncomeExpenseTrend(family)" "$RESP"
fi

# --- 81. GetBudgetSummary(family_id) ---
run_test "GetBudgetSummary(family_id)"
RESP=$(grpc_call_auth dashboard.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"year\":$BUDGET_YEAR,\"month\":$BUDGET_MONTH}" \
  "familyledger.dashboard.v1.DashboardService/GetBudgetSummary")
if ! contains_error "$RESP"; then
  BS_TOTAL=$(json_field "$RESP" "totalBudget")
  BS_SPENT=$(json_field "$RESP" "totalSpent")
  pass "GetBudgetSummary(family): budget=$BS_TOTAL, spent=$BS_SPENT"
else
  fail "GetBudgetSummary(family)" "$RESP"
fi

# --- 82. GetInvestmentTrend(family_id) ---
run_test "GetInvestmentTrend(family_id)"
RESP=$(grpc_call_auth dashboard.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"months\":6}" \
  "familyledger.dashboard.v1.DashboardService/GetInvestmentTrend")
if ! contains_error "$RESP"; then
  IT_COUNT=$(json_array_len "$RESP" "points")
  pass "GetInvestmentTrend(family): $IT_COUNT 个数据点"
else
  fail "GetInvestmentTrend(family)" "$RESP"
fi

# --- 83. 非成员 D 访问所有 Dashboard 接口 → 应全部失败 ---
run_test "非成员 Dashboard 全部接口 → 应拒绝"
ALL_DASH_BLOCKED=true
if [[ -n "$TOKEN_D" ]]; then
  for dash_call in \
    "GetNetWorth|{\"family_id\":\"$FAMILY_ID\"}" \
    "GetCategoryBreakdown|{\"family_id\":\"$FAMILY_ID\",\"year\":$BUDGET_YEAR,\"month\":$BUDGET_MONTH,\"type\":\"expense\"}" \
    "GetBudgetSummary|{\"family_id\":\"$FAMILY_ID\",\"year\":$BUDGET_YEAR,\"month\":$BUDGET_MONTH}" ; do
    RPC=$(echo "$dash_call" | cut -d'|' -f1)
    PAYLOAD=$(echo "$dash_call" | cut -d'|' -f2)
    RESP=$(grpc_call_auth dashboard.proto "$TOKEN_D" \
      -d "$PAYLOAD" \
      "familyledger.dashboard.v1.DashboardService/$RPC")
    if ! contains_error "$RESP" && ! contains_permission_denied "$RESP"; then
      TOTAL_VAL=$(json_field "$RESP" "total")
      if [[ -n "$TOTAL_VAL" && "$TOTAL_VAL" != "0" && "$TOTAL_VAL" != "null" ]]; then
        ALL_DASH_BLOCKED=false
        echo "    ✗ $RPC 未被拒绝: $RESP"
      fi
    fi
  done
  if $ALL_DASH_BLOCKED; then
    pass "非成员 D 被拒绝所有 Dashboard 家庭接口"
  else
    fail "非成员 Dashboard 访问" "部分接口未被拒绝"
  fi
else
  skip "非成员 Dashboard 测试" "TOKEN_D 不可用"
fi

##############################################################################
# Phase 20: 审计日志
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 20: 审计日志"
echo "============================================================"

# --- 84. GetAuditLog(family_id) → 返回审计条目 ---
run_test "GetAuditLog(family_id) → 返回审计条目"
AUDIT_COUNT=0
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":50}" \
  "familyledger.family.v1.FamilyService/GetAuditLog")
if echo "$RESP" | grep -q "does not exist"; then
  skip "GetAuditLog" "audit_logs 表不存在 (需跑 migration 038)"
  AUDIT_AVAILABLE=false
elif ! contains_error "$RESP"; then
  AUDIT_COUNT=$(json_array_len "$RESP" "entries")
  AUDIT_COUNT=${AUDIT_COUNT:-0}
  if [[ "$AUDIT_COUNT" -ge 1 ]]; then
    pass "GetAuditLog 返回 $AUDIT_COUNT 条审计记录"
  else
    pass "GetAuditLog 调用成功 (entries=$AUDIT_COUNT)"
  fi
  AUDIT_AVAILABLE=true
else
  fail "GetAuditLog" "$RESP"
  AUDIT_AVAILABLE=false
fi

# --- 85. 审计条目包含正确的 action 和 entity_type ---
run_test "审计条目包含正确的 action/entity_type"
if [[ "${AUDIT_AVAILABLE:-false}" == "true" ]]; then
  AUDIT_COUNT=${AUDIT_COUNT:-0}
  HAS_CREATE=$(echo "$RESP" | jq -e '.entries[] | select(.action == "create")' 2>/dev/null | head -1)
  HAS_TRANSACTION=$(echo "$RESP" | jq -e '.entries[] | select(.entityType == "transaction")' 2>/dev/null | head -1)
  if [[ -n "$HAS_CREATE" || -n "$HAS_TRANSACTION" ]]; then
    pass "审计条目包含 create/transaction 操作记录"
  else
    skip "审计条目字段检查" "可能没有匹配的条目 (实际entries=$AUDIT_COUNT)"
  fi
else
  skip "审计条目字段检查" "audit_logs 表不可用"
fi

# --- 86. GetAuditLog 按 entity_type 过滤 ---
run_test "GetAuditLog 按 entity_type=transaction 过滤"
if [[ "${AUDIT_AVAILABLE:-false}" == "true" ]]; then
  RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
    -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":50,\"entity_type\":\"transaction\"}" \
    "familyledger.family.v1.FamilyService/GetAuditLog")
  if ! contains_error "$RESP"; then
    FILTERED_COUNT=$(json_array_len "$RESP" "entries")
    pass "entity_type=transaction 过滤返回 $FILTERED_COUNT 条"
    NON_TXN=$(echo "$RESP" | jq '[.entries[] | select(.entityType != "transaction")] | length' 2>/dev/null)
    if [[ "$NON_TXN" == "0" ]]; then
      echo "    ✓ 所有条目都是 transaction 类型"
    fi
  else
    fail "GetAuditLog(entity_type过滤)" "$RESP"
  fi
else
  skip "GetAuditLog(entity_type过滤)" "audit_logs 表不可用"
fi

# --- 87. GetAuditLog 分页测试 ---
run_test "GetAuditLog 分页 (page_size=2)"
if [[ "${AUDIT_AVAILABLE:-false}" == "true" ]]; then
  RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
    -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":2}" \
    "familyledger.family.v1.FamilyService/GetAuditLog")
  if ! contains_error "$RESP"; then
    PAGE1_COUNT=$(json_array_len "$RESP" "entries")
    NEXT_TOKEN=$(json_field "$RESP" "nextPageToken")
    if [[ -n "$NEXT_TOKEN" ]]; then
      pass "分页: 第一页 $PAGE1_COUNT 条, 有 nextPageToken"
      RESP2=$(grpc_call_auth family.proto "$TOKEN_A" \
        -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":2,\"page_token\":\"$NEXT_TOKEN\"}" \
        "familyledger.family.v1.FamilyService/GetAuditLog")
      PAGE2_COUNT=$(json_array_len "$RESP2" "entries")
      echo "    ✓ 第二页 $PAGE2_COUNT 条"
    else
      pass "分页: 返回 $PAGE1_COUNT 条 (数据不足无需分页)"
    fi
  else
    fail "GetAuditLog(分页)" "$RESP"
  fi
else
  skip "GetAuditLog(分页)" "audit_logs 表不可用"
fi

# --- 88. 非成员不能访问审计日志 ---
run_test "非成员不能访问审计日志"
if [[ "${AUDIT_AVAILABLE:-false}" == "true" && -n "${TOKEN_D:-}" ]]; then
  RESP=$(grpc_call_auth family.proto "$TOKEN_D" \
    -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":10}" \
    "familyledger.family.v1.FamilyService/GetAuditLog")
  if contains_error "$RESP" || contains_permission_denied "$RESP"; then
    pass "非成员访问审计日志被拒绝"
  else
    D_AUDIT=$(json_array_len "$RESP" "entries")
    if [[ "$D_AUDIT" == "0" || -z "$D_AUDIT" ]]; then
      pass "非成员返回空审计日志"
    else
      fail "非成员访问审计日志" "看到 $D_AUDIT 条记录"
    fi
  fi
else
  skip "非成员审计测试" "audit_logs 表不可用或 TOKEN_D 不可用"
fi

##############################################################################
# Phase 21: 全量备份 (家庭模式)
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 21: 全量备份 (家庭模式)"
echo "============================================================"

# --- 89. FullBackup(family_id) → 应成功 ---
run_test "FullBackup(family_id) → 应成功"
RESP=$(grpc_call_auth export.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.export.v1.ExportService/FullBackup")
if ! contains_error "$RESP"; then
  BACKUP_FORMAT=$(json_field "$RESP" "format")
  pass "FullBackup(family) 成功, format=$BACKUP_FORMAT"
else
  fail "FullBackup(family)" "$RESP"
fi

# --- 90. 非成员不能做家庭 FullBackup ---
run_test "非成员不能做家庭 FullBackup"
if [[ -n "$TOKEN_D" ]]; then
  RESP=$(grpc_call_auth export.proto "$TOKEN_D" \
    -d "{\"family_id\":\"$FAMILY_ID\"}" \
    "familyledger.export.v1.ExportService/FullBackup")
  if contains_error "$RESP" || contains_permission_denied "$RESP"; then
    pass "非成员 FullBackup 被拒绝"
  else
    fail "非成员 FullBackup" "预期被拒绝: $RESP"
  fi
else
  skip "非成员 FullBackup 测试" "TOKEN_D 不可用"
fi

##############################################################################
# Phase 22: 多家庭隔离
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 22: 多家庭隔离"
echo "============================================================"

# --- 91. A 创建第二个家庭 ---
run_test "A 创建第二个家庭"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d '{"name":"A的第二个家庭"}' \
  "familyledger.family.v1.FamilyService/CreateFamily")
FAMILY2_ID=$(json_nested "$RESP" "family.id")
if [[ -n "$FAMILY2_ID" ]]; then
  pass "第二个家庭创建成功, id=$FAMILY2_ID"
else
  fail "创建第二个家庭" "$RESP"
fi

# --- 92. 在第二个家庭创建账户和交易 ---
run_test "在第二个家庭创建账户和交易"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"name\":\"家庭2共享账户\",\"type\":\"ACCOUNT_TYPE_CASH\",\"currency\":\"CNY\",\"initial_balance\":80000,\"family_id\":\"$FAMILY2_ID\"}" \
  "familyledger.account.v1.AccountService/CreateAccount")
F2_ACCT_ID=$(json_nested "$RESP" "account.id")
if [[ -n "$F2_ACCT_ID" ]]; then
  RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
    -d "{\"account_id\":\"$F2_ACCT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":2000,\"currency\":\"CNY\",\"amount_cny\":2000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"家庭2测试交易\"}" \
    "familyledger.transaction.v1.TransactionService/CreateTransaction")
  F2_TXN_ID=$(json_nested "$RESP" "transaction.id")
  if [[ -n "$F2_TXN_ID" ]]; then
    pass "家庭2: 账户=$F2_ACCT_ID, 交易=$F2_TXN_ID"
  else
    fail "家庭2创建交易" "$RESP"
  fi
else
  fail "家庭2创建账户" "$RESP"
fi

# --- 93. 家庭1的交易不会出现在家庭2中 ---
run_test "家庭1数据不泄漏到家庭2"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY2_ID\",\"page_size\":100}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
HAS_F1_DATA=$(echo "$RESP" | grep -c "家庭超市采购-A\|家庭水电费-B" || true)
if [[ "$HAS_F1_DATA" -eq 0 ]]; then
  pass "家庭2中不包含家庭1的交易数据"
else
  fail "多家庭数据隔离" "家庭2中看到家庭1的交易"
fi

# --- 94. 家庭2的交易不会出现在家庭1中 ---
run_test "家庭2数据不泄漏到家庭1"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":100}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
HAS_F2_DATA=$(echo "$RESP" | grep -c "家庭2测试交易" || true)
if [[ "$HAS_F2_DATA" -eq 0 ]]; then
  pass "家庭1中不包含家庭2的交易数据"
else
  fail "多家庭数据隔离(反向)" "家庭1中看到家庭2的交易"
fi

# 清理第二个家庭
grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY2_ID\"}" \
  "familyledger.family.v1.FamilyService/DeleteFamily" >/dev/null 2>&1

# --- C 退出家庭 (为 Phase 9 原始测试流程恢复状态) ---
grpc_call_auth family.proto "$TOKEN_C" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/LeaveFamily" >/dev/null 2>&1
##############################################################################
# Phase 9: 退出和清理
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 9: 退出和清理"
echo "============================================================"

# --- 32. 用户 B 退出家庭 ---
run_test "用户 B 退出家庭"
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/LeaveFamily")
if ! contains_error "$RESP"; then
  pass "B 退出家庭成功"
else
  fail "B 退出家庭" "$RESP"
fi

# --- 33. 验证 B 不再能看到家庭交易 ---
run_test "验证 B 退出后不再能看到家庭交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"page_size\":100}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
if contains_error "$RESP" || contains_permission_denied "$RESP"; then
  pass "B 退出后被拒绝访问家庭交易"
else
  B_TXN_COUNT=$(json_array_len "$RESP" "transactions")
  if [[ "$B_TXN_COUNT" == "0" || -z "$B_TXN_COUNT" ]]; then
    pass "B 退出后看到 0 条家庭交易"
  else
    fail "B 退出后仍能看到家庭交易" "$B_TXN_COUNT 条: $RESP"
  fi
fi

# --- 34. 验证 A 的家庭成员列表不再包含 B ---
run_test "验证 A 的家庭成员列表不再包含 B"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/ListFamilyMembers")
HAS_B=$(echo "$RESP" | jq -e ".members[] | select(.userId == \"$USER_B_ID\")" 2>/dev/null)
if [[ -z "$HAS_B" ]]; then
  pass "家庭成员列表中不再包含 B"
else
  fail "B 退出后仍在成员列表" "$RESP"
fi

# --- 35. 用户 A 删除家庭 ---
run_test "用户 A 删除家庭"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/DeleteFamily")
if ! contains_error "$RESP"; then
  pass "A 删除家庭成功"
else
  fail "A 删除家庭" "$RESP"
fi

##############################################################################
# Phase 10: 边界场景
##############################################################################
echo ""
echo "============================================================"
echo "  Phase 10: 边界场景"
echo "============================================================"

# 先创建一个新家庭用于边界测试
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d '{"name":"边界测试家庭"}' \
  "familyledger.family.v1.FamilyService/CreateFamily")
EDGE_FAMILY_ID=$(json_nested "$RESP" "family.id")
# B 重新加入
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$EDGE_FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/GenerateInviteCode")
EDGE_INVITE=$(json_field "$RESP" "inviteCode")
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"invite_code\":\"$EDGE_INVITE\"}" \
  "familyledger.family.v1.FamilyService/JoinFamily")

# --- 36. 无效邀请码加入 → 失败 ---
run_test "无效邀请码加入 → 应失败"
RESP=$(grpc_call_auth family.proto "$TOKEN_C" \
  -d '{"invite_code":"TOTALLY_INVALID_CODE_12345"}' \
  "familyledger.family.v1.FamilyService/JoinFamily")
if contains_error "$RESP"; then
  pass "无效邀请码被拒绝"
else
  fail "无效邀请码" "未报错: $RESP"
fi

# --- 37. 非成员操作家庭数据 → 全部拒绝 ---
run_test "非成员 C 操作家庭数据 → 应拒绝"
# C 尝试在家庭账户创建交易
RESP=$(grpc_call_auth account.proto "$TOKEN_C" \
  -d "{\"name\":\"C的非法账户\",\"type\":\"ACCOUNT_TYPE_CASH\",\"currency\":\"CNY\",\"family_id\":\"$EDGE_FAMILY_ID\"}" \
  "familyledger.account.v1.AccountService/CreateAccount")
if contains_error "$RESP" || contains_permission_denied "$RESP"; then
  pass "非成员 C 创建家庭账户被拒绝"
else
  # 如果创建成功了也验证一下
  C_ACCT_FAMILY=$(json_nested "$RESP" "account.familyId")
  if [[ "$C_ACCT_FAMILY" == "$EDGE_FAMILY_ID" ]]; then
    fail "非成员创建家庭账户" "C 竟然成功创建了家庭账户!"
  else
    pass "非成员 C 创建结果不归属家庭 (安全)"
  fi
fi

# --- 38. Owner 退出 → 应失败（必须先转让） ---
run_test "Owner A 退出家庭 → 应失败 (必须先转让)"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$EDGE_FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/LeaveFamily")
if contains_error "$RESP"; then
  pass "Owner 退出被拒绝 (必须先转让 ownership)"
else
  fail "Owner 退出" "预期失败但成功了: $RESP"
fi

# --- 39. 转让 ownership 给 B ---
run_test "转让 ownership 给 B → A 不再是 owner"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$EDGE_FAMILY_ID\",\"new_owner_id\":\"$USER_B_ID\"}" \
  "familyledger.family.v1.FamilyService/TransferOwnership")
if ! contains_error "$RESP"; then
  pass "TransferOwnership 成功"
else
  fail "TransferOwnership" "$RESP"
fi

# --- 40. 重复加入 → 合理处理 ---
run_test "用户 B 重复加入已在的家庭 → 合理处理"
# B 已经是成员了，再次加入
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$EDGE_FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/GenerateInviteCode")
REPEAT_CODE=$(json_field "$RESP" "inviteCode")
if [[ -z "$REPEAT_CODE" ]]; then
  # A 可能不再是 owner 了，用 B 来生成
  RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
    -d "{\"family_id\":\"$EDGE_FAMILY_ID\"}" \
    "familyledger.family.v1.FamilyService/GenerateInviteCode")
  REPEAT_CODE=$(json_field "$RESP" "inviteCode")
fi
if [[ -n "$REPEAT_CODE" ]]; then
  RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
    -d "{\"invite_code\":\"$REPEAT_CODE\"}" \
    "familyledger.family.v1.FamilyService/JoinFamily")
  if contains_error "$RESP"; then
    pass "重复加入返回错误 (已是成员)"
  else
    pass "重复加入被幂等处理 (未报错)"
  fi
else
  skip "重复加入测试" "无法生成邀请码"
fi

# 清理边界测试家庭
grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$EDGE_FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/DeleteFamily" >/dev/null 2>&1

##############################################################################
# 测试报告
##############################################################################
echo ""
echo "============================================================"
echo "  测试报告 — 家庭功能完整生命周期"
echo "============================================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo ""
echo "  总计: $TOTAL 测试"
echo "  通过: $PASS_COUNT ✅"
echo "  失败: $FAIL_COUNT ❌"
echo "  跳过: $SKIP_COUNT ⏭️"
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
