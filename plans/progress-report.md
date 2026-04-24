# FamilyLedger 工作进展报告

> 截止 2026-04-24 09:46 | 103 commits | 10,131 行 Go + 27,978 行 Dart（不含生成代码）

---

## 总体进度

| Phase | 后端 | 客户端 | 整体 | 变化 |
|-------|------|--------|------|------|
| Phase 1: 注册登录 + 记账 + 同步 | ✅ 完成 | ✅ 完成 | **95%** | ↑ category UUID v5 统一 |
| Phase 1b: 交易编辑与删除 | ✅ 完成 | ✅ 完成 | **93%** | — |
| Phase 2: 家庭协作 + 多账户 | ✅ 完成 | ✅ 完成 | **85%** | — |
| Phase 3: 预算 + 通知 | ✅ 完成 | ✅ 完成 | **90%** | ↓ FCM 仍为 placeholder |
| Phase 4: 贷款跟踪 | ✅ 完成 | ✅ 完成 | **95%** | — |
| Phase 4b: 组合贷款增强 | ✅ 完成 | ✅ 完成 | **90%** | — |
| Phase 5: 投资 + 行情 | ✅ 完成 | ✅ 完成 | **80%** | — MockFetcher |
| Phase 6: 固定资产 + 折旧 | ✅ 完成 | ✅ 完成 | **95%** | — |
| Phase 7: Dashboard + 报表导出 | ✅ 完成 | ✅ 完成 | **93%** | ↑ local-first + 3s timeout |
| Phase 8: 多币种 + CSV导入 + OAuth | ✅ 完成 | ✅ 完成 | **80%** | — OAuth mock |
| Phase 9: UI 打磨 | — | ✅ 大部分完成 | **85%** | ↑↑ 6 组件已集成 |

**加权整体完成度: ~89%**

---

## 今日修复 (2026-04-24, +7 commits)

| Commit | 内容 | 影响 |
|--------|------|------|
| `1e43bbf` | SyncEngine replay ops to business tables + frontend soft-delete | P0: 离线同步真正生效 |
| `9e34e76` | 删除 WebSocket user_id 后门 | 安全: 强制 JWT 认证 |
| `f61bd9c` | 骨架屏替换全部 CircularProgressIndicator + ErrorState + WS 指数退避 | UX: 8 页面骨架屏, 重连优化 |
| `e18b281` | Phase 9: 6 个微交互组件集成到页面 | Phase 9: SuccessOverlay/CustomRefresh×5/AnimatedCounter×2/AnimatedTabBar/Hero/VirtualList |
| `ac6e55a` | Category ID 统一为 UUID v5 | P0: 客户端+服务端分类 ID 一致 |
| `0831459` | Go 依赖安全更新 (pgx/grpc/jwt) | 安全: 4 个 CVE 修复 |
| `2d63109` | Dashboard local-first + 3s gRPC 超时 | 性能: 离线即时显示本地数据 |

---

## 后端 (Go gRPC Server)

### 已完成 ✅

| 模块 | Service | 行数 | RPC 数 | 备注 |
|------|---------|------|--------|------|
| 认证 | AuthService | 274 | 4 | JWT + OAuth mock |
| 交易 | TransactionService | 663 | 5 | CRUD + FOR UPDATE 锁 |
| 同步 | SyncService | 616 | 2 | ✅ replay to business tables |
| 家庭 | FamilyService | 665 | 8 | 邀请码+权限 |
| 账户 | AccountService | 645 | 6 | 7种类型+转账 |
| 预算 | BudgetService | 479 | 6 | 月度+分类子预算 |
| 通知 | NotifyService | 541 | 6 | 设备注册 (FCM placeholder) |
| 贷款 | LoanService | 1,583 | 13 | 等额本息/本金+组合贷+提前还款 |
| 投资 | InvestmentService | 645 | 8 | 持仓+交易记录 |
| 行情 | MarketDataService | 424+147+112 | 4 | ⚠️ MockFetcher |
| 资产 | AssetService | 805 | 9 | 直线法+双倍余额递减 |
| 仪表盘 | DashboardService | 609 | 5 | 净资产+趋势+分类 |
| 导出 | ExportService | 322 | 1 | CSV/Excel/PDF |
| 导入 | ImportService | 445 | 2 | GBK+9种日期格式 |
| 公共包 | pkg/ | 780 | — | db/jwt/middleware/ws/category |
| **合计** | **14 Services + 5 pkg** | **~10,131** | **79 RPCs** | |

### 数据库
- **32 个 migration** 文件 (001-032)
- **软删除**: accounts, transactions, loans, loan_groups, investments, fixed_assets
- **定时任务**: 5 个 goroutine (预算/行情/折旧/汇率/清理)
- **Category UUID v5**: 服务端 seed 和迁移都用确定性 UUID

### 安全
- ✅ JWT 拦截器 (gRPC + WebSocket)
- ✅ FOR UPDATE 并发锁 (transaction update/delete)
- ✅ WebSocket user_id 后门已删除
- ✅ Go 依赖已更新 (pgx 5.9.2, grpc 1.80.0, jwt 5.3.1)
- ⚠️ Go 后端零 `_test.go` 文件

