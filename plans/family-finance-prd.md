<!-- 同步自飞书文档: https://my.feishu.cn/docx/N507dBSDZoTDgzxyXUYctfFonZw -->

# PRD: 家庭资产管理系统（FamilyLedger）

> 版本: 1.0 | 日期: 2026-04-21 | 作者: Claw & 小Q

---

## Problem Statement

个人和家庭的资产分散在银行账户、投资平台、房产、贷款等多个维度，缺少一个统一的视角来管理全部财务状况。市面上的记账软件要么只做记账（不涉及投资/贷款），要么只做投资追踪（不管日常开销），要么不支持家庭多人协作。

用户需要一个**一站式的家庭资产管理平台**，能够：

- 记录日常收支
- 跟踪贷款还款计划
- 监控投资组合表现
- 管理固定资产
- 家庭成员协作共享数据
- 用一个 Dashboard 看清全部身家

---

## Solution

构建一个跨平台（iOS + Android）移动应用 **FamilyLedger**，配合自建 Go 后端，提供：

### 📱 客户端

> - Flutter 跨平台，原生体验
> - 离线优先，本地 SQLite
> - 联网自动同步

### 🎁 后端

> - Go + gRPC
> - PostgreSQL
> - WebSocket 实时同步

**核心能力：**

- **统一资产视图**：Dashboard 汇总净资产、收支、投资、负债
- **多模块覆盖**：记账、预算、贷款、投资、固定资产
- **家庭协作**：创建家庭组，邀请成员，权限分级
- **离线优先**：无网时可记账，联网后自动同步
- **智能提醒**：还款日、预算超支、账单日等推送通知

---

## User Stories

### 账户与认证

1. As a 用户, I want to 注册账号（手机号/邮箱）, so that 我能使用系统
1. As a 用户, I want to 使用微信/Apple 账号快速登录, so that 减少注册摩擦
1. As a 用户, I want to 创建一个"家庭", so that 我的家人可以共同管理财务
1. As a 家庭管理员, I want to 通过邀请码/链接邀请家人加入, so that 不需要交换账号信息
1. As a 家庭管理员, I want to 给成员分配角色（管理员/普通成员）, so that 控制谁能做什么
1. As a 家庭管理员, I want to 设置细粒度权限（如：普通成员只能记账，不能删除/导出）, so that 保护数据安全
1. As a 用户, I want to 同时拥有个人账本和家庭账本, so that 区分个人和家庭开支

### 账户管理

1. As a 用户, I want to 添加多个资金账户（银行卡、支付宝、微信、现金等）, so that 分别追踪每个账户余额
1. As a 用户, I want to 如果不想管理账户就使用默认账户, so that 简化使用
1. As a 用户, I want to 记录账户间转账, so that 资金流转不影响总额
1. As a 用户, I want to 查看每个账户的余额和交易记录, so that 了解资金分布

### 记账

1. As a 用户, I want to 快速记录一笔收入/支出, so that 不遗漏日常消费
1. As a 用户, I want to 选择预设分类（餐饮、交通、工资等）, so that 快速归类
1. As a 用户, I want to 创建自定义分类, so that 适应我的个人需求
1. As a 用户, I want to 给交易添加备注、标签、图片, so that 记录更多上下文
1. As a 用户, I want to 在没有网络时也能记账, so that 随时随地可用
1. As a 用户, I want to 联网后自动同步离线记录, so that 数据不丢失
1. As a 用户, I want to 通过 CSV 导入历史账单, so that 迁移已有数据
1. As a 用户, I want to 支持多币种记账, so that 海外消费也能记录
1. As a 用户, I want to 系统自动获取汇率并换算成人民币, so that 不需要手动查汇率

### 交易编辑与删除（NEW — 2026-04-24）

1. As a 用户, I want to 编辑已有的交易记录（金额、分类、备注、标签等）, so that 记错了可以修正
1. As a 用户, I want to 删除错误的交易记录, so that 保持账本准确
1. As a 用户, I want to 在交易列表左滑露出编辑和删除按钮, so that 操作便捷符合直觉
1. As a 用户, I want to 删除交易时有二次确认, so that 防止误删
1. As a 用户, I want to 编辑/删除操作在离线时也能执行，联网后同步到服务端, so that 随时随地可用
1. As a 用户, I want to 点击交易记录进入详情页查看完整信息并可编辑, so that 有清晰的查看和修改入口

