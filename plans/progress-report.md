# FamilyLedger 工作进展报告

> 截止 2026-04-23 | 50 commits | 8,406 行 Go + 44,094 行 Dart（不含生成代码）

---

## 总体进度

| Phase | 后端 | 客户端 | 整体 |
|-------|------|--------|------|
| Phase 1: 注册登录 + 记账 + 同步 | ✅ 完成 | ✅ 完成 | **90%** |
| Phase 2: 家庭协作 + 多账户 | ✅ 完成 | ✅ 完成 | **85%** |
| Phase 3: 预算 + 通知 | ✅ 完成 | ✅ 完成 | **95%** |
| Phase 4: 贷款跟踪 | ✅ 完成 | ✅ 完成 | **95%** |
| Phase 5: 投资 + 行情 | ✅ 完成 | ✅ 完成 | **85%** |
| Phase 6: 固定资产 + 折旧 | ✅ 完成 | ✅ 完成 | **95%** |
| Phase 7: Dashboard + 报表导出 | ✅ 完成 | ✅ 完成 | **90%** |
| Phase 8: 多币种 + CSV导入 + OAuth | ✅ 完成 | ✅ 完成 | **80%** |
| Phase 9: UI 打磨 | — | 🟡 部分完成 | **60%** |

---

## 后端 (Go gRPC Server)

### 已完成 ✅

| 模块 | Service | 行数 | RPC 数 | 备注 |
|------|---------|------|--------|------|
| 认证 | AuthService | 274 | 4 | JWT + OAuth mock |
| 交易 | TransactionService | 364 | 3 | 支持 tags/image_urls |
| 同步 | SyncService | 179 | 2 | gRPC 增量同步 |
| 家庭 | FamilyService | 665 | 8 | 邀请码+权限 |
| 账户 | AccountService | 645 | 6 | 7种类型+转账 |
| 预算 | BudgetService | 479 | 6 | 月度+分类子预算 |
| 通知 | NotifyService | 541 | 6 | 设备注册+推送 |
| 贷款 | LoanService | 1,017 | 9 | 等额本息/本金+提前还款 |
| 投资 | InvestmentService | 645 | 8 | 持仓+交易记录 |
| 行情 | MarketDataService | 424+147+112 | 4 | Mock fetcher ±5% |
| 资产 | AssetService | 805 | 9 | 直线法+双倍余额递减 |
| 仪表盘 | DashboardService | 609 | 5 | 净资产+趋势+分类 |
| 导出 | ExportService | 322 | 1 | CSV/Excel/PDF |
| 导入 | ImportService | 428 | 2 | GBK+9种日期格式 |
| **合计** | **14 Services** | **~7,600** | **73 RPCs** | |

### 数据库
- **25 张表**: users, accounts, categories, transactions, transfers, families, family_members, sync_operations, budgets, category_budgets, notification_settings, notifications, user_devices, loans, loan_schedules, loan_rate_changes, investments, investment_trades, market_quotes, price_history, fixed_assets, asset_valuations, depreciation_rules, exchange_rates, import_sessions
- **29 个 migration** 文件
- **软删除**: accounts, transactions, loans, investments, fixed_assets
- **GIN 索引**: transactions.tags

### WebSocket + 定时任务
- WebSocket Hub 实时推送变更通知
- 每日 21:00 CST — 预算超支 + 贷款还款检查
- 每月 1 日 00:05 CST — 自动折旧
- 每小时 — 汇率刷新 + 导入会话清理
- 每 15 分钟 — 行情刷新 (crypto 24/7, 股票按交易时段)

### JWT 中间件
- gRPC 拦截器验证 Bearer token
- 排除 Register/Login/OAuthLogin 不需认证

---

## 客户端 (Flutter iOS)

### 已完成 ✅

