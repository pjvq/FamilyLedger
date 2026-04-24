# FamilyLedger 工作进展报告

> 截止 2026-04-24 08:50 | 98 commits | 9,740 行 Go + 27,856 行 Dart（不含生成代码）

---

## 总体进度

| Phase | 后端 | 客户端 | 整体 | 变化 |
|-------|------|--------|------|------|
| Phase 1: 注册登录 + 记账 + 同步 | ✅ 完成 | ✅ 完成 | **92%** | ↑ SyncEngine replay 修复 |
| Phase 1b: 交易编辑与删除 | ✅ 完成 | ✅ 完成 | **93%** | ↑ 软删除一致性修复 |
| Phase 2: 家庭协作 + 多账户 | ✅ 完成 | ✅ 完成 | **85%** | — |
| Phase 3: 预算 + 通知 | ✅ 完成 | ✅ 完成 | **90%** | ↓ FCM 仍为 placeholder |
| Phase 4: 贷款跟踪 | ✅ 完成 | ✅ 完成 | **95%** | — |
| Phase 4b: 组合贷款增强 | ✅ 完成 | ✅ 完成 | **90%** | — |
| Phase 5: 投资 + 行情 | ✅ 完成 | ✅ 完成 | **80%** | — MockFetcher |
| Phase 6: 固定资产 + 折旧 | ✅ 完成 | ✅ 完成 | **95%** | — |
| Phase 7: Dashboard + 报表导出 | ✅ 完成 | ✅ 完成 | **90%** | — |
| Phase 8: 多币种 + CSV导入 + OAuth | ✅ 完成 | ✅ 完成 | **80%** | — OAuth mock |
| Phase 9: UI 打磨 | — | 🟡 进行中 | **70%** | ↑ 骨架屏+错误状态已集成 |

**加权整体完成度: ~87%**

---

## 今日修复 (2026-04-24, +4 commits)

| Commit | 内容 | 影响 |
|--------|------|------|
| `1e43bbf` | SyncEngine replay ops to business tables + frontend soft-delete | P0: 离线同步真正生效 |
| `9e34e76` | 删除 WebSocket user_id 后门 | 安全: 强制 JWT 认证 |
| `f61bd9c` | 骨架屏替换全部 CircularProgressIndicator + ErrorState + WS 指数退避 | UX: 8 页面骨架屏, 重连优化 |

---

## 后端 (Go gRPC Server)

### 已完成 ✅

| 模块 | Service | 行数 | RPC 数 | 备注 |
|------|---------|------|--------|------|
| 认证 | AuthService | 274 | 4 | JWT + OAuth mock |
| 交易 | TransactionService | 663 | 5 | CRUD + FOR UPDATE 锁 |
| 同步 | SyncService | 616 | 2 | ✅ 今日修复: replay to business tables |
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
| **合计** | **14 Services** | **~9,740** | **79 RPCs** | |

### 数据库
- **31 个 migration** 文件 (001-031)
- **软删除**: accounts, transactions, loans, loan_groups, investments, fixed_assets
- **定时任务**: 5 个 goroutine (预算/行情/折旧/汇率/清理)

### 安全
- ✅ JWT 拦截器 (gRPC + WebSocket)
- ✅ FOR UPDATE 并发锁 (transaction update/delete)
- ✅ WebSocket user_id 后门已删除
- ⚠️ Go 后端零 `_test.go` 文件

---

## 客户端 (Flutter iOS)

### 数据层
- **Drift** 本地数据库 schema v9 (✅ 今日新增 deletedAt)
- **23 张 Drift 表** (与服务端 31 张表映射)
- **gRPC clients**: 14 个 service 全覆盖
- **SyncEngine**: WebSocket 实时通知 + 指数退避重连 (✅ 今日修复) + 离线队列

### UI 组件库

| 组件 | 已集成到页面 | 状态 |
|------|-------------|------|
| EmptyState 空状态 | ✅ 13 个页面 | ✅ |
| SkeletonLoading 骨架屏 | ✅ 8 个页面 (今日集成) | ✅ |
| ErrorState 错误状态 | ✅ 有 error 字段的页面 | ✅ |
| SuccessAnimation 记账成功 | ❌ 未在 add_transaction_page 调用 | 🔴 |
| CustomRefreshIndicator | ❌ 所有页面仍用默认 RefreshIndicator | 🔴 |
| AnimatedCounter 数字滚动 | ❌ 未在 investments_page 使用 | 🔴 |
| SwipeToDelete | ⚠️ 用 Dismissible 替代 | 🟡 |
| AnimatedTabBar | ❌ 未在任何页面使用 | 🔴 |
| SharedElementRoute | ❌ 未在列表→详情转场使用 | 🔴 |
| VirtualList 虚拟列表 | ❌ 未在 transaction_history 使用 | 🔴 |
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
| 4 | **category_id 统一** | 1 | 本地 cat_food vs 服务端 UUID | 0.5 天 |
| 5 | **Dashboard 本地优先** | 7 | 当前纯依赖 gRPC，应优先 Drift 聚合 | 1 天 |

### 🟡 组件已写好但未集成

| # | 组件 | 目标页面 | 预估 |
|---|------|---------|------|
| 6 | TransactionSuccessOverlay | add_transaction_page 记账成功 | 0.5h |
| 7 | CustomRefreshIndicator | 9 个有 RefreshIndicator 的页面 | 1h |
| 8 | AnimatedCounter | investments_page + dashboard 金额 | 1h |
| 9 | AnimatedTabBar | loan_group_detail_page Tab | 0.5h |
| 10 | SharedElementRoute | 列表→详情所有转场 | 2h |
| 11 | VirtualList | transaction_history_page | 0.5h |

### 🟠 验证/测试缺失

| # | 项目 | 说明 | 预估 |
|---|------|------|------|
| 12 | Go 后端单元测试 | 14 个 service，0 个 _test.go | 2-3 天 |
| 13 | 多设备同步实测 | Phase 1/2 核心场景 | 0.5 天 |
| 14 | 1000+ 条压测 | VirtualList 性能验证 | 0.5 天 |
| 15 | 60fps 微交互验证 | DevTools Performance overlay | 0.5 天 |

---

## 代码统计

| 指标 | 值 | vs 上次 |
|------|------|---------|
| Git commits | 98 | +48 |
| Go 代码 (不含 proto gen) | 9,740 行 | +1,334 |
| Dart 代码 (不含 generated) | 27,856 行 | — |
| Proto 定义 | 13 文件 / 79 RPCs | +6 RPCs |
| DB migrations | 31 对 | +2 |
| 后端 Services | 14 个 | — |
| Flutter 页面 | 28 个 | — |
| UI 组件 | 12 个 | +1 (ErrorState) |
| Widget tests | 560 | — |
| Shell E2E tests | 21 | — |

---

## 下一步优先级建议

| 优先级 | 工作 | 预估 | 理由 |
|--------|------|------|------|
| **P0** | category_id 统一（本地 preset → 服务端 UUID 映射） | 0.5 天 | 记账核心链路断裂 |
| **P0** | Dashboard 本地优先 fallback | 1 天 | 离线体验核心 |
| **P1** | Phase 9 组件集成（6 个组件→页面） | 1 天 | 组件都写好了就差插上 |
| **P1** | Go 后端单元测试 | 2 天 | 代码质量底线 |
| **P2** | 真实行情 API | 2-3 天 | Phase 5 不可用 |
| **P2** | OAuth 真实对接 | 2-3 天 | Phase 8 上线前必须 |
| **P3** | FCM/APNs | 1-2 天 | 上线后再接也行 |
