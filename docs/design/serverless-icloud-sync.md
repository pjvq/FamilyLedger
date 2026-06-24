# 去服务器化 · 本地优先 + iCloud 同步设计

> 状态：定稿
> 日期：2026-06-23

## 概述

FamilyLedger 从「Flutter 客户端 + Go gRPC 服务端 + PostgreSQL」演进为**本地优先、无自建服务器**架构：

- **iOS**：本地 Drift（SQLite）为唯一事实来源，通过 **iCloud（CloudKit）** 做多端同步，并支持用户自行开启的家庭共享。
- **Android**：本地 Drift 单机保存，不参与同步；通过手动加密备份文件实现换机迁移。
- **Go 服务端与 PostgreSQL**：整体退役。

身份不再依赖自建账号体系：iOS 使用 iCloud 账号隐式身份，Android 无需登录，不保留第三方登录。iOS 与 Android 之间不互相同步。

---

## 1. 背景与目标

### 1.1 现状

- **架构**：Monorepo —— Flutter 客户端（`app/`）+ Go gRPC 后端（`server/`，19 个业务包）+ PostgreSQL（46 条 migration）。
- **同步**：客户端通过 gRPC `PushOperations` / `PullChanges` 增量同步，WebSocket 实时推送（`server/pkg/ws/hub.go`）。
- **本地存储**：客户端已是 Drift（SQLite）离线优先，断网可用。
- **服务器地址**：编译期 `--dart-define` 注入（`app/lib/core/constants/app_constants.dart:11-18`）。

### 1.2 目标

1. **隐私优先**：用户数据不经过任何第三方/自建服务器，数据托管在用户自己的 iCloud。
2. **零运维**：用户无需也无法接触任何服务器。
3. **保留离线优先 + （iOS）多端同步体验**。

### 1.3 非目标

- 跨 Apple / Android 生态的统一同步。
- 第三方登录（含微信）。
- 服务端强制的细粒度权限与防篡改审计。

---

## 2. 现状架构盘点：服务端职责归属

服务端的绝大多数职责是「纯计算」，搬到客户端即可；真正与服务器强绑定的只有「多人协作的权限强制」和需要 `AppSecret` 的微信 OAuth。

| 服务端职责 | 文件锚点 | 去服务器后的处置 |
|-----------|---------|------------------|
| 增量同步 Push/Pull | `server/internal/sync/service.go` | 由 iCloud 替代（本文核心） |
| 实时推送 WebSocket | `server/pkg/ws/hub.go` | CloudKit 订阅推送（`CKSubscription`）替代 |
| 行情数据（A股/港股/美股/加密/贵金属/汇率） | `server/internal/market/fetcher.go` | 直接搬到客户端：全部是免费、免鉴权的公开 HTTP 接口（EastMoney / Yahoo / CoinGecko / Sina / open.er-api.com），移动端可直连 |
| 定时任务（预算检查、贷款提醒、折旧、汇率刷新） | `server/cmd/server/main.go` | 本地化：纯计算 + 本地通知。固定日期类提醒（贷款还款日、账单日）用 `UNCalendarNotificationTrigger` 预排，不依赖 Background App Refresh |
| 通知 | `server/internal/notify/service.go` | 本地通知：服务端推送本就未实现（仅 DB 收件箱），本地化反而更简单 |
| 导出 CSV/Excel/PDF、导入 CSV | `server/internal/export`、`importcsv` | 纯数据转换，客户端可做（导出已部分本地化，见 `docs/import-export-design.md`） |
| Dashboard 聚合、各实体 CRUD、贷款提前还款/折旧计算 | `server/internal/dashboard`、`loan`、`asset` 等 | 纯计算，跑在本地 SQLite 上 |
| 认证 JWT、邮箱密码、刷新令牌 | `server/internal/auth/service.go` | 移除；iOS 改用 iCloud 账号隐式身份，Android 无需登录 |
| 微信 / Apple OAuth | `server/internal/auth/oauth_provider.go` | 移除第三方登录 |
| 家庭 + 5 维权限 + 邀请码 + 审计 | `server/internal/family`、`pkg/permission` | 改用 CloudKit 共享，权限模型简化（见 §8） |

---

## 3. 同步模型适配性

现有设计有三点使其天然适配无服务器架构：

