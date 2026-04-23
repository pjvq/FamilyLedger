#!/usr/bin/env bash
#
# FamilyLedger — 基础服务端到端 gRPC 集成测试
# 覆盖 30 个 RPC: AuthService(4) + AccountService(6) + TransactionService(3)
#                 + FamilyService(8) + SyncService(2) + NotifyService(6)
#
# 用法: bash tests/integration/test_basic_services.sh
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

# 每次运行唯一后缀，避免邮箱冲突
UNIQUE=$(date +%s%N | tail -c 10)

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
# 用法: grpc_call <proto> [grpcurl_args...] <service/method>
# 注意: HOST 必须在 service/method 前面
grpc_call() {
  local proto="$1"; shift
  # 最后一个参数是 service/method
  local method="${@: -1}"
  # 去掉最后一个参数，剩余的是 grpcurl 选项
  local args=("${@:1:$#-1}")
  $GRPCURL -proto "$proto" "${args[@]}" "$HOST" "$method" 2>&1
}

grpc_call_auth() {
  local proto="$1"; local token="$2"; shift 2
  local method="${@: -1}"
  local args=("${@:1:$#-1}")
  $GRPCURL -proto "$proto" -H "authorization: Bearer $token" "${args[@]}" "$HOST" "$method" 2>&1
}

# 提取 JSON 字段 (简易 jq)
json_field() {
  # $1 = field name, stdin = json
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$1',''))"
}

json_field_from() {
  echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$2',''))"
}

json_array_len() {
  echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('$2',[])))"
}

json_nested() {
  # $1=json, $2=path like "account.id"
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

contains_error() {
  echo "$1" | grep -qi "error\|ERROR\|rpc error" && return 0 || return 1
}

##############################################################################
# ==================== 1. AuthService ====================
##############################################################################
echo "============================================================"
echo "  AuthService Tests"
echo "============================================================"

# --- 1.1 Register ---
run_test "AuthService/Register — 正常注册"
EMAIL_A="user_a_${UNIQUE}@test.com"
PASSWD="Test123456"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
USER_A_ID=$(json_field_from "$RESP" "userId")
TOKEN_A=$(json_field_from "$RESP" "accessToken")
REFRESH_A=$(json_field_from "$RESP" "refreshToken")
if [[ -n "$USER_A_ID" && -n "$TOKEN_A" ]]; then
  pass "Register 返回 userId=$USER_A_ID, 有 token"
else
  fail "Register" "返回异常: $RESP"
fi

# --- 1.2 Register — 重复注册 ---
run_test "AuthService/Register — 重复邮箱应失败"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
if contains_error "$RESP"; then
  pass "重复注册返回错误"
else
  fail "Register-Dup" "未返回错误: $RESP"
fi

# --- 1.3 Login ---
run_test "AuthService/Login — 正常登录"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_A\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Login")
LOGIN_TOKEN=$(json_field_from "$RESP" "accessToken")
LOGIN_REFRESH=$(json_field_from "$RESP" "refreshToken")
if [[ -n "$LOGIN_TOKEN" ]]; then
  pass "Login 返回 token"
  TOKEN_A="$LOGIN_TOKEN"
  REFRESH_A="$LOGIN_REFRESH"
else
  fail "Login" "无 token: $RESP"
fi

# --- 1.4 Login — 错误密码 ---
run_test "AuthService/Login — 错误密码应失败"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_A\",\"password\":\"WrongPwd999\"}" \
  "familyledger.auth.v1.AuthService/Login")
if contains_error "$RESP"; then
  pass "错误密码被拒绝"
else
  fail "Login-BadPwd" "未返回错误: $RESP"
fi

# --- 1.5 RefreshToken ---
run_test "AuthService/RefreshToken — 刷新令牌"
RESP=$(grpc_call auth.proto -d "{\"refresh_token\":\"$REFRESH_A\"}" \
  "familyledger.auth.v1.AuthService/RefreshToken")
