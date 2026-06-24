# 去服务器化 · iCloud 同步设计文档

> 状态：**已定稿（所有 Open Questions 已决策）**
> 作者：Claude Code 辅助调研
> 日期：2026-06-23
> 关联：本提案是对当前「Flutter 客户端 + Go gRPC 服务端 + PostgreSQL」架构的一次重大演进评估。
>
> **最终决策（2026-06-23）**：
> - **平台**：iOS / macOS（仅 iOS，**macOS 暂不做**）走「本地 Drift + iCloud（CloudKit）多端同步」；**Android 纯本地 Drift，不同步**；iOS↔Android 不互通。
> - **Go 服务端 + PostgreSQL：两端均彻底退役。**
> - **登录**：砍掉所有第三方登录 —— iOS 用 iCloud 隐式身份、Android 无需登录；**不保留微信**。
> - **家庭共享**：用 **CKShare**（仅 iOS，「共享即信任」）。
> - **Android 备份**：**手动导出加密文件**（用户自存，换机导入）。
> - **存量迁移**：仅少量测试用户 → 一次性导出/导入，**不做双跑期**。

---

## 0. TL;DR（先给结论）

**问题**：当前 FamilyLedger 必须连接自建 Go 服务器才能多端同步。用户希望**更注重隐私、不依赖服务器、改用 iCloud 同步**。

**采纳的方案**：iOS 用 iCloud 同步，Android 仅本地保存。基于此决策的结论：

| 场景 | 结论 | 说明 |
|------|------|------|
| **iOS / macOS 个人多端** | ✅ **采用 iCloud（CloudKit）同步** | 现有架构天然适配：实体 ID 是客户端 UUID、LWW 用的是**客户端时钟**、Drift 已是离线优先。服务端绝大部分职责只是「顺便放在那里」的纯计算。 |
| **iOS 家庭共享** | 🟡 **可选，CloudKit 共享（CKShare）** | 仅 Apple 设备间可用；**会失去服务端强制的细粒度 5 维权限**，降级为「共享即信任」（见 §8）。 |
| **Android** | ✅ **纯本地保存（设计如此，不同步）** | 不连服务器、不连 iCloud；单机离线账本。需补一条**本地备份/迁移**通道防丢数据（见 §9）。 |
| **iOS ↔ Android 互相同步** | ❌ **不支持（明确不做）** | iCloud 是 Apple 私有生态，无 Android SDK；本决策放弃跨生态同步。 |
| **微信登录** | ❌ 去服务器后无法保留 | 微信 OAuth 需要 `AppSecret` 在服务端交换，不能进客户端二进制。 |

**一句话**：两端都变成**本地优先、零服务器**；iOS 额外用 iCloud 做多端同步与（可选）家庭共享，Android 是单机本地账本。架构更简单、更私密；代价是 **(1) iOS↔Android 不互通**、**(2) Android 无自动多端同步（靠本地备份兜底）**、**(3) 家庭权限退化为「共享即信任」**。


---

## 1. 背景与目标

### 1.1 现状

- **架构**：Monorepo —— Flutter 客户端（`app/`）+ Go gRPC 后端（`server/`，19 个业务包）+ PostgreSQL（46 条 migration）。
- **同步**：客户端通过 gRPC `PushOperations` / `PullChanges` 增量同步，WebSocket 实时推送（`server/pkg/ws/hub.go`）。
- **本地存储**：客户端已是 Drift（SQLite）离线优先，断网可用。
- **服务器地址**：编译期 `--dart-define` 注入（`app/lib/core/constants/app_constants.dart:11-18`）。

### 1.2 目标

1. **隐私优先**：用户数据不经过任何第三方/自建服务器，理想情况下端到端加密。
2. **零运维**：用户无需也无法接触任何服务器，数据托管在用户自己的 iCloud。
3. **保留离线优先 + 多端同步体验**。

### 1.3 非目标（本期不追求）

- 跨 Apple/Android 生态的统一同步（见 §9 决策）。
- 保留微信登录。
- 服务端强制的细粒度权限审计。

---

## 2. 现状架构盘点：服务端到底在做什么

调研结论：**服务端的绝大多数职责是「纯计算」或「顺手放在服务端」，并非必须**。真正离不开服务器的只有「多人协作的权限强制」和「微信 OAuth」。

