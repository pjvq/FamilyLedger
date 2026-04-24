# FamilyLedger — 测试体系文档

> 截止 2026-04-24 17:35 | 146 commits | 覆盖 6 层测试

---

## 测试概览

| 层级 | 类型 | 数量 | 耗时 | 覆盖范围 |
|------|------|------|------|---------|
| **L1** | Go 单元测试 (pgxmock) | **242** | ~5s | **14 个 service 全覆盖** |
| **L2** | Flutter Widget 测试 | 566 | ~18s | 31 页面 + 组件 |
| **L3** | Flutter VirtualList 性能测试 | 6 | ~2s | 1000+ 条渲染 |
| **L4** | gRPC Shell E2E | 24 assertions | ~10s | 纯后端 RPC |
| **L5** | Flutter Integration E2E | 79 | ~60s | 模拟器 + gRPC |
| **L6** | Shell 集成测试 (tests/) | 6 脚本 | ~30s | 多设备同步 + 压测 |

**总计**: 242 Go + 566 Widget + 6 Perf + 24 Shell + 79 Integration + 6 脚本 = **~923 测试点**

---

## 环境准备

### 1. 启动后端

```bash
# 方式 A: Docker Compose（完整环境）
cd /Users/qujunping/Projects/FamilyLedger
docker-compose up -d

# 方式 B: 本地编译（开发调试推荐）
docker start familyledger-db          # 只启动 PostgreSQL
cd server && go build -o bin/server ./cmd/server
DB_HOST=localhost DB_PORT=5432 DB_USER=familyledger DB_PASSWORD=familyledger \
  DB_NAME=familyledger DB_SSLMODE=disable \
  JWT_SECRET=familyledger-dev-secret-change-in-production \
  GRPC_PORT=50051 WS_PORT=8080 ./bin/server
```

### 2. 验证后端

```bash
grpcurl -plaintext -import-path proto -proto auth.proto \
  -d '{"email":"ping@test.com","password":"Test123!"}' \
  localhost:50051 familyledger.auth.v1.AuthService/Register
```

---

## L1: Go 单元测试

使用 `pgxmock/v4` mock 数据库 + `testify` 断言。所有 15 个 service 已重构为 `db.Pool` 接口（`server/pkg/db/pool.go`），支持 mock 注入。

```bash
cd server && go test ./... -count=1 -v
```

| Package | Tests | 覆盖方法 |
|---------|-------|---------|
| account | 10 | Create, List, Get, Update, Delete |
| auth | 14 | Register, Login, RefreshToken, OAuthLogin |
| budget | 13 | Create, List, Get, Update, Delete + 子预算 |
| dashboard | 14 | NetWorth, Trend, CategoryBreakdown, BudgetExecution, Recent |
| sync | 6 | PushOperations (replay), PullChanges |
| transaction | 11 | Create, List (cursor), Update, Delete + 边界 |
| **loan** | **34** | CreateLoan, GetLoan, ListLoans, UpdateLoan, DeleteLoan, GetLoanSchedule, RecordPayment, SimulatePrepayment, generateSchedule 纯逻辑, advanceMonths |
| **asset** | **31** | CRUD, 估值, 折旧规则, 纯逻辑（直线法/双倍余额法）, 类型转换 |
| **investment** | **29** | CRUD, 交易记录（买入/卖出超额）, 验证, 类型转换 |
| **family** | **17** | 创建/加入/离开, 邀请码权限, 角色设置, 成员列表 |
| **notify** | **22** | 设备注册/注销, 通知设置, 列表/分页, 已读标记, CreateNotification |
| **importcsv** | **16** | CSV 解析, GBK/UTF-8 编码, 字段提取, 日期格式 |
| **market** | **17** | 行情缓存, 批量查询, 搜索回退, 价格历史, 类型转换 |
| **export** | **14** | CSV/Excel/PDF 三格式, 日期校验, 金额转换 |
| **合计** | **242** | **14 个 service 全覆盖** |

### 关键设计

- `db.Pool` 接口定义 4 个方法: `Query`, `QueryRow`, `Exec`, `Begin`
- `*pgxpool.Pool` 自动满足接口（零适配代码）
- 每个 test 创建独立 mock pool，无共享状态
- 覆盖 happy path + error path + 权限校验 + 纯逻辑算法

### 关键 commits

- `3b61a4b` — 初始 68 tests (account, auth, budget, dashboard, sync, transaction)
- `fa70666` — loan 34 tests (638 行)
- `7ae8578` — 剩余 7 service 140 tests (2253 行)

---

## L2: Flutter Widget 测试

```bash
cd app && flutter test --reporter compact
```

**566 tests**, 覆盖全部 31 个页面 + 核心组件：

| 测试文件 | 覆盖范围 |
|---------|---------|
| `transaction_home_test.dart` | 交易列表、历史页、详情页 |
| `home_transaction_test.dart` | 首页 + 交易创建 |
| `auth_settings_test.dart` | 登录、注册、设置页 |
| `budget_loan_test.dart` | 预算 + 贷款页面 |
| `investment_asset_test.dart` | 投资 + 固定资产 |
| `dashboard_report_test.dart` | Dashboard + 导出 + CSV导入 |
| `account_more_test.dart` | 账户 + 更多页面 |
| `loan_test.dart` | 贷款详情 + 组合贷 |
| `core_widgets_test.dart` | 空状态、骨架屏、SwipeToDelete 等组件 |
| `settings_notification_test.dart` | 设置 + 通知 |

---

## L3: VirtualList 性能测试

```bash
cd app && flutter test test/perf_virtual_list_test.dart
```

**6 项测试**, 验证大数据量渲染性能。实测 1100 条 build time 21ms。

---

## L4: gRPC Shell E2E

```bash
bash scripts/e2e-grpc-test.sh
```

**24 个断言**, 纯 `grpcurl` 调用。覆盖注册/登录/JWT、CRUD、余额重算、权限校验、外币、软删除。

---

## L5: Flutter Integration E2E

```bash
cd app && flutter test integration_test/e2e_grpc_test.dart -d <simulator-id>
```

**79 个测试**, 覆盖全 13 个 gRPC service。

---

## L6: Shell 集成测试

位于 `tests/integration/`，6 个脚本，覆盖多设备同步 + 1000 条压测。

---

## 运行顺序（推荐）

```bash
# 1. Go 单元测试（不需要数据库）
cd server && go test ./... -count=1          # 242 tests, ~5s

# 2. Flutter Widget 测试（不需要后端）
cd app && flutter test --reporter compact    # 566 tests, ~18s

# 3. VirtualList 性能测试
cd app && flutter test test/perf_virtual_list_test.dart  # 6 tests, ~2s

# 4. 需要后端运行的测试
docker-compose up -d
bash scripts/e2e-grpc-test.sh
for f in tests/integration/test_*.sh; do bash "$f"; done

# 5. 需要模拟器的测试
cd app && flutter test integration_test/e2e_grpc_test.dart -d <sim>
```

---

## 已知限制

| # | 问题 | 影响 |
|---|------|------|
| 1 | OAuth 登录为 Mock | 无法真机测试微信/Apple 登录 |
| 2 | FCM/APNs 推送为 Placeholder | 通知只写 DB 不发推送 |
| 3 | WebSocket 通知无自动化测试 | 手动验证 |