---

## 客户端 (Flutter iOS)

### 数据层
- **Drift** 本地数据库 schema v10 (✅ category UUID v5 迁移)
- **23 张 Drift 表** (与服务端 32 张表映射)
- **gRPC clients**: 14 个 service 全覆盖, 带 3s timeout
- **SyncEngine**: WebSocket 实时通知 + 指数退避重连 + 离线队列
- **Dashboard**: local-first 架构（本地瞬间显示 → 后台 gRPC 静默刷新）

### UI 组件库

| 组件 | 已集成到页面 | 状态 |
|------|-------------|------|
| EmptyState 空状态 | ✅ 13 个页面 | ✅ |
| SkeletonLoading 骨架屏 | ✅ 8 个页面 | ✅ |
| ErrorState 错误状态 | ✅ 有 error 字段的页面 | ✅ |
| SuccessAnimation 记账成功 | ✅ add_transaction_page | ✅ |
| CustomRefreshIndicator | ✅ 5 个列表页 | ✅ |
| AnimatedCounter 数字滚动 | ✅ balance_card + investments_page | ✅ |
| SwipeToDelete | ⚠️ 用 Dismissible 替代 | 🟡 |
| AnimatedTabBar | ✅ loan_group_detail_page | ✅ |
| SharedElementRoute | ✅ 列表→详情转场 | ✅ |
| VirtualList 虚拟列表 | ✅ transaction_history_page | ✅ |
| AmountStyle 等宽数字 | ✅ 18 个页面 | ✅ |
| Accessibility 无障碍 | ✅ 部分页面 | 🟡 |

### 测试
- 560 widget tests ✅ 全绿
- 21 shell E2E tests ✅
- 117 integration tests ✅

---

## 与实施计划逐条对照 — 未完成项

### 🔴 代码功能缺失（Mock/Placeholder）

| # | 缺失项 | Phase | 说明 | 预估工作量 |
|---|--------|-------|------|-----------|
| 1 | **真实行情 API** | 5 | MockFetcher → 东方财富/Yahoo/CoinGecko | 2-3 天 |
| 2 | **微信/Apple OAuth** | 8 | mock → 真实 SDK 对接 | 2-3 天 |
| 3 | **FCM/APNs 推送** | 3 | 后端只写 DB，不发真实推送 | 1-2 天 |

### 🟡 SyncEngine 不完整

| # | 问题 | 说明 | 预估 |
|---|------|------|------|
| 4 | `_applyRemoteOp` account/category 分支为空 | 只处理 transaction，其他 `break;` | 0.5 天 |
| 5 | 前端 `oauthLogin()` 拼假 account ID | `acc_default_${resp.userId}` 与服务端 UUID 不匹配 | 0.5 天 |

### 🟠 验证/测试缺失

| # | 项目 | 说明 | 预估 |
|---|------|------|------|
| 6 | Go 后端单元测试 | 14 个 service，0 个 _test.go | 2-3 天 |
| 7 | 多设备同步实测 | Phase 1/2 核心场景 | 0.5 天 |
| 8 | 1000+ 条压测 | VirtualList 性能验证 | 0.5 天 |
| 9 | 60fps 微交互验证 | DevTools Performance overlay | 0.5 天 |

### 🔵 UI 细节

| # | 项目 | 说明 | 预估 |
|---|------|------|------|
| 10 | 自定义 SwipeToDelete | 当前用基础 Dismissible，未用自定义红色区域组件 | 1h |
| 11 | 无障碍覆盖不完整 | 部分页面缺 Semantics 标签 | 2h |
| 12 | 自定义字体 DINRoundPro | 6 处 TODO 标记 | 1h |

---

## 代码统计

| 指标 | 值 | vs 上次 |
|------|------|---------|
| Git commits | 103 | +5 |
| Go 代码 (不含 proto gen) | 10,131 行 | +391 |
| Dart 代码 (不含 generated) | 27,978 行 | +122 |
| Proto 定义 | 13 文件 / 79 RPCs | — |
| DB migrations | 32 对 | +1 |
| 后端 Services | 14 个 | — |
| Flutter 页面 | 28 个 | — |
| UI 组件 | 12 个 | — |
| Widget tests | 560 | — |
| Shell E2E tests | 21 | — |

---

## 下一步优先级建议

| 优先级 | 工作 | 预估 | 理由 |
|--------|------|------|------|
| **P1** | SyncEngine account/category 分支实现 | 0.5 天 | 数据同步完整性 |
| **P1** | Go 后端单元测试 | 2-3 天 | 代码质量底线 |
| **P1** | 真实行情 API | 2-3 天 | Phase 5 核心功能不可用 |
| **P2** | OAuth 真实对接 | 2-3 天 | Phase 8 上线前必须 |
| **P2** | FCM/APNs 推送 | 1-2 天 | 上线后再接也行 |
| **P2** | 多设备同步 + 压测 | 1 天 | 验证核心体验 |
| **P3** | UI 细节（SwipeToDelete/无障碍/字体） | 0.5 天 | 打磨 |
