# FamilyLedger 工作进展报告

> 截止 2026-04-24 12:45 | 115 commits | 30,047 行 Go + 28,253 行 Dart(不含生成代码)
> ⚠️ 本版基于代码深度审计,修正了之前多处虚高评估

---

## 总体进度

| Phase | 后端 | 客户端 | 整体 | 说明 |
|-------|------|--------|------|------|
| Phase 1: 注册登录 + 记账 + 同步 | ✅ | ✅ | **90%** | 自定义分类迁至 Phase 1c |
| Phase 1b: 交易编辑与删除 | ✅ | ✅ | **93%** | 批量删除缺失 |
| Phase 1c: 分类管理 | ❌ | ❌ | **0%** | 主分类+子分类+内置图标库+CRUD,全新 |
| Phase 2: 家庭协作 + 多账户 | ⚠️ | ⚠️ | **60%** | 细粒度权限空、个人/家庭双账本缺 |
| Phase 3: 预算 + 通知 | ⚠️ | ⚠️ | **65%** | FCM 不发推送、缺信用卡账单提醒 |
| Phase 4: 贷款跟踪 | ✅ | ✅ | **95%** | 最完整的模块 |
| Phase 4b: 组合贷款增强 | ✅ | ✅ | **90%** | |
| Phase 5: 投资 + 行情 | ✅ | ✅ | **85%** | 行情+汇率已接真实 API |
| Phase 6: 固定资产 + 折旧 | ✅ | ✅ | **90%** | |
| Phase 7: Dashboard + 报表导出 | ✅ | ✅ | **88%** | Dashboard 数据依赖行情/汇率的准确性 |
| Phase 8: 多币种 + CSV导入 + OAuth | ⚠️ | ⚠️ | **55%** | OAuth mock、汇率假数据 |
| Phase 9: UI 打磨 | - | ✅ | **97%** | 11/11 完成 |

**加权真实完成度: ~78%**

---

## 代码统计

| 指标 | 值 |
|------|------|
| Git commits | 115 |
| Go 代码 | 30,047 行 |
| Dart 代码(不含 generated) | 28,253 行 |
| Proto 定义 | 1,354 行 / 13 文件 / 79 RPCs |
| DB migrations | 32 对 |
| 后端 Services | 15 个 |
| Flutter 页面 | 31 个 |
| Flutter providers | 16 个 |
| Go unit tests | 68 |
| Widget tests | 566 |
| Shell E2E scripts | 7 |
| Semantics 节点 | 99 |

---

## 后端 (Go gRPC Server)

### Service 清单

| Service | 行数 | 方法数 | 测试 | 问题 |
|---------|------|--------|------|------|
| AuthService | 274 | 5 | 14 | ❌ OAuth `code="test"` mock |
| TransactionService | 677 | 5 | 11 | 无自定义分类 CRUD |
| SyncService | 616 | 10 | 6 | ✅ replay ops 实装 |
| FamilyService | 665 | 11 | 0 | 细粒度权限仅角色级 |
| AccountService | 645 | 9 | 10 | ✅ |
| BudgetService | 479 | 9 | 13 | ✅ |
| NotifyService | 541 | 11 | 0 | ❌ 只写 DB 不发推送 |
| LoanService | 1,583 | 18 | 0 | ✅ 最大最完整 |
| InvestmentService | 645 | 9 | 0 | ✅ CRUD |
| MarketDataService | 424 | 6 | 0 | ❌ GetQuote 只读 DB,无数据灌入 |
| ExchangeService | 112 | - | 0 | ❌ rand 随机波动假数据 |
| AssetService | 805 | 13 | 0 | ✅ |
| DashboardService | 609 | 6 | 14 | ✅ |
| ExportService | 322 | 5 | 0 | ✅ CSV/Excel/PDF |
| ImportService | 445 | 3 | 0 | ✅ GBK+9种日期 |

### 关键问题标记

| 问题 | 严重程度 | 说明 |
|------|---------|------|
| **行情数据无来源** | 🔴 高 | Go 后端 MarketDataService 的 `GetQuote` 只从 DB 读取,但没有 cron/worker 写入数据。Flutter 端的 RealFetcher(东方财富/Yahoo/CoinGecko)已实现但**未被使用**--实际走的是 gRPC→后端空 DB |
| ~~汇率假数据~~ ✅ | ~~🔴 高~~ | exchange_service 已改用 open.er-api.com 真实汇率,mock 仅作 fallback |
| **FCM 推送空壳** | 🟡 中 | notify service 有 device 注册+通知 CRUD,但 `Send` 方法不存在--通知只存 DB 不发设备 |
| **OAuth mock** | 🟡 中 | `code=="test"` 直接过,微信/Apple SDK 完全未接 |
| **分类管理 0%** | 🔴 高 | PRD 要求主分类+子分类+内置图标+CRUD。当前: proto 无 Create/Update/Delete RPC, DB 无 parent_id, 前端无管理页。已规划为 Phase 1c |

---

## 客户端 (Flutter)

### 已完成
- 31 页面全部 UI 实现
- 16 个 Riverpod provider
- Drift 本地数据库 + 14 个 gRPC client
- SyncEngine (transaction + account + category)
- Dashboard local-first (本地瞬显 + 3s gRPC 超时静默刷新)
- Phase 9 全部 11/11 微交互(骨架屏/空状态/SwipeToDelete/无障碍/VirtualList...)
- 566 widget tests 全绿

