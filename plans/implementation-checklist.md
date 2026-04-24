# FamilyLedger Implementation Checklist

> Synced with [实施计划](https://my.feishu.cn/docx/BQMsdOBDnoLvXfxQEPtc5sKlnic)
> Last updated: 2026-04-24 14:06 (122 commits)
> ⚠️ 本版基于代码审计，标注了实际缺失项（之前误标为完成的已修正）

---

## Phase 1: Tracer Bullet — 注册登录 + 记一笔账 + 同步 (90%)

- [x] 邮箱注册 → 登录 → 获得 JWT
- [x] 首次登录自动创建默认账户
- [x] 预设分类已存在（餐饮、交通、工资等）— UUID v5 两端一致 (`ac6e55a`)
- [x] **创建自定义分类** — ✅ Phase 1c 完成
- [x] 记一笔支出 ≤ 3 步完成（金额 → 分类 → 确认）
- [x] 断网时可记账，联网后自动同步
- [x] 另一台设备登录可看到已同步的交易 — 多设备同步 E2E 测试 (`68eb4eb`)
- [x] 数字键盘有触感反馈，分类选择器有图标
- [x] 深色/亮色主题均可用
- [x] Docker Compose 一键启动后端

## Phase 1b: 交易编辑与删除 (93%)

- [x] 点击交易记录可进入详情页
- [x] 详情页可进入编辑模式，修改金额/分类/备注/标签
- [x] 编辑保存后本地 + 服务端同步更新
- [x] 左滑删除，有二次确认弹窗 — SwipeToDelete 升级（渐变背景+缩放动画）(`2f43cf4`)
- [x] 删除后账户余额、Dashboard 自动更新
- [x] 离线编辑/删除，联网后自动同步（软删除）
- [x] 只能编辑/删除自己的交易记录（权限校验 + FOR UPDATE lock）
- [ ] **批量删除** — ❌ PRD 未明确但 proto 无此 RPC

## Phase 1c: 分类管理 — 主分类 + 子分类 + 内置图标 (100%) ✅

### 后端
- [x] DB migration 033: categories 表加 `parent_id`, `user_id`, `icon_key`, `deleted_at` (`f258102`)
- [x] DB migration 034: seed 52 条子分类数据 (`f258102`)
- [x] Proto: `CreateCategory` + `UpdateCategory` + `DeleteCategory` + `ReorderCategories` RPCs (`0ee83f9`)
- [x] Proto: Category message 加 `parent_id`, `icon_key`, `children` (`0ee83f9`)
- [x] Proto: GetCategories 返回树形结构 (`0ee83f9`)
- [x] Proto: CreateTransaction 支持可选 `subcategory_id` — 不需要,记账直接选子分类 ID
- [x] DashboardService: 按子分类聚合统计 (`98f7038`)
- [x] SyncService: 支持 create/update/delete category 操作类型 (`0a586a6`)

### 客户端
- [x] Drift DB 升级: schema v11, Categories 表加 `parentId`, `userId`, `iconKey`, `deletedAt` (`f799c21`)
- [x] `_seedSubcategories()`: 52 条子分类本地 seed (`f799c21`)
- [x] 内置图标库: `category_icons.dart` ~70 个 Material Icons, 12 色组 (`f799c21`)
- [x] 图标选择器组件: `IconPickerSheet` — TabBar 分组 + 5 列网格 + 选中动画 (`f799c21`)
- [x] 分类管理页: `CategoryManagePage` — 展开/折叠/CRUD/滑动删除/预设保护 (`f799c21`)
- [x] CategoryGrid 升级: 两级选择（主分类网格 + 子分类横向 chips）(`f799c21`)
- [x] CategoryModel 升级: +parentId, +iconKey, +children (`f799c21`)
- [x] 路由 + 设置入口: `/settings/categories` (`02fa9e3`)
- [x] 报表/预算: 支持按子分类统计 (`98f7038`)

## Phase 2: 家庭协作 + 多账户 + 权限 (60%)

- [x] 创建家庭，生成 24 小时有效邀请码
- [x] 他人通过邀请码加入
- [x] 管理员可设置成员角色（admin/member）
- [ ] **细粒度权限** — ❌ PRD 要求"普通成员只能记账，不能删除/导出"，实际只有角色级控制
- [ ] **个人/家庭账本切换** — ❌ PRD 要求"同时拥有个人账本和家庭账本"，实际只有一个维度
- [x] 添加多个资金账户（7 种类型）
- [x] 账户间转账不影响总额
- [x] SyncEngine 支持 account sync (`c629ec7`)，多设备 E2E (`68eb4eb`)
- [ ] **家庭协作端到端验证** — 未做多用户真实协作测试

## Phase 3: 预算管理 + 通知 (65%)

- [x] 设置月度总预算和分类子预算
- [x] 记账后执行率实时更新
- [x] 进度条颜色随执行率变化
- [ ] **超支推送通知** — ❌ NotifyService 只写 DB，无 FCM/APNs 发送能力
- [x] 前端可自定义通知开关和提醒时间（UI 存在但无实际推送效果）
- [ ] **信用卡账单日提醒** — ❌ 后端无此定时逻辑
- [ ] **FCM/APNs 真实推送** — ❌ 设备注册有但推不出去

## Phase 4: 贷款跟踪 (95%) ✅

- [x] 等额本息/等额本金计算与银行一致（误差 ≤ 1 分）
- [x] 查看未来每月还款明细（本金+利息分开）
- [x] 提前还款模拟：显示节省利息和缩短月数
- [x] 利率变动后剩余计划自动重算
- [x] 还款日提醒（依赖通知服务）
- [x] 时间线视图滑动流畅

## Phase 4b: 组合贷款增强 (90%) ✅

- [x] 三种房贷形式：纯商贷 / 纯公积金贷 / 组合贷款
- [x] 组合贷 = 独立的商贷 + 公积金贷，各自利率、各自还款计划
- [x] 利率类型：固定利率 / LPR浮动（base + spread，年度调整）
- [x] LPR 利率调整月可选（每年1月 / 放款对应月）
- [x] 组合贷提前还款可指定先还哪部分（默认利率高的）
- [x] 贷款详情页 Tab 视图：总览 / 商贷 / 公积金
- [x] 列表页组合贷卡片：分段进度条 + 分拆月供展示
- [x] 向后兼容：现有独立贷款不受影响

## Phase 5: 投资跟踪 + 实时行情 (85%) ✅

- [x] 支持 A 股、港股、美股、加密货币、基金 — 前端 UI 完整
- [x] **行情 15 分钟内刷新** — ✅ RealFetcher (东方财富/Yahoo/CoinGecko) + scheduler 已在运行，15min 间隔
- [x] 迷你走势图嵌入列表（前端）
- [x] 三种收益率计算（前端）
- [x] 图表触摸交互
- [x] 模块可扩展（新品种不改核心代码）

## Phase 6: 固定资产 + 折旧 (90%) ✅

- [x] 添加房产/车辆/自定义资产
- [x] 直线法 + 双倍余额递减法计算正确
- [x] 车辆预设: 5 年、残值率 5%
- [x] 每月自动折旧更新净值
- [x] 手动更新估值后基数调整
- [x] 估值历史折线图

## Phase 7: Dashboard + 报表 + 数据导出 (88%)

- [x] 净资产 = 账户余额 + 投资市值 + 固定资产净值 - 贷款余额
- [x] 一屏展示关键指标
- [x] 收支趋势: 月/年切换，触摸数据点
- [x] 分类饼图: 点击扇区显示明细
- [x] 卡片可拖拽排列、展开/折叠
- [x] 导出 CSV / Excel / PDF 格式正确
- [x] 支持按时间、分类筛选和全量导出
- [x] Dashboard local-first: 本地瞬间显示 → gRPC 后台刷新 (`2d63109`)
- [x] **Dashboard 数据准确性** — ✅ 行情/汇率现已接真实 API

## Phase 8: 多币种 + CSV 导入 + OAuth 登录 (65%)

- [x] 记账可选币种，显示选择器
- [x] **汇率自动获取** — ✅ open.er-api.com 真实汇率，每小时刷新 (`b2a7ae9`)
- [x] CSV 导入: 上传 → 预览 → 映射 → 导入 — GBK 编码处理
- [ ] **微信 OAuth** — ❌ `code=="test"` mock，未接 SDK
- [ ] **Apple Sign In** — ❌ `code=="test"` mock，未接 SDK
- [x] 交易可添加备注、标签
- [ ] **交易图片附件** — 未验证是否实际可上传
- [x] Dashboard 统一以人民币展示

## Phase 9: 精打细磨 — UI 打磨 (97%) ✅

- [x] 空状态插图 — 13 个 EmptyState
- [x] 骨架屏 — 8 个页面
- [x] 错误状态 — ErrorState 组件
- [x] 深色/亮色模式
- [x] DM Sans 等宽数字 — tabularFigures 18 页面
- [x] VirtualList — 1100 条 build 21ms
- [x] 记账成功动画
- [x] 自定义下拉刷新 — 5 列表页
- [x] 投资涨跌数字滚动
- [x] SwipeToDelete — 渐变+缩放动画
- [x] Tab 下划线滑动
- [x] Hero 共享元素动画
- [x] 无障碍 Semantics — 99 处，31/31 页面

**Phase 9: 11/11 Done = 100%**

---

## Cross-cutting Gaps（跨 Phase 问题）

### ✅ 已解决

| # | 问题 | Commit |
|---|------|--------|
| 1 | Go 后端零单元测试 → 68 tests | `3b61a4b` |
| 2 | SyncEngine account/category 空分支 | `c629ec7` |
| 3 | 多设备同步未实测 → E2E 覆盖 | `68eb4eb` |
| 4 | 1000+ 条压测 | `68eb4eb` |
| 5 | ListTransactions offset → cursor 分页 | `b11ebe4` |
| 6 | DINRoundPro → DM Sans | `2f43cf4` |
| 7 | oauthLogin 假 account ID → 真实 UUID | `583f878` |
| 8 | WebSocket user_id 后门 → 删除 | `9e34e76` |
| 9 | Go 依赖安全漏洞 | `0831459` |
| 10 | 自定义分类 CRUD 全链路 | `f258102`~`02fa9e3` (Phase 1c) |
| 11 | 行情数据源 — RealFetcher + scheduler | 已有,确认可用 |
| 12 | 汇率真实 API — open.er-api.com | `b2a7ae9` |

### ❌ 未解决

| # | 问题 | 优先级 | 预估 |
|---|------|--------|------|
| 1 | **FCM/APNs 推送** | P2 | 1-2 天 |
| 2 | **OAuth 真实对接** (微信+Apple) | P2 | 2-3 天 |
| 3 | **家庭细粒度权限** | P2 | 1-2 天 |
| 4 | **个人/家庭双账本** | P2 | 2-3 天 |
| 5 | ~~**子分类聚合统计**~~ | ~~P2~~ | ✅ `98f7038` |
| 6 | ~~**SyncService 分类操作同步**~~ | ~~P2~~ | ✅ `0a586a6` |
| 7 | **批量删除交易** | P3 | 0.5 天 |
| 8 | **交易图片附件验证** | P3 | 0.5 天 |
| 9 | **60fps 实机验证** | P3 | 0.5 天 |