### 预算管理

1. As a 用户, I want to 设置月度总预算, so that 控制整体开支
1. As a 用户, I want to 按分类设置子预算（餐饮 3000、交通 500 等）, so that 精细化管控
1. As a 用户, I want to 实时查看预算执行进度, so that 知道还能花多少
1. As a 用户, I want to 预算超支时收到提醒, so that 及时调整消费

### 贷款跟踪

1. As a 用户, I want to 添加贷款（房贷/车贷/信用卡/自定义）, so that 统一管理所有负债
1. As a 用户, I want to 输入贷款金额、利率、期限、起始日期, so that 系统自动生成还款计划
1. As a 用户, I want to 支持等额本息和等额本金两种还款方式, so that 匹配我的实际贷款
1. As a 用户, I want to 查看未来每个月的还款金额明细（本金+利息）, so that 做好资金规划
1. As a 用户, I want to 模拟提前还款, so that 评估是否值得提前还
1. As a 用户, I want to 记录利率变动（如 LPR 调整）, so that 还款计划自动更新
1. As a 用户, I want to 收到还款日提醒, so that 不会逾期
1. As a 用户, I want to 信用卡账单日和还款日提醒, so that 及时还款

### 组合贷款（NEW — 2026-04-23）

1. As a 用户, I want to 选择贷款形式（纯商贷/纯公积金/组合贷款）, so that 匹配我的实际房贷类型
1. As a 用户, I want to 组合贷款分别录入商贷和公积金部分的金额、利率、期限, so that 系统分别计算还款计划
1. As a 用户, I want to 选择利率类型（固定利率/LPR浮动）, so that 匹配我的实际贷款合同
1. As a 用户, I want to LPR浮动利率自动按年调整（每年1月或放款月）, so that 不需要手动修改利率
1. As a 用户, I want to 组合贷提前还款时选择先还哪部分（默认推荐商贷因为利率高）, so that 最大化节省利息
1. As a 用户, I want to 在贷款详情页用Tab查看总览/商贷/公积金各自的还款计划, so that 分别了解每笔贷款进度
1. As a 用户, I want to 在贷款列表看到组合贷的分拆月供（商贷+公积金）, so that 一眼看清每月实际还款构成

### 投资跟踪

1. As a 用户, I want to 添加投资品种（股票/基金/债券/加密货币）, so that 追踪投资组合
1. As a 用户, I want to 记录买入/卖出交易, so that 计算持仓成本和收益
1. As a 用户, I want to 查看实时行情（15 分钟延迟可接受）, so that 了解当前市值
1. As a 用户, I want to 查看多种收益率指标（总收益率、年化收益率、IRR）, so that 评估投资表现
1. As a 用户, I want to 支持 A 股、港股、美股、加密货币, so that 覆盖我的投资范围
1. As a 用户, I want to 投资模块可扩展, so that 未来能加入更多品种

### 固定资产

1. As a 用户, I want to 添加固定资产（房产、车辆等）, so that 纳入净资产计算
1. As a 用户, I want to 手动录入并定期更新资产估值, so that 反映真实价值
1. As a 用户, I want to 系统自动计算折旧（如车辆）, so that 不需要手动调整
1. As a 用户, I want to 自定义折旧方式和年限, so that 匹配不同资产类型

### Dashboard & 报表

1. As a 用户, I want to 在首页看到净资产总览, so that 一目了然
1. As a 用户, I want to 查看收支趋势图（月/年折线图）, so that 发现消费规律
1. As a 用户, I want to 查看分类支出占比（饼图）, so that 知道钱花在哪了
1. As a 用户, I want to 查看预算执行率图表, so that 直观了解预算状况
1. As a 用户, I want to 查看净资产变化趋势, so that 追踪财富增长
1. As a 用户, I want to 查看投资收益曲线, so that 评估投资表现随时间的变化

### 数据导出

