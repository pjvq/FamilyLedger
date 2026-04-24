# FamilyLedger 工作进展报告

> 截止 2026-04-24 17:35 | 146 commits | monorepo: proto/ + server/ (Go) + app/ (Flutter)
> Go 242 tests + Flutter 566 tests = **808 全绿**

---

## 总体进度

| Phase | 整体 | 说明 |
|-------|------|------|
| Phase 1: 注册登录 + 记账 + 同步 | **92%** | Docker Compose 一键启动 |
| Phase 1b: 交易编辑与删除 | **100%** ✅ | 含批量删除 `585b133` |
| Phase 1c: 分类管理 | **100%** ✅ | 主/子分类 + 图标库 + CRUD |
| Phase 2: 家庭协作 + 多账户 + 权限 | **90%** | 双账本+细粒度权限 ✅; 多用户 E2E 未验证 |
| Phase 3: 预算 + 通知 | **65%** | FCM/APNs 不发推送 |
| Phase 4: 贷款跟踪 | **95%** ✅ | 最完整模块 |
| Phase 4b: 组合贷款增强 | **90%** ✅ | 商贷+公积金+LPR |
| Phase 5: 投资 + 行情 | **85%** ✅ | RealFetcher + 15min 刷新 |
| Phase 6: 固定资产 + 折旧 | **90%** ✅ | 直线法+双倍余额法 |
| Phase 7: Dashboard + 报表导出 | **90%** | local-first + 真实行情/汇率 |
| Phase 8: 多币种 + CSV导入 + OAuth | **50%** | 汇率 ✅; OAuth ❌ mock |
| Phase 9: UI 打磨 | **100%** ✅ | 11/11 微交互全完成 |

**加权真实完成度: ~85%**

---

## 代码统计

| 指标 | 值 |
|------|------|
| Git commits | 146 |
| Proto 定义 | 1,406 行 / 13 文件 / 79 RPCs |
| Go 后端 (非 proto/vendor) | ~14,000 行 / 30+ 文件 |
| Go 测试 | **2,891 行 / 14 文件 / 242 tests** |
| Dart 客户端 (非 generated) | ~53,000 行 / 91 文件 |
| Dart 测试 | ~11,050 行 / 12 文件 / 566 tests |
| DB Migrations | 34 对 / 583 行 SQL |
| Shell E2E scripts | 3,315 行 |
| Drift schema version | 11 |
| 后端 Services | 15 |
| Flutter 页面 | 36 (含 dialogs/sheets) |
| Flutter providers | 16 |
| Scheduled tasks | 5 |

---

## 后端 Service 测试覆盖

| Service | 行数 | Tests | 覆盖要点 |
|---------|------|-------|---------|
| account | 687 | 10 | CRUD + 转账 |
| auth | 274 | 14 | Register + Login + OAuth + JWT |
| budget | 479 | 13 | CRUD + 子预算 |
| dashboard | 707 | 14 | NetWorth + Trend + Category + Budget |
| sync | 787 | 6 | Push + Pull |
| transaction | 1,013 | 11 | CRUD + cursor 分页 + 权限 |
| **loan** | **1,583** | **34** | CRUD + Schedule + Payment + Prepayment + 纯逻辑 |
| **asset** | **870** | **31** | CRUD + 估值 + 折旧规则 + 算法 |
| **investment** | **709** | **29** | CRUD + Trade + 验证 + 类型转换 |
| **family** | **665** | **17** | Create/Join/Leave + 角色 + 权限 |
| **notify** | **541** | **22** | 设备 + 设置 + 通知列表 + 已读 |
| **importcsv** | **445** | **16** | CSV 解析 + 编码 + 字段提取 |
| **market** | **424** | **17** | 行情 + 搜索 + 历史 |
| **export** | **330** | **14** | CSV/Excel/PDF |
| **合计** | **~9,500** | **242** | **14/15 service (exchange 无 RPC)** |

---

## 已完成的关键修复

| # | 问题 | 修复 | Commit |
|---|------|------|--------|
| 1 | gRPC UNAUTHENTICATED 错误 | token null → AuthInterceptor 修复 | `6dc67a5` |
| 2 | category_id 不匹配 | 登录后同步 accounts + categories | `ac6e55a` |
| 3 | SyncEngine 空分支 | account/category upsert/delete | `c629ec7` |
| 4 | offset 分页性能差 | cursor 分页 | `b11ebe4` |
| 5 | oauthLogin 假 account ID | 改为同步服务端账户 | `583f878` |
| 6 | WebSocket user_id 后门 | 删除 | `9e34e76` |
| 7 | Go 依赖安全漏洞 | 升级 | `0831459` |
| 8 | 细粒度权限缺失 | pkg/permission + 前端门控 | `c4b819f` |
| 9 | 个人/家庭切换缺失 | 双账本数据隔离 | `107ab8e` |
| 10 | 金融模块缺家庭权限 | budget/loan/investment/asset 权限 | `f0ecf36` |
| 11 | 图片上传安全隐患 | magic bytes + 配额 + 路径穿越 | `421935d` |
| 12 | Go 后端零测试 → 242 | pgxmock + testify 全覆盖 | `3b61a4b` → `7ae8578` |

---

## 剩余待办

### 🔴 P2 — 上线前必须

| # | 问题 | 预估 |
|---|------|------|
| 1 | FCM/APNs 真实推送 | 1-2 天 |
| 2 | OAuth 真实对接 (微信+Apple) | 2-3 天 |

### 🟡 P3 — 可后做

| # | 问题 | 预估 |
|---|------|------|
| 3 | 信用卡账单日提醒 | 0.5 天 |
| 4 | 家庭协作 E2E 验证 | 0.5 天 |
| 5 | 图片附件真机验证 | 0.5 天 |
| 6 | 60fps 真机性能验证 | 0.5 天 |
| 7 | 图片存储 → 对象存储 | 1 天 |
| 8 | 清理调试 print 语句 | 0.5 天 |

---

## Scheduled Tasks (5 个)

| Task | 频率 | 功能 |
|------|------|------|
| Budget + Loan Check | 每天 21:00 CST | 超支预算 + 贷款还款提醒 |
| Market Quotes Refresh | 每 15 分钟 | 东财/Yahoo/CoinGecko |
| Monthly Depreciation | 每月 1 号 00:05 | 固定资产自动折旧 |
| Exchange Rate Refresh | 每小时 | open.er-api.com |
| Import Session Cleanup | 每小时 | 清理过期导入会话 |