1. **实体 ID 是客户端生成的 UUID**（`account_provider.dart` 用 `Uuid().v4()`；分类用确定性 UUIDv5 `category_uuid.dart`）——去掉服务器不会有 ID 冲突，无需中心分配。

2. **冲突解决（LWW）使用客户端时钟，而非服务端时钟。** 服务端 `PushOperations` 直接采纳客户端上送的时间戳（`sync/service.go:131-134`），客户端入队时用 `DateTime.now()` 打戳、冲突时按该时间戳取舍（`sync_engine.dart:567-613`）。冲突解决逻辑不依赖中心时钟，移除服务器后语义不变。

3. **客户端已是完整的离线优先副本**，配出站操作队列（`SyncQueue`）与拉取水位（`SyncMetadata`）。服务端在同步上仅相当于「带游标的操作日志中转站」，可由 iCloud 取代。

主要工程量集中在：把「操作日志（ops-log）模型」对接到 CloudKit 的「记录状态（record-state）模型」（§6、§7）。

---

## 4. 同步方案选型

| 方案 | 机制 | 多端并发合并 | schema 演进 | 结论 |
|------|------|-------------|------------|------|
| iCloud Drive 同步整库 SQLite 文件 | 把 `.sqlite` 当文档放进 iCloud Drive | 整文件 LWW，两端并发改即丢数据 | 版本不一致直接冲突（Drift 只能前向迁移、不容忍未知列） | 不采用：会丢数据 |
| **CloudKit（CKRecord 逐记录）** | 每个实体一条 `CKRecord`，私有数据库 | 逐记录 / 逐字段 LWW，并发安全 | 新字段老版本可忽略，平滑 | **采用** |
| CloudKit + CKShare 共享数据库 | 在上者之上用共享区实现家庭 | 同上 | 同上 | 采用（家庭共享，§8） |

采用 CloudKit 逐记录方案，理由：

- CloudKit **私有数据库**默认在用户 iCloud 名下、受 Apple 加密、零成本、对用户透明，契合「隐私优先 + 零运维」。
- 逐记录模型与「客户端 UUID + 客户端时钟 LWW」的现状高度同构，迁移成本最低。
- 规避整库文件同步的并发丢数据与 schema 冲突。

CloudKit 接入采用自研 **Platform Channel 调用原生 Swift CloudKit**（无成熟 Flutter 一等公民插件），属 iOS 原生工作量。

---

## 5. 总体架构

一份 Flutter 代码、两种平台形态，同步层做成可插拔接口（§11.3）：

```
═══════════════ iOS（本地优先 + iCloud 同步）═══════════════
┌──────────────────────────────────────────────────────────────────┐
│  Flutter UI ──► Domain 逻辑（CRUD/计算/校验，原服务端逻辑下沉）     │
│                      │                                             │
│  Drift (SQLite) 本地库  ◄── 唯一事实来源（离线优先）               │
│                      │                                             │
│  iCloudSyncEngine                                                  │
│     ├─ 出站：本地变更 → CKRecord → 写入 CloudKit                    │
│     ├─ 入站：CKFetchChanges（serverChangeToken 游标）→ 合并回 Drift │
│     └─ 推送：CKSubscription 静默通知 → 触发增量拉取                 │
│  行情/汇率：直连公开 HTTP；提醒/预算/折旧：本地计算 + 本地通知       │
└──────────────────────────────────┬─────────────────────────────────┘
                                    │  Apple 账号下的 iCloud
                                    ▼
                  ┌──────────────────────────────────┐
                  │  CloudKit                         │
                  │   • 私有数据库（个人数据）        │
                  │   • 共享数据库 / CKShare（家庭）  │
                  │   • CKAsset（票据图片）           │
                  └──────────────────────────────────┘

═══════════════ Android（纯本地，不同步）═══════════════
┌──────────────────────────────────────────────────────────────────┐
│  Flutter UI ──► Domain 逻辑（同一套）                              │
│  Drift (SQLite) 本地库  ◄── 唯一事实来源（单机）                    │
│  行情/汇率：直连公开 HTTP；提醒/预算/折旧：本地计算 + 本地通知       │
│  （无同步引擎）→ 手动加密备份/恢复（§9）                            │
└──────────────────────────────────────────────────────────────────┘

   两端均无任何自建服务器 / PostgreSQL / gRPC / WebSocket
```

