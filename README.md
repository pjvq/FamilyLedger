# FamilyLedger 家庭资产管理

全功能家庭资产管理系统，包含 **Flutter iOS 客户端** + **Go gRPC 后端**。

## 功能概览

| 模块 | 功能 |
|------|------|
| 📊 Dashboard | 净资产卡片、资产构成饼图、收支趋势、可拖拽布局 |
| 💳 记账 | 收入/支出、14 种分类、多币种(自动 CNY 换算)、标签、图片附件 |
| 🏦 账户 | 7 种账户类型(银行卡/现金/支付宝/微信/信用卡/投资/其他) |
| 💰 预算 | 月度预算、圆环进度、超支脉冲动画 |
| 🏠 贷款 | 等额本息/等额本金、提前还款模拟、利率变动记录 |
| 📈 投资 | 持仓管理、迷你走势 sparkline、fl_chart 触摸十字线、组合饼图 |
| 🏗 固定资产 | 直线法/双倍余额递减法折旧、估值折线图 |
| 📑 报表导出 | CSV(UTF-8 BOM) / Excel(带样式) / PDF(横版 A4 斑马纹) |
| 📥 CSV 导入 | 4 步向导、GBK/UTF-8 自动检测、9 种日期格式、模糊分类匹配 |
| 🔔 通知 | 预算超支 + 贷款还款提醒、分组列表、滑动已读 |
| 🔐 认证 | JWT + OAuth(微信/Apple mock)、gRPC 拦截器 |
| 🔄 同步 | WebSocket 实时推送 + gRPC 增量同步 + Drift 本地数据库 |

## 技术栈

- **后端**: Go 1.24 / gRPC / PostgreSQL 16 / golang-migrate
- **客户端**: Flutter 3.41 / Dart 3.11 / Riverpod / Drift / Material 3
- **协议**: Protocol Buffers 3 (13 个 proto 文件)
- **部署**: Docker Compose (golang:1.24-alpine + postgres:16-alpine)
- **数据库**: 29 个 migration 文件，软删除模式

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
├── server/                   # Go 后端
│   ├── cmd/server/           # 入口
│   ├── internal/             # 业务逻辑 (14 packages)
│   │   ├── auth/             # 认证 + OAuth
│   │   ├── transaction/      # 交易记录
│   │   ├── account/          # 账户管理
│   │   ├── family/           # 家庭组
│   │   ├── sync/             # 增量同步
│   │   ├── budget/           # 预算
│   │   ├── notify/           # 通知
│   │   ├── loan/             # 贷款(~1000行)
│   │   ├── investment/       # 投资
│   │   ├── market/           # 行情(fetcher + exchange)
│   │   ├── asset/            # 固定资产 + 折旧
│   │   ├── dashboard/        # 仪表盘聚合(609行)
│   │   ├── export/           # 导出(CSV/Excel/PDF)
│   │   └── importcsv/        # CSV 导入
│   ├── pkg/                  # 公共包(db/jwt/middleware/ws)
│   ├── migrations/           # 29 个 SQL migration
│   ├── Makefile
│   ├── Dockerfile
│   └── entrypoint.sh
├── app/                      # Flutter 客户端
│   ├── lib/
│   │   ├── core/             # 常量、主题、路由
│   │   ├── data/             # Drift 数据库 + gRPC clients
│   │   ├── domain/           # Providers
│   │   ├── features/         # 14 个功能页面
│   │   ├── generated/        # Proto 生成代码
│   │   ├── sync/             # SyncEngine
│   │   └── main.dart
│   ├── integration_test/     # 集成测试
│   └── pubspec.yaml
└── docker-compose.yml
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
#   gRPC  → localhost:50051
#   WebSocket → localhost:8080
#   PostgreSQL → localhost:5432
```

仅启动数据库（本地开发后端时）：

```bash
docker compose up -d postgres

# 安装 migrate CLI
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# 手动执行 migration
cd server
migrate -path migrations -database "postgres://familyledger:familyledger@localhost:5432/familyledger?sslmode=disable" up

# 编译运行
make run
```

### 2. 运行 Flutter 客户端

```bash
cd app

# 安装依赖
flutter pub get

# 在 iOS 模拟器上运行
flutter run --device-id <SIMULATOR_UDID>

# 查看可用设备
flutter devices
```

> **Tips**:
> - 客户端默认连接 `localhost:50051` (gRPC) 和 `localhost:8080` (WebSocket)
> - 后端未运行时客户端仍可启动（SyncEngine 会优雅降级），数据存在本地 Drift DB
> - 修改服务器地址：编辑 `app/lib/core/constants/app_constants.dart`

### 3. 运行集成测试

```bash
cd app

# 在 iOS 模拟器上运行集成测试 (无需后端)
flutter test integration_test/app_test.dart \
  --device-id <SIMULATOR_UDID> \
  --no-pub

# 截图输出到 /tmp/e2e-phase9/
```

## 后端开发

### Proto 代码生成

```bash
cd server

# 生成 Go gRPC 代码
make proto

# 生成 Dart 客户端代码
cd ../app
# 需要: protoc-gen-dart 21.1.2, protobuf 4.2.0
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

# 执行
make migrate-up

# 回滚
make migrate-down
```

### Makefile 命令

```bash
make proto         # 生成 Proto 代码
make build         # 编译 server
make run           # 编译 + 运行
make test          # 运行测试
make docker-up     # Docker 启动
make docker-down   # Docker 停止
```

## 定时任务

| 任务 | 周期 | 说明 |
|------|------|------|
| 预算 + 贷款提醒 | 每日 21:00 CST | 检查预算超支 + 贷款即将到期 |
| 自动折旧 | 每月 1 日 00:05 CST | 固定资产按规则计提折旧 |
| 汇率刷新 | 每小时 | 更新 exchange_rates 表 |
| 行情刷新 | 每 15 分钟 | crypto 24/7, 股票按交易时段 |
| 导入会话清理 | 每小时 | 清理过期的 import_sessions |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `DB_HOST` | localhost | PostgreSQL 主机 |
| `DB_PORT` | 5432 | PostgreSQL 端口 |
| `DB_USER` | familyledger | 数据库用户 |
| `DB_PASSWORD` | familyledger | 数据库密码 |
| `DB_NAME` | familyledger | 数据库名 |
| `DB_SSLMODE` | disable | SSL 模式 |
| `JWT_SECRET` | (必填) | JWT 签名密钥 |
| `GRPC_PORT` | 50051 | gRPC 服务端口 |
| `WS_PORT` | 8080 | WebSocket 服务端口 |

## 中国大陆开发注意

```bash
# Flutter 镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# Go 模块代理
export GOPROXY=https://goproxy.cn,direct

# Flutter 编译时清除代理
export http_proxy="" https_proxy="" no_proxy="*"
```

## License

Private — All rights reserved.