### 客户端关键问题

| 问题 | 说明 |
|------|------|
| 汇率 refreshRates() | TODO 注释:`call backend API`,实际只 reload 本地 DB |
| 行情数据源断路 | RealFetcher 代码存在但客户端实际走 gRPC→后端空 DB |
| 自定义分类 UI 无 | 只有预设分类选择,无新增/编辑入口 |

---

## 严重被高估的部分(详细说明)

### 1. 投资+行情 - 报告 95% → 实际 ~70%

**看起来有但不工作的链路:**
- Flutter 端有完整的投资 UI(5 种市场、买卖、持仓、走势图)
- Flutter 端有 RealFetcher 代码(东方财富/天天基金/Yahoo/CoinGecko)
- Go 后端有 MarketDataService(GetQuote/BatchGetQuotes/SearchStock)

**断裂点:**
- RealFetcher 写了但**没有被任何代码调用**(是之前的 commit `d4126c5` 产物,但行情请求实际走的是 gRPC 到后端)
- Go 后端 `GetQuote` 从 `market_data` 表 SELECT,但**没有任何 cron/worker/定时任务往这张表写数据**
- 结果:用户看到的行情永远是空的或初始 seed 数据

### 2. 多币种/汇率 - 报告 80% → 实际 ~65%

- 记账选币种 ✅、`amount_cny` 归一 ✅
- Go 端 `ExchangeService.RefreshRates()` 源码:给已有汇率加 ±0.5% 随机波动 → `source = 'mock'`
- Flutter 端 `exchange_rate_provider.dart` 的 `refreshRates()` 方法:TODO 注释,只调 `_loadFromDb()`
- 硬编码默认值:USD/CNY=7.25, EUR/CNY=7.90...

### 3. 通知 - 报告 90% → 实际 ~55%

- 后端 NotifyService 有 11 个方法(RegisterDevice/GetNotifications/MarkAsRead 等)
- **没有 SendNotification/PushNotification 方法**--通知只能 DB 里写,设备收不到
- 缺信用卡账单日提醒逻辑
- 前端 NotificationSettingsPage 设置了开关但无实际效果

---

## 完全缺失的 PRD 功能

| # | PRD 要求 | 现状 | 预估 |
|---|---------|------|------|
| 1 | 分类管理(主分类+子分类+自定义+内置图标) | Phase 1c,全新开发 | 2-3 天 |
| 2 | 个人/家庭账本切换 | "同时拥有个人账本和家庭账本" - 只有一个维度 | 2-3 天 |
| 3 | 细粒度权限控制 | "普通成员只能记账,不能删除/导出" - 只有 admin/member 角色 | 1-2 天 |
| 4 | 系统自动获取汇率 | 硬编码+随机波动 | 0.5 天 |
| 5 | 实时行情(15分钟内) | 后端无数据源 | 1 天 |
| 6 | FCM/APNs 推送 | 设备注册了但推不出去 | 1-2 天 |
| 7 | 微信/Apple OAuth | mock 直接过 | 2-3 天 |
| 8 | 批量删除交易 | Proto 无此 RPC | 0.5 天 |

---

## 测试体系(5 层)

| 层级 | 数量 | 耗时 | 覆盖 |
|------|------|------|------|
| L1: Go unit tests | 68 | ~2s | 6/15 service (auth/account/transaction/sync/dashboard/budget) |
| L2: Flutter widget tests | 566 | ~12s | 31/31 页面 |
| L4: Shell E2E (scripts/) | 24 assertions | ~8s | 核心记账→同步→删除→余额链路 |
| L5: Shell E2E (tests/integration/) | 6 脚本 / ~48 assertions | ~15s | 基础服务/金融/分析/多设备/压测 |
| L6: VirtualList perf | 6 tests | ~3s | 1100 条 build 21ms |

**总计 ~750 测试点**

### 测试覆盖缺口

- Go 后端 9/15 service **零测试**(family/notify/loan/investment/asset/export/import/market/exchange)
- Flutter 集成测试(真实设备 UI 流程)未运行
- E2E 测试未覆盖:OAuth 流程、多币种、组合贷款、导出

---

## CI

- `.github/workflows/` 下 3 个 workflow 文件已创建(go.yml / flutter.yml / e2e.yml)
- GitHub Actions 因账户付费问题暂不可用
- **约定:commit 前手动跑 Go test + Flutter analyze + Flutter test**

---

## 下一步优先级

| 优先级 | 工作 | 预估 | 理由 |
|--------|------|------|------|
| **P0** | Phase 1c: 分类管理（主/子分类 + 图标库 + CRUD） | 2-3 天 | PRD 核心功能，涉及 DB/Proto/后端/前端全链路 |
| ~~P1~~ ✅ | ~~行情数据源接入~~ | ✅ | RealFetcher + scheduler 已在跑 |
| ~~P1~~ ✅ | ~~汇率真实 API 替换~~ | ✅ | open.er-api.com,每小时刷新 |
| **P2** | FCM 推送集成 | 1-2 天 | 上线必备 |
| **P2** | OAuth 真实对接 | 2-3 天 | 上线必备 |
| **P2** | 家庭协作补全（权限+双账本） | 2-3 天 | PRD 核心差异化功能 |
| **P3** | Go 后端剩余 9 service 测试 | 2-3 天 | 覆盖率 |
| **P3** | 60fps 实机验证 | 0.5 天 | 需真机 |
