# FamilyLedger 家庭资产管理

全功能家庭资产管理系统：**Flutter 客户端 (iOS/Android)** + **Go gRPC 后端**。

支持个人记账与家庭多人协作，涵盖记账、预算、贷款、投资、固定资产五大模块，一个 Dashboard 看清全部身家。

## 功能概览

| 模块 | 功能 |
|------|------|
| 📊 Dashboard | 净资产卡片、资产构成饼图、收支趋势、投资收益曲线、可拖拽布局 |
| 💳 记账 | 收入/支出、14 种预设分类+自定义、多币种(自动 CNY 换算)、标签、图片附件 |
| 🏦 账户 | 7 种账户类型(银行卡/现金/支付宝/微信/信用卡/投资/其他) |
| 💰 预算 | 月度总预算+分类子预算、圆环进度、超支脉冲动画+通知 |
| 🏠 贷款 | 等额本息/等额本金、组合贷(商贷+公积金)、提前还款模拟、LPR 利率变动 |
| 📈 投资 | 持仓管理、IRR 收益率、迷你走势 sparkline、组合饼图、A股/港股/美股/加密 |
| 🏗 固定资产 | 直线法/双倍余额递减法折旧、估值折线图 |
| 📑 导出 | CSV(UTF-8 BOM) / Excel(带样式) / PDF(横版 A4) / 全量 JSON 备份 |
| 📥 CSV 导入 | 4 步向导、GBK/UTF-8 自动检测、9 种日期格式、模糊分类匹配 |
| 🔔 通知 | 预算超支 + 贷款还款 + 信用卡账单日 + 自定义提醒 |
| 👨‍👩‍👧 家庭 | 创建家庭组、邀请成员、细粒度权限(5维)、操作审计日志、实时同步 |
| 🔐 认证 | JWT + OAuth(微信/Apple) + Provider 接口抽象 |
| 🔄 同步 | WebSocket 实时推送(Ping-Pong 心跳) + gRPC 增量同步 + LWW 冲突解决 + 分页拉取 |

## 架构

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Client (iOS/Android)                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │ Features │→ │ Domain   │→ │ Data     │→ │ Generated  │  │
│  │ (UI)     │  │ (Logic)  │  │ (Drift)  │  │ (Proto)    │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
│        ↕ gRPC + WebSocket                                    │
├─────────────────────────────────────────────────────────────┤
│  Go Server                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │ gRPC API │→ │ Business │→ │ Pipeline │→ │ PostgreSQL │  │
│  │ (proto)  │  │ (19 pkg) │  │ (stages) │  │ (46 migr)  │  │
│  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 客户端 — Clean Architecture + DIP

```
features/ (UI层)
    ↓ depends on
domain/ (业务层 — 纯 Dart，无框架依赖)
    ├── entities/       纯 domain 实体 (AccountEntity, TransactionEntity, CategoryEntity)
    ├── interfaces/     抽象 repository 接口 (ITransactionRepository, IAccountRepository, ICategoryRepository)
    ├── services/       业务服务 (BalanceCalculator, CategorySyncService, OfflineSyncQueue)
    ├── providers/      StateNotifier (依赖接口，不依赖 concrete)
    └── repositories/   接口实现 (Drift-backed, 可替换为 mock)
    ↑ implements
data/ (基础设施层 — Drift DB, gRPC clients)
```

**依赖倒置原则 (DIP)：** Domain 层定义接口，Data 层实现接口，Provider 层通过 Riverpod 注入——测试时 mock 替换，零 DB 依赖。

### 服务端 — Pipeline Pattern

`CreateTransaction` 采用有序 Stage Pipeline：

```
Request → ValidateStage → PermissionStage → BeginTxStage → CategoryStage
        → OverdraftStage → PersistStage → SyncStage → [Commit]
        → notifyPostCommit() (best-effort)
```

每个 Stage 实现 `Stage` interface，独立可测，新增 concern 只需实现 + 注册 (OCP)。

### 同步引擎 — 形式化状态机

```
offline ↔ pending ↔ syncing → synced
                  ↔ syncing → failed
```

状态变更唯一路径：`SyncState.applyEvent()` + `SyncState.applyConnectivity()` 纯函数。37 个 property-based 测试覆盖所有合法/非法转换。

## 技术栈

| 层 | 技术 |
|----|------|
| 后端 | Go 1.25 / gRPC / PostgreSQL 16 / golang-migrate / WebSocket |
| 客户端 | Flutter 3.41 / Dart 3.11 / Riverpod / Drift (SQLite) / Material 3 |
| 协议 | Protocol Buffers 3 (13 个 proto 文件) |
| 部署 | Docker Compose (golang:1.25-alpine + postgres:16-alpine) |
| 数据库 | 46 个 migration 文件，软删除模式 |
| CI | GitHub Actions — Flutter (shard + coverage ≥40%) + Go (coverage ≥80%) + E2E |
| 测试 | Go 29 packages + Flutter 50 test files + E2E 6 golden-path smoke tests |

## 项目结构