| 服务端职责 | 文件锚点 | 去服务器后的处置 |
|-----------|---------|------------------|
| 增量同步 Push/Pull | `server/internal/sync/service.go` | **由 iCloud 替代**（本文核心） |
| 实时推送 WebSocket | `server/pkg/ws/hub.go` | CloudKit 订阅推送（`CKSubscription` / 静默 APNs）替代 |
| 行情数据（A股/港股/美股/加密/贵金属/汇率） | `server/internal/market/fetcher.go` | ✅ **直接搬到客户端**：全部是免费、免鉴权的公开 HTTP 接口（EastMoney / Yahoo / CoinGecko / Sina / open.er-api.com），移动端可直连 |
| 定时任务（预算检查、贷款提醒、折旧、汇率刷新） | `server/cmd/server/main.go` | ✅ **本地化**：纯计算 + 本地通知（iOS `UNNotificationRequest`），用 Background App Refresh 触发 |
| 通知 | `server/internal/notify/service.go` | ✅ **本地通知**：服务端推送本就是 TODO 未实现（`service.go` 有 `TODO(M8)`），现在只是 DB 收件箱，本地化反而更简单 |
| 导出 CSV/Excel/PDF、导入 CSV | `server/internal/export`、`importcsv` | ✅ 纯数据转换，客户端可做（导出已部分本地化，见 `docs/import-export-design.md`） |
| Dashboard 聚合、各实体 CRUD、贷款提前还款/折旧计算 | `server/internal/dashboard`、`loan`、`asset` 等 | ✅ 纯计算，跑在本地 SQLite 上即可 |
| 认证 JWT、邮箱密码、刷新令牌 | `server/internal/auth/service.go` | 🟡 **重做**：去服务器后改用 iCloud 账号身份；不再需要自建 JWT |
| 微信 / Apple OAuth | `server/internal/auth/oauth_provider.go` | ❌ 微信丢失；Apple 登录可客户端验证 |
| **家庭 + 5 维权限 + 邀请码 + 审计** | `server/internal/family`、`pkg/permission` | ⚠️ **最难**：服务端是唯一可信仲裁者，去服务器后无法强制（见 §8） |

> 结论引用：行情接口全部免鉴权（`fetcher.go` EastMoney/Yahoo/CoinGecko/Sina）；通知推送未实现（`notify/service.go` `TODO(M8)`）；权限是每个 `family_member` 行上的 JSON（`family/service.go` 的 `CanView/CanCreate/CanEdit/CanDelete/CanManageAccounts`），由 `pkg/permission/check.go` 在服务端强制。

---

## 3. 关键事实：现有同步模型为什么「天然适配」无服务器

调研发现三个对本方案极其有利的设计现状：

1. **实体 ID 是客户端生成的 UUID**（`account_provider.dart` 用 `Uuid().v4()`；分类用确定性 UUIDv5 `category_uuid.dart`）。
   → 去掉服务器**不会有 ID 冲突**，无需中心分配。

2. **LWW（last-writer-wins）用的已经是「客户端时钟」，不是服务端时钟。**
   - 服务端 `PushOperations` 直接采纳客户端上送的 `timestamp`（`sync/service.go:131-134`：`ts := time.Now(); if op.Timestamp != nil { ts = op.Timestamp.AsTime() }`）。
   - 客户端在入队时用 `DateTime.now()` 打戳（`offline_sync_queue.dart`），冲突时按这个时间戳取舍（`sync_engine.dart:567-613`）。
   - → **冲突解决逻辑不依赖中心时钟**，删掉服务器后语义不变（**已有的时钟漂移风险也原样保留**，见 §7.3）。

3. **客户端已是完整的离线优先副本** + 出站操作队列（`SyncQueue`）+ 拉取水位（`SyncMetadata.sync_last_pull_ts`）。
   → 服务端在同步上其实只是一个「带时间游标的操作日志中转站」。把这个中转站换成 iCloud 即可。

**主要工程工作量**因此集中在一点：**把「操作日志（ops-log）模型」对接到 iCloud 的「记录状态（record-state）模型」**（§6）。

---

## 4. iCloud 同步方案选型

「用 iCloud 同步」其实有三条技术路线，差异巨大：

