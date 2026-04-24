# FamilyLedger 工作进展报告

> 截止 2026-04-24 11:00 | 111 commits | 12,500 行 Go + 28,211 行 Dart（不含生成代码）

---

## 总体进度

| Phase | 后端 | 客户端 | 整体 | 变化 |
|-------|------|--------|------|------|
| Phase 1: 注册登录 + 记账 + 同步 | ✅ 完成 | ✅ 完成 | **97%** | ↑ account/category sync done |
| Phase 1b: 交易编辑与删除 | ✅ 完成 | ✅ 完成 | **95%** | — |
| Phase 2: 家庭协作 + 多账户 | ✅ 完成 | ✅ 完成 | **88%** | ↑ multi-device test |
| Phase 3: 预算 + 通知 | ✅ 完成 | ✅ 完成 | **90%** | — FCM 仍为 placeholder |
| Phase 4: 贷款跟踪 | ✅ 完成 | ✅ 完成 | **95%** | — |
| Phase 4b: 组合贷款增强 | ✅ 完成 | ✅ 完成 | **90%** | — |
| Phase 5: 投资 + 行情 | ✅ 完成 | ✅ 完成 | **95%** | ↑↑ RealFetcher (东方财富/Yahoo/CoinGecko) |
| Phase 6: 固定资产 + 折旧 | ✅ 完成 | ✅ 完成 | **95%** | — |
| Phase 7: Dashboard + 报表导出 | ✅ 完成 | ✅ 完成 | **95%** | ↑ local-first + 3s timeout |
| Phase 8: 多币种 + CSV导入 + OAuth | ✅ 完成 | ✅ 完成 | **80%** | — OAuth mock |
| Phase 9: UI 打磨 | — | ✅ 完成 | **97%** | ↑↑ 字体+SwipeToDelete+无障碍 |

**加权整体完成度: ~94%**

---

## 今日修复 (2026-04-24, +15 commits)

| Commit | 内容 | 影响 |
|--------|------|------|
| `1e43bbf` | SyncEngine replay ops to business tables + frontend soft-delete | P0: 离线同步真正生效 |
| `9e34e76` | 删除 WebSocket user_id 后门 | 安全: 强制 JWT 认证 |
| `f61bd9c` | 骨架屏 + ErrorState + WS 指数退避 | UX: 8 页面骨架屏 |
| `e18b281` | Phase 9: 6 个微交互组件集成到页面 | Phase 9: 9/11 微交互 Done |
| `ac6e55a` | Category ID 统一为 UUID v5 | P0: 客户端+服务端分类一致 |
| `0831459` | Go 依赖安全更新 (pgx/grpc/jwt) | 安全: 4 CVE 修复 |
| `2d63109` | Dashboard local-first + 3s gRPC 超时 | 性能: 断网瞬间显示 |
| `c629ec7` | SyncEngine account + category 同步实现 | P1: 三种实体双向同步 |
| `d4126c5` | RealFetcher 替换 MockFetcher | P1: 5 市场真实行情 |
| `68eb4eb` | 多设备同步 E2E + 1000 条压测 + VirtualList stress test | P2: 验证核心体验 |
| `3b61a4b` | 68 个 Go 单元测试 + db.Pool 接口抽象 | P1: 后端测试从 0→68 |
| `b11ebe4` | ListTransactions offset → cursor 分页 | 性能: O(n)→O(1) 翻页 |
| `2f43cf4` | DM Sans 字体 + SwipeToDelete 升级 + 7 页面无障碍 | Phase 9: 11/11 Done |

---

## 后端 (Go gRPC Server)

### 已完成 ✅

| 模块 | Service | 行数 | RPC 数 | 测试 | 备注 |
|------|---------|------|--------|------|------|
| 认证 | AuthService | 274 | 4 | 14 | JWT + OAuth mock |
| 交易 | TransactionService | 663 | 5 | 11 | CRUD + FOR UPDATE 锁 |
| 同步 | SyncService | 616 | 2 | 6 | ✅ replay + account/category |
| 家庭 | FamilyService | 665 | 8 | — | 邀请码+权限 |
| 账户 | AccountService | 645 | 6 | 10 | 7 种类型+转账 |
| 预算 | BudgetService | 479 | 6 | 13 | 月度+分类子预算 |
| 通知 | NotifyService | 541 | 6 | — | 设备注册 (FCM placeholder) |
| 贷款 | LoanService | 1,583 | 13 | — | 等额本息/本金+组合贷 |
| 投资 | InvestmentService | 645 | 8 | — | 持仓+交易记录 |
| 行情 | MarketDataService | 683+112 | 4 | — | ✅ RealFetcher (3 API源) |
| 资产 | AssetService | 805 | 9 | — | 直线法+双倍余额递减 |
| 仪表盘 | DashboardService | 609 | 5 | 14 | 净资产+趋势+分类 |
| 导出 | ExportService | 322 | 1 | — | CSV/Excel/PDF |
| 导入 | ImportService | 445 | 2 | — | GBK+9种日期格式 |
| 公共包 | pkg/ | ~800 | — | — | db/jwt/middleware/ws/category |
| **合计** | **15 Services + 5 pkg** | **~12,415** | **79 RPCs** | **68** | |

### 行情数据源 (RealFetcher)

| 市场 | API 源 | 方法 |
|------|--------|------|
| A股 | 东方财富 push2 | SH/SZ 自动识别 |
| 港股 | 东方财富 push2 | secid 116. |
| 基金 | 天天基金 JSONP | NAV 净值 |
| 美股 | Yahoo Finance v8 | User-Agent 必须 |
| 加密货币 | CoinGecko | USD→分 |