---

## 6. 数据模型映射：Drift 实体 → CloudKit 记录

### 6.1 实体映射

每个同步实体类型对应一个 CloudKit `RecordType`，`recordName` 直接复用现有 UUID：

| Drift 实体 | CKRecordType | 主键来源 |
|-----------|--------------|---------|
| transaction / account / category / loan / loan_group / investment / fixed_asset / budget | 同名 RecordType | 现有客户端 UUID |
| 票据图片 | 对应 transaction 记录上的 `CKAsset` 字段 | —— |

`category_merge`（分类合并）不是领域实体，不建记录类型。它是一次性操作；CloudKit 是状态模型而非操作日志，故合并在本地展开为「受影响交易的 `category_id` 改写（update）+ 源分类软删除」，按普通变更同步。

### 6.2 删除语义（tombstone）

8 个可同步领域实体中：6 个已有 `deleted_at`（transaction / category / loan / loan_group / investment / fixed_asset）；account 用 `isActive=false` 软删（语义等价、结构不同）；budget 为硬删除。

CloudKit 的删除经 `CKFetchRecordZoneChangesOperation` 的 `deletedRecordZoneIDs` 回传。为统一处理：

- 给 **budget 增加 `deleted_at` 软删除列**；
- 把 **account 的 `isActive=false` 映射为删除语义**；
- 两者纳入删除变更传播。

### 6.3 冲突排序字段

现有仅有 `updated_at`（约半数表）与出站队列，无逐行版本号 / 向量时钟。为应对无服务器后冲突窗口放大（§7.3），每条记录增加 **HLC（混合逻辑时钟）字段 `hlc`**，冲突按 hlc 排序；CloudKit 自带的 `recordChangeTag` 用于乐观并发控制。

### 6.4 票据图片（CKAsset）与配额

图片当前不在 SQLite，存于服务端文件系统（`storage.go`），客户端只存 URL（`core_tables.dart:64`）。迁移为 `CKAsset` 挂在对应 transaction 记录上，本地缓存文件，URL 字段改为资产引用。

iCloud 免费仅 5GB 且与照片/备份/邮件共享，票据图易吃满配额，故：

- **上传前压缩**：长边 ≤1600px、JPEG 质量 ≈0.7、单张目标 <300KB；提供「原图/压缩」开关，默认压缩。
- **配额满降级**：图片同步失败不阻塞数据同步，单独排队重试并提示用户。
- **不做云端自动清理**（首版）：仅提供手动删除，老图保留本地。

### 6.5 schema 版本偏斜

Drift 只支持前向迁移、不容忍未知列（`database.dart:54-209`，schemaVersion=24）。CloudKit 记录级模型下老版本 App 可忽略不认识的字段，远比整库文件同步安全。约束：**CloudKit schema 只增不改**；客户端按「未知字段忽略、缺失字段给默认值」处理；对低于最低兼容版本的 App 提示升级。

---

## 7. 同步引擎设计

### 7.1 接口替换

| 现有（gRPC） | 替换为（CloudKit） |
|-------------|-------------------|
| `PushOperations`（出站操作日志） | 本地 `SyncQueue` 的变更映射为 CKRecord 写入（`CKModifyRecordsOperation`） |
| `PullChanges`（时间水位 + 分页游标） | `CKFetchRecordZoneChangesOperation` + `serverChangeToken` 游标 |
| WebSocket 实时推送 | `CKSubscription`（数据库订阅）+ 静默推送，收到后触发增量拉取 |
| 30s 轮询兜底 | 保留为兜底；CloudKit 推送为主 |

游标 `serverChangeToken` 是二进制 `Data`，非时间戳，不能复用 `SyncMetadata.value`（`int`）。新建专用表 **`CloudKitSyncState(zone TEXT PK, change_token TEXT)`** 存其 Base64。

### 7.2 出站流程

`SyncQueue`（`support_tables.dart:67-81`）与死信队列（`SyncDeadLetters`）的重试 / 幂等 / 死信机制可复用，但有两处改造：