| 方案 | 机制 | 多端并发合并 | schema 演进 | 评价 |
|------|------|-------------|------------|------|
| **A. iCloud Drive 同步整库 SQLite 文件** | 把 `.sqlite` 当文档放进 iCloud Drive | ❌ **整文件 LWW**，两端并发改 = 丢数据 | ❌ 版本不一致直接打架（调研 §5：Drift 只能前向迁移、不容忍未知列） | ❌ **不推荐**：会丢数据 |
| **B. CloudKit（CKRecord 逐记录）** | 每个实体 = 一条 `CKRecord`，私有数据库 | ✅ 逐记录/逐字段 LWW，并发安全 | ✅ 新字段老版本可忽略，平滑 | ✅ **推荐**：Apple 官方多端方案 |
| **C. CloudKit + 共享数据库（CKShare）** | 在 B 之上用共享区实现家庭 | ✅ | ✅ | 🟡 家庭共享用（§8） |

**推荐：方案 B（个人）+ 方案 C（家庭）。**

理由：
- CloudKit 的**私有数据库**默认就在用户 iCloud 名下、端到端受 Apple 加密、零成本、对用户透明 —— 完美契合「隐私优先 + 零运维」。
- 逐记录模型与「客户端 UUID + 客户端时钟 LWW」的现状**高度同构**，迁移成本最低。
- 避免了整库文件同步的并发丢数据与 schema 打架问题。

> ⚠️ Flutter 接入 CloudKit 没有成熟一等公民插件。需通过 **Platform Channel 调用原生 Swift CloudKit**（iOS/macOS），或评估社区插件（`cloud_kit` 等，能力有限）。这部分是 iOS 原生工作量，需排期（§10）。

---

## 5. 推荐架构总览

一份 Flutter 代码、两种平台形态（同步层可插拔，见 §9.3）：

```
═══════════════ iOS / macOS（本地优先 + iCloud 同步）═══════════════
┌──────────────────────────────────────────────────────────────────┐
│  Flutter UI ──► Domain 逻辑（CRUD/计算/校验，原服务端逻辑下沉）     │
│                      │                                             │
│  Drift (SQLite) 本地库  ◄── 唯一事实来源（离线优先，不变）          │
│                      │                                             │
│  iCloudSyncEngine（替换原 gRPC SyncEngine）                        │
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
│  （无同步引擎）→ 可选：手动加密备份/恢复（§9.2）                    │
└──────────────────────────────────────────────────────────────────┘

   两端均无任何自建服务器 / PostgreSQL / gRPC / WebSocket
```

**Go 服务端 + PostgreSQL 在两端均整体退役。** iOS 通过 iCloud 多端同步；Android 单机本地；二者不互通（§9）。家庭共享见 §8（仅 iOS）。


---

## 6. 数据模型映射：Drift 实体 → CloudKit 记录

现有数据模型对 CloudKit 友好，但有几处**必须补齐的缺口**（来自调研）。

### 6.1 实体映射

每个同步实体类型对应一个 CloudKit `RecordType`，`recordName` 直接用现有 UUID：

| Drift 实体 | CKRecordType | 主键来源 |
|-----------|--------------|---------|
| transaction / account / category / loan / loan_group / investment / fixed_asset / budget | 同名 RecordType | 现有客户端 UUID |
| 票据图片 | 作为 transaction 记录上的 `CKAsset` 字段 | —— |

（同步实体清单见 `sync_engine.dart:72-82` 的 `_knownEntityTypes`。）

### 6.2 三个必须补齐的缺口

1. **删除语义不统一（tombstone）**
   - 现状：仅 6/15 实体有 `deleted_at` 软删除；transfers/budgets/loan_schedules 等是**硬删除**。
   - CloudKit：删除是 `CKRecord` 的真实删除，靠 `CKFetchRecordZoneChangesOperation` 的 `deletedRecordZoneIDs` 回传。
   - **方案**：统一为「软删除 + tombstone 记录」或依赖 CloudKit 的删除变更回传；对当前硬删除的实体补齐删除传播。

2. **缺少逐行版本号 / 向量时钟**
   - 现状：只有 `updated_at`（约一半表有）+ 出站队列，**无 version、无 vector clock、无 CRDT**。
   - CloudKit：自带 `recordChangeTag`，且服务端做逐字段 LWW。
   - **方案**：保留现有「客户端时间戳 LWW」语义，用 CloudKit 的 `recordChangeTag` 做乐观并发；冲突时按 `updated_at` 取舍（与现状一致）。

3. **图片 blob**
   - 现状：图片**不在 SQLite**，存在服务端文件系统（`storage.go`，S3 是未实现的桩 `s3.go:25-26`），客户端只存 URL（`core_tables.dart:64`，逗号分隔）。
   - **方案**：迁移为 **`CKAsset`** 挂在对应 transaction 记录上；本地缓存文件，URL 字段改为本地/CloudKit 资产引用。

