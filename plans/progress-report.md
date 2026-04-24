# FamilyLedger 工作进展报告

> 截止 2026-04-24 15:20 | 132 commits | monorepo: proto/ + server/ (Go) + app/ (Flutter)
> 基于全量代码审查

---

## 总体进度

| Phase | 后端 | 客户端 | 整体 | 说明 |
|-------|------|--------|------|------|
| Phase 1: 注册登录 + 记账 + 同步 | ✅ | ✅ | **92%** | 批量删除缺失 |
| Phase 1b: 交易编辑与删除 | ✅ | ✅ | **93%** | 批量删除缺 proto |
| Phase 1c: 分类管理 | ✅ | ✅ | **100%** | 主/子分类+图标库+CRUD 全链路 |
| Phase 2: 家庭协作 + 多账户 + 权限 | ✅ | ✅ | **85%** | ✅ 双账本+细粒度权限; ❌ FCM/OAuth |
| Phase 3: 预算 + 通知 | ⚠️ | ⚠️ | **65%** | FCM 不发推送 |
| Phase 4: 贷款跟踪 | ✅ | ✅ | **95%** | 最完整模块 |
| Phase 4b: 组合贷款增强 | ✅ | ✅ | **90%** | |
| Phase 5: 投资 + 行情 | ✅ | ✅ | **85%** | RealFetcher + scheduler 在跑 |
| Phase 6: 固定资产 + 折旧 | ✅ | ✅ | **90%** | |
| Phase 7: Dashboard + 报表导出 | ✅ | ✅ | **90%** | local-first + 真实行情/汇率 |
| Phase 8: 多币种 + CSV导入 + OAuth | ⚠️ | ⚠️ | **65%** | 汇率 ✅; OAuth ❌ |
| Phase 9: UI 打磨 | - | ✅ | **100%** | 11/11 微交互 |

**加权真实完成度: ~83%**

---

## 代码统计

| 指标 | 值 |
|------|------|
| Git commits | 132 |
| Proto 定义 | 1,406 行 / 13 文件 / 79 RPCs |
| Go 后端 (非 proto/vendor) | 13,312 行 / 30 文件 |
| Dart 客户端 (非 generated) | 52,592 行 / 91 文件 |
| Dart generated (proto + drift) | 20,314 行 |
| Dart 测试 | 11,050 行 / 12 文件 |
| DB Migrations | 34 对 / 583 行 SQL |
| Shell E2E scripts | 3,315 行 |
| Go unit tests | 68 |
| Flutter widget tests | 566 |
| Shell E2E assertions | ~70 |
| Drift schema version | 11 |
| 后端 Services | 15 |
| Flutter 页面 | 36 (含 dialogs/sheets) |
| Flutter providers | 16 |
| Scheduled tasks | 5 (budget/market/depreciation/exchange/import-cleanup) |

---

## 架构概览

### 后端 (Go gRPC Server)

```
server/
├── cmd/server/main.go          — 入口, 15 service 注册, 5 scheduled tasks
├── internal/
│   ├── account/service.go      — 687 行, 9 方法, auth ✅, permission ✅, tx ✅
│   ├── asset/service.go        — 805 行, 13 方法, auth ✅, tx ✅, permission ❌
│   ├── auth/service.go         — 274 行, 4 方法, JWT + bcrypt
│   ├── budget/service.go       — 479 行, 9 方法, auth ✅, tx ✅
│   ├── dashboard/service.go    — 707 行, 6 方法, auth ✅
│   ├── export/service.go       — 330 行, 2 方法, auth ✅, permission ✅
│   ├── family/service.go       — 665 行, 11 方法, auth ✅, tx ✅
│   ├── importcsv/service.go    — 445 行, 3 方法, auth ✅, tx ✅
│   ├── investment/service.go   — 645 行, 9 方法, auth ✅, FOR UPDATE ✅
│   ├── loan/service.go         — 1,583 行, 18 方法, auth ✅, tx ✅ (最大)
│   ├── market/service.go       — 424 行, 6 方法 (public, no auth)
│   ├── market/exchange_service.go — 230 行, open.er-api.com 真实汇率
│   ├── market/fetcher.go       — 719 行, 东财/Yahoo/CoinGecko
│   ├── notify/service.go       — 541 行, 11 方法, auth ✅
│   ├── sync/service.go         — 787 行, 14 方法, auth ✅, replay ops ✅
│   └── transaction/service.go  — 1,013 行, 10 方法, auth ✅, permission ✅, tx ✅
├── pkg/
│   ├── category/uuid.go        — UUID v5 确定性分类 ID
│   ├── db/                     — Pool interface + config
│   ├── jwt/jwt.go              — HS256 JWT manager
│   ├── middleware/auth.go      — gRPC unary + stream auth interceptor
│   ├── permission/check.go     — Family permission checker (role + JSON)
│   └── ws/hub.go               — WebSocket hub (JWT auth)
└── migrations/                 — 34 up/down pairs
```

