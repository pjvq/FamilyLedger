# FamilyLedger Implementation Checklist

> Synced with [飞书实施计划](https://my.feishu.cn/docx/BQMsdOBDnoLvXfxQEPtc5sKlnic)
> Last updated: 2026-04-27 11:00 (269 commits)
> Go 330 test functions + Flutter 535 tests = **865 全绿**

---

## Phase 1: Tracer Bullet - 注册登录 + 记一笔账 + 同步 (95%)

- [x] 邮箱注册 → 登录 → 获得 JWT
- [x] 首次登录自动创建默认账户
- [x] 预设分类 (UUID v5 两端一致)
- [x] 创建自定义分类 (Phase 1c)
- [x] 记一笔支出 ≤ 3 步完成
- [x] 断网时可记账，联网后自动同步
- [x] 多设备同步 + LWW 冲突解决
- [x] 数字键盘触感反馈
- [x] 深色/亮色主题
- [x] Docker Compose 一键启动
- [x] 分页同步 (pageSize=100, maxPages=200)

## Phase 1b: 交易编辑与删除 (100%) ✅

- [x] 点击交易进入详情页
- [x] 详情页编辑模式
- [x] 编辑保存后本地 + 服务端同步
- [x] 左滑删除 + 二次确认
- [x] 删除后余额/Dashboard 自动更新
- [x] 离线编辑/删除 + 联网同步
- [x] 权限校验 (个人 + 家庭)
- [x] 家庭成员编辑/删除权限检查

## Phase 1c: 分类管理 (100%) ✅

- [x] 主/子分类 CRUD
- [x] 图标库选择
- [x] 排序 + 隐藏

## Phase 2: 家庭协作 + 多账户 + 权限 (95%)

- [x] 创建家庭组
- [x] 邀请码/链接邀请成员
- [x] 角色分配 (管理员/普通成员)
- [x] 细粒度权限 (can_create/can_edit/can_delete/can_manage_accounts/can_view)
- [x] 个人/家庭双账本切换
- [x] Dashboard 数据隔离 (个人排除家庭 / 家庭汇总成员)
- [x] 家庭数据实时同步 (WebSocket 广播全员)
- [x] 操作审计日志 (#28)
- [x] PullChanges 支持 family_id
- [ ] 多用户 E2E 测试

## Phase 3: 预算 + 通知 (85%)

- [x] 月度总预算 + 分类子预算
- [x] 实时预算执行进度
- [x] 家庭预算执行率 (汇总所有成员)
- [x] 预算超支通知 (本地 + WebSocket)
- [x] 家庭预算超支通知全员
- [x] 贷款还款日提醒
- [x] 信用卡账单日/还款日提醒 (#25)
- [x] 自定义提醒 CRUD (#21)
- [ ] FCM 推送 (目前只写 DB + WebSocket)

## Phase 4: 贷款跟踪 (95%)

- [x] 等额本息 / 等额本金
- [x] 还款计划生成
- [x] 提前还款模拟
- [x] 利率变动记录 (LPR)
- [x] 还款日提醒
- [x] 家庭贷款共享

## Phase 4b: 组合贷款 (90%)

- [x] 纯商贷 / 纯公积金 / 组合贷
- [x] 分别录入金额、利率、期限
- [x] 固定利率 / LPR浮动
- [x] Tab 查看总览/商贷/公积金
- [x] 列表显示分拆月供
- [ ] 提前还款选择先还哪部分

## Phase 5: 投资 + 行情 (90%)

- [x] 持仓管理 (A股/港股/美股/加密)
- [x] 买入/卖出记录
- [x] 实时行情 (15min 延迟)
- [x] 总收益率 / 年化收益率
- [x] IRR 计算 (Newton-Raphson XIRR) (#23)
- [x] 投资收益曲线 (月度趋势) (#24)
- [x] 行情拉取按交易时段调频 (#19)
- [x] 家庭投资组合汇总 (#9)
- [x] 迷你走势 sparkline + 触摸十字线
- [ ] 多数据源降级 (Yahoo → Alpha Vantage)

## Phase 6: 固定资产 + 折旧 (90%)

- [x] 添加固定资产 (房产/车辆)
- [x] 直线法折旧
- [x] 双倍余额递减法折旧
- [x] 自定义折旧方式和年限
- [x] 每月自动折旧
- [x] 家庭固定资产共享
- [ ] 估值历史图表优化

## Phase 7: Dashboard + 报表导出 (95%)

- [x] 净资产总览
- [x] 收支趋势图
- [x] 分类支出饼图
- [x] 预算执行率图表
- [x] 净资产变化趋势
- [x] 投资收益曲线 (#24)
- [x] 多币种汇率 API (#26)
- [x] CSV / Excel / PDF 导出
- [x] 全量 JSON 备份 (#22)
- [x] 家庭导出 (所有成员数据)
- [x] 按时间/分类筛选导出

## Phase 8: 多币种 + CSV导入 + OAuth (75%)

- [x] 多币种记账 + 自动汇率
- [x] 汇率定时刷新 (exchangerate-api)
- [x] 汇率 API 暴露给前端 (#26)
- [x] CSV 导入 4 步向导
- [x] GBK/UTF-8 自动检测
- [x] 导入 session 持久化 (30min TTL) (#20)
- [x] OAuth Provider 接口 (Mock/WeChat/Apple) (#13)
- [ ] 前端微信登录页面
- [ ] 前端 Apple Sign In 页面

## Phase 9: UI 打磨 (100%) ✅

- [x] 记账成功震动 + 飞入动画
- [x] 自定义下拉刷新动画
- [x] 预算超支脉冲动画
- [x] 投资涨跌滚动计数器
- [x] 左滑删除渐变+缩放
- [x] TabBar 下划线跟随
- [x] 共享元素转场动画
- [x] Skeleton 骨架屏
- [x] 空状态插图引导
- [x] 友好错误页 + 一键重试
- [x] 深色模式优先

## 基础设施

- [x] JWT 生产环境强制校验 (#17)
- [x] WebSocket Ping-Pong 心跳 (#16)
- [x] FileStorage 接口抽象 (#14)
- [x] 前端 Server-first ID 分配 (#18)
- [x] Operation Log 覆盖 7 种实体 (#27)
- [x] LWW 冲突解决策略
- [x] 分页同步 (pageSize=100)
- [ ] CI/CD Pipeline
- [ ] 生产部署文档