1. As a 用户, I want to 导出数据为 CSV 格式, so that 在 Excel 中分析
1. As a 用户, I want to 导出数据为 Excel 格式, so that 直接打开使用
1. As a 用户, I want to 导出报表为 PDF, so that 存档或打印
1. As a 用户, I want to 按时间范围筛选导出, so that 只导出需要的数据
1. As a 用户, I want to 按分类筛选导出, so that 导出特定类型的数据
1. As a 用户, I want to 全量导出所有数据, so that 完整备份

### 通知

1. As a 用户, I want to 收到贷款还款日推送提醒, so that 不会忘记还款
1. As a 用户, I want to 收到信用卡账单日/还款日提醒, so that 及时处理
1. As a 用户, I want to 收到预算超支提醒, so that 控制开支
1. As a 用户, I want to 自定义提醒时间和方式, so that 不被打扰

---

## Implementation Decisions

### 整体架构

[架构图 — 见飞书文档](https://my.feishu.cn/docx/N507dBSDZoTDgzxyXUYctfFonZw)

### 客户端技术选型

| 技术 | 选型 | 说明 |
| --- | --- | --- |
| 语言 | Dart | Flutter 原生语言 |
| UI 框架 | Flutter + Material 3 | 平台自适应组件，原生体验 |
| 本地数据库 | Drift (SQLite ORM) | 离线优先的核心 |
| 状态管理 | Riverpod 2 | 编译期安全，可测试性强 |
| 网络层 | gRPC-dart | 与后端通信 |
| 图表 | fl_chart | 高性能图表库 |
| 推送 | firebase_messaging + APNs | 跨平台推送 |

### 客户端核心模块

| 模块 | 职责 | 关键接口 |
| --- | --- | --- |
| `SyncEngine` | 离线队列 + 冲突解决 + 增量同步 | `enqueue(op)`, `sync()`, `onConflict(resolver)` |
| `AccountBook` | 记账 CRUD、分类管理、CSV 导入 | `addTransaction(...)`, `import(csv)`, `listByFilter(...)` |
| `BudgetManager` | 预算设置、执行率计算、超支检测 | `setBudget(...)`, `getProgress(category, month)` |
| `LoanTracker` | 还款计划生成、提前还款模拟、利率变动 | `createLoan(...)`, `getSchedule()`, `simulatePrepay(...)` |
| `InvestmentPortfolio` | 持仓管理、收益计算、行情拉取 | `addHolding(...)`, `getReturns(method)`, `refreshQuotes()` |
| `AssetRegistry` | 固定资产管理、折旧计算 | `addAsset(...)`, `applyDepreciation()`, `updateValuation(...)` |
| `DashboardAggregator` | 汇总净资产、生成报表数据 | `getNetWorth()`, `getChartData(type, range)` |
| `ExportService` | 多格式导出、筛选条件 | `export(format, filter)` |

### 后端技术选型

| 技术 | 选型 | 说明 |
| --- | --- | --- |
| 语言 | Go 1.22+ | 高性能、简洁 |
| RPC 框架 | gRPC + protobuf | 类型安全、高效二进制传输 |
| 实时推送 | WebSocket | 多端数据同步通知 |
| 数据库 | PostgreSQL 16 | JSONB 支持、ACID |
| ORM / SQL | sqlc | 类型安全的 SQL 代码生成 |
| 认证 | JWT + OAuth2 | 微信/Apple 登录 |
| 推送 | FCM + APNs | Android + iOS 推送 |
| 部署 | Docker Compose on VPS | 单机部署，简单可靠 |

### 后端核心服务

| 服务 | 职责 |
| --- | --- |
| `AuthService` | 注册/登录、OAuth、JWT 签发/验证、家庭管理、权限控制 |
| `SyncService` | 接收客户端操作日志、冲突检测与合并、广播变更（WebSocket） |
| `TransactionService` | 交易记录 CRUD、分类管理、汇率转换 |
| `BudgetService` | 预算 CRUD、执行率计算 |
| `LoanService` | 贷款管理、还款计划生成、提前还款模拟、利率变动 |
| `InvestmentService` | 持仓管理、收益计算 |
| `MarketDataService` | 定时拉取行情/汇率、缓存、分发 |
| `AssetService` | 固定资产管理、折旧计算 |
| `NotifyService` | 推送通知调度（还款提醒、预算超支等） |
| `ExportService` | 服务端导出（大数据量时） |
| `DashboardService` | 聚合计算净资产、报表数据 |

### 数据库核心表设计（概要）

[数据库 ER 图 — 见飞书文档](https://my.feishu.cn/docx/N507dBSDZoTDgzxyXUYctfFonZw)

### 离线同步策略

> 🔄 **核心思路：Operation Log + Last-Write-Wins + WebSocket 广播**

- **客户端写入**：每次写操作生成一个带时间戳和客户端 ID 的 Operation Log，存入本地 `sync_queue` 表
- **联网时**：按序上传 Operation Log 到后端 `SyncService`
- **冲突解决**：Last-Write-Wins (LWW) 为主，关键字段（如账户余额）用服务端仲裁
- **实时同步**：后端通过 WebSocket 广播变更给同一家庭的所有在线设备
- **全量同步**：首次登录或长时间离线后，拉取全量快照

### 权限模型

| 角色 | 记账 | 编辑他人记录 | 删除 | 管理贷款/投资 | 管理成员 | 导出 |
| --- | --- | --- | --- | --- | --- | --- |
| 管理员 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 普通成员 | ✅ | ❌ | ❌ | 仅查看 | ❌ | ❌ |

> 权限可由管理员自定义调整，以上为默认值。

### 多币种处理

- 每笔交易记录**原始币种**和金额
- 同时记录当时的汇率和换算后的**人民币金额**
- 汇率来源：后端定时（每小时）从 exchangerate-api 拉取并缓存
- Dashboard 统一以**人民币**展示

### 折旧计算

- 支持**直线法**（默认）和**双倍余额递减法**
- 用户指定：原始价值、残值率、折旧年限
- 系统按月自动计算当前净值
- 车辆预设：5 年折旧，残值率 5%

---

## Testing Decisions

### 需要重点测试的模块

| 模块 | 测试方式 | 理由 |
| --- | --- | --- |
| `LoanTracker` / `LoanService` | 单元测试 | 还款计划计算、提前还款模拟涉及复杂财务算法，必须精确 |
| `SyncEngine` / `SyncService` | 单元 + 集成测试 | 离线同步 + 冲突解决是系统最复杂的部分 |
| `InvestmentPortfolio` | 单元测试 | IRR、年化收益率等计算必须准确 |
| `BudgetManager` | 单元测试 | 跨月、跨分类的预算计算 |
| `AuthService` | 集成测试 | JWT 签发/验证、权限控制不能出错 |
| `ExportService` | 集成测试 | 多格式输出的正确性 |
| 折旧计算 | 单元测试 | 财务计算精度 |
| 汇率转换 | 单元测试 | 精度 + 降级策略（API 不可用时） |

### 测试原则

- 测试**外部行为**，不测内部实现
- 财务计算类模块：用已知正确结果做**表驱动测试**（table-driven tests）
- 同步引擎：模拟多客户端并发场景
- 客户端：Widget 测试覆盖核心交互流程

---

---

## UX / UI 设计原则

> 🎨 **界面和交互是本项目的核心竞争力，不是附属品。宁可功能少一点，也不能体验差。**

### 设计标准

1. **对标一线产品**：交互质感对标 MoneyWiz、Copilot Money、YNAB，不是"能用就行"的工具软件
1. **动效不是装饰**：每一个转场、滑动、展开都要有物理感（弹性、惯性、阻尼），用 Flutter 的 `Hero`、`AnimatedContainer`、`Sliver` 做到 60fps 流畅
1. **信息密度适中**：Dashboard 要一屏看清关键数字，但不能密密麻麻——用**卡片 + 留白 + 层级**组织信息
1. **操作路径极短**：记一笔账 ≤ 3 次点击完成（金额 → 分类 → 确认），高频操作必须快
1. **手势驱动**：左滑删除、下拉刷新、长按编辑——遵循平台原生手势习惯，iOS 和 Android 各自适配

### 视觉规范

#### 🌙 深色模式优先

> - 财务类 App 用户经常晚上查看
> - 深色背景 + 高对比度数字
> - 亮色模式同样精心设计，不是简单反色

#### 🎯 色彩系统

> - 收入 = 绿色系，支出 = 红/橙色系
> - 资产 = 蓝色系，负债 = 暖红色系
> - 不超过 5 种主色，保持视觉统一
> - 图表配色需色盲友好

### 关键交互要求

| 场景 | 要求 | 参考 |
| --- | --- | --- |
| 记账输入 | 自定义数字键盘，大按键，触感反馈 | 随手记的数字键盘体验 |
| 分类选择 | 图标网格 + 最近使用 + 搜索，一步到位 | MoneyWiz 分类选择器 |
| Dashboard | 可拖拽排列的卡片，支持展开/折叠 | iOS 股票 App 的卡片布局 |
| 图表交互 | 手指触摸显示数据点，双指缩放时间轴 | Robinhood 的图表交互 |
| 还款计划 | 时间线视图，滑动浏览月份，高亮当月 | 日历式时间线 |
| 投资行情 | 迷你K线/走势图嵌入列表，涨跌色实时刷新 | 同花顺自选股列表 |
| 切换账本 | 顶部下拉切换个人/家庭，带头像和动画 | Notion 的 workspace 切换 |
| 空状态 | 每个页面都要有精心设计的空状态插图 + 引导 | 不允许出现白屏或"暂无数据"纯文字 |
| 加载状态 | Skeleton 骨架屏，不用 Loading 圈 | — |
| 错误状态 | 友好的错误页 + 一键重试，不暴露技术细节 | — |

### 字体与排版

- 数字使用**等宽字体**（如 SF Mono / DIN / Roboto Mono），对齐美观
- 金额数字要**大而醒目**，辅助信息用小字灰色
- 中文用系统字体，保证渲染质量
- 行间距、段落间距要舒适，不能挤在一起

### 微交互清单

- ✅ 记账成功：轻微震动 + 金额数字飞入卡片动画
- ✅ 下拉刷新同步：自定义刷新动画（不用默认的圆圈）
- ✅ 预算超支：进度条变红 + 脉冲动画警示
- ✅ 投资涨跌：数字变化时的滚动计数器效果
- ✅ 删除操作：左滑露出红色删除区域，二次确认
- ✅ Tab 切换：带下划线滑动跟随的 TabBar
- ✅ 页面转场：共享元素动画（如从列表点进详情）

## Out of Scope

> 🚫 以下功能**不在本期范围内**，留待后续迭代：
>
> - 自动导入银行流水（微信/支付宝 CSV 解析）
> - OCR 识别票据/小票
> - AI 自动分类
> - Web 端（仅移动端）
> - 国际化（仅中文）
> - 持仓成本分红再投资计算
> - 自动房产估值（如接链家 API）
> - 社交功能（如与朋友比较消费）
> - Apple Watch / 小组件

---

## Further Notes

### 预设分类体系

#### 💸 支出分类

> 餐饮、交通、购物、居住、娱乐、医疗、教育、通讯、人情、服饰、日用、旅行、宠物、其他

#### 💰 收入分类

> 工资、奖金、投资收益、兼职、红包、报销、其他

> 用户可新增、编辑、删除、排序自定义分类。预设分类不可删除但可隐藏。

### 行情数据源

| 市场 | 主数据源 | 备用数据源 |
| --- | --- | --- |
| A 股 | 东方财富 API | 新浪财经 |
| 港股 | 东方财富 API | Yahoo Finance |
| 美股 | Yahoo Finance | Alpha Vantage |
| 加密货币 | CoinGecko | Binance API |

### 安全考虑

- 所有通信走 **TLS**
- 密码 **bcrypt** 哈希
- JWT 有效期 7 天 + Refresh Token
- 敏感数据（如贷款金额）在客户端本地**加密存储**
- 家庭邀请码有效期 24 小时，一次性使用

---

> 📌 **项目暂定名：FamilyLedger**，后续可改。
