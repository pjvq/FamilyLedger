# FamilyLedger Implementation Checklist

> Synced with [实施计划](https://my.feishu.cn/docx/BQMsdOBDnoLvXfxQEPtc5sKlnic)
> Last updated: 2026-04-24 17:35 (146 commits)
> Go 242 tests + Flutter 566 tests = **808 全绿**

---

## Phase 1: Tracer Bullet - 注册登录 + 记一笔账 + 同步 (90%)

- [x] 邮箱注册 → 登录 → 获得 JWT
- [x] 首次登录自动创建默认账户
- [x] 预设分类已存在(餐饮、交通、工资等)- UUID v5 两端一致 (`ac6e55a`)
- [x] **创建自定义分类** - ✅ Phase 1c 完成
- [x] 记一笔支出 ≤ 3 步完成(金额 → 分类 → 确认)
- [x] 断网时可记账,联网后自动同步
- [x] 另一台设备登录可看到已同步的交易 - 多设备同步 E2E 测试 (`68eb4eb`)
- [x] 数字键盘有触感反馈,分类选择器有图标
- [x] 深色/亮色主题均可用
- [x] Docker Compose 一键启动后端

## Phase 1b: 交易编辑与删除 (100%) ✅

- [x] 点击交易记录可进入详情页
- [x] 详情页可进入编辑模式,修改金额/分类/备注/标签
- [x] 编辑保存后本地 + 服务端同步更新
- [x] 左滑删除,有二次确认弹窗 - SwipeToDelete (`2f43cf4`)
- [x] 删除后账户余额、Dashboard 自动更新
- [x] 离线编辑/删除,联网后自动同步(软删除)
- [x] 只能编辑/删除自己的交易记录(权限校验 + FOR UPDATE lock)
- [x] **批量删除** - ✅ `585b133`

## Phase 1c: 分类管理 - 主分类 + 子分类 + 内置图标 (100%) ✅

- [x] DB migration: categories 表 `parent_id`, `user_id`, `icon_key`, `deleted_at` (`f258102`)
- [x] 52 条子分类 seed (`f258102`)
- [x] Proto: CRUD RPCs + 树形结构 (`0ee83f9`)
- [x] DashboardService 按子分类聚合 (`98f7038`)
- [x] SyncService 支持 category 同步 (`0a586a6`)
- [x] 客户端: Drift schema v11, 内置图标库 ~70 icons, IconPickerSheet, CategoryManagePage (`f799c21`)
- [x] CategoryGrid 两级选择 (`f799c21`)

## Phase 2: 家庭协作 + 多账户 + 权限 (90%)

- [x] 创建家庭,生成 24 小时有效邀请码
- [x] 他人通过邀请码加入
- [x] 管理员可设置成员角色(admin/member)
- [x] 细粒度权限 - `pkg/permission` + 后端强制 + 前端 UI 门控 (`c4b819f`)
- [x] 个人/家庭账本切换 - 前端切换器 + 后端数据隔离 (`107ab8e`)
- [x] 添加多个资金账户(7 种类型)
- [x] 账户间转账不影响总额
- [x] SyncEngine 支持 account sync (`c629ec7`)
- [ ] **家庭协作端到端验证** - 未做多用户真实协作测试

## Phase 3: 预算管理 + 通知 (65%)

- [x] 设置月度总预算和分类子预算
- [x] 记账后执行率实时更新
- [x] 进度条颜色随执行率变化
- [x] 前端通知设置 UI(开关 + 提醒天数)
- [ ] **FCM/APNs 真实推送** - ❌ NotifyService 只写 DB,无推送能力
- [ ] **超支推送通知** - ❌ 依赖推送
- [ ] **信用卡账单日提醒** - ❌ 后端无定时逻辑

## Phase 4: 贷款跟踪 (95%) ✅

- [x] 等额本息/等额本金(误差 ≤ 1 分)
- [x] 每月还款明细(本金+利息分开)
- [x] 提前还款模拟
- [x] 利率变动后重算
- [x] 还款日提醒(依赖通知)
- [x] 时间线视图

## Phase 4b: 组合贷款增强 (90%) ✅

- [x] 纯商贷 / 纯公积金贷 / 组合贷款
- [x] LPR 浮动利率(base + spread)
- [x] 组合贷提前还款可指定先还哪部分
- [x] 列表页组合贷卡片

## Phase 5: 投资跟踪 + 实时行情 (85%) ✅

- [x] A 股、港股、美股、加密货币、基金
- [x] RealFetcher (东方财富/Yahoo/CoinGecko) + 15min 刷新
- [x] 迷你走势图 + 图表触摸交互
- [x] 三种收益率计算
- [x] 模块可扩展

## Phase 6: 固定资产 + 折旧 (90%) ✅

- [x] 房产/车辆/自定义资产
- [x] 直线法 + 双倍余额递减法
- [x] 车辆预设: 5 年、残值率 5%
- [x] 每月自动折旧更新净值
- [x] 估值历史折线图

## Phase 7: Dashboard + 报表 + 数据导出 (90%)

- [x] 净资产 = 余额 + 投资市值 + 资产净值 - 贷款余额
- [x] 一屏展示关键指标
- [x] 收支趋势月/年切换
- [x] 分类饼图
- [x] 卡片拖拽排列
- [x] 导出 CSV / Excel / PDF
- [x] Dashboard local-first (`2d63109`)
- [x] 行情/汇率接真实 API

## Phase 8: 多币种 + CSV 导入 + OAuth (50%)

- [x] 记账可选币种
- [x] 汇率自动获取 - open.er-api.com (`b2a7ae9`)
- [x] CSV 导入(GBK 编码处理)
- [x] 交易备注、标签
- [x] Dashboard 统一人民币展示
- [x] **交易图片附件** - 代码完成 (`2bcaa1f`) + 安全加固 (`421935d`)
- [ ] **微信 OAuth** - ❌ mock,未接 SDK
- [ ] **Apple Sign In** - ❌ mock,未接 SDK

## Phase 9: UI 打磨 (100%) ✅

- [x] 空状态插图 (13 个) + 骨架屏 (8 页) + 错误状态
- [x] DM Sans 等宽数字 (18 页面)
- [x] VirtualList 1100 条 build 21ms
- [x] 记账成功动画 + 下拉刷新 + 涨跌滚动
- [x] SwipeToDelete 渐变+缩放 + Tab 下划线滑动 + Hero 动画
- [x] 无障碍 Semantics (99 处, 31/31 页面)

---

## 测试覆盖

| 层 | 测试数 | 覆盖范围 |
|----|--------|---------|
| **Go 后端** | **242** | 14 个 service 全覆盖: account, auth, budget, dashboard, sync, transaction, loan, asset, investment, family, notify, importcsv, market, export |
| **Flutter** | **566** | domain (models/providers), data (grpc/drift), features (widgets), sync engine |
| **合计** | **808** | |

关键 commits:
- `3b61a4b` 初始 68 Go tests
- `fa70666` loan 34 tests
- `7ae8578` 剩余 7 service 140 tests

---

## 剩余待办

### 🔴 P2 — 上线前必须

| # | 待办 | 预估 | 备注 |
|---|------|------|------|
| 1 | FCM/APNs 真实推送 | 1-2天 | 需 Firebase SDK + APNs 证书 |
| 2 | OAuth 真实对接 (微信+Apple) | 2-3天 | 需微信 AppID + Apple Developer |

### 🟡 P3 — 可后做

| # | 待办 | 预估 | 备注 |
|---|------|------|------|
| 3 | 信用卡账单日提醒 | 0.5天 | 后端无定时逻辑 |
| 4 | 家庭协作 E2E 验证 | 0.5天 | 多用户真实协作测试 |
| 5 | 交易图片附件真机验证 | 0.5天 | 代码完成,未跑通上传 |
| 6 | 60fps 真机性能验证 | 0.5天 | 需 Profile 模式 |
| 7 | 图片存储迁移对象存储 | 1天 | 本地磁盘 → S3/OSS |
| 8 | 清理调试 print 语句 | 0.5天 | |

### ✅ 已完成（本轮清零）

- [x] Go 后端全 service 测试 — 242 tests (`7ae8578`)
- [x] 图片上传安全加固 — magic bytes + 配额 + 路径穿越 (`421935d`)
- [x] 批量删除交易 (`585b133`)
- [x] 家庭权限扩展到 budget/loan/investment/asset (`f0ecf36`)