| 功能 | 页面 | 核心交互 |
|------|------|----------|
| 认证 | login_page, register_page | 邮箱注册/登录, OAuth (微信/Apple) mock |
| 首页 | home_page | 5-tab 底部导航, 个人/家庭切换 |
| 仪表盘 | dashboard_page | 7 区域可拖拽 (ReorderableListView), 净资产渐变卡片, 资产构成饼图, 收支趋势折线图 |
| 记账 | add_transaction_page | 自定义数字键盘, 14 种分类图标, 收入/支出切换, 多币种选择器, 标签 chips, 图片附件 |
| 账户 | accounts_page, add_account_page, transfer_page | 7 种账户类型, 账户间转账 |
| 预算 | budget_page, budget_execution_card | 圆环进度 CustomPainter, 超支脉冲动画 |
| 通知 | notifications_page, notification_settings_page | 分组列表, 未读蓝点, 滑动已读 |
| 贷款 | loans_page, add_loan_page, loan_detail_page, prepayment_page | 时间线 CustomPainter, 等额本息/本金, 提前还款模拟, 利率变动 |
| 投资 | investments_page, add_investment_page, investment_detail_page, trade_page, portfolio_chart | 迷你走势 sparkline, fl_chart 触摸十字线, 组合饼图 |
| 资产 | assets_page, add_asset_page, asset_detail_page | 折旧预设, 渐变头部, 估值折线图 |
| 报表 | report_page, export_page | 报表筛选, share_plus 导出 |
| 导入 | csv_import_page | 4 步向导 (选文件→预览→映射→导入) |
| 更多 | more_page | 模块入口集合 |
| 设置 | settings_page, family_members_page | 家庭成员管理 |

### 数据层
- **Drift** 本地数据库 (schema v7): 完整离线支持
- **gRPC clients**: 全 14 个 service 的 Dart 客户端已生成
- **Providers**: 每个模块有 Riverpod Provider, gRPC first → local fallback
- **SyncEngine**: WebSocket 实时通知 + 定时增量同步 + 离线队列

### UI 组件库 (Phase 9)
| 组件 | 文件 | 状态 |
|------|------|------|
| EmptyState 空状态插图 | empty_state.dart | ✅ 已用于 13 个页面 |
| SkeletonLoading 骨架屏 | skeleton_loading.dart | ✅ 代码存在 |
| SuccessAnimation 成功动画 | success_animation.dart | ✅ |
| SwipeToDelete 滑动删除 | swipe_to_delete.dart | ✅ |
| AnimatedCounter 数字动画 | animated_counter.dart | ✅ |
| AnimatedTabBar 动画导航 | animated_tab_bar.dart | ✅ |
| SharedElementRoute 共享元素 | shared_element_route.dart | ✅ |
| ErrorState 错误状态 | error_state.dart | ✅ 代码存在 |
| VirtualList 虚拟列表 | virtual_list.dart | ✅ |
| AmountStyle 金额等宽 | amount_style.dart | ✅ 已用于 18 个页面 |
| Accessibility 无障碍 | accessibility.dart | ✅ 10+ 个页面有语义标签 |
| CustomRefresh 下拉刷新 | custom_refresh.dart | ✅ |

### 主题
- Material 3 + 深色/亮色主题
- 37 个 Dart 文件引用 Theme
- integration_test 验证了 dark mode 切换

---

## PRD 对照 — 逐条验收

### Phase 1: 注册登录 + 记账 + 同步

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| 邮箱注册→登录→获得 JWT | ✅ | AuthService 4 RPC |
| 首次登录自动创建默认账户 | ✅ | 在 Register 中创建 |
| 预设分类已存在 | ✅ | migration 预置 14 种分类 |
| 记一笔支出 ≤ 3 步 | ✅ | 金额→分类→确认 |
| 断网可记账,联网自动同步 | 🟡 | Drift 离线存储 ✅, SyncEngine 有队列 ✅, 但缺端到端联调验证 |
| 另一台设备登录可看到已同步交易 | 🟡 | 后端逻辑完备, 缺多设备实测 |
| 数字键盘有触感反馈 | ✅ | HapticFeedback + 语义标签 |
| 深色/亮色主题均可用 | ✅ | integration_test 截图验证 |
| Docker Compose 一键启动 | ✅ | `docker compose up -d` |

