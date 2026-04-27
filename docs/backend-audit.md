# FamilyLedger 后端审计报告

**审计日期**: 2026-04-27  
**代码统计**: ~43,700 行 Go，79 个源文件，18 个 test package  
**技术栈**: Go 1.24 + gRPC + PostgreSQL 16 + WebSocket + golang-migrate  
**测试**: 330 test functions 全绿（~94s）

---

## 1. 整体评估

### 实际测试能力

| 维度 | 评分 | 说明 |
|------|------|------|
| Service 单元测试 | ⭐⭐⭐⭐ | 14 个 service 全覆盖，pgxmock 隔离 |
| SQL 正确性 | ⭐⭐ | pgxmock 验证 SQL 被调用，但不验证 SQL 逻辑本身 |
| 集成测试（真实 DB） | ❌ | 零。所有测试都是 mock |
| 基础设施测试 | ⭐⭐ | jwt/middleware/db/permission/category 全部无测试 |
| 错误路径覆盖 | ⭐⭐⭐ | 大部分 service 测了 error path |
| 并发/竞态 | ❌ | 无并发测试 |
| 性能/压测 | ❌ | 无 benchmark |
| 端到端 | ⭐⭐⭐ | Shell 脚本 E2E 覆盖主流程 |

### 总结

**Service 层测试充足但全是 mock；基础设施层零测试；无集成测试验证真实 SQL。**

pgxmock 能验证「代码调用了正确的 SQL」，但不能验证「SQL 在真实 PostgreSQL 上执行结果正确」。一旦 SQL 有拼写错误、JOIN 条件遗漏、类型不匹配，mock 测试无法发现。

---

## 2. 测试分布

### 有测试的 (18 packages, 7940 行测试代码)

| Package | Tests | 行数 | 测试质量 |
|---------|-------|------|---------|
| `internal/dashboard` | ~40 | 877 | ⭐⭐⭐⭐ 覆盖 6 个 API + 家庭/个人隔离 |
| `internal/transaction` | ~35 | 864 | ⭐⭐⭐⭐ CRUD + 权限 + 家庭 |
| `internal/notify` | ~30 | 740 | ⭐⭐⭐⭐ 提醒 + 信用卡 + 自定义 |
| `internal/loan` | 34 | 638 | ⭐⭐⭐⭐⭐ 最完整，含纯逻辑算法测试 |
| `internal/investment` | 29 | 621 | ⭐⭐⭐⭐ CRUD + IRR |
| `internal/asset` | 31 | 560 | ⭐⭐⭐⭐ 折旧纯逻辑 + CRUD |
| `internal/sync` | ~20 | 486+172 | ⭐⭐⭐ Push/Pull + entity_ops |
| `internal/budget` | 13 | 462 | ⭐⭐⭐ CRUD + 家庭执行率 |
| `internal/family` | 17 | 387 | ⭐⭐⭐ 创建/邀请/权限/审计 |
| `internal/auth` | ~20 | 332+111 | ⭐⭐⭐ JWT + OAuth Provider |
| `internal/export` | 14 | 287 | ⭐⭐⭐ 三格式 + 全量备份 |
| `internal/account` | 10 | 270 | ⭐⭐⭐ 基本 CRUD |
| `internal/importcsv` | 16 | 267 | ⭐⭐⭐ 解析 + session |
| `internal/market` | ~39 | 242+175 | ⭐⭐⭐⭐ 行情 + 交易时段 |
| `pkg/ws` | 7 | 208 | ⭐⭐⭐ Ping-Pong + 广播 |
| `pkg/config` | 11 | ~100 | ⭐⭐⭐⭐ JWT 配置校验全分支 |
| `pkg/storage` | 9 | 107 | ⭐⭐⭐ Local + S3 接口 |
| `pkg/audit` | 5 | ~55 | ⭐⭐⭐ 审计日志 helper |

### 无测试的 (5 packages, 362 行业务代码)

