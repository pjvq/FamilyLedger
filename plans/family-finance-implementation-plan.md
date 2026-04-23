<!-- 同步自飞书文档: https://my.feishu.cn/docx/BQMsdOBDnoLvXfxQEPtc5sKlnic -->

# FamilyLedger 实施计划

> Source PRD: [PRD: 家庭资产管理系统（FamilyLedger）](https://www.feishu.cn/docx/N507dBSDZoTDgzxyXUYctfFonZw)

> 🎯 **9 个 Phase，每个 Phase 是一个端到端的 vertical slice（Tracer Bullet），可独立交付和验证。**

---

## Architectural Decisions

### Monorepo 结构

```plaintext
familyledger/
├── proto/                    # Protobuf 定义（共享）
├── server/                   # Go 后端
│   ├── cmd/server/           # 入口
│   ├── internal/             # 各 service 实现
│   │   ├── auth/             # 认证
│   │   ├── sync/             # 同步
│   │   ├── transaction/      # 交易
│   │   ├── budget/           # 预算
│   │   ├── loan/             # 贷款
│   │   ├── investment/       # 投资
│   │   ├── asset/            # 固定资产
│   │   ├── market/           # 行情
│   │   ├── notify/           # 通知
│   │   ├── export/           # 导出
│   │   └── dashboard/        # 聚合
│   ├── pkg/                  # 公共包
│   ├── sql/                  # sqlc 查询定义
│   └── migrations/           # DB migrations
├── app/                      # Flutter 客户端
│   └── lib/
│       ├── core/             # 主题、路由、常量
│       ├── data/             # Drift DB、gRPC client
│       ├── domain/           # 业务逻辑 (Riverpod)
│       ├── features/         # 按功能模块组织 UI
│       └── sync/             # 离线同步引擎
└── docker-compose.yml
```

### 核心技术约定

#### 🔧 后端

- Go 1.22+ / gRPC + protobuf
- PostgreSQL 16 + uuid-ossp
- sqlc (类型安全 SQL)
- golang-migrate (迁移)
- JWT: access 15min + refresh 30d

#### 📱 客户端

- Flutter / Dart
- Drift (SQLite ORM) 离线优先
- Riverpod 2 状态管理
- gRPC-dart 通信
- fl_chart 图表

### 数据约定

- 所有实体用 **UUID** 主键
- 金额用 **int64 存分**（避免浮点精度），展示层 ÷ 100
- 时间统一用 `google.protobuf.Timestamp`
- 所有业务表带 `user_id` 或 `family_id`，query 层强制过滤
- 软删除：`deleted_at` 字段

### 离线同步

- 每次写操作生成 `SyncOp{id, entity_type, entity_id, op_type, payload, client_id, timestamp}`
- 联网后批量上传，服务端按 timestamp 排序应用
- 冲突策略：**LWW**（Last Write Wins），字段级合并
- WebSocket 广播 `ChangeEvent`，客户端增量拉取

---

## Phase 1: Tracer Bullet — 注册登录 + 记一笔账 + 同步

> 🚀 **User Stories**: #1, #8, #9, #12, #13, #16, #17
> 端到端打通：注册 → 登录 → 看到默认账户 → 记账 → 本地存储 → 同步到服务端 → 另一台设备可见

### What to build

#### 后端

- PostgreSQL schema: users, accounts, categories, transactions, sync_operations
- AuthService: 注册（邮箱+密码）、登录、JWT 签发/刷新
- TransactionService: 创建交易、查询交易列表
- SyncService: 批量上传 SyncOp、返回增量变更
- WebSocket: 连接管理、变更广播
- Proto: auth.proto, transaction.proto, sync.proto

#### 客户端

- Drift 本地 DB（users, accounts, categories, transactions, sync_queue）
- 登录/注册页面
- 首页: 简单交易列表 + 余额
- 记账页: **自定义数字键盘** + 预设分类网格选择器
- SyncEngine: 离线队列 + 联网自动上传 + WebSocket 接收
- Material 3 主题（深色+亮色）

### Acceptance criteria

- [ ] 邮箱注册 → 登录 → 获得 JWT
- [ ] 首次登录自动创建默认账户
- [ ] 预设分类已存在（餐饮、交通、工资等）
- [ ] 记一笔支出 ≤ 3 步完成（金额 → 分类 → 确认）
- [ ] 断网时可记账，联网后自动同步
- [ ] 另一台设备登录可看到已同步的交易
- [ ] 数字键盘有触感反馈，分类选择器有图标
- [ ] 深色/亮色主题均可用
- [ ] Docker Compose 一键启动后端

---

## Phase 1b: 交易编辑与删除 (NEW — 2026-04-24)

> 🛠️ **User Stories**: 交易编辑/删除的完整 CRUD 闭环
> 真机调试发现记错了无法修改，补充 Phase 1 缺失的编辑/删除能力。

### What to build

#### 后端

- Proto: transaction.proto 新增 `UpdateTransaction` + `DeleteTransaction` 两个 RPC
- `UpdateTransactionRequest`: transaction_id + 可更新字段（amount, category_id, note, tags, type, currency）
- `DeleteTransactionRequest`: transaction_id
- DB migration: transactions 表确认支持软删除（`deleted_at`）
- TransactionService 实现: 更新字段 + 软删除 + 重算账户余额
- SyncService: 支持 `update_transaction` 和 `delete_transaction` 操作类型
- 测试: 更新/删除的单元测试 + 权限校验（只能操作自己的交易）

#### 客户端

- Drift DB: `updateTransaction()` + 软删除方法
- TransactionNotifier: `updateTransaction()` + `deleteTransaction()`
  - 先更新本地 DB，再推 gRPC，失败则加入同步队列
  - 删除后重算账户余额 + 刷新 Dashboard
- 交易详情页 (TransactionDetailPage): 新建
  - 显示完整信息（金额、分类、备注、标签、图片、时间、账户）
  - 右上角编辑按钮 → 进入编辑模式（复用 AddTransactionPage UI）
  - 底部删除按钮（红色，二次确认）
- 交易列表: 左滑操作
  - 蓝色编辑按钮 + 红色删除按钮
  - 点击行 → 进入详情页
- SyncEngine: 支持 `update_transaction` 和 `delete_transaction` 操作类型

### UI 设计要求

- **左滑操作**: 与 PRD 微交互清单一致（“左滑露出红色删除区域 + 二次确认”）
- **编辑页**: 复用记账页 UI，预填已有数据，标题改为“编辑交易”
- **详情页**: 卡片式布局，显示分类图标 + 名称、金额、时间、备注、标签、图片
- **删除确认**: iOS 风格 AlertDialog，“确定删除这笔交易？” + 金额预览
- **动画**: 删除后列表项 slideOut 动画，编辑保存后卡片内容渐变更新

### Acceptance criteria

- [ ] 点击交易记录可进入详情页
- [ ] 详情页可进入编辑模式，修改金额/分类/备注/标签
- [ ] 编辑保存后本地 + 服务端同步更新
- [ ] 左滑删除，有二次确认弹窗
- [ ] 删除后账户余额、Dashboard 自动更新
- [ ] 离线编辑/删除，联网后自动同步
- [ ] 只能编辑/删除自己的交易记录（权限校验）
- [ ] 删除动画流畅（slideOut + 列表自动收缩）

---

## Phase 2: 家庭协作 + 多账户 + 权限

> 🎁 **User Stories**: #3, #4, #5, #6, #7, #10, #11
> 创建家庭 → 邀请成员 → 权限控制 → 多账户 + 转账

### What to build

#### 后端

- Schema: families, family_members (role + permissions JSON)
- AuthService 扩展: 创建家庭、邀请码生成、加入、权限管理
- TransactionService 扩展: 家庭上下文 CRUD、账户间转账
- AccountService: 多账户 CRUD
- gRPC 拦截器: 按 permissions 校验

#### 客户端

- 设置页: 创建家庭、邀请成员（分享邀请码）
- 顶部切换器: 个人 ↔ 家庭（带头像 + 动画）
- 账户管理页: CRUD 账户、查看余额
- 转账记录页: 来源/目标账户选择
- 权限管理页（管理员）

### Acceptance criteria

- [ ] 创建家庭，生成 24 小时有效邀请码
- [ ] 他人通过邀请码加入
- [ ] 管理员可设置成员权限
- [ ] 普通成员受权限限制
- [ ] 顶部切换个人/家庭，带动画
- [ ] 添加多个资金账户
- [ ] 账户间转账不影响总额
- [ ] 家庭成员操作实时同步

---

## Phase 3: 预算管理 + 通知

> 💰 **User Stories**: #21, #22, #23, #24, #55, #56, #57, #58
> 月度预算 + 分类子预算 → 执行进度 → 超支推送

### What to build

#### 后端

- Schema: budgets, notifications, user_devices
- BudgetService: 预算 CRUD、执行率计算
- NotifyService: FCM/APNs 推送、定时检查
- 定时任务: 每日检查预算超支

#### 客户端

- 预算设置页: 总预算 + 分类子预算
- 预算进度页: 进度条（绿→黄→红）
- 通知设置页: 各类通知开关
- FCM 集成
- 超支脉冲动画

### Acceptance criteria

- [ ] 设置月度总预算和分类子预算
- [ ] 记账后执行率实时更新
- [ ] 进度条颜色随执行率变化
- [ ] 超支时推送通知 + 脉冲动画
- [ ] 可自定义通知开关和提醒时间

---

## Phase 4: 贷款跟踪

> 🏦 **User Stories**: #25, #26, #27, #28, #29, #30, #31, #32
> 添加贷款 → 自动还款计划 → 提前还款模拟 → 利率变动 → 还款提醒

### What to build

#### 后端

- Schema: loans, loan_schedules, loan_rate_changes
- LoanService: 贷款 CRUD、还款计划生成（等额本息/等额本金）、提前还款模拟、利率变动处理
- NotifyService 扩展: 还款日、信用卡账单日提醒

#### 客户端

- 贷款列表页: 卡片展示（剩余本金、月还款、进度）
- 添加贷款表单: 类型/金额/利率/期限/起始日期/还款方式
- 还款计划页: **时间线视图**，滑动浏览月份，高亮当月
- 提前还款模拟页: 输入金额 → 节省利息对比
- 利率变动记录页

### Acceptance criteria

- [ ] 等额本息/等额本金计算与银行一致（误差 ≤ 1 分）
- [ ] 查看未来每月还款明细（本金+利息分开）
- [ ] 提前还款模拟：显示节省利息和缩短月数
- [ ] 利率变动后剩余计划自动重算
- [ ] 还款日、信用卡账单日推送提醒
- [ ] 时间线视图滑动流畅

---

## Phase 4b: 组合贷款增强 (NEW — 2026-04-23)

> 🏠 **新增 User Stories**: 支持商贷+公积金+组合贷在 Phase 4 基础上扩展，支持中国特色房贷：纯商贷、纯公积金、商贷+公积金组合贷款

### 调研结论

| 类型 | 利率特征 | 还款计划 |
| --- | --- | --- |
| **纯商贷** | LPR + 基点（浮动）或固定 | 单笔独立计算 |
| **纯公积金** | 固定利率（首套 2.85%，二套 3.325%） | 单笔独立计算 |
| **组合贷** | 两笔独立贷款，各自利率 | 分别计算，合并展示 |

**核心逻辑**：组合贷 = 一笔公积金贷 + 一笔商贷，各自独立计算月供，合并展示总月供。

### What to build

#### 后端

- Schema: loan_groups 表（组合贷容器）, loans 新增 group_id/sub_type/rate_type/lpr_base/lpr_spread/rate_adjust_month
- LoanService 扩展: CreateLoanGroup（事务创建 group + 子贷款 + schedule）, GetLoanGroup, ListLoanGroups, SimulateGroupPrepayment
- LPR 利率计算: effective_rate = lpr_base + lpr_spread
- 组合贷提前还款: 可指定先还哪笔（默认利率高的）
- Proto: 新枚举 LoanSubType/RateType, 新 message LoanGroup, 4 个新 RPC

#### 客户端

- 添加贷款重构: 3 选 1 入口（商贷🏦/公积金🏠/组合贷🏘️）
- 组合贷向导: Step 1 总额 → Step 2 公积金部分 → Step 3 商贷部分
- LPR 浮动利率: "LPR基准" + "基点偏移" 两个输入框
- 贷款详情: Tab 视图（总览/商贷/公积金）
- 贷款列表: 组合贷卡片（分段进度条 + 分拆月供）
- 提前还款: 选择还哪部分

### Acceptance criteria

- [ ] 支持纯商贷、纯公积金、组合贷款三种形式
- [ ] 组合贷 = 独立商贷 + 独立公积金贷，各自利率、各自还款计划
- [ ] 利率类型: 固定 / LPR浮动（base + spread，年度调整）
- [ ] 组合贷提前还款可指定先还哪部分（默认推荐商贷）
- [ ] 贷款详情 Tab 视图: 总览/商贷/公积金
- [ ] 列表组合贷卡片: 分段进度条 + 分拆月供展示
- [ ] 向后兼容: 现有独立贷款不受影响

---

## Phase 5: 投资跟踪 + 实时行情

> 📈 **User Stories**: #33, #34, #35, #36, #37, #38
> 投资品种管理 → 买卖记录 → 实时行情 → 多种收益率 → 可扩展

### What to build

#### 后端

- Schema: investments, investment_trades, market_quotes
- InvestmentService: 持仓管理、收益计算（总收益率/年化/IRR）
- MarketDataService: 定时拉取行情（东方财富/Yahoo/CoinGecko），15 分钟缓存
- 定时任务: 交易时段每 15 分钟，非交易时段降频

#### 客户端

- 投资列表: 每行嵌入**迷你走势图**，涨跌色实时刷新
- 添加投资: 搜索代码/名称，选择市场
- 交易记录: 买入/卖出表单
- 投资详情: 收益率切换、走势图（触摸数据点、双指缩放）
- 组合汇总: 持仓占比饼图

### Acceptance criteria

- [ ] 支持 A 股、港股、美股、加密货币
- [ ] 行情 15 分钟内刷新
- [ ] 迷你走势图嵌入列表
- [ ] 三种收益率计算正确（table-driven 测试）
- [ ] 图表触摸交互流畅
- [ ] 模块可扩展（新品种不改核心代码）

---

## Phase 6: 固定资产 + 折旧

> 🏠 **User Stories**: #39, #40, #41, #42
> 添加固定资产 → 折旧自动计算 → 估值更新 → 纳入净资产

### What to build

#### 后端

- Schema: fixed_assets, asset_valuations, depreciation_rules
- AssetService: 资产 CRUD、折旧计算（直线法/双倍余额递减法）
- 定时任务: 每月 1 日自动折旧

#### 客户端

- 资产列表: 卡片（名称、类型、估值、折旧进度）
- 添加资产: 类型/购入价/日期
- 折旧设置: 方式/年限/残值率（车辆预设）
- 估值历史: 折线图

### Acceptance criteria

- [ ] 添加房产/车辆/自定义资产
- [ ] 直线法 + 双倍余额递减法计算正确（单元测试）
- [ ] 车辆预设: 5 年、残值率 5%
- [ ] 每月自动折旧更新净值
- [ ] 手动更新估值后基数调整
- [ ] 估值历史折线图

---

## Phase 7: Dashboard + 报表 + 数据导出

> 📊 **User Stories**: #43, #44, #45, #46, #47, #48, #49, #50, #51, #52, #53, #54
> 净资产总览 → 多维图表 → 报表 → 多格式导出

### What to build

#### 后端

- DashboardService: 聚合计算净资产（现金 + 投资市值 + 固定资产 - 贷款余额）、各维度报表数据
- ExportService: 按筛选条件导出 CSV / Excel / PDF

#### 客户端

- Dashboard 重构:
  - 净资产总卡片（大数字 + 较上月变化）
  - 资产构成饼图
  - 收支趋势折线图（月/年切换）
  - 分类支出饼图
  - 预算执行率卡片
  - 净资产趋势线
  - 投资收益曲线
  - **卡片可拖拽排序、展开/折叠**
- 报表页: 时间范围筛选 + 详细表格
- 导出页: 格式选择 + 筛选条件

### Acceptance criteria

- [ ] 净资产 = 账户余额 + 投资市值 + 固定资产净值 - 贷款余额
- [ ] 一屏展示关键指标
- [ ] 收支趋势: 月/年切换，触摸数据点
- [ ] 分类饼图: 点击扇区显示明细
- [ ] 卡片可拖拽排列、展开/折叠
- [ ] 导出 CSV / Excel / PDF 格式正确
- [ ] 支持按时间、分类筛选和全量导出

---

## Phase 8: 多币种 + CSV 导入 + OAuth 登录

> 🌍 **User Stories**: #2 (OAuth), #14, #15, #18, #19, #20
> 多币种自动汇率 → CSV 导入 → 微信/Apple 登录 → 备注/标签/图片

### What to build

#### 后端

- Schema: exchange_rates
- MarketDataService 扩展: 每小时拉取汇率
- TransactionService 扩展: 多币种、汇率换算
- ImportService: CSV 解析、字段映射、批量导入
- AuthService 扩展: 微信 OAuth、Apple Sign In

#### 客户端

- 记账扩展: 币种选择器、自动换算人民币
- 交易详情扩展: 备注、标签、图片附件
- CSV 导入: 上传 → 字段映射预览 → 确认
- 登录扩展: 微信一键登录、Apple Sign In

### Acceptance criteria

- [ ] 记账可选币种，自动换算人民币
- [ ] 汇率每小时更新，API 不可用时降级用缓存
- [ ] CSV 导入: 上传 → 预览 → 映射 → 导入
- [ ] 微信 OAuth + Apple Sign In 登录成功
- [ ] 交易可添加备注、标签、图片
- [ ] Dashboard 统一以人民币展示

---

## Phase 9: 精打细磨 — UI 打磨 + 空状态 + 错误处理

> ✨ **覆盖全部 UX/UI 设计原则**
> 空状态 → 骨架屏 → 微交互 → 错误处理 → 性能优化 → 无障碍

### What to build

**全面打磨 UI 细节：**

| 项目 | 要求 |
| --- | --- |
| 空状态 | 每个页面精心设计的插图 + 引导文案，禁止出现"暂无数据"纯文字 |
| 骨架屏 | 所有列表加载使用 Skeleton，不用 Loading 圈 |
| 记账成功 | 轻微震动 + 金额数字飞入卡片动画 |
| 下拉刷新 | 自定义刷新动画 |
| 投资涨跌 | 数字滚动计数器效果 |
| 删除操作 | 左滑露出红色区域 + 二次确认 |
| Tab 切换 | 下划线滑动跟随 |
| 页面转场 | 共享元素动画（列表 → 详情） |
| 错误状态 | 友好文案 + 一键重试，不暴露技术细节 |
| 性能 | 列表虚拟化、图片缓存、1000+ 条交易滚动无掉帧 |
| 无障碍 | 语义标签、对比度达标 |

### Acceptance criteria

- [ ] 所有页面有空状态插图
- [ ] 所有列表加载使用骨架屏
- [ ] 8 项微交互全部实现且 60fps
- [ ] 错误状态有友好页面 + 重试
- [ ] 1000+ 条交易列表滚动流畅
- [ ] 深色/亮色模式视觉均正确
- [ ] 数字等宽字体，金额对齐美观

---

## Phase 总览

[架构图 — 见飞书文档](https://my.feishu.cn/docx/BQMsdOBDnoLvXfxQEPtc5sKlnic)

> 📅 **预估总工期：约 25 周（6 个月）**
> Phase 1-2 是地基，完成后系统已可日常使用记账。Phase 3-6 逐步扩展功能域。Phase 7-9 做集成和打磨。
