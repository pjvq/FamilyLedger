# FamilyLedger — 测试体系文档

> 截止 2026-04-27 | 269 commits | 覆盖 6 层测试

---

## 测试概览

| 层级 | 类型 | 数量 | 耗时 | 覆盖范围 |
|------|------|------|------|---------|
| **L1** | Go 单元测试 (pgxmock) | **330** | ~94s | **18 个 package 全覆盖** |
| **L2** | Flutter Widget 测试 | 535 | ~12s | 页面 + 组件 + Provider |
| **L3** | Flutter 性能测试 | 6 | ~2s | 1000+ 条列表渲染 |
| **L4** | gRPC Shell E2E | 24 assertions | ~10s | 纯后端 RPC |
| **L5** | Flutter Integration E2E | 79 | ~60s | 模拟器 + gRPC |
| **L6** | Shell 集成测试 | 6 脚本 | ~30s | 多设备同步 + 压测 |

**总计: ~980 测试点**

---

## L1: Go 后端单元测试

使用 `pgxmock` 模拟 PostgreSQL，每个 service 完整覆盖。

```bash
cd server && go test ./... -count=1
```

### 覆盖的 18 个 Package

| Package | 测试重点 |
|---------|---------|
| `internal/account` | CRUD + 家庭账户 |
| `internal/asset` | 折旧计算 (直线法/双倍余额) |
| `internal/auth` | JWT + OAuth Provider 接口 |
| `internal/budget` | 预算执行率 + 家庭汇总 |
| `internal/dashboard` | 6 个聚合 API + 家庭/个人隔离 + 汇率 + 投资曲线 |
| `internal/export` | CSV/Excel/PDF + 全量备份 |
| `internal/family` | 创建/邀请/权限 + 审计日志 |
| `internal/importcsv` | 4 步导入 + session 过期 |
| `internal/investment` | CRUD + IRR + 家庭汇总 |
| `internal/loan` | 等额本息/本金 + 组合贷 + 提前还款 |
| `internal/market` | 行情拉取 + 交易时段调度 (22 tests) |
| `internal/notify` | 预算超支 + 贷款提醒 + 信用卡 + 自定义提醒 |
| `internal/sync` | PullChanges + PushOperations + 7 种 entity_ops |
| `internal/transaction` | CRUD + 家庭权限 + FileStorage |
| `pkg/audit` | 审计日志 helper |
| `pkg/config` | JWT Secret 校验 (11 tests) |
| `pkg/storage` | FileStorage 接口 (Local + S3) |
| `pkg/ws` | WebSocket Ping-Pong 心跳 + 广播 (7 tests, 含 90s 超时测试) |

### 运行耗时说明

总耗时 ~94s，其中 `pkg/ws` 约 93s（包含一个真实 Ping 超时断连测试，需等待 60s deadline）。其余 17 个 package 均在 5s 内完成。

---

## L2: Flutter Widget / Unit 测试

```bash
cd app && flutter test
```

### 覆盖内容

- **数据库测试**: Drift schema migration、查询逻辑
- **Provider 测试**: Transaction、Loan、Investment、Asset、Budget 等 StateNotifier
- **Widget 测试**: 14 个功能页面的关键交互
- **同步测试**: SyncEngine LWW 冲突解决 (8 tests)
- **前端逻辑**: addTransaction 无闪烁 (server-first, 3 tests)、分页加载 (6 tests)

---

## L5: 集成测试 (iOS 模拟器)

```bash
cd app && flutter test integration_test/app_test.dart --device-id <UDID>
```

覆盖完整用户流程:
1. 注册 → 登录 → 记账 → 查看 Dashboard
2. 创建贷款 → 查看还款计划
3. 添加投资 → 查看行情
4. 导出 CSV → 验证内容
5. 离线记账 → 恢复网络 → 自动同步

---

## 测试原则

1. **测试外部行为**，不测内部实现
2. **表驱动测试** (table-driven) 用于财务计算
3. **pgxmock** 隔离数据库，每个测试独立
4. **家庭模式** 必须有对应测试（个人模式 + 家庭模式 + 权限拒绝）
5. **不糊弄**：每个新功能/修复必须附带测试，通过后才能 commit

---

## 运行全量测试

```bash
# 一行命令跑完全部
cd /path/to/FamilyLedger/server && go test ./... -count=1 && \
cd ../app && flutter test
```