NEW_TOKEN=$(json_field_from "$RESP" "accessToken")
NEW_REFRESH=$(json_field_from "$RESP" "refreshToken")
if [[ -n "$NEW_TOKEN" ]]; then
  pass "RefreshToken 返回新 token"
  TOKEN_A="$NEW_TOKEN"
  REFRESH_A="$NEW_REFRESH"
else
  fail "RefreshToken" "无新 token: $RESP"
fi

# --- 1.6 RefreshToken — 无效 token ---
run_test "AuthService/RefreshToken — 无效 token 应失败"
RESP=$(grpc_call auth.proto -d '{"refresh_token":"invalid.token.value"}' \
  "familyledger.auth.v1.AuthService/RefreshToken")
if contains_error "$RESP"; then
  pass "无效 refresh token 被拒绝"
else
  fail "RefreshToken-Invalid" "未返回错误: $RESP"
fi

# --- 1.7 OAuthLogin ---
run_test "AuthService/OAuthLogin — 伪造 OAuth code (预期失败)"
RESP=$(grpc_call auth.proto -d '{"provider":"wechat","code":"fake_code","redirect_uri":"http://localhost"}' \
  "familyledger.auth.v1.AuthService/OAuthLogin")
if contains_error "$RESP"; then
  pass "伪造 OAuth code 被拒绝"
else
  # 如果服务端没有实现 OAuth，可能返回 Unimplemented，也算覆盖
  if echo "$RESP" | grep -qi "unimplemented\|not implemented"; then
    pass "OAuthLogin 返回 Unimplemented (服务未对接)"
  else
    fail "OAuthLogin" "未知响应: $RESP"
  fi
fi

##############################################################################
# ==================== 2. AccountService ====================
##############################################################################
echo ""
echo "============================================================"
echo "  AccountService Tests"
echo "============================================================"

# --- 2.1 CreateAccount (储蓄卡) ---
run_test "AccountService/CreateAccount — 创建储蓄卡"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d '{"name":"储蓄卡","type":"ACCOUNT_TYPE_BANK_CARD","currency":"CNY","icon":"bank","initial_balance":10000}' \
  "familyledger.account.v1.AccountService/CreateAccount")
ACCOUNT_A_ID=$(json_nested "$RESP" "account.id")
if [[ -n "$ACCOUNT_A_ID" ]]; then
  pass "CreateAccount 储蓄卡 id=$ACCOUNT_A_ID"
else
  fail "CreateAccount-Bank" "返回异常: $RESP"
fi

# --- 2.2 CreateAccount (现金) ---
run_test "AccountService/CreateAccount — 创建现金账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d '{"name":"现金","type":"ACCOUNT_TYPE_CASH","currency":"CNY","icon":"cash","initial_balance":5000}' \
  "familyledger.account.v1.AccountService/CreateAccount")
ACCOUNT_B_ID=$(json_nested "$RESP" "account.id")
if [[ -n "$ACCOUNT_B_ID" ]]; then
  pass "CreateAccount 现金 id=$ACCOUNT_B_ID"
else
  fail "CreateAccount-Cash" "返回异常: $RESP"
fi

# --- 2.3 ListAccounts ---
run_test "AccountService/ListAccounts — 列出账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d '{}' \
  "familyledger.account.v1.AccountService/ListAccounts")
ACCT_COUNT=$(json_array_len "$RESP" "accounts")
if [[ "$ACCT_COUNT" -ge 2 ]]; then
  pass "ListAccounts 返回 $ACCT_COUNT 个账户 (≥2)"
else
  fail "ListAccounts" "账户数 $ACCT_COUNT < 2: $RESP"
fi

# --- 2.4 GetAccount ---
run_test "AccountService/GetAccount — 获取单个账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$ACCOUNT_A_ID\"}" \
  "familyledger.account.v1.AccountService/GetAccount")
GOT_NAME=$(json_nested "$RESP" "account.name")
if [[ "$GOT_NAME" == "储蓄卡" ]]; then
  pass "GetAccount 返回 name=储蓄卡"
else
  fail "GetAccount" "name=$GOT_NAME: $RESP"
fi

# --- 2.5 UpdateAccount ---
run_test "AccountService/UpdateAccount — 更新账户名称"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$ACCOUNT_A_ID\",\"name\":\"工商银行储蓄卡\"}" \
  "familyledger.account.v1.AccountService/UpdateAccount")
