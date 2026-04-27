# FamilyLedger 工作进展报告

> 截止 2026-04-27 11:00 | 269 commits | monorepo: proto/ + server/ (Go) + app/ (Flutter)
> Go 330 test functions (18 packages) + Flutter 535 tests = **865 全绿**

---

## 总体进度

| Phase | 后端 | 客户端 | 整体 | 说明 |
|-------|------|--------|------|------|
| Phase 1: 注册登录 + 记账 + 同步 | ✅ | ✅ | **95%** | Docker Compose 一键启动 |
| Phase 1b: 交易编辑与删除 | ✅ | ✅ | **100%** ✅ | 含批量删除 + 家庭权限 |
| Phase 1c: 分类管理 | ✅ | ✅ | **100%** ✅ | 主/子分类+图标库+CRUD |
| Phase 2: 家庭协作 + 多账户 + 权限 | ✅ | ✅ | **95%** | 双账本+细粒度权限+审计日志+实时同步 |
| Phase 3: 预算 + 通知 | ✅ | ✅ | **85%** | 家庭超支通知全员; FCM 待配置 |
| Phase 4: 贷款跟踪 | ✅ | ✅ | **95%** | 最完整模块 |
| Phase 4b: 组合贷款增强 | ✅ | ✅ | **90%** | 商贷+公积金+LPR |
| Phase 5: 投资 + 行情 | ✅ | ✅ | **90%** | IRR + 收益曲线 + 交易时段调频 |
| Phase 6: 固定资产 + 折旧 | ✅ | ✅ | **90%** | 直线法+双倍余额法 |
| Phase 7: Dashboard + 报表导出 | ✅ | ✅ | **95%** | 家庭模式全支持 + 全量备份 |
| Phase 8: 多币种 + CSV导入 + OAuth | ✅ | ⚠️ | **75%** | 汇率API ✅; OAuth Provider接口 ✅; 前端OAuth页面待做 |
| Phase 9: UI 打磨 | - | ✅ | **100%** ✅ | 11/11 微交互全完成 |

**加权真实完成度: ~92%**

---

## 代码统计

| 维度 | 数值 |
|------|------|
| Go 代码行数 | ~43,700 (79 files) |
| Dart 代码行数 | ~56,600 (92 files, 非生成代码) |
| Proto 文件 | 13 |
| 数据库 Migration | 38 |
| Go Test Functions | 330 (18 packages) |
| Flutter Tests | 535 |
| Commits | 269 |

---

## 最近重大改动 (2026-04-27)

### 代码全面审查 — 发现 28 个问题并全部修复

审查文档：[飞书](https://www.feishu.cn/docx/IL5vdnsAFo5LQExzyaNcv5fbn3b)

| Commit | 范围 | Issues |
|--------|------|--------|
| `551d661` | P0 严重 Bug | #1-#6: Dashboard/Sync/Transaction 家庭模式缺失 |
| `18dae79` | P1 体验问题 | #7-#12: Export/Budget/Notify家庭 + 前端分页/LWW |
| `b581fc4` | P1 漏项 | #9: Investment家庭汇总 |
| `1902d5b` | P2 设计+新功能 | #13-#28: 见下方详细列表 |

#### P2 修复详情 (#13-#28)

**设计问题：**
- #13 OAuth → Provider 接口抽象 (Mock/WeChat/Apple)
- #14 图片存储 → FileStorage 接口 (Local + S3 预留)
- #16 WebSocket Ping-Pong 心跳 (30s/60s)
- #17 JWT Secret 生产环境强制校验 (≥32字符)
- #18 前端 addTransaction Server-first (消除 ID 闪烁)
- #19 MarketQuotes 按交易时段调频 (15min vs 4h)
- #20 CSV Session PostgreSQL 持久化 (30min TTL)

**新功能：**
- #21 自定义提醒 CRUD + 定时检查
- #22 全量数据备份 (JSON)
- #23 投资 IRR 计算 (Newton-Raphson XIRR)
- #24 投资收益曲线 (月度趋势)
- #25 信用卡账单日/还款日提醒
- #26 多币种汇率展示 API
- #27 离线同步扩展 (覆盖 7 种 entity_type)
- #28 家庭操作审计日志

**新增基础设施：**
- 3 个新 DB migration (036-038)
- 3 个新 Go package: `pkg/config`, `pkg/storage`, `pkg/audit`
- 100+ 新后端测试

---

## 仍待完成

| 优先级 | 事项 | 估计工作量 |
|--------|------|-----------|
| P1 | FCM 推送实际配置 (目前只写 DB + WebSocket) | 1 天 |
| P1 | 前端 OAuth 登录页面 (后端 Provider 已就绪) | 1 天 |
| P2 | 多用户 E2E 测试 (两个模拟器同时操作) | 2 天 |
| P2 | 数据恢复功能 (配合全量备份的 Restore 端) | 1 天 |
| P3 | Android 适配 + 发布 | 3 天 |
| P3 | CI/CD Pipeline (GitHub Actions) | 1 天 |

---

## 架构决策记录

| 决策 | 原因 |
|------|------|
| Local-first (Drift + SyncEngine) | 离线可用，体验流畅 |
| LWW 冲突解决 (Last-Write-Wins) | 简单可预测，家庭场景冲突率低 |
| gRPC + Proto | 类型安全，高效二进制传输 |
| WebSocket 实时推送 | 家庭成员操作即时可见 |
| Server-first ID 分配 | 消除 delete+re-insert 导致的 UI 闪烁 |
| FileStorage 接口 | 开发用本地磁盘，生产可切 S3 |
| OAuth Provider 接口 | 开发用 Mock，生产按需启用 WeChat/Apple |
| JWT 生产强制校验 | 防止开发默认值泄漏到生产 |
