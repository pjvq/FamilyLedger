#!/usr/bin/env bash
#
# FamilyLedger — 1000 笔交易性能测试
# 测试场景: 批量创建、分页列出、Dashboard 查询性能
#
# 用法: bash tests/integration/test_perf_1000_transactions.sh
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

TXN_COUNT=1000

# 每次运行唯一后缀，避免邮箱冲突
UNIQUE=$(date +%s%N | tail -c 10)

# 分类 UUID（支出7 + 收入3）
EXPENSE_CATEGORIES=(
  "95d6dc66-12c4-5f2b-bf9b-1d439a9c8100"  # 餐饮
  "6f7a88e1-fb21-5409-b6b3-606787668c02"  # 交通
  "3feb7580-9bad-5c6a-bf4f-db9e59eb3e64"  # 购物
  "f925409c-19b9-5461-8a3d-5dc88e50efeb"  # 居住
  "805a7628-6497-5252-b4ab-a76361e5aa0a"  # 娱乐
  "f0683ffe-fe9c-593f-8701-4ec1c296b32c"  # 医疗
  "b41989ae-e78a-59f2-9c02-4f904d8e6841"  # 教育
)
INCOME_CATEGORIES=(
  "5c7b17d7-a3ec-59c0-b2ad-4a62ad32f2c3"  # 工资
  "a163e39c-8eb4-5317-8ef9-7c433897b569"  # 奖金
  "0aacf353-c7a5-5ac1-8da6-5b8815ffcef7"  # 投资收益
)
ALL_CATEGORIES=("${EXPENSE_CATEGORIES[@]}" "${INCOME_CATEGORIES[@]}")
NUM_CATEGORIES=${#ALL_CATEGORIES[@]}

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

contains_error() {
  echo "$1" | grep -qi "error\|ERROR\|rpc error" && return 0 || return 1
}

# 纳秒时间戳 (macOS 的 date 不支持 %N，用 python3 兜底)
now_ns() {
  python3 -c "import time; print(int(time.time()*1e9))"
}

# 计算毫秒差值: delta_ms <start_ns> <end_ns>
delta_ms() {
  python3 -c "print(int(($2 - $1) / 1e6))"
}

# 生成随机数: rand_range <min> <max>
rand_range() {
  python3 -c "import random; print(random.randint($1, $2))"
}

# 生成 txn_date 分布在过去 12 个月: random_past_date
random_past_date() {
  python3 -c "
import random, datetime
now = datetime.datetime.now(datetime.timezone.utc)
days_back = random.randint(0, 365)
dt = now - datetime.timedelta(days=days_back)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
"
}

##############################################################################
echo "============================================================"
echo "  FamilyLedger — 1000 笔交易性能测试"
echo "============================================================"

##############################################################################
# 1. 注册 + 登录
##############################################################################
run_test "注册测试用户并登录"
EMAIL="perf_${UNIQUE}@test.com"
PASSWD="Test123456"
RESP=$(grpc_call auth.proto -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWD\"}" \
  "familyledger.auth.v1.AuthService/Register")
USER_ID=$(json_field_from "$RESP" "userId")
TOKEN=$(json_field_from "$RESP" "accessToken")
if [[ -n "$USER_ID" && -n "$TOKEN" ]]; then
  pass "注册成功 userId=$USER_ID"
else
  fail "Register" "返回异常: $RESP"
  echo "无法继续测试，退出"
  exit 1
fi

##############################################################################
# 2. 创建带充足余额的测试账户
##############################################################################
run_test "创建性能测试账户"
RESP=$(grpc_call_auth account.proto "$TOKEN" \
  -d '{"name":"性能测试账户","type":"ACCOUNT_TYPE_BANK_CARD","currency":"CNY","icon":"bank","initial_balance":"100000000"}' \
  "familyledger.account.v1.AccountService/CreateAccount")
ACCOUNT_ID=$(json_nested "$RESP" "account.id")
if [[ -n "$ACCOUNT_ID" ]]; then
  pass "测试账户 id=$ACCOUNT_ID (余额 ¥1,000,000)"
else
  fail "CreateAccount" "返回异常: $RESP"
  echo "无法继续测试，退出"
  exit 1
fi

##############################################################################
# 3. 批量创建 1000 笔交易
##############################################################################
run_test "批量创建 $TXN_COUNT 笔交易"
echo "  创建中..."

CREATE_START=$(now_ns)
CREATE_ERRORS=0

for i in $(seq 1 $TXN_COUNT); do
  # 循环选择分类
  CAT_IDX=$((( i - 1 ) % NUM_CATEGORIES))
  CATEGORY_ID="${ALL_CATEGORIES[$CAT_IDX]}"

  # 前 70% 是支出，后 30% 是收入
  if [[ $CAT_IDX -lt ${#EXPENSE_CATEGORIES[@]} ]]; then
    TXN_TYPE="TRANSACTION_TYPE_EXPENSE"
  else
    TXN_TYPE="TRANSACTION_TYPE_INCOME"
  fi

  # 随机金额 100-100000（1元-1000元，以分为单位）
  AMOUNT=$(rand_range 100 100000)

  # 随机日期分布在过去 12 个月
  TXN_DATE=$(random_past_date)

  NOTE="perf_test_${i}_${UNIQUE}"

  RESP=$(grpc_call_auth transaction.proto "$TOKEN" \
    -d "{\"account_id\":\"$ACCOUNT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":$AMOUNT,\"currency\":\"CNY\",\"amount_cny\":$AMOUNT,\"exchange_rate\":1.0,\"type\":\"$TXN_TYPE\",\"note\":\"$NOTE\",\"txn_date\":\"$TXN_DATE\"}" \
    "familyledger.transaction.v1.TransactionService/CreateTransaction")

  if contains_error "$RESP"; then
    CREATE_ERRORS=$((CREATE_ERRORS + 1))
    if [[ $CREATE_ERRORS -le 3 ]]; then
      echo "  [WARN] 第 $i 笔创建失败: $RESP"
    fi
  fi

  # 每 100 笔打印进度
  if [[ $((i % 100)) -eq 0 ]]; then
    echo "  已创建 $i / $TXN_COUNT ..."
  fi
done

CREATE_END=$(now_ns)
CREATE_MS=$(delta_ms $CREATE_START $CREATE_END)
CREATE_SEC=$(python3 -c "print(f'{$CREATE_MS/1000:.1f}')")
CREATE_AVG=$(python3 -c "print(f'{$CREATE_MS/$TXN_COUNT:.1f}')")

CREATED_OK=$(( TXN_COUNT - CREATE_ERRORS ))
if [[ $CREATE_ERRORS -eq 0 ]]; then
  pass "创建 $TXN_COUNT 笔交易全部成功，耗时 ${CREATE_SEC}s (avg ${CREATE_AVG}ms/txn)"
elif [[ $CREATE_ERRORS -lt 10 ]]; then
  pass "创建 $CREATED_OK/$TXN_COUNT 笔成功 ($CREATE_ERRORS 失败)，耗时 ${CREATE_SEC}s"
else
  fail "批量创建" "$CREATE_ERRORS/$TXN_COUNT 笔失败"
fi

##############################################################################
# 4. 分页列出全部交易并计数
##############################################################################
run_test "分页列出全部交易 (page_size=100)"

LIST_START=$(now_ns)
TOTAL_LISTED=0
PAGE_TOKEN=""
PAGE_NUM=0

while true; do
  PAGE_NUM=$((PAGE_NUM + 1))

  if [[ -n "$PAGE_TOKEN" ]]; then
    RESP=$(grpc_call_auth transaction.proto "$TOKEN" \
      -d "{\"page_size\":100,\"page_token\":\"$PAGE_TOKEN\"}" \
      "familyledger.transaction.v1.TransactionService/ListTransactions")
  else
    RESP=$(grpc_call_auth transaction.proto "$TOKEN" \
      -d '{"page_size":100}' \
      "familyledger.transaction.v1.TransactionService/ListTransactions")
  fi

  if contains_error "$RESP"; then
    fail "ListTransactions page $PAGE_NUM" "$RESP"
    break
  fi

  PAGE_COUNT=$(json_array_len "$RESP" "transactions")
  TOTAL_LISTED=$((TOTAL_LISTED + PAGE_COUNT))
  PAGE_TOKEN=$(json_field_from "$RESP" "nextPageToken")

  if [[ -z "$PAGE_TOKEN" || "$PAGE_COUNT" -eq 0 ]]; then
    break
  fi

  # 安全阀：最多 50 页
  if [[ $PAGE_NUM -ge 50 ]]; then
    echo "  [WARN] 超过 50 页，中断分页"
    break
  fi
done

LIST_END=$(now_ns)
LIST_MS=$(delta_ms $LIST_START $LIST_END)
LIST_SEC=$(python3 -c "print(f'{$LIST_MS/1000:.1f}')")

echo "  列出 $TOTAL_LISTED 条交易, $PAGE_NUM 页, 耗时 ${LIST_SEC}s"

if [[ $TOTAL_LISTED -ge $TXN_COUNT ]]; then
  pass "ListTransactions 返回 $TOTAL_LISTED 条 (≥$TXN_COUNT)"
else
  fail "ListTransactions 计数" "仅 $TOTAL_LISTED 条，期望 ≥$TXN_COUNT"
fi

##############################################################################
# 5. Dashboard — GetNetWorth
##############################################################################
run_test "DashboardService/GetNetWorth 性能"

NW_START=$(now_ns)
RESP=$(grpc_call_auth dashboard.proto "$TOKEN" \
  -d '{"family_id":""}' \
  "familyledger.dashboard.v1.DashboardService/GetNetWorth")
NW_END=$(now_ns)
NW_MS=$(delta_ms $NW_START $NW_END)

if ! contains_error "$RESP"; then
  NW_TOTAL=$(json_field_from "$RESP" "total")
  pass "GetNetWorth 耗时 ${NW_MS}ms, total=$NW_TOTAL"
else
  fail "GetNetWorth" "$RESP"
  NW_MS="ERR"
fi

##############################################################################
# 6. Dashboard — GetCategoryBreakdown
##############################################################################
run_test "DashboardService/GetCategoryBreakdown 性能"

CB_START=$(now_ns)
RESP=$(grpc_call_auth dashboard.proto "$TOKEN" \
  -d "{\"user_id\":\"$USER_ID\",\"family_id\":\"\",\"year\":2026,\"month\":4,\"type\":\"expense\"}" \
  "familyledger.dashboard.v1.DashboardService/GetCategoryBreakdown")
CB_END=$(now_ns)
CB_MS=$(delta_ms $CB_START $CB_END)

if ! contains_error "$RESP"; then
  CB_TOTAL=$(json_field_from "$RESP" "total")
  CB_ITEMS=$(json_array_len "$RESP" "items")
  pass "GetCategoryBreakdown 耗时 ${CB_MS}ms, total=$CB_TOTAL, categories=$CB_ITEMS"
else
  fail "GetCategoryBreakdown" "$RESP"
  CB_MS="ERR"
fi

##############################################################################
# 性能结果汇总
##############################################################################
echo ""
echo "============================================================"
echo "  === Performance Results ==="
echo "============================================================"
echo ""
echo "  Create $TXN_COUNT txns: ${CREATE_SEC}s (avg ${CREATE_AVG}ms/txn)"
echo "  List all pages:         ${LIST_SEC}s ($TOTAL_LISTED txns, $PAGE_NUM pages)"
echo "  GetNetWorth:            ${NW_MS}ms"
echo "  GetCategoryBreakdown:   ${CB_MS}ms"
echo ""

##############################################################################
# 测试报告
##############################################################################
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
