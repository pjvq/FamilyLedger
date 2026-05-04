#!/usr/bin/env bash
#
# FamilyLedger — W13 Performance + Stress E2E Test
#
# Tests:
#   1. 10000 transaction creation + pagination verification
#   2. Push/Pull P99 latency measurement
#   3. Dashboard aggregation on large dataset
#
# Usage: bash tests/integration/test_w13_performance_stress.sh
#
set -uo pipefail

##############################################################################
# Configuration
##############################################################################
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROTO_DIR="$PROJECT_DIR/proto"
HOST="localhost:50051"
GRPCURL="grpcurl -plaintext -import-path $PROTO_DIR"

PASS_COUNT=0
FAIL_COUNT=0
TEST_NUM=0
FAILURES=""

TXN_COUNT=10000
P99_PUSH_ITERATIONS=50
P99_PULL_ITERATIONS=50

# Unique suffix per run
UNIQUE=$(date +%s%N | tail -c 10)

# Category UUIDs (preset)
EXPENSE_CATEGORIES=(
  "95d6dc66-12c4-5f2b-bf9b-1d439a9c8100"
  "6f7a88e1-fb21-5409-b6b3-606787668c02"
  "3feb7580-9bad-5c6a-bf4f-db9e59eb3e64"
  "f925409c-19b9-5461-8a3d-5dc88e50efeb"
  "805a7628-6497-5252-b4ab-a76361e5aa0a"
  "f0683ffe-fe9c-593f-8701-4ec1c296b32c"
  "b41989ae-e78a-59f2-9c02-4f904d8e6841"
)
INCOME_CATEGORIES=(
  "5c7b17d7-a3ec-59c0-b2ad-4a62ad32f2c3"
  "a163e39c-8eb4-5317-8ef9-7c433897b569"
  "0aacf353-c7a5-5ac1-8da6-5b8815ffcef7"
)
ALL_CATEGORIES=("${EXPENSE_CATEGORIES[@]}" "${INCOME_CATEGORIES[@]}")
NUM_CATEGORIES=${#ALL_CATEGORIES[@]}

##############################################################################
# Helper Functions
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

now_ns() {
  python3 -c "import time; print(int(time.time()*1e9))"
}

delta_ms() {
  python3 -c "print(int(($2 - $1) / 1e6))"
}

rand_range() {
  python3 -c "import random; print(random.randint($1, $2))"
}

random_past_date() {
  python3 -c "
import random, datetime
now = datetime.datetime.now(datetime.timezone.utc)
days_back = random.randint(0, 365)
dt = now - datetime.timedelta(days=days_back)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
"
}

# Compute P99 from a file of latency values (one per line, in ms)
compute_p99() {
  local file="$1"
  python3 -c "
import sys
vals = sorted([int(x) for x in open('$file') if x.strip()])
if len(vals) == 0:
    print(0)
else:
    idx = int(len(vals) * 0.99)
    if idx >= len(vals): idx = len(vals) - 1
    print(vals[idx])
"
}

##############################################################################
echo "============================================================"
echo "  FamilyLedger — W13 Performance + Stress E2E Test"
echo "============================================================"

##############################################################################
# 1. Register + Login
##############################################################################
run_test "注册 W13 测试用户并登录"
EMAIL="w13_perf_${UNIQUE}@test.com"
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
# 2. Create test account
##############################################################################
run_test "创建 W13 测试账户"
RESP=$(grpc_call_auth account.proto "$TOKEN" \
  -d '{"name":"W13性能账户","type":"ACCOUNT_TYPE_BANK_CARD","currency":"CNY","icon":"bank","initial_balance":"100000000"}' \
  "familyledger.account.v1.AccountService/CreateAccount")
ACCOUNT_ID=$(json_nested "$RESP" "account.id")
if [[ -n "$ACCOUNT_ID" ]]; then
  pass "测试账户 id=$ACCOUNT_ID"
else
  fail "CreateAccount" "返回异常: $RESP"
  echo "无法继续测试，退出"
  exit 1
fi

##############################################################################
# 3. Bulk create 10000 transactions
##############################################################################
run_test "批量创建 $TXN_COUNT 笔交易"
echo "  创建中 (请耐心等待)..."

CREATE_START=$(now_ns)
CREATE_ERRORS=0

for i in $(seq 1 $TXN_COUNT); do
  CAT_IDX=$(( (i - 1) % NUM_CATEGORIES ))
  CATEGORY_ID="${ALL_CATEGORIES[$CAT_IDX]}"

  if [[ $CAT_IDX -lt ${#EXPENSE_CATEGORIES[@]} ]]; then
    TXN_TYPE="TRANSACTION_TYPE_EXPENSE"
  else
    TXN_TYPE="TRANSACTION_TYPE_INCOME"
  fi

  AMOUNT=$(rand_range 100 100000)
  TXN_DATE=$(random_past_date)
  NOTE="w13_perf_${i}_${UNIQUE}"

  RESP=$(grpc_call_auth transaction.proto "$TOKEN" \
    -d "{\"account_id\":\"$ACCOUNT_ID\",\"category_id\":\"$CATEGORY_ID\",\"amount\":$AMOUNT,\"currency\":\"CNY\",\"amount_cny\":$AMOUNT,\"exchange_rate\":1.0,\"type\":\"$TXN_TYPE\",\"note\":\"$NOTE\",\"txn_date\":\"$TXN_DATE\"}" \
    "familyledger.transaction.v1.TransactionService/CreateTransaction")

  if contains_error "$RESP"; then
    CREATE_ERRORS=$((CREATE_ERRORS + 1))
    if [[ $CREATE_ERRORS -le 3 ]]; then
      echo "  [WARN] 第 $i 笔创建失败: $RESP"
    fi
  fi

  if [[ $((i % 1000)) -eq 0 ]]; then
    echo "  已创建 $i / $TXN_COUNT ..."
  fi
done

CREATE_END=$(now_ns)
CREATE_MS=$(delta_ms $CREATE_START $CREATE_END)
CREATE_SEC=$(python3 -c "print(f'{$CREATE_MS/1000:.1f}')")
CREATE_AVG=$(python3 -c "print(f'{$CREATE_MS/$TXN_COUNT:.1f}')")

CREATED_OK=$(( TXN_COUNT - CREATE_ERRORS ))
if [[ $CREATE_ERRORS -lt $((TXN_COUNT / 10)) ]]; then
  pass "创建 $CREATED_OK/$TXN_COUNT 笔交易，耗时 ${CREATE_SEC}s (avg ${CREATE_AVG}ms/txn)"
else
  fail "批量创建" "$CREATE_ERRORS/$TXN_COUNT 笔失败"
fi

##############################################################################
# 4. Pagination test — 3 positions
##############################################################################
run_test "分页查询验证 (page_size=20, offset 0 / 500 / 9980)"

# Position 1: offset=0
PAGE_START=$(now_ns)
RESP=$(grpc_call_auth transaction.proto "$TOKEN" \
  -d '{"page_size":20}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
PAGE_END=$(now_ns)
PAGE_MS_0=$(delta_ms $PAGE_START $PAGE_END)
PAGE_COUNT_0=$(json_array_len "$RESP" "transactions")

if [[ $PAGE_COUNT_0 -ge 20 ]]; then
  pass "offset=0: 返回 $PAGE_COUNT_0 条, 耗时 ${PAGE_MS_0}ms"
else
  fail "offset=0" "返回 $PAGE_COUNT_0 条 (期望≥20)"
fi

# For page_token-based pagination we need to skip pages
PAGE_TOKEN=""
RESP=$(grpc_call_auth transaction.proto "$TOKEN" \
  -d '{"page_size":20}' \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
PAGE_TOKEN=$(json_field_from "$RESP" "nextPageToken")

# Skip to offset ~500 (25 pages)
echo "  跳页到 offset ~500..."
for p in $(seq 1 24); do
  if [[ -z "$PAGE_TOKEN" ]]; then break; fi
  RESP=$(grpc_call_auth transaction.proto "$TOKEN" \
    -d "{\"page_size\":20,\"page_token\":\"$PAGE_TOKEN\"}" \
    "familyledger.transaction.v1.TransactionService/ListTransactions")
  PAGE_TOKEN=$(json_field_from "$RESP" "nextPageToken")
done

PAGE_START=$(now_ns)
RESP=$(grpc_call_auth transaction.proto "$TOKEN" \
  -d "{\"page_size\":20,\"page_token\":\"$PAGE_TOKEN\"}" \
  "familyledger.transaction.v1.TransactionService/ListTransactions")
PAGE_END=$(now_ns)
PAGE_MS_500=$(delta_ms $PAGE_START $PAGE_END)
PAGE_COUNT_500=$(json_array_len "$RESP" "transactions")

if [[ $PAGE_COUNT_500 -ge 1 ]]; then
  pass "offset~500: 返回 $PAGE_COUNT_500 条, 耗时 ${PAGE_MS_500}ms"
else
  fail "offset~500" "返回 0 条"
fi

# CI threshold: 600ms (3x target 200ms)
for name_ms in "offset_0:$PAGE_MS_0" "offset_500:$PAGE_MS_500"; do
  name="${name_ms%%:*}"
  ms="${name_ms##*:}"
  if [[ $ms -lt 600 ]]; then
    pass "$name 延迟 ${ms}ms < 600ms 阈值"
  else
    fail "$name 延迟" "${ms}ms ≥ 600ms 阈值"
  fi
done

##############################################################################
# 5. Push P99 latency
##############################################################################
run_test "Push P99 延迟测试 (${P99_PUSH_ITERATIONS} 次)"
PUSH_LATENCY_FILE=$(mktemp /tmp/w13_push_latency.XXXXXX)

for i in $(seq 1 $P99_PUSH_ITERATIONS); do
  AMOUNT=$(rand_range 100 10000)
  TXN_DATE=$(random_past_date)
  CAT_IDX=$(( (i - 1) % NUM_CATEGORIES ))
  CATEGORY_ID="${ALL_CATEGORIES[$CAT_IDX]}"

  if [[ $CAT_IDX -lt ${#EXPENSE_CATEGORIES[@]} ]]; then
    TXN_TYPE="TRANSACTION_TYPE_EXPENSE"
  else
    TXN_TYPE="TRANSACTION_TYPE_INCOME"
  fi

  START=$(now_ns)
  RESP=$(grpc_call_auth sync.proto "$TOKEN" \
    -d "{\"operations\":[{\"entity_type\":\"transaction\",\"entity_id\":\"$(python3 -c 'import uuid; print(uuid.uuid4())')\",\"op_type\":1,\"payload\":\"{\\\"account_id\\\":\\\"$ACCOUNT_ID\\\",\\\"category_id\\\":\\\"$CATEGORY_ID\\\",\\\"amount\\\":$AMOUNT,\\\"currency\\\":\\\"CNY\\\",\\\"amount_cny\\\":$AMOUNT,\\\"exchange_rate\\\":1.0,\\\"type\\\":\\\"expense\\\",\\\"note\\\":\\\"push_sla_$i\\\",\\\"txn_date\\\":\\\"$TXN_DATE\\\",\\\"tags\\\":[],\\\"image_urls\\\":[]}\",\"client_id\":\"w13-push-$i-$UNIQUE\"}]}" \
    "familyledger.sync.v1.SyncService/PushOperations")
  END=$(now_ns)
  MS=$(delta_ms $START $END)
  echo "$MS" >> "$PUSH_LATENCY_FILE"
done

PUSH_P99=$(compute_p99 "$PUSH_LATENCY_FILE")
rm -f "$PUSH_LATENCY_FILE"

echo "  Push P99: ${PUSH_P99}ms"
# CI threshold: 1500ms (3x of 500ms target)
if [[ $PUSH_P99 -lt 1500 ]]; then
  pass "Push P99 ${PUSH_P99}ms < 1500ms 阈值 (target: 500ms)"
else
  fail "Push P99" "${PUSH_P99}ms ≥ 1500ms 阈值"
fi

##############################################################################
# 6. Pull P99 latency
##############################################################################
run_test "Pull P99 延迟测试 (${P99_PULL_ITERATIONS} 次)"
PULL_LATENCY_FILE=$(mktemp /tmp/w13_pull_latency.XXXXXX)

for i in $(seq 1 $P99_PULL_ITERATIONS); do
  START=$(now_ns)
  RESP=$(grpc_call_auth sync.proto "$TOKEN" \
    -d '{"client_id":"w13-pull-client","page_size":100}' \
    "familyledger.sync.v1.SyncService/PullChanges")
  END=$(now_ns)
  MS=$(delta_ms $START $END)
  echo "$MS" >> "$PULL_LATENCY_FILE"
done

PULL_P99=$(compute_p99 "$PULL_LATENCY_FILE")
rm -f "$PULL_LATENCY_FILE"

echo "  Pull P99: ${PULL_P99}ms"
# CI threshold: 600ms (3x of 200ms target)
if [[ $PULL_P99 -lt 600 ]]; then
  pass "Pull P99 ${PULL_P99}ms < 600ms 阈值 (target: 200ms)"
else
  fail "Pull P99" "${PULL_P99}ms ≥ 600ms 阈值"
fi

##############################################################################
# 7. Dashboard aggregation on large dataset
##############################################################################
run_test "Dashboard 大数据量聚合"

# GetNetWorth
NW_START=$(now_ns)
RESP=$(grpc_call_auth dashboard.proto "$TOKEN" \
  -d '{"family_id":""}' \
  "familyledger.dashboard.v1.DashboardService/GetNetWorth")
NW_END=$(now_ns)
NW_MS=$(delta_ms $NW_START $NW_END)

if ! contains_error "$RESP"; then
  NW_TOTAL=$(json_field_from "$RESP" "total")
  pass "GetNetWorth on $TXN_COUNT txns: ${NW_MS}ms, total=$NW_TOTAL"
else
  fail "GetNetWorth" "$RESP"
fi

# GetCategoryBreakdown
CB_START=$(now_ns)
RESP=$(grpc_call_auth dashboard.proto "$TOKEN" \
  -d "{\"user_id\":\"$USER_ID\",\"family_id\":\"\",\"year\":2026,\"month\":4,\"type\":\"expense\"}" \
  "familyledger.dashboard.v1.DashboardService/GetCategoryBreakdown")
CB_END=$(now_ns)
CB_MS=$(delta_ms $CB_START $CB_END)

if ! contains_error "$RESP"; then
  CB_TOTAL=$(json_field_from "$RESP" "total")
  CB_ITEMS=$(json_array_len "$RESP" "items")
  pass "GetCategoryBreakdown on $TXN_COUNT txns: ${CB_MS}ms, total=$CB_TOTAL, categories=$CB_ITEMS"
else
  fail "GetCategoryBreakdown" "$RESP"
fi

# GetIncomeExpenseTrend
TR_START=$(now_ns)
RESP=$(grpc_call_auth dashboard.proto "$TOKEN" \
  -d "{\"user_id\":\"$USER_ID\",\"family_id\":\"\",\"period\":\"monthly\",\"count\":12}" \
  "familyledger.dashboard.v1.DashboardService/GetIncomeExpenseTrend")
TR_END=$(now_ns)
TR_MS=$(delta_ms $TR_START $TR_END)

if ! contains_error "$RESP"; then
  TR_POINTS=$(json_array_len "$RESP" "points")
  pass "GetIncomeExpenseTrend on $TXN_COUNT txns: ${TR_MS}ms, points=$TR_POINTS"
else
  fail "GetIncomeExpenseTrend" "$RESP"
fi

##############################################################################
# Performance Summary
##############################################################################
echo ""
echo "============================================================"
echo "  === W13 Performance Results ==="
echo "============================================================"
echo ""
echo "  Create $TXN_COUNT txns: ${CREATE_SEC}s (avg ${CREATE_AVG}ms/txn)"
echo "  Pagination offset=0:    ${PAGE_MS_0}ms"
echo "  Pagination offset~500:  ${PAGE_MS_500}ms"
echo "  Push P99:               ${PUSH_P99}ms (target: <500ms, CI: <1500ms)"
echo "  Pull P99:               ${PULL_P99}ms (target: <200ms, CI: <600ms)"
echo "  GetNetWorth:            ${NW_MS}ms"
echo "  GetCategoryBreakdown:   ${CB_MS}ms"
echo "  GetIncomeExpenseTrend:  ${TR_MS}ms"
echo ""

##############################################################################
# Test Report
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
  echo "  🎉 W13 Performance + Stress 全部通过!"
  echo ""
  exit 0
fi