### 6.3 schema 版本偏斜（重要）

- Drift 只支持**前向迁移**、不容忍未知列（`database.dart:54-209`，schemaVersion=24）。
- **风险**：设备 A（v24）与设备 B（v22）通过 iCloud 交换数据，老设备遇到新字段会出问题。
- **CloudKit 的优势正在于此**：记录级模型下，老版本 App **可以忽略不认识的字段**，比「同步整库文件」安全得多。
- **方案**：CloudKit schema 只增不改（additive）；客户端按「未知字段忽略、缺失字段给默认值」处理；App 内对最低兼容版本设阈值提示升级。

---

## 7. 同步引擎重设计

### 7.1 替换关系

| 现有（gRPC） | 替换为（CloudKit） |
|-------------|-------------------|
| `PushOperations`（出站操作日志） | 将本地 `SyncQueue` 的每条变更**映射为 CKRecord 写入**（`CKModifyRecordsOperation`） |
| `PullChanges`（`since` 时间水位 + 分页游标） | `CKFetchRecordZoneChangesOperation` + **`serverChangeToken`** 游标（替换 `sync_last_pull_ts`） |
| WebSocket 实时推送 | `CKSubscription`（数据库订阅）+ 静默推送，收到后触发增量拉取 |
| 30s 轮询兜底（`AppConstants.syncIntervalSeconds`） | 保留为兜底；CloudKit 推送为主 |

### 7.2 出站流程（基本不变）

现有 `SyncQueue`（`support_tables.dart:67-81`，含 `uploaded/retryCount/nextRetryAt`）、死信队列（`SyncDeadLetters`）**可原样复用**，只把「上送目标」从 gRPC 换成 CloudKit 写入。重试/幂等/死信机制都不用动。

### 7.3 冲突解决（保留现状语义 + 已知风险）

- 继续沿用**客户端时间戳 LWW**（与 `sync_engine.dart:567-613` 一致）。
- **保留的已知风险**：两台设备时钟漂移时，较旧的写可能静默覆盖较新的写。当前服务端版本也有此问题（因为它采纳客户端时间戳），所以**不是去服务器引入的新缺陷**。
- **改进选项**（可选）：引入 Lamport 逻辑时钟 / HLC（混合逻辑时钟）做更稳健的因果排序，作为后续增强。

### 7.4 实时性

- 去掉 WebSocket 后，若只靠轮询，跨端可见延迟最长到一个轮询周期。
- 用 CloudKit `CKSubscription` 静默推送可把延迟拉回到秒级，体验与现有 WebSocket 接近。

---

## 8. 家庭共享与权限（最难的取舍）

这是**整个方案唯一的真正难点**，必须产品决策。

### 8.1 现状（服务端强制）

- 5 维权限 `CanView/CanCreate/CanEdit/CanDelete/CanManageAccounts` 存在每个 `family_member` 行（`family/service.go`）。
- 服务端在每个写操作上强制（`pkg/permission/check.go`），是**唯一可信仲裁点**。
- 邀请码（8 位、7 天 TTL）、角色（owner/admin/member）、审计日志全靠服务端。

### 8.2 去服务器后的本质问题

**本地优先 = 每个客户端都持有全量数据副本。** 没有可信第三方，就**无法在密码学上阻止**一个成员忽略权限去删改数据。"服务端强制权限"在无服务器世界里无解，只能二选一：

| 选项 | 做法 | 代价 |
|------|------|------|
| **8A. 共享即信任（推荐，简单）** | 用 **CKShare** 把账本共享给家人，所有被共享成员**平等读写**（CloudKit 仅支持 read-only / read-write 两档粗粒度权限） | 失去 5 维细粒度权限与防篡改审计；适合「家人之间互相信任」的真实家庭场景 |
| **8B. 保留细粒度权限 → 保留一个「瘦」服务** | 砍掉 19 包巨服务，只留一个「同步中转 + 权限仲裁」微服务 | 不再是「零服务器」，但比现状轻得多；与「隐私优先」目标部分矛盾 |
| 8C. 密码学能力令牌 | 用加密分区 / capability token 强制权限 | 工程量巨大，不建议 |

**建议**：家庭场景采用 **8A（CKShare，共享即信任）**。这与多数家庭账本的真实信任模型一致，也最贴合「隐私 + 零服务器」目标。把「5 维权限」降级为产品层面的「角色提示」而非强制。