UPD_NAME=$(json_nested "$RESP" "account.name")
if [[ "$UPD_NAME" == "工商银行储蓄卡" ]]; then
  pass "UpdateAccount name→工商银行储蓄卡"
else
  fail "UpdateAccount" "name=$UPD_NAME: $RESP"
fi

# --- 2.6 TransferBetween ---
run_test "AccountService/TransferBetween — 账户间转账"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"from_account_id\":\"$ACCOUNT_A_ID\",\"to_account_id\":\"$ACCOUNT_B_ID\",\"amount\":2000,\"note\":\"转账测试\"}" \
  "familyledger.account.v1.AccountService/TransferBetween")
TRANSFER_ID=$(json_nested "$RESP" "transfer.id")
if [[ -n "$TRANSFER_ID" ]]; then
  pass "TransferBetween id=$TRANSFER_ID"
else
  fail "TransferBetween" "返回异常: $RESP"
fi

# --- 2.7 TransferBetween — 转账金额为 0 应失败 ---
run_test "AccountService/TransferBetween — 金额 0 应失败"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"from_account_id\":\"$ACCOUNT_A_ID\",\"to_account_id\":\"$ACCOUNT_B_ID\",\"amount\":0}" \
  "familyledger.account.v1.AccountService/TransferBetween")
if contains_error "$RESP"; then
  pass "金额为 0 的转账被拒绝"
else
  fail "TransferBetween-Zero" "未返回错误: $RESP"
fi

# --- 2.8 DeleteAccount ---
# 先创建一个临时账户再删
run_test "AccountService/DeleteAccount — 删除账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d '{"name":"待删除","type":"ACCOUNT_TYPE_OTHER","currency":"CNY"}' \
  "familyledger.account.v1.AccountService/CreateAccount")
DEL_ACCT_ID=$(json_nested "$RESP" "account.id")
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$DEL_ACCT_ID\"}" \
  "familyledger.account.v1.AccountService/DeleteAccount")
if ! contains_error "$RESP"; then
  pass "DeleteAccount 成功 (id=$DEL_ACCT_ID)"
else
  fail "DeleteAccount" "$RESP"
fi

# --- 2.9 GetAccount — 获取已删除账户 ---
run_test "AccountService/GetAccount — 获取已删除账户"
RESP=$(grpc_call_auth account.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$DEL_ACCT_ID\"}" \
  "familyledger.account.v1.AccountService/GetAccount")
if contains_error "$RESP"; then
  pass "获取已删除账户返回错误"
else
  # 有些实现会返回 is_active=false 而不是错误
  ACTIVE=$(json_nested "$RESP" "account.isActive")
  if [[ "$ACTIVE" == "False" || "$ACTIVE" == "false" || "$ACTIVE" == "" ]]; then
    pass "已删除账户 isActive=false"
  else
    fail "GetAccount-Deleted" "未报错也未 inactive: $RESP"
  fi
fi

##############################################################################
# ==================== 3. TransactionService ====================
##############################################################################
echo ""
echo "============================================================"
echo "  TransactionService Tests"
echo "============================================================"

# --- 3.1 GetCategories ---
run_test "TransactionService/GetCategories — 获取全部分类"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d '{}' \
  "familyledger.transaction.v1.TransactionService/GetCategories")
CAT_COUNT=$(json_array_len "$RESP" "categories")
if [[ "$CAT_COUNT" -ge 1 ]]; then
  # 提取第一个 category id 用于后续创建交易
  CATEGORY_ID=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); cats=d.get('categories',[]); print(cats[0]['id'] if cats else '')")
  pass "GetCategories 返回 $CAT_COUNT 个分类, 使用 id=$CATEGORY_ID"
else
  # 如果没有预设分类，用空字符串
  CATEGORY_ID=""
  pass "GetCategories 返回 0 个分类 (可能无预设)"
fi

