# FamilyLedger — 测试体系文档

> 截止 2026-04-24 17:50 | 148 commits | 覆盖 6 层测试

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
| auth | 14 | Register, Login, RefreshToken, OAuthLogin (happy + error + auth check) |
| budget | 13 | Create, List, Get, Update, Delete + 子预算 |
| dashboard | 14 | NetWorth, Trend, CategoryBreakdown, BudgetExecution, Recent |
| sync | 6 | PushOperations (replay), PullChanges |
| transaction | 11 | Create, List (cursor pagination), Update, Delete + 边界 |
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

- `db.Pool` 接口定义 4 个方法: `Query`, `QueryRow`, `Exec`, `BeginTx`
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
cd app
http_proxy="" https_proxy="" no_proxy="*" \
  PUB_HOSTED_URL=https://pub.flutter-io.cn \
  FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn \
  flutter test --reporter compact
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

**6 项测试**, 验证大数据量渲染性能：

| 测试 | 验证点 |
|------|--------|
| builds 1000+ items without error | 构建不报错 |
| scrolls to bottom successfully | 滚动到底不崩 |
| only visible items are built | 虚拟化生效（不全量构建） |
| measures build time for 1000+ items | build time < 50ms |
| scroll to middle then to bottom | 跳跃滚动 |
| handles rapid scrolling without crash | 快速滚动稳定性 |

**实测结果**: 1100 条 build time 21ms

---

## L4: gRPC Shell E2E

```bash
bash scripts/e2e-grpc-test.sh
```

**24 个断言**, 纯 `grpcurl` 调用，不需要模拟器。覆盖：

- 注册 + 登录 + JWT token
- 默认账户 + 分类创建
- 交易 CRUD（创建、更新、删除）
- 余额重算（amount_cny）
- 权限校验（不能改/删别人的交易）
- 外币交易余额计算
- 软删除验证

---

## L5: Flutter Integration E2E

```bash
cd app
flutter test integration_test/e2e_grpc_test.dart -d <simulator-id> --reporter=compact
```

**79 个测试**, 在模拟器上运行，覆盖全 13 个 gRPC service：

| 模块 | 测试数 | 覆盖 RPC |
|------|--------|---------|
| Auth | 6 | Register, Login, RefreshToken, OAuthLogin |
| Account | 8 | CRUD + 转账 + 类型 |
| Transaction | 12 | CRUD + 编辑余额 + 软删除 + 分页 |
| Family | 8 | 创建 + 邀请 + 权限 |
| Budget | 6 | CRUD + 子预算 |
| Loan | 10 | 等额本息/本金 + 组合贷 + 提前还款 |
| Investment | 6 | 持仓 + 交易记录 |
| Asset | 6 | 折旧 + 估值 |
| Dashboard | 5 | 净资产 + 趋势 + 分类 |
| Export | 2 | CSV + Excel |
| Import | 3 | GBK + 映射 + 导入 |
| Notify | 4 | 设备注册 + 通知 |
| Sync | 3 | Push + Pull + 冲突 |

---

## L6: Shell 集成测试

位于 `tests/integration/`，需要后端运行。

```bash
# 运行全部
for f in tests/integration/test_*.sh; do bash "$f"; done
```

| 脚本 | 覆盖 | 断言数 |
|------|------|--------|
| `test_basic_services.sh` | Auth + Account + Transaction + Family + Sync + Notify (30 RPCs) | ~10 |
| `test_finance_services.sh` | Loan + Budget + Investment + Asset + Market (35 RPCs) | ~9 |
| `test_finance_services_v2.sh` | 金融服务回归 | ~5 |
| `test_analytics_services.sh` | Dashboard + Export + Import (8 RPCs) | ~8 |
| `test_multi_device_sync.sh` | 双设备同步 E2E (11 cases) | ~9 |
| `test_perf_1000_transactions.sh` | 1000 条批量创建 + 分页 + Dashboard 性能 | ~7 |

### 多设备同步测试场景

1. Device A 创建交易 → Device B pull 可见
2. Device A 编辑交易 → Device B pull 更新
3. Device A 删除交易 → Device B pull 不可见
4. Device A 创建账户 → Device B pull 可见
5. 双设备并发写入 → LWW 冲突解决
6. 离线写入 → 上线后 push → 对端 pull 可见

### 1000 条压测验证点

- 批量创建 1000 条 < 30s
- ListTransactions cursor 分页 < 100ms/page
- Dashboard 聚合查询 < 500ms
- 内存占用无异常增长

---

## 关键测试场景矩阵

### 交易生命周期

