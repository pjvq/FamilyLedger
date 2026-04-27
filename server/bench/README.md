# gRPC Load Test (ghz)

基于 [ghz](https://ghz.sh/) 的 gRPC 端到端压测框架。

## 前置条件

1. **ghz** — `brew install ghz`
2. **运行中的 gRPC Server** (默认 `localhost:50051`)
   - 或脚本会自动尝试启动本地 server（需要 PostgreSQL）
3. **Proto 文件** — 项目根目录 `proto/` 下

## 快速开始

```bash
# 从项目根目录
make bench-grpc

# 或直接运行
bash server/bench/grpc-load-test.sh
```

## 环境变量配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `BENCH_SERVER_ADDR` | `localhost:50051` | gRPC server 地址 |
| `BENCH_TOTAL` | `1000` | 每个接口的总请求数 |
| `BENCH_CONCURRENCY` | `10` | 并发数 |
| `BENCH_CONNECTIONS` | `5` | gRPC 连接数 |
| `BENCH_TOKEN` | (空) | 预配置的 Bearer token |
| `BENCH_REFRESH_TOKEN` | (空) | Refresh token（测 RefreshToken 接口） |
| `BENCH_EMAIL` | `bench@test.com` | 测试用户邮箱 |
| `BENCH_PASSWORD` | `benchtest123` | 测试用户密码 |

## 测试覆盖的接口

| 接口 | 类型 | 说明 |
|------|------|------|
| `AuthService/Login` | 认证 | 登录热路径 |
| `AuthService/RefreshToken` | 认证 | Token 刷新 |
| `TransactionService/ListTransactions` | 读 | 交易列表（读热路径）|
| `TransactionService/CreateTransaction` | 写 | 创建交易（写热路径）|
| `DashboardService/GetNetWorth` | 聚合 | 净资产聚合查询 |
| `DashboardService/GetCategoryBreakdown` | 聚合 | 分类支出分析 |
| `SyncService/PullChanges` | 同步 | 增量同步拉取 |

## 自定义压测参数

```bash
# 重度压测
BENCH_TOTAL=10000 BENCH_CONCURRENCY=50 BENCH_CONNECTIONS=20 make bench-grpc

# 轻量冒烟
BENCH_TOTAL=100 BENCH_CONCURRENCY=5 make bench-grpc

# 指定远程 server
BENCH_SERVER_ADDR=staging.example.com:50051 make bench-grpc
```

## 结果输出

- 终端输出：Summary 格式（QPS、延迟百分位、错误率）
- JSON 文件：`server/bench/results/<endpoint>.json`

## 使用 ghz 配置文件

```bash
ghz --config server/bench/ghz-config.json
```

配置文件 `ghz-config.json` 预定义了各接口的压测参数，便于 CI 集成。

## 关键指标关注

- **p99 延迟** — 应 < 200ms（读）/ < 500ms（写）
- **错误率** — 应 < 1%
- **QPS** — baseline 基准用于回归检测

## 独立压测 Server（无外部依赖）

如果没有运行中的 server，可以使用 bench_server_test.go：

```bash
cd server/bench
go test -tags bench -run TestBenchServer -v -timeout 300s
```

此模式会使用 testcontainers 启动 PostgreSQL，然后对内嵌 server 执行压测。