- **payload 序列化**：现存 gRPC protobuf 序列化结果，需改为 CKRecord 可接受的字段/类型映射（native types / JSON）。
- **按操作组提交**：`CKModifyRecordsOperation` 的原子性是 per-zone per-operation。一笔转账涉及 2 条 transaction + 2 个 account 余额变更，必须放进同一 operation 才原子（当前由 PG 事务保证）。出站以「操作组」为单位——同一本地写事务内产生的 ops 聚成一个 operation 原子提交，而非逐条上送。

### 7.3 冲突解决

沿用客户端时钟 LWW（`sync_engine.dart:567-613`）的取舍语义，但排序键升级为 HLC（§6.3）：

- gRPC + WebSocket 时代冲突窗口约毫秒级；CloudKit 静默推送 + 30s 轮询兜底后可能放大到分钟级，纯墙钟时间戳 LWW 误判概率上升。
- HLC 在墙钟基础上叠加逻辑计数，提供更稳健的因果排序，消除时钟漂移导致的静默覆盖。

### 7.4 实时性

仅靠轮询时跨端可见延迟最长为一个轮询周期；`CKSubscription` 静默推送可把延迟拉回秒级，体验与现有 WebSocket 接近。

---

## 8. 家庭共享与权限

### 8.1 现状

5 维权限 `CanView/CanCreate/CanEdit/CanDelete/CanManageAccounts` 存于每个 `family_member` 行（`family/service.go`），由 `pkg/permission/check.go` 在服务端强制；邀请码、角色（owner/admin/member）、审计日志均依赖服务端。服务端是唯一可信仲裁点。

### 8.2 设计

本地优先意味着每个客户端都持有全量数据副本，没有可信第三方就无法在密码学上阻止成员越权改数据——服务端强制的细粒度权限在无服务器架构下无法保留。

采用 **CloudKit 共享（CKShare）的「共享即信任」模型**：

- 用 CKShare 把账本共享给家人，被共享成员平等读写（CloudKit 仅 read-only / read-write 两档粗粒度权限）。
- 邀请用 CloudKit 系统级共享邀请（`UICloudSharingController`，Flutter 中经 Platform Channel 调起原生 UI）替代自建邀请码。
- 5 维权限降级为产品层面的「角色提示」而非强制；审计退化为本地日志（不可防篡改）。

该模型与多数家庭账本「家人互信」的真实场景一致，且仅在 Apple 设备间可用。

---

## 9. 平台策略

| 平台 | 存储 | 同步 | 家庭共享 |
|------|------|------|---------|
| **iOS** | 本地 Drift（事实来源） | iCloud（CloudKit）多端同步（§5–§7） | CKShare（§8，用户可选用，仅 Apple 设备间） |
| **Android** | 本地 Drift（事实来源） | 不同步（单机本地账本） | 不参与 |

iCloud / CloudKit 无原生 Android SDK，本项目不追求跨生态同步；iOS 与 Android 不互相同步。macOS 暂不支持（CloudKit 方案未来可低成本扩展）。

### 9.1 Android：纯本地形态

Android 端是「去掉同步引擎的现有客户端」，工程量最小：

- 保留 Drift 本地库与全部业务逻辑（CRUD、计算、行情、本地通知）。
- 同步层（`app/lib/sync/`、gRPC/WebSocket）在 Android 构建中不启用。
- `SyncQueue` / `SyncMetadata` / 死信队列服务于同步；Android 备份为整库快照而非增量，故不需要这些表，编译期关闭即可。

### 9.2 Android 备份 / 设备迁移

「只本地保存」的风险是换机/丢机即数据全失。采用**手动导出加密文件**：

- **导出**：整库导出为加密文件，用户自存任意位置（网盘 / 微信 / U 盘）；复用现有导出能力（`docs/import-export-design.md`）。
- **导入**：换机时选文件 + 输入口令恢复。
- **提示**：App 内定期提醒备份，降低长期不备份的丢数据风险。
- **加密**：AES-256-GCM，密钥由用户口令经 Argon2id 派生；文件格式 = `magic header + 版本号 + salt + nonce + 密文`，头部记录 `schemaVersion` 以支持跨版本恢复。

该通道是单向备份/恢复，非多端同步。

### 9.3 一份代码两种形态