### 客户端 (Flutter)

```
app/lib/
├── core/
│   ├── router/app_router.dart  — 所有路由
│   ├── theme/                  — AppColors, dark/light, DM Sans
│   └── widgets/                — EmptyState, ErrorState, SwipeToDelete, NumberPad, ...
├── data/
│   ├── local/
│   │   ├── tables.dart         — 14 张 Drift 表定义
│   │   └── database.dart       — 980 行, schema v11, 11 migrations
│   └── remote/
│       └── grpc_clients.dart   — 14 gRPC client + AuthInterceptor
├── domain/providers/           — 16 个 Riverpod StateNotifier/Provider
├── features/                   — 14 模块, 43 dart 文件
│   ├── home/home_page.dart     — BottomNav + ModeSwitcher (个人↔家庭)
│   ├── transaction/            — 记账+历史+详情+编辑
│   ├── account/                — 账户管理+转账
│   ├── budget/                 — 预算设置+执行进度
│   ├── loan/                   — 贷款+组合贷+提前还款
│   ├── investment/             — 投资+交易+走势图
│   ├── asset/                  — 固定资产+折旧+估值
│   ├── dashboard/              — 综合仪表盘
│   ├── report/                 — 报表+导出
│   └── ...                     — auth, settings, notification, import
└── sync/sync_engine.dart       — 离线同步队列
```

---

## 后端 Service 详情

| Service | 行数 | RPC 数 | Tests | Auth | Permission | TX | FOR UPDATE |
|---------|------|--------|-------|------|------------|----|----|
| auth | 274 | 4 | 14 | - | - | 2 | - |
| transaction | 1,013 | 10 | 11 | 8 | 3 | 4 | 2 |
| account | 687 | 9 | 10 | 6 | 9 | 2 | 3 |
| family | 665 | 11 | 0 | 8 | - | 2 | - |
| sync | 787 | 14 | 6 | 2 | - | 1 | 3 |
| budget | 479 | 9 | 13 | 6 | - | 2 | - |
| notify | 541 | 11 | 0 | 6 | - | - | - |
| loan | 1,583 | 18 | 0 | 13 | - | 4 | - |
| investment | 645 | 9 | 0 | 8 | - | 1 | 1 |
| asset | 805 | 13 | 0 | 9 | - | 3 | - |
| market | 424 | 6 | 0 | - | - | - | - |
| exchange | 230 | - | 0 | - | - | - | - |
| dashboard | 707 | 6 | 14 | 5 | - | - | - |
| export | 330 | 2 | 0 | 1 | 1 | - | - |
| importcsv | 445 | 3 | 0 | 1 | - | 1 | - |
| **合计** | **9,615** | **125** | **68** | **73** | **13** | **22** | **9** |

### 测试覆盖

- **有测试 (6/15)**: auth(14), transaction(11), account(10), budget(13), dashboard(14), sync(6)
- **无测试 (9/15)**: family, notify, loan, investment, asset, market, exchange, export, importcsv

---

## 数据库 Schema (34 migrations)

| # | 表 | 说明 |
|---|---|------|
| 001 | users | email/password_hash/name |
| 002 | accounts | user_id, family_id, type, balance, currency |
| 003-004 | categories | 预设 + seed, parent_id (033-034 子分类) |
| 005 | transactions | amount, amount_cny, exchange_rate, deleted_at |
| 006 | sync_operations | op 日志 |
| 007-009 | families, family_members | role, permissions JSON, invite_code |
| 010 | transfers | from_account, to_account |
| 011-012 | budgets, category_budgets | 月度总/分类预算 |
| 013-015 | user_devices, notifications, notification_settings | 推送基础设施 |
| 016-018 | loans, loan_schedules, loan_rate_changes | 贷款全套 |
| 019-022 | investments, trades, market_quotes, price_history | 投资全套 |
| 023-025 | fixed_assets, asset_valuations, depreciation_rules | 固定资产 |
| 026 | exchange_rates | 汇率缓存 |
| 027 | transactions.tags | 标签扩展 |
| 028 | import_sessions | CSV 导入会话 |
| 029 | users.oauth_* | OAuth 扩展字段 |
| 030-031 | loan_groups | 组合贷款 |
| 032 | (fix) | UUID v5 分类修复 |
| 033-034 | categories | 子分类 parent_id + 52 条 seed |