```
FamilyLedger/
├── proto/                        # Proto 定义 (13 files)
├── server/                       # Go 后端 (~61,000 行源码)
│   ├── cmd/server/               # 入口 + 定时任务注册
│   ├── internal/                 # 业务逻辑
│   │   ├── auth/                 # 认证 + OAuth Provider 接口
│   │   ├── transaction/          # 交易 Pipeline (7 stages)
│   │   ├── account/              # 账户管理
│   │   ├── family/               # 家庭组 + 审计日志
│   │   ├── sync/                 # 增量同步 + entity_ops (7 种实体)
│   │   ├── budget/               # 预算 + 家庭执行率
│   │   ├── notify/               # 通知 + 自定义提醒 + 信用卡提醒
│   │   ├── loan/                 # 贷款 + 组合贷
│   │   ├── investment/           # 投资 + IRR 计算
│   │   ├── market/               # 行情拉取 + 交易时段调度
│   │   ├── asset/                # 固定资产 + 折旧
│   │   ├── dashboard/            # 仪表盘聚合 + 汇率 API
│   │   ├── export/               # 导出(CSV/Excel/PDF/全量备份)
│   │   ├── importcsv/            # CSV 导入 (session 持久化)
│   │   ├── security/             # 安全策略
│   │   ├── migration/            # 数据库迁移管理
│   │   ├── integration/          # 集成测试 (testcontainers)
│   │   ├── testutil/             # 测试工具
│   │   └── benchmark/            # 性能基准测试
│   ├── pkg/                      # 公共包
│   │   ├── audit/                # 审计日志 helper
│   │   ├── config/               # JWT 配置校验
│   │   ├── db/                   # 数据库连接池
│   │   ├── jwt/                  # JWT 签发/验证
│   │   ├── middleware/           # gRPC 拦截器
│   │   ├── permission/           # 家庭权限检查
│   │   ├── storage/              # FileStorage 接口 (Local + S3)
│   │   ├── category/             # 预设分类 UUID
│   │   └── ws/                   # WebSocket Hub + Ping-Pong
│   ├── migrations/               # 46 个 SQL migration (up/down)
│   ├── Makefile
│   └── Dockerfile
├── app/                          # Flutter 客户端 (~64,000 行源码)
│   ├── lib/
│   │   ├── core/                 # 常量、主题、路由
│   │   ├── data/                 # Drift 数据库 + gRPC clients
│   │   ├── domain/              # Clean Architecture 业务层
│   │   │   ├── entities/         # 纯 domain 实体 (无框架依赖)
│   │   │   ├── interfaces/       # Repository 抽象接口 (DIP)
│   │   │   ├── repositories/     # 接口 concrete 实现
│   │   │   ├── services/         # BalanceCalculator, CategorySyncService
│   │   │   ├── providers/        # StateNotifier (Riverpod)
│   │   │   └── models/           # DTO / ViewModel
│   │   ├── features/             # 16 个功能模块页面
│   │   ├── generated/            # Proto 生成代码
│   │   ├── sync/                 # SyncEngine 状态机
│   │   └── main.dart
│   ├── test/                     # 单元/Widget 测试 (50 files)
│   └── test/integration_test/    # E2E golden-path 测试
├── scripts/                      # 自动化脚本
│   ├── run-e2e-smoke.sh          # E2E 测试运行器 (docker up → test → down)
│   └── run-flutter-tests.sh      # Flutter 分片测试 (CI OOM 防护)
├── .github/workflows/            # CI 配置
│   ├── ci.yml                    # 主 CI (lint + test + coverage gate)
│   ├── flutter.yml               # Flutter 专属 (coverage ≥40% + delta comment)
│   ├── go.yml                    # Go 专属 (coverage ≥80% + delta comment)
│   └── flutter-e2e.yml           # E2E 冒烟测试 (Docker Compose)
├── docs/                         # 项目文档
├── docker-compose.yml
├── deploy.sh                     # 一键部署脚本
└── README.md
```

## 快速开始

### 前置依赖

- Docker & Docker Compose
- Flutter 3.41+ (stable channel)
- Go 1.25+ (仅开发后端时需要)
- protoc 34.x + protoc-gen-go / protoc-gen-dart (仅重新生成 proto 时需要)
- **iOS**: Xcode 16+、CocoaPods
- **Android**: Android Studio、Android SDK 34+、Java 17+

### 1. 启动后端

```bash
# 一键启动 PostgreSQL + Server (自动执行 migration)
docker compose up -d

# 查看日志
docker compose logs -f server

# 服务端口:
#   gRPC      → localhost:50051
#   WebSocket → localhost:8080
#   PostgreSQL → localhost:5432
```

仅启动数据库（本地开发后端时）：

```bash
docker compose up -d postgres

# 手动执行 migration
cd server
make migrate-up

# 编译运行
make run
```

### 2. 运行 Flutter 客户端

```bash
cd app
flutter pub get

# iOS (需要 macOS + Xcode)
cd ios && pod install && cd ..
flutter run -d iphone

# Android (需要连接设备或启动模拟器)
flutter run -d android
```