Flutter 单 codebase，用编译期开关 / 平台判断区分：iOS 走「Drift + iCloudSyncEngine」，Android 走「Drift only + 手动加密备份」。同步层抽象为可插拔接口（接口 + 平台实现），避免在 Android 构建引入 CloudKit / 原生依赖。

---

## 10. 数据迁移

存量仅少量测试用户，一次性切换，不设双跑期：

1. **导出**：从旧服务端拉取全量数据（已有导出能力）。
2. **本地落库**：写入本地 Drift（事实来源）。
3. **首次上云（仅 iOS）**：`iCloudSyncEngine` 把本地全量映射为 CKRecord 写入私有库；分批 200 records/批（留 CloudKit 400 上限余量），CKAsset 单独上传；用迁移进度表记录已传 `recordName` 实现断点续传，失败只补未完成项。Android 端到第 2 步即完成。
4. **图片迁移**：旧服务端票据图下载后，iOS 转为 `CKAsset` 上云、Android 存本地。
5. **退役服务端**：迁移完成后下线 Go 服务端 + PostgreSQL。

---

## 11. 隐私与安全

- 数据只存用户自己的 iCloud 私有库，默认 Apple 加密；开启「高级数据保护（Advanced Data Protection）」后为端到端加密，连 Apple 也无法读取。
- 无自建服务器：无数据库被拖库风险、无运维、无服务器侧数据留存。
- 不再需要自建 JWT、密码哈希、令牌撤销表。
- Android 备份文件本地加密（§9.2），密钥不离开用户。

---

## 12. 风险与权衡

| 风险 / 取舍 | 严重度 | 处理 |
|------------|--------|------|
| iOS 与 Android 不互通 | 中 | 设计取舍；产品文案明确告知 Android 为单机本地 |
| Android 换机/丢机数据全失 | 高 | 手动加密备份/恢复（§9.2，必做） |
| 家庭细粒度权限无法强制 | 中 | 共享即信任（§8，仅 iOS） |
| 无第三方登录 | 中 | iOS 用 iCloud 隐式身份，Android 无需登录 |
| Flutter 无成熟 CloudKit 插件 | 中 | 自研原生 Swift Platform Channel（§4） |
| 设备时钟漂移 | 低 | HLC 排序（§6.3 / §7.3） |
| schema 版本偏斜 | 低 | CloudKit 记录级模型容忍；schema 只增不改 |
| CloudKit 配额 / 限流 | 低 | 个人数据量小（多年约 1–5 万行）；图片压缩 + 分批写入 |

---

## 13. 分阶段实施

- **Phase 1 — 服务端职责下沉**（两端共用）：行情/汇率直连客户端；提醒/预算/折旧本地计算 + 本地通知；导入导出本地化；同步层抽象为可插拔接口。产出：不依赖服务端业务逻辑的客户端。
- **Phase 2 — Android 本地形态**：关闭同步层；实现手动加密备份/恢复（§9.2）。产出：可独立发布的 Android 纯本地版。
- **Phase 3 — iCloud 同步引擎（iOS）**：原生 CloudKit Platform Channel；`iCloudSyncEngine`；补齐 tombstone（§6.2）、HLC（§6.3）、CKAsset（§6.4）、游标表（§7.1）、操作组提交（§7.2）。
- **Phase 4 — iOS 家庭共享**：CKShare + 系统共享邀请；权限作为角色提示。
- **Phase 5 — 迁移与退役**：一次性迁移；下线 Go 服务端 + PostgreSQL。

---

## 附：代码锚点

- 同步实体类型：`server/internal/sync/service.go:217-238`、`app/lib/sync/sync_engine.dart:72-82`
- 客户端时钟 LWW：`server/internal/sync/service.go:131-134`、`app/lib/sync/sync_engine.dart:567-613`
- 客户端 UUID：`app/lib/domain/providers/account_provider.dart`、`app/lib/core/utils/category_uuid.dart`
- 出站队列 / 水位：`app/lib/data/local/support_tables.dart:67-135`
- 行情免鉴权接口：`server/internal/market/fetcher.go`
- 5 维权限：`server/internal/family/service.go`、`server/pkg/permission/check.go`
- 图片存储：`server/pkg/storage/storage.go`、`app/lib/data/local/core_tables.dart:64`
- 客户端 schema 迁移：`app/lib/data/local/database.dart:54-209`（schemaVersion=24）