---

## 前端 Provider 清单

| Provider | 类型 | 本地 DB | gRPC | 家庭感知 |
|----------|------|---------|------|----------|
| auth | StateNotifier | ✅ | ✅ | - |
| transaction | StateNotifier | ✅ watch | ✅ CRUD | ✅ familyId |
| account | StateNotifier | ✅ | ✅ | ✅ familyId |
| budget | StateNotifier | ✅ | ✅ | ❌ |
| dashboard | StateNotifier | ✅ local-first | ✅ 3s timeout | ❌ |
| family | StateNotifier | ✅ | ✅ | ✅ (核心) |
| loan | StateNotifier | ✅ | ✅ | ❌ |
| investment | StateNotifier | ✅ | ✅ | ❌ |
| asset | StateNotifier | ✅ | ✅ | ❌ |
| notification | StateNotifier | ✅ | ✅ | ❌ |
| exchange_rate | StateNotifier | ✅ | ✅ | - |
| market_data | StateNotifier | ✅ | ✅ | - |
| export | StateNotifier | - | ✅ | ❌ |
| sync_status | Provider | - | - | - |
| theme | StateNotifier | SharedPrefs | - | - |
| app_providers | Misc | - | - | - |

### Permission Providers (新增)

| Provider | 说明 |
|----------|------|
| `canCreateProvider` | 家庭模式下是否可创建 |
| `canEditProvider` | 家庭模式下是否可编辑 |
| `canDeleteProvider` | 家庭模式下是否可删除 |
| `canManageAccountsProvider` | 家庭模式下是否可管理账户 |

---

## 已知问题 & 风险

### 🔴 高优先级

| # | 问题 | 影响 | 预估修复 |
|---|------|------|---------|
| 1 | **FCM/APNs 推送空壳** | 通知只存 DB，设备收不到 | 1-2 天 |
| 2 | **OAuth mock** | `code=="test"` 直接过 | 2-3 天 |

### 🟡 中优先级

| # | 问题 | 影响 |
|---|------|------|
| 3 | budget/loan/asset/investment 缺 family permission 检查 | 家庭模式下这些模块无权限控制 |
| 4 | Go 后端 9/15 service 零测试 | loan(1583行)无任何测试 |
| 5 | 家庭协作未做多用户端到端验证 | 未知兼容性问题 |
| 6 | loan service 无 FOR UPDATE | 并发还款可能余额 race |

### 🟢 低优先级

| # | 问题 |
|---|------|
| 7 | 批量删除交易（proto 无此 RPC） |
| 8 | 交易图片附件未验证实际上传 |
| 9 | 60fps 实机性能验证 |
| 10 | 信用卡账单日提醒逻辑缺失 |

---

## Scheduled Tasks (5 个)

| Task | 频率 | 功能 |
|------|------|------|
| Budget + Loan Check | 每天 21:00 CST | 检查超支预算 + 贷款还款提醒 |
| Market Quotes Refresh | 每 15 分钟 | A股/港股/美股/基金/加密 (东财/Yahoo/CoinGecko) |
| Monthly Depreciation | 每月 1 号 00:05 | 固定资产自动折旧 |
| Exchange Rate Refresh | 每小时 | open.er-api.com 真实汇率 |
| Import Session Cleanup | 每小时 | 清理过期导入会话 |

---

## 测试体系

| 层级 | 数量 | 覆盖 |
|------|------|------|
| Go unit tests | 68 | 6/15 service |
| Flutter widget tests | 566 | 36/36 页面 |
| Shell E2E (scripts/) | ~24 assertions | 核心记账链路 |
| Shell E2E (tests/integration/) | ~48 assertions | 金融/分析/多设备/压测 |
| VirtualList perf | 6 | 1100 条 build 21ms |
| **总计** | **~712** | |

---

## 下一步优先级

| 优先级 | 工作 | 预估 | 状态 |
|--------|------|------|------|
| **P2** | FCM/APNs 推送集成 | 1-2 天 | 未开始 |
| **P2** | OAuth 真实对接 (微信+Apple) | 2-3 天 | 未开始 |
| **P3** | budget/loan/asset/investment family 权限 | 1 天 | 未开始 |
| **P3** | Go 后端剩余 9 service 测试 | 2-3 天 | 未开始 |
| **P3** | 家庭协作多用户 E2E | 1 天 | 未开始 |
| **P4** | 批量删除 / 图片附件 / 60fps | 1.5 天 | 未开始 |
