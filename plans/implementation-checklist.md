# FamilyLedger Implementation Checklist

> Synced with [实施计划](https://my.feishu.cn/docx/BQMsdOBDnoLvXfxQEPtc5sKlnic)
> Last updated: 2026-04-24 (98 commits)

---

## Phase 1: Tracer Bullet — 注册登录 + 记一笔账 + 同步

- [x] 邮箱注册 → 登录 → 获得 JWT
- [x] 首次登录自动创建默认账户
- [x] 预设分类已存在（餐饮、交通、工资等）
- [x] 记一笔支出 ≤ 3 步完成（金额 → 分类 → 确认）
- [x] 断网时可记账，联网后自动同步
- [ ] **另一台设备登录可看到已同步的交易** — 缺多设备实测
- [x] 数字键盘有触感反馈，分类选择器有图标
- [x] 深色/亮色主题均可用
- [x] Docker Compose 一键启动后端

**Phase 1 Today's fixes:**
- ✅ SyncEngine PushOperations now replays ops to business tables (commit `1e43bbf`)
- ✅ Frontend soft-delete (Drift v9, commit `1e43bbf`)

## Phase 1b: 交易编辑与删除 (NEW)

- [x] 点击交易记录可进入详情页
- [x] 详情页可进入编辑模式，修改金额/分类/备注/标签
- [x] 编辑保存后本地 + 服务端同步更新
- [x] 左滑删除，有二次确认弹窗 (Dismissible)
- [x] 删除后账户余额、Dashboard 自动更新
- [x] 离线编辑/删除，联网后自动同步
- [x] 只能编辑/删除自己的交易记录（权限校验 + FOR UPDATE lock）
- [ ] **删除动画流畅（slideOut + 列表自动收缩）** — 用 Dismissible 基础动画，未做自定义 slideOut

## Phase 2: 家庭协作 + 多账户 + 权限

- [x] 创建家庭，生成 24 小时有效邀请码
- [x] 他人通过邀请码加入
- [x] 管理员可设置成员权限
- [x] 普通成员受权限限制
- [x] 顶部切换个人/家庭，带动画
- [x] 添加多个资金账户
- [x] 账户间转账不影响总额
- [ ] **家庭成员操作实时同步** — WebSocket Hub 存在，缺多用户端对端实测

## Phase 3: 预算管理 + 通知

- [x] 设置月度总预算和分类子预算
- [x] 记账后执行率实时更新
- [x] 进度条颜色随执行率变化
- [x] 超支时推送通知 + 脉冲动画
- [x] 可自定义通知开关和提醒时间
- [ ] **FCM/APNs 真实推送** — 后端只写 DB 不发 push

## Phase 4: 贷款跟踪

- [x] 等额本息/等额本金计算与银行一致（误差 ≤ 1 分）
- [x] 查看未来每月还款明细（本金+利息分开）
- [x] 提前还款模拟：显示节省利息和缩短月数
- [x] 利率变动后剩余计划自动重算
- [x] 还款日、信用卡账单日推送提醒
- [x] 时间线视图滑动流畅

## Phase 4b: 组合贷款增强

- [x] 支持三种房贷形式：纯商贷 / 纯公积金贷 / 组合贷款
- [x] 组合贷 = 独立的商贷 + 公积金贷，各自利率、各自还款计划
- [x] 利率类型：固定利率 / LPR浮动（base + spread，年度调整）
- [x] LPR 利率调整月可选（每年1月 / 放款对应月）
- [x] 组合贷提前还款可指定先还哪部分（默认利率高的）
- [x] 贷款详情页 Tab 视图：总览 / 商贷 / 公积金
- [x] 列表页组合贷卡片：分段进度条 + 分拆月供展示
- [x] 向后兼容：现有独立贷款不受影响

## Phase 5: 投资跟踪 + 实时行情

- [x] 支持 A 股、港股、美股、加密货币
- [ ] **行情 15 分钟内刷新** — MockFetcher 假数据，未接真实 API
- [x] 迷你走势图嵌入列表
- [x] 三种收益率计算正确（table-driven 测试）
- [x] 图表触摸交互流畅
- [x] 模块可扩展（新品种不改核心代码）

## Phase 6: 固定资产 + 折旧

- [x] 添加房产/车辆/自定义资产
- [x] 直线法 + 双倍余额递减法计算正确（单元测试）
- [x] 车辆预设: 5 年、残值率 5%
- [x] 每月自动折旧更新净值
- [x] 手动更新估值后基数调整
- [x] 估值历史折线图

## Phase 7: Dashboard + 报表 + 数据导出

- [x] 净资产 = 账户余额 + 投资市值 + 固定资产净值 - 贷款余额
- [x] 一屏展示关键指标
- [x] 收支趋势: 月/年切换，触摸数据点
- [x] 分类饼图: 点击扇区显示明细
- [x] 卡片可拖拽排列、展开/折叠
- [x] 导出 CSV / Excel / PDF 格式正确
- [x] 支持按时间、分类筛选和全量导出

## Phase 8: 多币种 + CSV 导入 + OAuth 登录

- [x] 记账可选币种，自动换算人民币
- [x] 汇率每小时更新，API 不可用时降级用缓存
- [x] CSV 导入: 上传 → 预览 → 映射 → 导入
- [ ] **微信 OAuth + Apple Sign In 登录成功** — Mock 实现（code="test"），需对接真实 SDK
- [x] 交易可添加备注、标签、图片
- [x] Dashboard 统一以人民币展示

## Phase 9: 精打细磨 — UI 打磨 + 空状态 + 错误处理

- [x] 所有页面有空状态插图 — 13 个 EmptyState 预设
- [x] 所有列表加载使用骨架屏 — ✅ 今天全部替换完成 (commit `f61bd9c`)
- [ ] **8 项微交互全部实现且 60fps** — 见下方详细对照
- [x] 错误状态有友好页面 + 重试 — ✅ ErrorState 组件已集成 (commit `f61bd9c`)
- [ ] **1000+ 条交易列表滚动流畅** — VirtualList 组件存在但未集成到 transaction_history_page
- [x] 深色/亮色模式视觉均正确
- [x] 数字等宽字体，金额对齐美观 — tabularFigures 用于 18 个页面

### Phase 9 微交互详细对照

| 项目 | 组件存在 | 实际集成使用 | 状态 |
|------|---------|-------------|------|
| 空状态插图 | ✅ empty_state.dart | ✅ 13 个页面 | ✅ Done |
| 骨架屏 | ✅ skeleton_loading.dart | ✅ 8 个页面 | ✅ Done |
| 记账成功动画+震动 | ✅ success_animation.dart | ❌ **未在 add_transaction_page 中调用** | 🔴 Gap |
| 自定义下拉刷新 | ✅ custom_refresh.dart | ❌ **所有页面仍用默认 RefreshIndicator** | 🔴 Gap |
| 投资涨跌数字滚动 | ✅ animated_counter.dart | ❌ **未在 investments_page 中使用** | 🔴 Gap |
| 左滑删除 | ✅ swipe_to_delete.dart | ⚠️ transaction_history 用 Dismissible，未用自定义组件 | 🟡 Partial |
| Tab 下划线滑动 | ✅ animated_tab_bar.dart | ❌ **未在任何页面使用** | 🔴 Gap |
| 共享元素动画 | ✅ shared_element_route.dart | ❌ **未在列表→详情转场使用** | 🔴 Gap |
| 错误状态 | ✅ error_state.dart | ✅ 已集成 | ✅ Done |
| VirtualList 高性能列表 | ✅ virtual_list.dart | ❌ **未在 transaction_history 使用** | 🔴 Gap |
| 无障碍 | ✅ accessibility.dart | ✅ 部分页面有语义标签 | 🟡 Partial |

---

## Cross-cutting Gaps（跨 Phase 问题）

| # | 问题 | 影响 | 优先级 |
|---|------|------|--------|
| 1 | **Go 后端零单元测试** — 无 `_test.go` 文件 | 代码质量 | P1 |
| 2 | **MockFetcher** — 行情数据全假 | Phase 5 不可用 | P1 |
| 3 | **OAuth Mock** — code="test" 直接通过 | Phase 8 不可用 | P1 |
| 4 | **FCM/APNs Placeholder** — 通知不发推送 | Phase 3 不完整 | P2 |
| 5 | **category_id 不同步** — 本地 cat_food vs 服务端 UUID | Phase 1 数据一致性 | P1 |
| 6 | **Dashboard 纯依赖服务端** — 应优先本地聚合 | Phase 1 离线体验 | P1 |
| 7 | **多设备同步未实测** | Phase 1/2 | P2 |
| 8 | **Phase 9 组件集成** — 6 个组件写好了没用上 | UI 打磨 | P2 |
| 9 | **ListTransactions 用 offset 分页** — 大数据量性能差 | 性能 | P3 |
