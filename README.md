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

## 技术栈

- **后端**: Go 1.24 / gRPC / PostgreSQL 16 / golang-migrate / WebSocket
- **客户端**: Flutter 3.41 / Dart 3.11 / Riverpod / Drift (SQLite) / Material 3
- **协议**: Protocol Buffers 3 (13 个 proto 文件)
- **部署**: Docker Compose (golang:1.24-alpine + postgres:16-alpine)
- **数据库**: 38 个 migration 文件，软删除模式
- **测试**: Go 330 test functions (18 packages) + Flutter 535 tests

## 项目结构

```
FamilyLedger/
├── proto/                    # Proto 定义 (13 files)
│   ├── auth.proto
│   ├── transaction.proto
│   ├── account.proto
│   ├── family.proto
│   ├── sync.proto
│   ├── budget.proto
│   ├── notify.proto
│   ├── loan.proto
│   ├── investment.proto
│   ├── asset.proto
│   ├── dashboard.proto
│   ├── export.proto
│   └── import.proto
├── server/                   # Go 后端 (~43,700 行)
│   ├── cmd/server/           # 入口 + 定时任务注册
│   ├── internal/             # 业务逻辑 (14 packages)
│   │   ├── auth/             # 认证 + OAuth Provider 接口
│   │   ├── transaction/      # 交易 CRUD + 家庭权限
│   │   ├── account/          # 账户管理
│   │   ├── family/           # 家庭组 + 审计日志
│   │   ├── sync/             # 增量同步 + entity_ops (7 种实体)
│   │   ├── budget/           # 预算 + 家庭执行率
│   │   ├── notify/           # 通知 + 自定义提醒 + 信用卡提醒
│   │   ├── loan/             # 贷款 + 组合贷
│   │   ├── investment/       # 投资 + IRR 计算
│   │   ├── market/           # 行情拉取 + 交易时段调度
│   │   ├── asset/            # 固定资产 + 折旧
│   │   ├── dashboard/        # 仪表盘聚合 + 汇率 API + 投资曲线
│   │   ├── export/           # 导出(CSV/Excel/PDF/全量备份)
│   │   └── importcsv/        # CSV 导入 (session 持久化)
│   ├── pkg/                  # 公共包
│   │   ├── audit/            # 审计日志 helper
│   │   ├── config/           # JWT 配置校验
│   │   ├── db/               # 数据库连接池
│   │   ├── jwt/              # JWT 签发/验证
│   │   ├── middleware/       # gRPC 拦截器
│   │   ├── permission/       # 家庭权限检查
│   │   ├── storage/          # FileStorage 接口 (Local + S3)
│   │   ├── category/         # 预设分类 UUID
│   │   └── ws/               # WebSocket Hub + Ping-Pong
│   ├── migrations/           # 38 个 SQL migration
│   ├── Makefile
│   ├── Dockerfile
│   └── entrypoint.sh
├── app/                      # Flutter 客户端 (~56,600 行)
│   ├── lib/
│   │   ├── core/             # 常量、主题、路由
│   │   ├── data/             # Drift 数据库 + gRPC clients
│   │   ├── domain/           # Providers (StateNotifier)
│   │   ├── features/         # 14 个功能页面
│   │   ├── generated/        # Proto 生成代码
│   │   ├── sync/             # SyncEngine (LWW + 分页)
│   │   └── main.dart
│   ├── test/                 # 535 单元/Widget 测试
│   ├── integration_test/     # E2E 集成测试
│   └── pubspec.yaml
├── docs/                     # 项目文档
├── docker-compose.yml
└── README.md
```

## 快速开始

### 前置依赖

- Docker & Docker Compose
- Flutter 3.41+ (stable channel)
- Go 1.24+ (仅开发后端时需要)
- protoc 34.x + protoc-gen-go / protoc-gen-dart (仅重新生成 proto 时需要)
- Xcode 16+ (iOS 编译)

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
flutter run
```

> - 客户端默认连接 `localhost:50051` (gRPC) 和 `localhost:8080` (WebSocket)
> - 后端未运行时客户端仍可启动（离线优先），数据存本地 Drift DB
> - 修改服务器地址：`app/lib/core/constants/app_constants.dart`

### 3. 运行测试

```bash
# 后端 (18 packages, 330 test functions)
cd server && go test ./... -count=1

# 前端 (535 tests)
cd app && flutter test

# 集成测试 (需要 iOS 模拟器)
cd app && flutter test integration_test/
```

### 4. 部署到服务器

一键部署：本地构建 Docker 镜像 → 传输到服务器 → 启动服务。

```bash
# 基本用法（默认 root 用户，22 端口）
./deploy.sh <HOST>

# 指定用户和端口
./deploy.sh <HOST> <USER> <PORT>

# 或者用 make
make deploy HOST=1.2.3.4
make deploy HOST=1.2.3.4 USER=ubuntu PORT=2222
```

**前置条件：**
- 本地已安装 Docker
- 目标服务器已安装 docker + docker compose
- 本地 SSH key 可免密登录目标服务器

**生产环境配置：**

创建 `.env.production` 放在项目根目录，脚本会自动传到服务器：

```env
JWT_SECRET=your-production-secret-at-least-32-chars
DB_PASSWORD=your-secure-db-password
APP_ENV=production
```

**部署流程：**
1. 本地构建 `familyledger-server:<git-short-hash>` 镜像
2. 压缩导出并 scp 到服务器 `/opt/familyledger/`
3. 远端 `docker load` 加载镜像
4. `docker compose up -d` 启动/重启服务（自动执行 migration）
5. 验证容器运行状态

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

所有项目文档在 [`docs/`](docs/) 目录：

| 文档 | 内容 |
|------|------|
| [progress-report.md](docs/progress-report.md) | 项目进展报告 |
| [implementation-checklist.md](docs/implementation-checklist.md) | 实施 Checklist |
| [family-finance-prd.md](docs/family-finance-prd.md) | PRD 本地副本 |
| [family-finance-implementation-plan.md](docs/family-finance-implementation-plan.md) | 实施计划 |
| [e2e-testing.md](docs/e2e-testing.md) | 测试体系 |
| [frontend-audit.md](docs/frontend-audit.md) | 前端审计 |
| [import-export-design.md](docs/import-export-design.md) | 导入导出设计 |
| [loan-enhancement-research.md](docs/loan-enhancement-research.md) | 贷款增强研究 |

> PRD 最新版以飞书文档为准：[在线 PRD](https://www.feishu.cn/docx/N507dBSDZoTDgzxyXUYctfFonZw)

## License

Private — All rights reserved.