| Package | 行数 | 风险 | 说明 |
|---------|------|------|------|
| `pkg/jwt` | 89 | 🔴 高 | JWT 签发/验证/过期逻辑。错误直接导致认证绕过 |
| `pkg/middleware` | 109 | 🔴 高 | gRPC 拦截器，解析 token → 注入 userID。错误导致鉴权失效 |
| `pkg/permission` | 88 | 🟡 中 | 家庭权限检查。错误导致越权 |
| `pkg/db` | 61 | 🟢 低 | 连接池封装，逻辑简单 |
| `pkg/category` | 15 | 🟢 低 | UUID 生成，确定性逻辑 |
| `cmd/server/main.go` | 370 | 🟡 中 | 服务启动编排、定时任务注册。配置错误导致服务异常 |

---

## 3. pgxmock 的局限性

### pgxmock 能发现的问题

✅ SQL 字符串拼接错误（忘写 WHERE）  
✅ 参数数量/顺序不匹配  
✅ Row scan 字段数量不对  
✅ 错误处理路径（返回 pgx.ErrNoRows 等）  
✅ 业务逻辑分支（if familyId != "" 等）

### pgxmock 不能发现的问题

❌ SQL 语法在真实 PostgreSQL 上是否能执行  
❌ JOIN 条件是否正确（mock 直接返回你预设的 rows）  
❌ 索引是否生效（性能问题）  
❌ 并发事务死锁  
❌ Migration 后数据兼容性  
❌ NULL 处理（`COALESCE`、`IS NULL` vs `= NULL`）  
❌ 时区处理（`TIMESTAMP` vs `TIMESTAMPTZ`）

### 现实例子

dashboard/service.go 有这样的 SQL：
```sql
WHERE i.user_id = $1 AND i.deleted_at IS NULL AND i.quantity > 0
```
如果改成：
```sql
WHERE i.user_id = $1 AND i.deleted_at = NULL AND i.quantity > 0
```
pgxmock 测试仍然通过（因为 mock 匹配的是 regex/query 字符串，不执行 SQL），但真实 DB 上永远返回 0 行。

---

## 4. 优先修复清单

### P0 — 必须补充

| # | 缺失 | 风险 | 建议 |
|---|------|------|------|
| 1 | `pkg/jwt` 测试 | 认证绕过 | 测：签发、验证、过期、篡改 payload、错误 secret |
| 2 | `pkg/middleware` 测试 | 鉴权失效 | 测：valid token → userID 注入、expired → Unauthenticated、missing → Unauthenticated |
| 3 | 集成测试（真实 PostgreSQL） | SQL 错误 | 用 `testcontainers-go` 启动 PG 容器，测关键 SQL 路径 |
| 4 | `pkg/permission` 测试 | 越权操作 | 测 5 种权限组合 × 允许/拒绝 |

### P1 — 应该补充

| # | 缺失 | 风险 | 建议 |
|---|------|------|------|
| 5 | 并发测试 | 竞态 bug | 测：两个 goroutine 同时操作同一笔交易 |
| 6 | Migration 链测试 | 升级崩溃 | 测 v001→v038 逐步执行无报错 |
| 7 | WebSocket 并发广播 | 内存泄漏 | 测：1000 个 client 同时连接 + 广播 |
| 8 | `cmd/server/main.go` 配置测试 | 启动失败 | 测：缺少环境变量时的行为 |

### P2 — 建议补充

| # | 缺失 | 说明 |
|---|------|------|
| 9 | Benchmark | 关键路径性能基线（ListTransactions 1000 条、Dashboard 聚合） |
| 10 | SQL 注入测试 | 虽然用了 `$1` 参数化，但值得验证 |
| 11 | 大数据量测试 | 10 万条交易时 Dashboard 性能 |
| 12 | 定时任务测试 | CheckBudgets/CheckCreditCard 在各种边界时间 |

---

