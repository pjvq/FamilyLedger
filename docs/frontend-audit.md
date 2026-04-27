# FamilyLedger Flutter 前端审计报告

**审计日期**: 2026-04-24 (初审) → 2026-04-27 (更新)  
**代码统计**: ~56,600 行 Dart（非生成代码），92 个源文件  
**技术栈**: Flutter + Riverpod (StateNotifier) + Drift (SQLite) + gRPC + WebSocket  
**测试**: 535 tests 全绿  

> **2026-04-27 更新**: 审计中发现的主要问题已全部修复（分页加载、LWW 冲突解决、ID 闪烁等）。详见 commit `18dae79` (P1 前端修复) 和 `1902d5b` (P2 #18 Server-first)。

---

## 目录

1. [架构总览](#1-架构总览)
2. [数据层 — data/local/](#2-数据层--datalocal)
3. [数据层 — data/remote/](#3-数据层--dataremote)
4. [领域层 — domain/providers/](#4-领域层--domainproviders)
5. [功能模块 — features/](#5-功能模块--features)
6. [核心层 — core/](#6-核心层--core)
7. [同步引擎 — sync/](#7-同步引擎--sync)
8. [跨切面问题汇总](#8-跨切面问题汇总)
9. [优先修复清单](#9-优先修复清单)

---

## 1. 架构总览

```
┌─────────────────────────────────┐
│       features/ (UI Pages)      │ ← ConsumerWidget / ConsumerStatefulWidget
├─────────────────────────────────┤
│     domain/providers/ (Logic)   │ ← StateNotifier<XxxState>
├─────────────┬───────────────────┤
│ data/local/ │  data/remote/     │ ← Drift DB / gRPC Clients
│ (SQLite)    │  (gRPC + WS)     │
└─────────────┴───────────────────┘
```

**设计模式**: Offline-first — 所有写操作先写本地 Drift DB，再尝试 gRPC 推送；失败时写入 SyncQueue，由 SyncEngine 定时批量重推。

**优点**:
- 离线能力完整，覆盖所有核心功能
- gRPC 连接异常时有 local fallback
- JWT 拦截器统一挂载在所有 gRPC client 上

**问题**:
- Provider 层直接操作 DB + gRPC，职责过重（既是状态管理，又是 Repository + Service）
- 没有独立的 Repository/UseCase 层，测试时必须 mock 整个 DB + gRPC
- domain/models/ 下的 model 文件（5 个，共 ~200 行）基本空壳，实际数据传输靠 Drift 生成类 + proto 类

---

## 2. 数据层 — data/local/

### 2.1 Drift 数据库 (database.dart)

| 项目 | 详情 |
|------|------|
| **Schema 版本** | **11** |
| **表数量** | 23 张表 |
| **迁移覆盖** | v1→v11 完整链式迁移，每步均有 `if (from < N)` 保护 |
| **测试构造** | `AppDatabase.forTesting(super.e)` 存在 |

**表清单**: Users, Accounts, Categories, Transactions, Families, FamilyMembers, Transfers, Budgets, CategoryBudgetsTable, Notifications, NotificationSettingsTable, LoanGroups, Loans, LoanSchedules, LoanRateChanges, Investments, InvestmentTrades, MarketQuotes, FixedAssets, AssetValuations, DepreciationRules, SyncQueue, ExchangeRates

**迁移历史**:
- v2: Families + FamilyMembers + Transfers + Accounts 扩展字段
- v3: Budgets + CategoryBudgets + Notifications + NotificationSettings
- v4: Loans + LoanSchedules + LoanRateChanges
- v5: Investments + InvestmentTrades + MarketQuotes
- v6: FixedAssets + AssetValuations + DepreciationRules
- v7: Transaction tags/imageUrls + ExchangeRates
- v8: LoanGroups + Loans 组合贷扩展 + SyncQueue
- v9: Transaction soft-delete (deletedAt)
- v10: Category UUID v5 迁移（cat_xxx → UUID）
- v11: Subcategory 支持（parentId/userId/iconKey/deletedAt）

**⚠️ 问题**:

1. **database.dart 超过 600 行** — 所有 CRUD 查询堆在 `AppDatabase` 类里（~50 个方法），应拆分为 DAO
2. **v10 迁移使用 raw SQL** — `_migrateCategoryUUIDs()` 用 `customStatement` 直接执行 SQL，绕过 Drift 类型安全
3. **缺少 down-migration** — 没有回退机制，数据库损坏只能重建
4. **Seed 数据硬编码** — 21 个预设分类 + 50+ 个子分类直接写在 database.dart，应抽到配置文件
5. **连接方式** — 使用 `NativeDatabase.createInBackground` 是正确的（后台 isolate）

### 2.2 表定义 (tables.dart)

**~325 行，23 张表定义**

- ✅ 所有表均有显式 `primaryKey`
- ✅ 外键引用使用 `.references(Table, #column)`
- ✅ 金额统一使用 `integer()` 存储（分），符合最佳实践
- ✅ Soft-delete 统一用 `deletedAt` nullable DateTime
- ⚠️ `FamilyMembers.id` 是独立 text PK（非 `familyId + userId` 复合键），查询时需额外 where

---

## 3. 数据层 — data/remote/

### 3.1 gRPC Clients (grpc_clients.dart)

**~155 行，15 个 gRPC Client Provider**

| Client | Service |
|--------|---------|
| authClientProvider | AuthService |
| transactionClientProvider | TransactionService |
| syncClientProvider | SyncService |
| familyClientProvider | FamilyService |
| accountClientProvider | AccountService |
| budgetClientProvider | BudgetService |
| notifyClientProvider | NotifyService |
| loanClientProvider | LoanService |
| investmentClientProvider | InvestmentService |
| marketDataClientProvider | MarketDataService |
| assetClientProvider | AssetService |
| dashboardClientProvider | DashboardService |
| exportClientProvider | ExportService |
| importClientProvider | ImportService |

**架构评价**:
- ✅ 单一 `ClientChannel` 通过 `grpcChannelProvider` 复用
- ✅ `AuthInterceptor` 统一注入 JWT
- ✅ `ref.onDispose(() => channel.shutdown())` 生命周期管理正确
- ⚠️ **credentials: ChannelCredentials.insecure()** — 开发环境可接受，正式环境需 TLS
- ⚠️ **serverHost = 'localhost'** — 硬编码，部署时需改为环境配置
- ⚠️ **无 token 刷新逻辑** — `AuthInterceptor` 只读取 `access_token`，token 过期后没有自动 refresh 流程
- ⚠️ **每个 Provider 都独立创建 interceptor 实例** — 15 个 `AuthInterceptor(prefs)` 实例，可共享

---

## 4. 领域层 — domain/providers/

### 4.1 Provider 汇总表

| Provider | 模式 | Local DB | gRPC | 错误处理 | Family 感知 |
|----------|------|----------|------|----------|-------------|
| **appProviders** | StateProvider / Provider | ✅ (DB singleton) | — | — | ✅ `currentFamilyIdProvider` |
| **authProvider** | StateNotifier\<AuthState\> | ✅ 用户/账户/分类 | ✅ register/login/oauthLogin | ✅ GrpcError catch → local fallback | ❌ 无 family 逻辑 |
| **transactionProvider** | StateNotifier\<TransactionState\> | ✅ Stream + CRUD | ✅ create/update/delete → sync queue | ✅ gRPC 失败写 SyncQueue | ✅ `watchTransactions(familyId)` |
| **accountProvider** | StateNotifier\<AccountState\> | ✅ | ✅ CRUD + transfer | ✅ gRPC fallback | ✅ `_familyId` 过滤 |
| **familyProvider** | StateNotifier\<FamilyState\> | ✅ | ✅ create/join/invite/leave/permissions | ✅ gRPC fallback | ✅ 核心 family 逻辑 |
| **budgetProvider** | StateNotifier\<BudgetState\> | ✅ | ✅ list/create/update/delete | ✅ gRPC fallback → local | ⚠️ `familyId = ''` 写死 |
| **dashboardProvider** | StateNotifier\<DashboardState\> | ✅ 本地计算 | ✅ 后台刷新（3s 超时） | ✅ 静默忽略远程失败 | ✅ `_familyId` |
| **notificationProvider** | StateNotifier\<NotificationState\> | ✅ | ✅ list/markRead/settings | ✅ gRPC fallback | ❌ 无 family 过滤 |
| **loanProvider** | StateNotifier\<LoanState\> | ✅ | ✅ list/create/delete/schedule/prepayment | ✅ gRPC fallback | ❌ 无 family 感知 |
| **investmentProvider** | StateNotifier\<InvestmentState\> | ✅ | ✅ CRUD + trade | ✅ gRPC fallback | ❌ 无 family 感知 |
| **assetProvider** | StateNotifier\<AssetState\> | ✅ | ✅ CRUD + valuation + depreciation | ✅ gRPC fallback | ❌ 无 family 感知 |
| **marketDataProvider** | StateNotifier\<MarketDataState\> | ✅ 15min 缓存 | ✅ getQuote/batch/search/history | ✅ 本地缓存 fallback | — 无需 family |
| **exchangeRateProvider** | StateNotifier\<Map\> | ✅ ExchangeRates 表 | ❌ TODO | ✅ 默认汇率 fallback | — |
| **exportProvider** | StateNotifier\<ExportState\> | ✅ 本地 CSV | ✅ export | ✅ 离线仅支持 CSV | ✅ `_familyId` |
| **syncStatusProvider** | StateNotifier\<SyncState\> | ✅ poll SyncQueue | — | ✅ | — |
| **themeModeProvider** | StateNotifier\<ThemeMode\> | ✅ SharedPrefs | — | — | — |

### 4.2 权限 Provider

```dart
canDeleteProvider   → Provider<bool>  // family mode: myPermissions.canDelete
canEditProvider     → Provider<bool>  // family mode: myPermissions.canEdit  
canCreateProvider   → Provider<bool>  // family mode: myPermissions.canCreate
canManageAccountsProvider → Provider<bool>
```

均在 `family_provider.dart` 中定义，个人模式下全部返回 `true`。

### 4.3 Provider 层问题

1. **❌ 职责过重** — 每个 Notifier 同时做状态管理 + DB 操作 + gRPC 调用 + 错误处理 + 离线降级。应拆分为 Repository + UseCase + Notifier。
2. **⚠️ Budget familyId 硬编码** — `budgetProvider` 中 `familyId = ''`，预算在家庭模式下不会过滤。
3. **⚠️ Loan/Investment/Asset 无 family 感知** — 这三个模块只按 userId 过滤，家庭共享贷款/投资的场景无法支持。
4. **⚠️ Auth 注册/登录时同步分类的代码重复 3 次**（register/login/oauthLogin）— 应提取为公共方法。
5. **⚠️ DashboardNotifier._computeLocalTrend** — 每个趋势点都调用 `getRecentTransactions(10000)`，6 个月调用 6 次，性能隐患。应改为单次查询按月聚合。
6. **⚠️ TransactionNotifier 无错误状态** — `TransactionState` 缺少 `error` 字段，addTransaction 失败时 UI 无法感知。
7. **⚠️ exchangeRateProvider** — 汇率刷新 `refreshRates()` 标注 TODO，实际未接入后端 API。

---

## 5. 功能模块 — features/

### 5.1 页面清单

| 模块 | 页面 | 行数 | 权限检查 | Loading | Error | Semantics |
|------|------|------|----------|---------|-------|-----------|
| **auth** | LoginPage | 283 | — | ✅ spinner | ✅ SnackBar | ✅ |
| **auth** | RegisterPage | 165 | — | ✅ spinner | ✅ SnackBar | ✅ |
| **home** | HomePage | 558 | — | — (shell) | — | ⚠️ 部分 |
| **dashboard** | DashboardPage | 1450 | — | ✅ | — | ⚠️ 无顶层 |
| **transaction** | AddTransactionPage | 641 | — | ✅ | ❌ 无错误 UI | ⚠️ 部分 |
| **transaction** | TransactionDetailPage | 492 | ✅ canEdit | ✅ | — | ✅ |
| **transaction** | TransactionHistoryPage | 431 | ✅ canDelete (swipe) | ✅ | — | ⚠️ 部分 |
| **account** | AccountsPage | 278 | ✅ canManageAccounts | ✅ | ✅ EmptyState | ✅ |
| **account** | AddAccountPage | 273 | — | ✅ | — | ✅ |
| **account** | TransferPage | 296 | — | ✅ | — | ✅ |
| **budget** | BudgetPage | 261 | ✅ canEdit | ✅ | ✅ | ✅ |
| **budget** | SetBudgetSheet | 303 | — | ✅ | — | ⚠️ 部分 |
| **budget** | BudgetExecutionCard | 242 | — | — | — | ✅ |
| **loan** | LoansPage | 583 | — | ✅ | ✅ ErrorState | ✅ |
| **loan** | AddLoanPage | 1140 | — | ✅ | — | ⚠️ 部分 |
| **loan** | LoanDetailPage | 1025 | — | ✅ | ✅ | ✅ |
| **loan** | LoanGroupDetailPage | 944 | — | ✅ | ✅ | ✅ |
| **loan** | PrepaymentPage | 590 | — | ✅ | — | ⚠️ 部分 |
| **loan** | RateChangeDialog | 151 | — | — | — | ⚠️ |
| **investment** | InvestmentsPage | 513 | — | ✅ | ✅ ErrorState | ✅ |
| **investment** | AddInvestmentPage | 413 | — | ✅ | — | ⚠️ 部分 |
| **investment** | InvestmentDetailPage | 741 | — | ✅ | — | ✅ |
| **investment** | TradePage | 380 | — | ✅ | — | ⚠️ 部分 |
| **investment** | PortfolioChart | 303 | — | — | — | ❌ 纯图表 |
| **asset** | AssetsPage | 427 | — | ✅ | ✅ ErrorState | ✅ |
| **asset** | AddAssetPage | 561 | — | ✅ | — | ⚠️ 部分 |
| **asset** | AssetDetailPage | 733 | — | ✅ | — | ✅ |
| **asset** | UpdateValuationDialog | 81 | — | — | — | ⚠️ |
| **notification** | NotificationsPage | 341 | — | ✅ | ✅ EmptyState | ✅ |
| **notification** | NotificationSettingsPage | 236 | — | — | — | ✅ |
| **settings** | SettingsPage | 625 | — | ✅ spinner | — | ✅ |
| **settings** | FamilyMembersPage | 386 | — | — | ✅ | ✅ |
| **settings** | CategoryManagePage | 539 | — | ✅ | — | ⚠️ 部分 |
| **report** | ReportPage | 447 | — | ✅ | — | ✅ |
| **report** | ExportPage | 346 | — | ✅ | ✅ 错误卡片 | ✅ |
| **import** | CsvImportPage | 579 | — | ✅ | ✅ | ✅ |
| **more** | MorePage | 248 | — | — | — | ✅ |

### 5.2 权限检查分析

| 权限 | 使用位置 |
|------|----------|
| `canEditProvider` | TransactionDetailPage（编辑按钮）、BudgetPage（设置预算 FAB + 编辑入口） |
| `canDeleteProvider` | TransactionHistoryPage（滑动删除） |
| `canCreateProvider` | ❌ **未在任何页面使用**（已定义但未消费） |
| `canManageAccountsProvider` | AccountsPage（添加账户 FAB） |

**⚠️ 问题**:
- `canCreateProvider` 定义了但从未被 UI 消费。AddTransactionPage 没有权限检查。
- Loan/Investment/Asset 页面完全没有权限检查（无 canEdit/canDelete 守卫）。
- 家庭模式下，任何成员都能创建贷款/投资/固定资产，无权限控制。

### 5.3 Loading/Error 状态

**✅ 良好**: 大多数列表页都有三态 UI（loading → empty → data / error）
- LoansPage、InvestmentsPage、AssetsPage 使用了 `ErrorState` 组件
- AccountsPage、NotificationsPage 使用了自定义 EmptyState

**⚠️ 缺失**:
- AddTransactionPage — 提交失败时无用户反馈（只有 dev.log）
- DashboardPage — gRPC 后台刷新失败时完全静默，用户无法知道数据是否陈旧
- AddLoanPage / AddInvestmentPage / AddAssetPage — 创建失败后无错误提示
- TransactionState 缺少 error 字段

### 5.4 Accessibility (Semantics)

**✅ 做得好的**:
- 大多数页面顶层包裹了 `Semantics(label: 'xxx页面')`
- TransactionDetailPage 中编辑按钮有 `Semantics(button: true, label: '编辑交易')`
- 金额显示使用 `SemanticAmount` 和 `SemanticPercent` 组件
- `a11yIconButton()` 工具函数确保 IconButton 有 tooltip
- `ContrastChecker` 工具类检查 WCAG AA 对比度

**⚠️ 需改进**:
- DashboardPage（1450 行）无顶层 Semantics
- PortfolioChart 纯图表无文字替代（屏幕阅读器用户完全跳过）
- RateChangeDialog、UpdateValuationDialog 缺少 Semantics
- 许多表单输入框缺少 `Semantics(textField: true)` 包装
- 底部导航栏未添加自定义 semanticLabel

---

## 6. 核心层 — core/

### 6.1 Router (app_router.dart)

**33 条路由定义**，全覆盖了所有 feature 页面。

| 检查项 | 状态 |
|--------|------|
| 所有页面都有路由 | ✅ |
| 默认路由 fallback | ✅ `default: _fade(HomePage())` |
| 参数传递 | ✅ `settings.arguments as Type` |
| 过渡动画 | ✅ _fade / _slide / _slideUp 三种 |
| 类型安全 | ⚠️ `arguments as String` 强转，无 null 检查可能 crash |

**⚠️ 问题**:
- 使用传统 `onGenerateRoute` 而非 go_router / auto_route，缺乏深度链接支持
- 路由参数没有 null safety 保护（如 `settings.arguments as String` 在 arguments 为 null 时会 crash）
- 无路由守卫（auth guard），`isLoggedIn` 只在 `initialRoute` 检查，deep link 可绕过

### 6.2 Theme

**文件**: app_theme.dart (150 行), app_colors.dart (50 行), amount_style.dart (70 行), accessibility.dart (100 行)

**✅ 优点**:
- Light/Dark 双主题完整定义
- `Material3 = true`，使用 `colorSchemeSeed`
- 金额专用字体样式 `AmountStyle`，使用 `tabularFigures` 等宽数字
- 语义化颜色：income=绿, expense=红, asset=蓝, liability=暖红
- 8 色色盲友好调色板 `chartPalette`

**⚠️ 问题**:
- `Google Fonts (DM Sans)` — 首次加载需要网络下载字体，离线环境可能 fallback 到系统字体
- `cardTheme.margin` 硬编码了 `horizontal: 16`，部分页面自行又加了 padding，导致累积间距

### 6.3 Widgets

共 12 个核心组件，导出统一通过 `widgets.dart`：

| 组件 | 行数 | 说明 |
|------|------|------|
| AnimatedCounter | 164 | 数字滚动动画 |
| AnimatedTabBar | 104 | Tab 切换动画 |
| CustomRefresh | 88 | 自定义下拉刷新 |
| EmptyState | 181 | 空状态占位（含动画） |
| ErrorState | 158 | 错误状态（含重试按钮） |
| MicroInteractions | 262 | 微交互动画集合 |
| SharedElementRoute | 90 | Hero 动画路由 |
| SkeletonLoading | 207 | 骨架屏 |
| SuccessAnimation | 168 | 成功动画（Lottie 风格） |
| SwipeToDelete | 164 | 滑动删除（确认） |
| SyncStatusIndicator | 74 | 同步状态小图标 |
| VirtualList | 103 | 高性能虚拟滚动列表 |

**✅ 组件库完善**，覆盖了常见 UI 模式。EmptyState 和 ErrorState 被广泛使用。

### 6.4 Constants

| 常量 | 值 | 备注 |
|------|----|------|
| serverHost | `localhost` | ⚠️ 硬编码 |
| grpcPort | 50051 | |
| wsPort | 8080 | |
| syncBatchSize | 50 | |
| syncIntervalSeconds | 30 | |
| pageSize | 20 | |

### 6.5 其他 core 文件

- `category_uuid.dart` (22 行) — UUID v5 生成器用于分类 ID 迁移
- `category_icons.dart` (263 行) — 子分类图标键到 IconData 的映射表

---

## 7. 同步引擎 — sync/

### 7.1 SyncEngine (sync_engine.dart, ~270 行)

**职责**:
1. 定时推送 SyncQueue → gRPC `PushOperations`
2. WebSocket 监听服务端推送
3. 收到通知后 gRPC `PullChanges` 增量拉取

**✅ 优点**:
- 支持指数退避重连（1s → 60s，带 jitter）
- 网络恢复时自动触发推送 + 重连
- `SyncEngine.forTesting()` 测试用 no-op 构造器
- 支持 transaction / account / category 三种实体同步

**⚠️ 问题**:
1. **仅同步 3 种实体** — Loan、Investment、FixedAsset、Budget 等模块的变更不经过 SyncQueue，离线时创建的这些实体仅存本地
2. **无冲突解决** — 如果两端同时修改同一 transaction，last-write-wins（服务端为准）
3. **WebSocket 明文传递 token** — `ws://...?token=$token`，生产需改为 wss + cookie
4. **`_pullChanges` 用了 `_prefs!`** — 如果 `_prefs` 为 null（forTesting 构造器），空操作而非 crash，但仍不优雅
5. **无断点续传** — PushOperations 如果中途失败，下次从头重推整个 batch（虽然已标记成功的不会重推）

---

## 8. 跨切面问题汇总

### 8.1 🔴 严重问题

| # | 问题 | 影响 | 位置 |
|---|------|------|------|
| S1 | **Token 无自动刷新** | access_token 过期后所有 gRPC 调用失败，直到用户重新登录 | grpc_clients.dart / auth_provider.dart |
| S2 | **路由参数无 null safety** | deep link 或 Navigation pop 时 `arguments as String` 可能 crash | app_router.dart |
| S3 | **canCreateProvider 未使用** | 家庭模式下无创建权限限制，member 可创建交易 | family_provider.dart / 所有 Add 页面 |
| S4 | **TransactionState 无 error 字段** | 交易创建/更新失败时用户无感知 | transaction_provider.dart |

### 8.2 🟡 中等问题

| # | 问题 | 影响 | 位置 |
|---|------|------|------|
| M1 | database.dart 600+ 行 God class | 可维护性差，所有 DAO 逻辑堆在一个类 | database.dart |
| M2 | Auth 注册/登录同步代码重复 3 次 | DRY 违反，bug fix 需改 3 处 | auth_provider.dart |
| M3 | Dashboard 趋势计算 O(n*m) | 每个月份查询全量 transaction（10000 条） | dashboard_provider.dart |
| M4 | Budget familyId 硬编码空字符串 | 家庭模式下预算无法按家庭隔离 | budget_provider.dart |
| M5 | Loan/Investment/Asset 无 family 感知 | 家庭共享资产管理不可能 | 对应 provider |
| M6 | SyncEngine 只同步 3 种实体 | 离线创建的贷款/投资/预算不会同步 | sync_engine.dart |
| M7 | serverHost/port 硬编码 | 部署需改代码 | app_constants.dart |
| M8 | 表单页面缺少错误提示 | AddLoan/AddInvestment/AddAsset 创建失败静默 | 对应页面 |

### 8.3 🟢 轻度问题 / 改进建议

| # | 问题 | 建议 |
|---|------|------|
| L1 | Google Fonts 依赖网络 | 打包字体到 assets/ |
| L2 | PortfolioChart 无无障碍替代 | 为图表添加 Semantics 摘要描述 |
| L3 | DashboardPage 无顶层 Semantics | 添加页面级语义标签 |
| L4 | exchangeRateProvider.refreshRates() 是 TODO | 接入后端汇率 API |
| L5 | 缺少国际化 (i18n) | 所有字符串硬编码中文 |
| L6 | 部分对话框缺少 Semantics | RateChangeDialog, UpdateValuationDialog |
| L7 | Provider 层缺少单元测试支架 | DB + gRPC 耦合使 mock 困难 |
| L8 | DashboardPage 1450 行 | 应拆分为多个子 widget 文件 |

---

## 9. 优先修复清单

### P0 — 立即修复

1. ✅ **Token 自动刷新** — `AuthInterceptor` JWT auto-refresh (`6dc67a5`)
2. ✅ **路由参数 null safety** — route null-safety (`454d2ad`)
3. ✅ **TransactionState 增加 error** — error field + reload + UI error state (`845e6f6`)

### P1 — 短期修复（1-2 周）

4. ✅ **canCreateProvider 接入** — 权限检查 + UI 门控 (`454d2ad`, `c4b819f`)
5. **Auth 同步代码去重** — 提取 `_syncServerDataToLocal()` 公共方法（未做）
6. **Dashboard 趋势性能** — 改为单次查询 + 内存分组（未做，local-first 缓解了体感）
7. **表单错误提示** — 部分页面已有（未全覆盖）

### P2 — 中期改进（1 个月）

8. **database.dart 拆分 DAO** — 按实体拆分（未做）
9. ✅ **Budget familyId 支持** — 家庭权限已扩展 (`f0ecf36`)
10. **SyncEngine 扩展实体** — 支持 loan / investment / asset 同步（未做）
11. **环境配置** — serverHost / port 从 .env / flavor 配置读取（未做）

### P3 — 长期架构优化

12. **引入 Repository 层** — 将 DB + gRPC 操作从 Notifier 中抽离
13. **路由升级** — 迁移到 go_router 或 auto_route
14. **国际化** — 引入 intl / slang
15. **字体本地化** — Google Fonts 打包到 assets
16. **Accessibility 全面审查** — 所有图表/对话框/表单添加完整 Semantics

---

*报告完毕。总体评价：代码质量中上，架构设计合理（offline-first + gRPC + Drift），核心功能完整。主要问题集中在 Provider 层职责过重、部分 family 模式权限未落实、以及一些离线/错误处理的边缘情况。*