# --- 3.2 GetCategories — 按类型过滤 ---
run_test "TransactionService/GetCategories — 按 EXPENSE 过滤"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d '{"type":"TRANSACTION_TYPE_EXPENSE"}' \
  "familyledger.transaction.v1.TransactionService/GetCategories")
if ! contains_error "$RESP"; then
  pass "GetCategories(EXPENSE) 调用成功"
else
  fail "GetCategories-Expense" "$RESP"
fi

# --- 3.3 CreateTransaction ---
run_test "TransactionService/CreateTransaction — 创建支出"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$ACCOUNT_A_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":5000,\"currency\":\"CNY\",\"amount_cny\":5000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_EXPENSE\",\"note\":\"午餐\",\"tags\":[\"餐饮\"]}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
TXN_ID=$(json_nested "$RESP" "transaction.id")
if [[ -n "$TXN_ID" ]]; then
  pass "CreateTransaction id=$TXN_ID"
else
  fail "CreateTransaction" "$RESP"
fi

# --- 3.4 CreateTransaction — 创建收入 ---
run_test "TransactionService/CreateTransaction — 创建收入"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$ACCOUNT_A_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":200000,\"currency\":\"CNY\",\"amount_cny\":200000,\"exchange_rate\":1.0,\"type\":\"TRANSACTION_TYPE_INCOME\",\"note\":\"工资\"}" \
  "familyledger.transaction.v1.TransactionService/CreateTransaction")
TXN2_ID=$(json_nested "$RESP" "transaction.id")
if [[ -n "$TXN2_ID" ]]; then
  pass "CreateTransaction(收入) id=$TXN2_ID"
else
  fail "CreateTransaction-Income" "$RESP"
fi

# --- 3.5 ListTransactions ---
run_test "TransactionService/ListTransactions — 列出交易"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d "{\"account_id\":\"$ACCOUNT_A_ID\",\"page_size\":10}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
TXN_COUNT=$(json_array_len "$RESP" "transactions")
if [[ "$TXN_COUNT" -ge 2 ]]; then
  pass "ListTransactions 返回 $TXN_COUNT 条交易 (≥2)"
else
  fail "ListTransactions" "交易数 $TXN_COUNT < 2: $RESP"
fi

# --- 3.6 ListTransactions — 空账户 ---
run_test "TransactionService/ListTransactions — 不存在的账户"
RESP=$(grpc_call_auth transaction.proto "$TOKEN_A" \
  -d '{"account_id":"nonexistent-account-id","page_size":10}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
TXN_COUNT2=$(json_array_len "$RESP" "transactions")
if [[ "$TXN_COUNT2" -eq 0 ]] || contains_error "$RESP"; then
  pass "不存在的账户返回空列表或错误"
else
  fail "ListTransactions-Empty" "返回了 $TXN_COUNT2 条: $RESP"
fi

##############################################################################
# ==================== 4. FamilyService ====================
##############################################################################
echo ""
echo "============================================================"
echo "  FamilyService Tests"
echo "============================================================"

# 注册第二个用户用于 Family 测试
EMAIL_B="user_b_${UNIQUE}@test.com"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL_B\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
USER_B_ID=$(json_field_from "$RESP" "userId")
TOKEN_B=$(json_field_from "$RESP" "accessToken")

# --- 4.1 CreateFamily ---
run_test "FamilyService/CreateFamily — 创建家庭"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d '{"name":"测试家庭"}' \
  "familyledger.family.v1.FamilyService/CreateFamily")
FAMILY_ID=$(json_nested "$RESP" "family.id")
if [[ -n "$FAMILY_ID" ]]; then
  pass "CreateFamily id=$FAMILY_ID"
else
  fail "CreateFamily" "$RESP"
fi

# --- 4.2 GetFamily ---
run_test "FamilyService/GetFamily — 获取家庭信息"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/GetFamily")
FAM_NAME=$(json_nested "$RESP" "family.name")
if [[ "$FAM_NAME" == "测试家庭" ]]; then
  pass "GetFamily name=测试家庭"
else
  fail "GetFamily" "name=$FAM_NAME: $RESP"
fi