> - 客户端默认连接 `localhost:50051` (gRPC) 和 `localhost:8080` (WebSocket)
> - Android 真机调试时需将地址改为电脑局域网 IP（`10.0.2.2` 对模拟器有效）
> - 后端未运行时客户端仍可启动（离线优先），数据存本地 Drift DB
> - 修改服务器地址：`app/lib/core/constants/app_constants.dart`

### 3. 运行测试

```bash
# Go 后端 (29 packages)
cd server && go test ./... -count=1

# Flutter 单元测试
cd app && flutter test

# Flutter 分片测试 (CI 环境，防 OOM)
cd app && ../scripts/run-flutter-tests.sh

# E2E 冒烟测试 (需要 Docker)
./scripts/run-e2e-smoke.sh full
# 或分步:
./scripts/run-e2e-smoke.sh --up    # 启动服务
./scripts/run-e2e-smoke.sh --test  # 运行测试
./scripts/run-e2e-smoke.sh --down  # 停止服务
```

### 4. 部署到服务器

```bash
# 基本用法
./deploy.sh <HOST>

# 指定用户和端口
./deploy.sh <HOST> <USER> <PORT>

# 或者用 make
make deploy HOST=1.2.3.4
```

**生产环境配置** — 创建 `.env.production`：

```env
JWT_SECRET=your-production-secret-at-least-32-chars
DB_PASSWORD=your-secure-password
APP_ENV=production
```

## CI/CD

| Workflow | 触发条件 | 内容 |
|----------|----------|------|
| `ci.yml` | push/PR (any) | Lint + Test + Coverage gate (25%) |
| `flutter.yml` | push/PR (app/**) | Flutter 分片测试 + Coverage ≥40% + PR delta comment |
| `go.yml` | push/PR (server/**) | Go test + Coverage ≥80% + PR delta comment |
| `flutter-e2e.yml` | push/PR (app/test/integration_test/**) | Docker Compose + 6 E2E golden-path tests |

覆盖率门禁：PR 合并前必须达到阈值，否则 CI 红灯。PR comment 自动报告覆盖率变化。

## 后端开发

### Proto 代码生成

```bash
# Go
cd server && make proto

# Dart
cd app
protoc --proto_path=../proto \
  --proto_path=/opt/homebrew/Cellar/protobuf/34.1/include \
  --dart_out=grpc:lib/generated/proto \
  ../proto/*.proto
```

### 数据库 Migration

```bash
cd server

# 创建新 migration
migrate create -ext sql -dir migrations -seq <name>

# 执行 / 回滚
make migrate-up
make migrate-down
```

## 定时任务

| 任务 | 周期 | 说明 |
|------|------|------|
| 预算 + 贷款 + 信用卡提醒 | 每日 21:00 CST | 检查超支 + 还款到期 + 账单日 |
| 自定义提醒检查 | 每小时 | 触发到期的自定义提醒 |
| 自动折旧 | 每月 1 日 00:05 CST | 固定资产按规则计提折旧 |
| 汇率刷新 | 每小时 | 更新 exchange_rates 表 |
| 行情刷新 | 动态 (15min / 4h) | 交易时段 15min，非交易时段 4h |
| 导入会话清理 | 每小时 | 清理过期的 import_sessions (30min TTL) |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `DB_HOST` | localhost | PostgreSQL 主机 |
| `DB_PORT` | 5432 | PostgreSQL 端口 |
| `DB_USER` | familyledger | 数据库用户 |
| `DB_PASSWORD` | familyledger | 数据库密码 |
| `DB_NAME` | familyledger | 数据库名 |
| `JWT_SECRET` | **(生产必填)** | JWT 签名密钥 (≥32字符) |
| `APP_ENV` | development | `production` 时强制校验 JWT_SECRET |
| `GRPC_PORT` | 50051 | gRPC 服务端口 |
| `WS_PORT` | 8080 | WebSocket 服务端口 |
| `OAUTH_MODE` | mock | `mock` / `production` |
| `FILE_STORAGE` | local | `local` / `s3` |

## 中国大陆开发注意

```bash
# Flutter 镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# Go 模块代理
export GOPROXY=https://goproxy.cn,direct
```

## 文档

| 文档 | 内容 |
|------|------|
| [progress-report.md](docs/progress-report.md) | 项目进展报告 |
| [implementation-checklist.md](docs/implementation-checklist.md) | 实施 Checklist |
| [family-finance-prd.md](docs/family-finance-prd.md) | PRD 本地副本 |
| [family-finance-implementation-plan.md](docs/family-finance-implementation-plan.md) | 实施计划 |
| [e2e-testing.md](docs/e2e-testing.md) | 测试体系 |
| [frontend-audit.md](docs/frontend-audit.md) | 前端审计 |
| [backend-audit.md](docs/backend-audit.md) | 后端审计 |
| [import-export-design.md](docs/import-export-design.md) | 导入导出设计 |
| [loan-enhancement-research.md](docs/loan-enhancement-research.md) | 贷款增强研究 |

> PRD 最新版以飞书文档为准：[在线 PRD](https://www.feishu.cn/docx/N507dBSDZoTDgzxyXUYctfFonZw)

## License

Private — All rights reserved.