### 8.3 邀请与审计

- 邀请：用 CloudKit `CKShare` 的系统级共享邀请（`UICloudSharingController`）替代自建邀请码。
- 审计：退化为**本地审计日志**（不可防篡改）；若必须防篡改，回到 8B。

---

## 9. 平台分化策略（最终决策）

**已决策**：iCloud / CloudKit 无原生 Android SDK，本项目**不追求跨生态同步**。最终采用平台分化：

| 平台 | 存储 | 同步 | 家庭共享 |
|------|------|------|---------|
| **iOS / macOS** | 本地 Drift（事实来源） | ✅ iCloud（CloudKit）多端同步（§5–§7） | 🟡 可选 CKShare（§8，仅 Apple 设备间） |
| **Android** | 本地 Drift（事实来源） | ❌ **不同步**（单机本地账本） | ❌ 不参与 |

被否决的备选：转 Apple 专属（放弃 Android）、双云分叉互不通、瘦服务跨端、跨平台 CRDT —— 均不采纳。**iOS↔Android 明确不互相同步。**

### 9.1 Android：纯本地的工程含义

Android 端代码量反而最小 —— 它就是「**去掉同步引擎的现有客户端**」：

- 保留 Drift 本地库与全部业务逻辑（CRUD、计算、行情、本地通知）。
- **移除** gRPC/WebSocket 同步层（`app/lib/sync/` 在 Android 构建中不启用）。
- 不需要 `SyncQueue` / `SyncMetadata` / 死信队列（这些是为同步服务的）—— 可在 Android 构建中编译期关闭。

### 9.2 Android 本地备份 / 设备迁移（已定：手动导出加密文件）

「只本地保存」最大的风险是**换机/丢机 = 数据全丢**。**已决策**采用**手动导出加密文件**方案（不引入云依赖、最私密）：

- **导出**：把整库导出为**加密文件**（AES，口令/密钥由用户掌握），用户自行存到任意位置（网盘 / 微信 / U 盘）。可复用现有导出能力（`docs/import-export-design.md`）。
- **导入**：换机时选文件 + 输入口令恢复。
- **提示**：App 内定期提醒用户「该备份了」，降低长期不备份的丢数据风险。

被否决的备选：Google Drive `appDataFolder`（要接 Drive API + 登录 Google）、Android Auto Backup（不可控）。

> 注意：这是**单向备份/恢复**，不是多端实时同步；不引入 CRDT、不跨平台。与「Android 只本地保存」的决策一致。

**待细化（实施期决定，非阻塞）**：加密算法与密钥派生（建议 AES-256-GCM + Argon2id 口令派生）、备份文件格式与版本号。


### 9.3 一份代码两种形态

Flutter 单 codebase，用编译期开关 / 平台判断区分：iOS 走「Drift + iCloudSyncEngine」，Android 走「Drift only（+ 可选本地备份）」。同步层做成可插拔（接口 + 平台实现），避免在 Android 构建里引入 CloudKit/原生依赖。


---

## 10. 迁移路径（现有用户数据）

> 已决策：仅少量测试用户，**不做双跑期**，一次性切换即可。

1. **一次性导出**：现有用户从旧服务端拉全量数据（已有导出能力）。
2. **本地落库**：客户端把全量写入本地 Drift（已是事实来源）。
3. **首次上云（仅 iOS）**：`iCloudSyncEngine` 把本地全量映射为 CKRecord 批量写入用户私有库（注意 CloudKit 批量限额，分批）。Android 端到第 2 步即完成（纯本地）。
4. **图片迁移**：旧服务端文件系统中的票据图 → 下载 → iOS 作为 `CKAsset` 上云、Android 存本地。
5. **退役服务端**：迁移完成后直接下线 Go 服务端 + PostgreSQL（无双跑期）。


---

## 11. 隐私与安全收益

- 数据只存用户自己的 iCloud（私有库），**默认 Apple 加密**；开启「高级数据保护（Advanced Data Protection）」后为端到端加密，连 Apple 也无法读取 —— 直接命中「隐私优先」。
- 无自建服务器 = **无数据库被拖库风险、无运维、无服务器日志留存**（与刚合并的 #135 日志分级形成对照：以后连服务端日志都没有了）。
- 不再需要自建 JWT、密码哈希、令牌撤销表。

---

## 12. 风险与权衡小结