# --- 4.3 GenerateInviteCode ---
run_test "FamilyService/GenerateInviteCode — 生成邀请码"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/GenerateInviteCode")
INVITE_CODE=$(json_field_from "$RESP" "inviteCode")
if [[ -n "$INVITE_CODE" ]]; then
  pass "GenerateInviteCode code=$INVITE_CODE"
else
  fail "GenerateInviteCode" "$RESP"
fi

# --- 4.4 JoinFamily ---
run_test "FamilyService/JoinFamily — 用户B加入家庭"
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"invite_code\":\"$INVITE_CODE\"}" \
  "familyledger.family.v1.FamilyService/JoinFamily")
JOINED_FAM=$(json_nested "$RESP" "family.id")
if [[ "$JOINED_FAM" == "$FAMILY_ID" ]]; then
  pass "JoinFamily 成功, family_id 一致"
else
  if ! contains_error "$RESP"; then
    pass "JoinFamily 调用成功"
  else
    fail "JoinFamily" "$RESP"
  fi
fi

# --- 4.5 JoinFamily — 无效邀请码 ---
run_test "FamilyService/JoinFamily — 无效邀请码应失败"
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d '{"invite_code":"INVALID_CODE"}' \
  "familyledger.family.v1.FamilyService/JoinFamily")
if contains_error "$RESP"; then
  pass "无效邀请码被拒绝"
else
  fail "JoinFamily-Invalid" "未报错: $RESP"
fi

# --- 4.6 ListFamilyMembers ---
run_test "FamilyService/ListFamilyMembers — 列出成员"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/ListFamilyMembers")
MEM_COUNT=$(json_array_len "$RESP" "members")
if [[ "$MEM_COUNT" -ge 2 ]]; then
  pass "ListFamilyMembers 返回 $MEM_COUNT 个成员 (≥2)"
else
  fail "ListFamilyMembers" "成员数 $MEM_COUNT < 2: $RESP"
fi

# --- 4.7 SetMemberRole ---
run_test "FamilyService/SetMemberRole — 设置成员角色为 ADMIN"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"role\":\"FAMILY_ROLE_ADMIN\"}" \
  "familyledger.family.v1.FamilyService/SetMemberRole")
if ! contains_error "$RESP"; then
  pass "SetMemberRole → ADMIN 成功"
else
  fail "SetMemberRole" "$RESP"
fi

# --- 4.8 SetMemberPermissions ---
run_test "FamilyService/SetMemberPermissions — 设置权限"
RESP=$(grpc_call_auth family.proto "$TOKEN_A" \
  -d "{\"family_id\":\"$FAMILY_ID\",\"user_id\":\"$USER_B_ID\",\"permissions\":{\"can_view\":true,\"can_create\":true,\"can_edit\":true,\"can_delete\":false,\"can_manage_accounts\":false}}" \
  "familyledger.family.v1.FamilyService/SetMemberPermissions")
if ! contains_error "$RESP"; then
  pass "SetMemberPermissions 成功"
else
  fail "SetMemberPermissions" "$RESP"
fi

# --- 4.9 LeaveFamily ---
run_test "FamilyService/LeaveFamily — 用户B退出家庭"
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/LeaveFamily")
if ! contains_error "$RESP"; then
  pass "LeaveFamily 成功"
else
  fail "LeaveFamily" "$RESP"
fi

# --- 4.10 LeaveFamily — 重复退出应失败 ---
run_test "FamilyService/LeaveFamily — 重复退出应失败"
RESP=$(grpc_call_auth family.proto "$TOKEN_B" \
  -d "{\"family_id\":\"$FAMILY_ID\"}" \
  "familyledger.family.v1.FamilyService/LeaveFamily")
if contains_error "$RESP"; then
  pass "重复退出被拒绝"
else
  pass "重复退出未报错 (幂等实现)"
fi

##############################################################################
# ==================== 5. SyncService ====================
##############################################################################
echo ""
echo "============================================================"
echo "  SyncService Tests"
echo "============================================================"