- 全部降级到 MockFetcher（API 失败不崩）
- 零外部依赖（stdlib net/http + encoding/json）
- Service 层 15 分钟 DB 缓存不变

### 数据库
- **32 个 migration** 文件 (001-032)
- **软删除**: accounts, transactions, loans, loan_groups, investments, fixed_assets
- **定时任务**: 5 个 goroutine (预算/行情/折旧/汇率/清理)
- **Category UUID v5**: 服务端 seed 和迁移都用确定性 UUID

### 安全
- ✅ JWT 拦截器 (gRPC + WebSocket)
- ✅ FOR UPDATE 并发锁
- ✅ WebSocket user_id 后门已删除
- ✅ Go 依赖已更新 (pgx 5.9.2, grpc 1.80.0, jwt 5.3.1)
- ✅ db.Pool 接口抽象 + pgxmock 测试

### 测试
- **68 个单元测试** (6 个 service: auth/account/transaction/sync/dashboard/budget)
- pgxmock/v4 + testify
- 覆盖 happy path + error path + auth check

---

## 客户端 (Flutter iOS)

### 数据层
- **Drift** 本地数据库 schema v10 (✅ category UUID v5 迁移)
- **23 张 Drift 表** (与服务端 32 张表映射)
- **gRPC clients**: 14 个 service 全覆盖, 带 3s timeout
- **SyncEngine**: ✅ transaction + account + category 三种实体全支持
- **Dashboard**: local-first 架构

### UI 组件库

| 组件 | 状态 | 说明 |
|------|------|------|
| EmptyState 空状态 | ✅ 13 个页面 | 插图+引导文案 |
| SkeletonLoading 骨架屏 | ✅ 8 个页面 | 替代 Loading 圈 |
| ErrorState 错误状态 | ✅ | 友好文案+重试 |
| SuccessAnimation 记账成功 | ✅ | 震动+飞入动画 |
| CustomRefreshIndicator | ✅ 5 个列表页 | 自定义动画 |
| AnimatedCounter 数字滚动 | ✅ | balance+investments |
| SwipeToDelete | ✅ | 渐变背景+缩放动画+ClipRRect |
| AnimatedTabBar | ✅ | 下划线滑动跟随 |
| SharedElementRoute | ✅ | Hero 转场动画 |
| VirtualList 虚拟列表 | ✅ | 1100 条 build 21ms |
| AmountStyle 等宽数字 | ✅ 18 页面 | DM Sans + tabularFigures |
| Accessibility 无障碍 | ✅ 99 处 | 31/31 页面全覆盖 |

### 测试
- **566 widget tests** ✅ 全绿 (含 6 个 VirtualList perf tests)
- **6 个 shell E2E 脚本** (含多设备同步 + 1000 条压测)
- **VirtualList 性能**: 1100 条 build 21ms, 只构建可见 item

---

## 与实施计划逐条对照 — 未完成项

### 🔴 代码功能缺失（Mock/Placeholder）

| # | 缺失项 | Phase | 说明 | 预估工作量 |
|---|--------|-------|------|-----------|
| 1 | **微信/Apple OAuth** | 8 | `code="test"` 直接通过 → 需接真实 SDK | 2-3 天 |
| 2 | **FCM/APNs 推送** | 3 | 后端只写 DB，不发真实推送；客户端未集成 firebase_messaging | 1-2 天 |

### 🟡 前端修正

| # | 问题 | 说明 | 预估 |
|---|------|------|------|
| 3 | `oauthLogin()` 拼假 account ID | `acc_default_${resp.userId}` 与服务端 UUID 不匹配 | 0.5 天 |

### 🔵 UI 细节

（已全部完成 ✅）

### 🟠 测试补充

| # | 项目 | 说明 | 预估 |
|---|------|------|------|
| 7 | Go 后端剩余 8 个 service 测试 | family/notify/loan/investment/asset/export/import/market | 2-3 天 |
| 8 | 60fps 微交互验证 | DevTools Performance overlay 实机验证 | 0.5 天 |

---

## 代码统计

| 指标 | 值 | vs 上次 |
|------|------|---------|
| Git commits | 111 | +8 |
| Go 代码 (不含 proto gen) | ~12,500 行 | +2,369 |
| Dart 代码 (不含 generated) | 28,211 行 | +233 |
| Proto 定义 | 13 文件 / 79 RPCs | — |
| DB migrations | 32 对 | — |
| 后端 Services | 15 个 | — |
| Flutter 页面 | 31 个 | — |
| UI 组件 | 12 个 | — |
| Go unit tests | 68 | **+68** |
| Widget tests | 566 | +6 |
| Shell E2E scripts | 6 | +2 |
| Semantics 节点 | 99 | **+19** |

---

## 下一步优先级建议

| 优先级 | 工作 | 预估 | 理由 |
|--------|------|------|------|
| **P1** | oauthLogin 假 account ID 修正 | 0.5 天 | 数据一致性 |
| **P2** | OAuth 真实对接 (微信+Apple) | 2-3 天 | Phase 8 上线前必须 |
| **P2** | FCM/APNs 推送 | 1-2 天 | 上线后再接也行 |
| **P2** | Go 后端剩余 service 测试 | 2-3 天 | 覆盖率提升 |
| **P3** | 60fps 实机验证 | 0.5 天 | 需真机 |