| 风险 / 取舍 | 严重度 | 缓解 |
|------------|--------|------|
| iOS↔Android 不互通 | 🟡 中（已接受） | 决策如此；产品文案明确告知 Android 为单机本地 |
| Android 换机/丢机数据全失 | 🔴 高 | §9.2 本地加密备份/恢复通道（必做） |
| 家庭细粒度权限无法强制 | 🟡 中 | §8A 共享即信任（仅 iOS） |
| 微信登录丢失 | 🟡 中（已接受） | 已决策砍掉；iOS 用 iCloud 隐式身份，Android 无需登录 |
| Flutter 无成熟 CloudKit 插件 | 🟡 中 | 原生 Swift Platform Channel，需排期 |
| 时钟漂移导致 LWW 误判 | 🟢 低（现状已有） | 可选引入 HLC |
| schema 版本偏斜（iOS 多端不同版本） | 🟢 低 | CloudKit 记录级模型天然容忍；只增不改 |
| CloudKit 配额/限流 | 🟢 低 | 个人数据量小（调研估算单用户多年 1–5 万行）；分批写入 |

---

## 13. 分阶段实施建议

- **Phase 0 — 决策**：✅ **已定**（iOS=iCloud，Android=本地，服务端退役）。
- **Phase 1 — 服务端职责下沉**（两端共用，可独立先做）：
  - 行情/汇率直连客户端；提醒/预算/折旧本地计算 + 本地通知；导入导出本地化（部分已完成）。
  - 把同步层抽象成可插拔接口（为 §9.3 双形态铺路）。
  - 产出：一个「不依赖服务端业务逻辑」的客户端（iOS/Android 通用）。
- **Phase 2 — Android 本地形态收尾**（成本最低，可先交付）：
  - Android 构建关闭同步层；补齐 §9.2 本地加密备份/恢复。
  - 产出：可独立发布的 Android 纯本地版。
- **Phase 3 — iCloud 同步引擎（iOS）**：
  - 原生 CloudKit Platform Channel；`iCloudSyncEngine` 替换 gRPC；补齐 tombstone / CKAsset / 版本标记。
  - 复用现有 `SyncQueue` / 死信 / LWW。
- **Phase 4 — iOS 家庭共享**：CKShare + 系统共享邀请；权限降级为角色提示。
- **Phase 5 — 迁移与退役**：一次性数据迁移工具，**不做双跑**（仅少量测试用户）；下线 Go 服务端 + PostgreSQL。

---

## 14. 决策记录（原 Open Questions，已全部定稿）

| # | 问题 | 决策 | 影响章节 |
|---|------|------|---------|
| 1 | 跨平台 | iOS 用 iCloud；Android 仅本地；**不互通** | §9 |
| 2 | Android 备份形态 | **手动导出加密文件**（用户自存，换机导入）；其余方案不采用 | §9.2 |
| 3 | 家庭共享 | **用 CKShare（仅 iOS，共享即信任）** | §8 |
| 4 | 微信登录 | **砍掉所有第三方登录**；iOS=iCloud 隐式身份，Android=无登录 | §2、§11 |
| 5 | 存量迁移 | 仅少量测试用户 → **一次性导出/导入，不做双跑期** | §10 |
| 6 | macOS | **暂不支持**，仅 iOS（CloudKit 方案未来可低成本加） | §9 |

> 所有问题已决策，本文进入「可据此拆解 Phase 1 任务」状态。


---

## 附：本文结论所依据的代码锚点

- 同步实体类型：`server/internal/sync/service.go:217-238`、`app/lib/sync/sync_engine.dart:72-82`
- LWW 用客户端时钟：`server/internal/sync/service.go:131-134`、`app/lib/sync/sync_engine.dart:567-613`
- 客户端 UUID：`app/lib/domain/providers/account_provider.dart`、`app/lib/core/utils/category_uuid.dart`
- 出站队列 / 水位：`app/lib/data/local/support_tables.dart:67-135`
- 行情免鉴权接口：`server/internal/market/fetcher.go`
- 推送未实现：`server/internal/notify/service.go`（`TODO(M8)`）
- 5 维权限：`server/internal/family/service.go`、`server/pkg/permission/check.go`
- 图片存储：`server/pkg/storage/storage.go`、`s3.go:25-26`、`app/lib/data/local/core_tables.dart:64`
- 客户端 schema 迁移：`app/lib/data/local/database.dart:54-209`（schemaVersion=24）