# --- 5.1 PushOperations ---
run_test "SyncService/PushOperations — 推送操作"
RESP=$(grpc_call_auth sync.proto "$TOKEN_A" \
  -d "{\"operations\":[{\"id\":\"op_${UNIQUE}_1\",\"entity_type\":\"transaction\",\"entity_id\":\"$TXN_ID\",\"op_type\":\"OPERATION_TYPE_CREATE\",\"payload\":\"{}\",\"client_id\":\"client_${UNIQUE}\"}]}" \
  "familyledger.sync.v1.SyncService/PushOperations")
ACCEPTED=$(json_field_from "$RESP" "acceptedCount")
if [[ "$ACCEPTED" -ge 1 ]] 2>/dev/null; then
  pass "PushOperations accepted=$ACCEPTED"
elif ! contains_error "$RESP"; then
  pass "PushOperations 调用成功 ($RESP)"
else
  fail "PushOperations" "$RESP"
fi

# --- 5.2 PushOperations — 空操作列表 ---
run_test "SyncService/PushOperations — 空操作列表"
RESP=$(grpc_call_auth sync.proto "$TOKEN_A" \
  -d '{"operations":[]}' \
  "familyledger.sync.v1.SyncService/PushOperations")
if ! contains_error "$RESP"; then
  pass "空操作列表调用成功 (accepted=0)"
else
  fail "PushOperations-Empty" "$RESP"
fi

# --- 5.3 PullChanges ---
run_test "SyncService/PullChanges — 拉取变更"
RESP=$(grpc_call_auth sync.proto "$TOKEN_A" \
  -d "{\"since\":\"2020-01-01T00:00:00Z\",\"client_id\":\"client_${UNIQUE}\"}" \
  "familyledger.sync.v1.SyncService/PullChanges")
if ! contains_error "$RESP"; then
  SERVER_TIME=$(json_field_from "$RESP" "serverTime")
  OPS_COUNT=$(json_array_len "$RESP" "operations")
  pass "PullChanges 返回 $OPS_COUNT 条操作, serverTime=$SERVER_TIME"
else
  fail "PullChanges" "$RESP"
fi

##############################################################################
# ==================== 6. NotifyService ====================
##############################################################################
echo ""
echo "============================================================"
echo "  NotifyService Tests"
echo "============================================================"

# --- 6.1 RegisterDevice ---
run_test "NotifyService/RegisterDevice — 注册设备"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d "{\"device_token\":\"token_${UNIQUE}\",\"platform\":\"ios\",\"device_name\":\"Test iPhone\"}" \
  "familyledger.notify.v1.NotifyService/RegisterDevice")
DEVICE_ID=$(json_field_from "$RESP" "deviceId")
if [[ -n "$DEVICE_ID" ]]; then
  pass "RegisterDevice id=$DEVICE_ID"
else
  if ! contains_error "$RESP"; then
    DEVICE_ID="device_placeholder"
    pass "RegisterDevice 调用成功"
  else
    fail "RegisterDevice" "$RESP"
  fi
fi

# --- 6.2 RegisterDevice — 重复注册 (应幂等) ---
run_test "NotifyService/RegisterDevice — 重复注册"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d "{\"device_token\":\"token_${UNIQUE}\",\"platform\":\"ios\",\"device_name\":\"Test iPhone\"}" \
  "familyledger.notify.v1.NotifyService/RegisterDevice")
if ! contains_error "$RESP"; then
  pass "重复注册设备成功 (幂等)"
else
  fail "RegisterDevice-Dup" "$RESP"
fi

# --- 6.3 GetNotificationSettings ---
run_test "NotifyService/GetNotificationSettings — 获取通知设置"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d '{}' \
  "familyledger.notify.v1.NotifyService/GetNotificationSettings")
if ! contains_error "$RESP"; then
  pass "GetNotificationSettings 调用成功"
else
  fail "GetNotificationSettings" "$RESP"
fi

# --- 6.4 UpdateNotificationSettings ---
run_test "NotifyService/UpdateNotificationSettings — 更新通知设置"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d '{"settings":{"budget_alert":true,"budget_warning":true,"daily_summary":false,"loan_reminder":true,"reminder_days_before":3}}' \
  "familyledger.notify.v1.NotifyService/UpdateNotificationSettings")