### Phase 2: 家庭协作 + 多账户

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| 创建家庭,生成 24h 邀请码 | ✅ | FamilyService.GenerateInviteCode |
| 通过邀请码加入 | ✅ | FamilyService.JoinFamily |
| 管理员设置成员权限 | ✅ | SetMemberRole + SetMemberPermissions |
| 普通成员受权限限制 | ✅ | 后端权限检查 |
| 顶部切换个人/家庭 | ✅ | home_page 切换器 |
| 多个资金账户 | ✅ | 7 种类型 |
| 账户间转账不影响总额 | ✅ | TransferBetween RPC |
| 家庭成员操作实时同步 | 🟡 | WebSocket Hub ✅, 缺多用户实测 |

### Phase 3: 预算 + 通知

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| 月度总预算+分类子预算 | ✅ | budgets + category_budgets |
| 执行率实时更新 | ✅ | GetBudgetExecution RPC |
| 进度条颜色随执行率变化 | ✅ | 圆环 CustomPainter |
| 超支推送+脉冲动画 | ✅ | 每日 21:00 检查 + 前端动画 |
| 自定义通知开关和提醒时间 | ✅ | notification_settings_page |

### Phase 4: 贷款跟踪

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| 等额本息/本金计算(误差≤1分) | ✅ | 尾差修正, 1017行 service |
| 每月还款明细(本金+利息分开) | ✅ | LoanSchedule |
| 提前还款模拟 | ✅ | reduce_months / reduce_payment |
| 利率变动后重算 | ✅ | RecordRateChange |
| 还款日推送提醒 | ✅ | 21:00 CST 定时检查 |
| 时间线视图 | ✅ | CustomPainter 时间线 |

### Phase 5: 投资 + 行情

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| A股/港股/美股/加密货币 | ✅ | 后端支持 4 种市场 |
| 行情 15 分钟刷新 | ✅ | 调度器按交易时段 |
| 迷你走势图嵌入列表 | ✅ | sparkline |
| 三种收益率计算 | ✅ | 持仓/累计/年化 |
| 图表触摸交互 | ✅ | fl_chart 十字线 |
| 模块可扩展 | ✅ | MockFetcher 可替换 |

**⚠️ 行情数据是 Mock**: MockFetcher 生成 ±5% 随机波动, 未接真实 API

### Phase 6: 固定资产 + 折旧

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| 房产/车辆/自定义资产 | ✅ | 带预设模板 |
| 直线法+双倍余额递减 | ✅ | 最后2年切直线, 残值保护 |
| 车辆预设 5年 5%残值 | ✅ | 前端预填 |
| 每月自动折旧 | ✅ | 每月 1 日 00:05 CST |
| 手动更新估值 | ✅ | UpdateValuation RPC |
| 估值历史折线图 | ✅ | asset_detail_page |

### Phase 7: Dashboard + 报表导出

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| 净资产公式正确 | ✅ | 账户+投资+资产-贷款 |
| 一屏关键指标 | ✅ | 7 区域 dashboard |
| 收支趋势月/年切换 | ✅ | TrendRequest 支持周期 |
| 分类饼图点击明细 | ✅ | CategoryBreakdown |
| 卡片可拖拽+折叠 | ✅ | ReorderableListView + SharedPreferences |
| CSV/Excel/PDF 正确 | ✅ | excelize + gofpdf + BOM |
| 按时间/分类筛选 | ✅ | ExportRequest 支持 filter |

### Phase 8: 多币种 + CSV导入 + OAuth

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| 记账可选币种 | ✅ | 币种选择器 + amount_in_default |
| 汇率每小时更新 | ✅ | exchange_service + 定时器 |
| API 不可用降级缓存 | ✅ | exchange_rates 表缓存 |
| CSV 4步导入 | ✅ | ParseCSV + ConfirmImport |
| 微信/Apple OAuth 登录 | 🟡 | **Mock 实现** (code="test"), 需替换真实 API |
| 标签+图片附件 | ✅ | tags GIN 索引 + image_urls |
| Dashboard 统一人民币 | ✅ | 默认 CNY 换算 |

