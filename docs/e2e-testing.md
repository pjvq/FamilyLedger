# FamilyLedger — 前后端联调测试方法

> 可复现、可反复运行、可 CI 集成

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

### 3. 启动 iOS 模拟器

```bash
xcrun simctl boot "iPhone 17"  # 或其他设备
open -a Simulator
```

---

## 测试层次

### Layer 1: gRPC Shell 测试（最快，纯后端）

```bash
bash scripts/e2e-grpc-test.sh
```

**特点**: 不需要模拟器，纯 grpcurl 调用，18 个断言，10 秒内完成。
**覆盖**: 注册、账户、分类、交易 CRUD、余额重算、权限校验、边界情况。

### Layer 2: Flutter Integration Test（模拟器 + gRPC）

```bash
cd app
flutter test integration_test/e2e_grpc_test.dart \
  -d <simulator-id> --reporter=compact
```

**特点**: 在模拟器上运行，80 个测试用例，含 gRPC 直调 + UI 交互。
**覆盖**: 全 13 个模块（Auth, Account, Transaction, Loan, Budget, Investment, Asset, Dashboard, Export, Import, Family, Notify）+ UI 注册→首页流程。

### Layer 3: 手动 + 脚本混合测试

当自动测试无法覆盖的交互场景：

```bash
# 1. 在模拟器中安装 app
cd app && flutter run -d <simulator-id>

# 2. 通过 grpcurl 在后端插入测试数据
TOKEN=$(grpcurl ... AuthService/Login | grep accessToken | ...)
grpcurl ... TransactionService/CreateTransaction ...

# 3. 在 app 中验证数据是否正确显示
# 4. 在 app 中操作，通过 grpcurl 验证后端数据
```

---

## 关键测试场景

### 交易编辑与删除（Phase 1b）

| # | 场景 | 验证点 | 方法 |
|---|------|--------|------|
| 1 | 创建交易 | 本地 + 服务端都有 | Integration Test 1.5 |
| 2 | 编辑金额 | amount + amountCny 同步更新 | Shell Test + IT 1.7 |
| 3 | 编辑后余额 | 账户余额正确重算 | Shell Test + IT 1.7b |
| 4 | 改类型 | expense↔income，余额翻转 | IT 1.7c + 1.7d |
| 5 | 权限校验 | 不能改/删别人的交易 | Shell Test + IT 1.8 |
| 6 | 软删除 | 设 deleted_at，不物理删 | Shell Test + IT 1.9 |
| 7 | 删后不可见 | ListTransactions 不返回 | IT 1.9b |
| 8 | 删后余额 | 金额回退，用 amountCny | Shell Test + IT 1.9c |
| 9 | 重复删除 | NOT_FOUND | IT 1.9d |
| 10 | 外币余额 | 余额用 amountCny 计算 | 手动（USD 记账→编辑→验证余额） |

### 数据同步

| # | 场景 | 验证点 |
|---|------|--------|
| 1 | 登录后同步 | accounts + categories 从服务端拉到本地 |
| 2 | 记账同步 | 本地写入 → gRPC push → 服务端有记录 |
| 3 | 离线记账 | gRPC 失败 → SyncQueue 有记录 → 联网后自动推 |
| 4 | Dashboard 刷新 | 记账/编辑/删除后自动调 loadAll() |

---

## 运行顺序（推荐）

```
1. bash scripts/e2e-grpc-test.sh                    # 18 tests, ~10s
2. cd app && flutter test --reporter=compact         # 560 widget tests, ~15s
3. flutter test integration_test/ -d <sim>           # 80 e2e tests, ~60s
```

## 清理测试数据

```sql
-- 连接 PostgreSQL
psql -h localhost -U familyledger -d familyledger

-- 清理 e2e 测试用户（保留真实用户）
DELETE FROM users WHERE email LIKE 'e2e-%@test.com';
```

---

## 已知问题 & 待修

| # | 问题 | 严重度 | 状态 |
|---|------|--------|------|
| 1 | 前端 deleteTransaction 是硬删除，后端是软删除 | P2 | 需加 Drift migration |
| 2 | Dashboard loadAll() 错误静默忽略 | P3 | 需要 error state 通知 UI |
| 3 | Docker image 未自动重建 | P3 | 开发时用本地编译的 server |
| 4 | MarkAsRead 传无效 UUID 返回 INVALID_ARGUMENT | P4 | 已修 test 预期 |

---

## CI 集成建议

```yaml
# .github/workflows/e2e.yml
jobs:
  e2e:
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_USER: familyledger, ... }
    steps:
      - run: cd server && go build && ./bin/server &
      - run: bash scripts/e2e-grpc-test.sh
      - run: cd app && flutter test integration_test/
```