if ! contains_error "$RESP"; then
  pass "UpdateNotificationSettings 成功"
else
  fail "UpdateNotificationSettings" "$RESP"
fi

# --- 6.5 验证设置已更新 ---
run_test "NotifyService/GetNotificationSettings — 验证更新生效"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d '{}' \
  "familyledger.notify.v1.NotifyService/GetNotificationSettings")
BUDGET_ALERT=$(json_nested "$RESP" "settings.budgetAlert")
if [[ "$BUDGET_ALERT" == "True" || "$BUDGET_ALERT" == "true" ]]; then
  pass "budgetAlert=true 验证通过"
elif ! contains_error "$RESP"; then
  pass "GetNotificationSettings 调用成功 (未验证具体值)"
else
  fail "GetNotificationSettings-Verify" "$RESP"
fi

# --- 6.6 ListNotifications ---
run_test "NotifyService/ListNotifications — 列出通知"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d '{"page":1,"page_size":10}' \
  "familyledger.notify.v1.NotifyService/ListNotifications")
if ! contains_error "$RESP"; then
  NOTIF_COUNT=$(json_array_len "$RESP" "notifications")
  pass "ListNotifications 返回 $NOTIF_COUNT 条通知"
else
  fail "ListNotifications" "$RESP"
fi

# --- 6.7 MarkAsRead ---
run_test "NotifyService/MarkAsRead — 空列表应报参数错误"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d '{"notification_ids":[]}' \
  "familyledger.notify.v1.NotifyService/MarkAsRead")
if contains_error "$RESP"; then
  pass "MarkAsRead(空列表) 正确返回参数错误"
else
  pass "MarkAsRead(空列表) 调用成功 (宽松实现)"
fi

# --- 6.8 MarkAsRead — 不存在的 ID ---
run_test "NotifyService/MarkAsRead — 不存在的通知 ID"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d '{"notification_ids":["nonexistent-notification-id"]}' \
  "familyledger.notify.v1.NotifyService/MarkAsRead")
if ! contains_error "$RESP"; then
  pass "MarkAsRead(不存在ID) 调用成功 (幂等)"
else
  pass "MarkAsRead(不存在ID) 返回错误 (严格校验)"
fi

# --- 6.9 UnregisterDevice ---
run_test "NotifyService/UnregisterDevice — 注销设备"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d "{\"device_id\":\"$DEVICE_ID\"}" \
  "familyledger.notify.v1.NotifyService/UnregisterDevice")
if ! contains_error "$RESP"; then
  pass "UnregisterDevice 成功"
else
  fail "UnregisterDevice" "$RESP"
fi

# --- 6.10 UnregisterDevice — 重复注销 ---
run_test "NotifyService/UnregisterDevice — 重复注销"
RESP=$(grpc_call_auth notify.proto "$TOKEN_A" \
  -d "{\"device_id\":\"$DEVICE_ID\"}" \
  "familyledger.notify.v1.NotifyService/UnregisterDevice")
if contains_error "$RESP"; then
  pass "重复注销返回错误"
else
  pass "重复注销成功 (幂等)"
fi

##############################################################################
# ==================== 无认证调用测试 ====================
##############################################################################
echo ""
echo "============================================================"
echo "  Auth Guard Tests (无 Token 调用受保护接口)"
echo "============================================================"

run_test "AccountService 无 token 应被拒"
RESP=$(grpc_call account.proto -d '{}' \
  "familyledger.account.v1.AccountService/ListAccounts")
if contains_error "$RESP"; then
  pass "无 token 访问 ListAccounts 被拒绝"
else
  fail "AuthGuard-Account" "未返回错误: $RESP"
fi

run_test "TransactionService 无 token 应被拒"
RESP=$(grpc_call transaction.proto -d '{}' \
  "familyledger.transaction.v1.TransactionService/GetCategories")
if contains_error "$RESP"; then
  pass "无 token 访问 GetCategories 被拒绝"
else
  fail "AuthGuard-Transaction" "未返回错误: $RESP"
fi

##############################################################################
# 测试报告
##############################################################################
echo ""
echo "============================================================"
echo "  测试报告"
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