### Phase 9: UI 打磨

| 验收标准 | 状态 | 说明 |
|----------|------|------|
| 所有页面有空状态插图 | ✅ | 13 个页面使用 EmptyState |
| 骨架屏加载 | 🟡 | 组件存在, **未在所有列表页集成** |
| 8 项微交互 60fps | 🟡 | 动画组件存在, 未全部验证 60fps |
| 错误状态+重试 | 🟡 | 组件存在, **未在所有页面集成** |
| 1000+条滚动流畅 | 🟡 | VirtualList 存在, 未压测 |
| 深色/亮色正确 | ✅ | 37 个文件适配, 截图验证 |
| 数字等宽对齐 | ✅ | tabularFigures 用于 18 个页面 |

---

## 未完成项 (按优先级排序)

### P0 — 核心功能缺失

| 项目 | 说明 | 工作量 |
|------|------|--------|
| 真实 OAuth 对接 | 微信 + Apple Sign In 目前是 mock | 2-3 天 |
| gRPC 端到端联调 | 前后端联调, 验证所有 73 个 RPC 能跑通 | 2-3 天 |
| 多设备同步实测 | 两台设备登录同账号, 验证 WebSocket 推送 | 1 天 |

### P1 — 行情数据

| 项目 | 说明 | 工作量 |
|------|------|--------|
| 真实行情 API | 东方财富/Yahoo Finance/CoinGecko 替换 MockFetcher | 2-3 天 |
| 真实汇率 API | 接 exchangerate-api.com 或央行数据 | 0.5 天 |

### P2 — UI 完善

| 项目 | 说明 | 工作量 |
|------|------|--------|
| SkeletonLoading 集成 | 所有列表页加上骨架屏 | 0.5 天 |
| ErrorState 集成 | 所有页面加上错误重试 | 0.5 天 |
| 性能压测 | 1000+ 条数据滚动验证 | 0.5 天 |
| 自定义字体 DINRoundPro | 金额数字专用字体 | 0.5 天 |
| 数字键盘 bug | 退格清空 + 金额最大长度限制 | 0.5 天 |

### P3 — 部署与运维

| 项目 | 说明 | 工作量 |
|------|------|--------|
| 后端集成测试 | gRPC 端对端测试用例 | 2 天 |
| CI/CD | GitHub Actions 编译+测试+Docker push | 1 天 |
| 生产环境部署 | SSL/TLS, 正式 JWT_SECRET, DB 备份策略 | 1-2 天 |
| App Store 上架 | 开发者账号+审核准备 | 1-2 天 |

---

## 代码统计

| 指标 | 数值 |
|------|------|
| Git commits | 50 |
| Go 代码 (不含 proto gen) | 8,406 行 / 21 文件 |
| Dart 代码 (不含 generated) | 44,094 行 / 139 文件 |
| Proto 定义 | 13 文件 / 73 RPCs |
| DB migrations | 29 个 |
| DB 表 | 25 张 |
| 后端 Services | 14 个 |
| Flutter 页面 | 28 个 |
| UI 组件 | 12 个 |
| 定时任务 | 5 个 |

---

## 架构亮点

1. **gRPC first, local fallback** — 每个 Provider 先尝试 gRPC, 失败降级到 Drift 本地操作
2. **离线优先** — SyncEngine 维护操作队列, 联网后自动推送
3. **WebSocket 实时推送** — Hub 广播变更通知, 客户端收到后触发增量拉取
4. **定时任务调度** — 行情按交易时段智能调度 (crypto 24/7, A股/港股工作日)
5. **折旧算法** — 双倍余额递减法最后 2 年切直线法, 净值不低于残值保护
6. **等额本息尾差修正** — 最后一期修正, 误差≤1分
7. **导入编码检测** — GBK/UTF-8 自动检测 + BOM 剥离 + 9 种日期格式