| 场景 | Go 单元 | Shell E2E | Integration | Widget |
|------|---------|-----------|-------------|--------|
| 创建交易 | ✅ | ✅ | ✅ | ✅ |
| 编辑金额 | ✅ | ✅ | ✅ | ✅ |
| 编辑后余额重算 | ✅ | ✅ | ✅ | — |
| 软删除 | ✅ | ✅ | ✅ | ✅ |
| 删后余额回退 | ✅ | ✅ | ✅ | — |
| 外币 amount_cny | — | ✅ | ✅ | — |
| 权限校验 | ✅ | ✅ | ✅ | — |
| cursor 分页 | ✅ | — | ✅ | — |

### 数据同步

| 场景 | 测试位置 | 状态 |
|------|---------|------|
| 登录后同步 accounts + categories | Integration + Widget | ✅ |
| 记账 → gRPC push | Integration | ✅ |
| 离线记账 → SyncQueue → 联网推送 | Shell (multi_device_sync) | ✅ |
| SyncEngine replay (transaction/account/category) | Go 单元 | ✅ |
| 多设备冲突 (LWW) | Shell (multi_device_sync) | ✅ |
| WebSocket 通知触发 pull | 手动验证 | ⚠️ 无自动化 |

### OAuth 登录

| 场景 | 测试位置 | 状态 |
|------|---------|------|
| 邮箱注册 → 同步 accounts/categories | Integration + Widget | ✅ |
| 邮箱登录 → 同步 accounts/categories | Integration + Widget | ✅ |
| OAuth 登录 → 同步 accounts/categories | — | ⚠️ Mock 实现，无自动化 |
| OAuth 登录 → 不创建假 account ID | — | ✅ (code fix `583f878`) |

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
docker-compose up -d  # 或手动启动 server
bash scripts/e2e-grpc-test.sh              # 24 assertions, ~10s
for f in tests/integration/test_*.sh; do bash "$f"; done  # 6 scripts, ~30s

# 5. 需要模拟器的测试
cd app && flutter test integration_test/e2e_grpc_test.dart -d <sim>  # 79 tests, ~60s
```

---

## 清理测试数据

```sql
-- 连接 PostgreSQL
psql -h localhost -U familyledger -d familyledger

-- 清理 e2e 测试用户（保留真实用户）
DELETE FROM users WHERE email LIKE 'e2e-%@test.com';
DELETE FROM users WHERE email LIKE 'test%@test.com';

-- 清理 1000 条压测数据
DELETE FROM transactions WHERE note LIKE 'perf_test_%';
```

---

## 已修复的历史问题

| # | 问题 | 修复 commit | 状态 |
|---|------|------------|------|
| 1 | 前端硬删除 vs 后端软删除 | `1e43bbf` Drift v9 softDeleteTransaction | ✅ |
| 2 | Dashboard loadAll() 错误静默忽略 | `2d63109` local-first + error state | ✅ |
| 3 | MarkAsRead 传无效 UUID 预期 | `9f35d58` 修 test 预期 | ✅ |
| 4 | ListTransactions offset 分页性能差 | `b11ebe4` cursor 分页 | ✅ |
| 5 | oauthLogin 创建假 account ID | `583f878` 改为同步服务端账户 | ✅ |
| 6 | SyncEngine account/category 不同步 | `c629ec7` 实现 upsert/delete | ✅ |

## 当前已知限制

| # | 问题 | 影响 | 备注 |
|---|------|------|------|
| 1 | OAuth 登录为 Mock 实现 | 无法真机测试微信/Apple 登录 | 需接真实 SDK |
| 2 | FCM/APNs 推送为 Placeholder | 通知只写 DB 不发推送 | 需接 Firebase |
| 3 | WebSocket 通知无自动化测试 | 手动验证 | 需 ws 客户端工具 |
| 4 | Docker image 未自动重建 | 开发用本地编译的 server | docker-compose build |

---

## CI 集成建议

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  go-unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.22' }
      - run: cd server && go test ./... -count=1

  flutter-widget:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: cd app && flutter test --reporter compact

  e2e:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: familyledger
          POSTGRES_PASSWORD: familyledger
          POSTGRES_DB: familyledger
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.22' }
      - run: |
          cd server && go build -o bin/server ./cmd/server
          DB_HOST=localhost JWT_SECRET=test GRPC_PORT=50051 WS_PORT=8080 \
            ./bin/server &
          sleep 3
      - run: bash scripts/e2e-grpc-test.sh
      - run: |
          for f in tests/integration/test_*.sh; do bash "$f"; done
```