## 5. 代码质量指标

| 指标 | 数值 | 评价 |
|------|------|------|
| 源文件数 | 79 | 合理 |
| 测试文件数 | 21 | 合理（含 test helper） |
| 测试/源码行比 | 7,940 / 43,700 = 18% | 偏低（健康值 30-50%） |
| Service 测试覆盖 | 14/14 = 100% | ✅ |
| Pkg 测试覆盖 | 4/9 = 44% | ⚠️ 关键包无测试 |
| 集成测试 | 0 | ❌ |
| Benchmark | 0 | ❌ |
| test function 密度 | 330/79 = 4.2 tests/file | 偏低 |

---

## 6. pgxmock 测试质量分析

### 好的模式（值得保留）

```go
// loan/service_test.go — 纯逻辑测试（不依赖 mock）
func TestGenerateSchedule_EqualPrincipal(t *testing.T) {
    schedule := generateSchedule(500000_00, 4.1, 360, time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC), "equal_principal")
    assert.Equal(t, 360, len(schedule))
    assert.InDelta(t, 500000_00, totalPrincipal(schedule), 1)
}
```
✅ 不依赖 mock，直接测试纯函数逻辑。

### 有问题的模式

```go
// 大量测试的模式：
mock.ExpectQuery("SELECT .+ FROM transactions").
    WithArgs(testUserID).
    WillReturnRows(someRows)

result, err := svc.ListTransactions(ctx, req)
assert.NoError(t, err)
assert.Len(t, result.Transactions, 2)
```
⚠️ 只验证了「收到预设的 rows 后能正确拼装 response」，不验证 SQL 本身是否正确。

### 理想的补充方式

```go
// integration_test.go — 用 testcontainers
func TestListTransactions_RealDB(t *testing.T) {
    ctx := context.Background()
    pg := startPostgres(t)  // testcontainers
    defer pg.Terminate(ctx)
    
    pool := connectAndMigrate(t, pg)
    svc := NewService(pool)
    
    // 插入真实数据
    insertTestUser(t, pool, "user1")
    insertTestTransaction(t, pool, "user1", 10000, "food")
    
    // 测试
    result, err := svc.ListTransactions(authedCtx("user1"), &pb.ListTransactionsRequest{})
    require.NoError(t, err)
    assert.Len(t, result.Transactions, 1)
    assert.Equal(t, int64(10000), result.Transactions[0].Amount)
}
```

---

## 7. 安全审计

| 检查项 | 状态 | 说明 |
|--------|------|------|
| SQL 注入 | ✅ 安全 | 全部使用 `$1` 参数化查询 |
| JWT Secret | ✅ | 生产环境强制 ≥32 字符 |
| 密码存储 | ✅ | bcrypt hash |
| 权限检查 | ⚠️ | 有实现但无独立测试 |
| Rate limiting | ❌ | 无。注册/登录可被暴力尝试 |
| Input validation | ⚠️ | 部分有（金额>0），部分缺失（字符串长度上限） |
| Error 信息泄露 | ⚠️ | 部分错误直接返回内部细节 |
| CORS | ✅ | gRPC 无此问题 |
| TLS | ⚠️ | 代码支持但本地开发用 plaintext |

---

## 8. 结论

**后端测试比前端健康**——至少每个 service 都有 mock 测试验证业务分支。但存在两个结构性问题：

1. **零集成测试**：所有 SQL 只经过 mock 验证，真实 DB 行为未测试。这意味着 migration 改了表结构后，如果忘改 SQL，mock 测试不会报错。
2. **基础设施无测试**：`pkg/jwt` 和 `pkg/middleware` 是整个系统的安全边界，89+109 行代码零测试覆盖。

最紧迫的是补充 `pkg/jwt` + `pkg/middleware` 的单元测试（~20 个 test function 就能覆盖全部分支），以及用 testcontainers 跑一轮集成测试验证关键 SQL 路径。
