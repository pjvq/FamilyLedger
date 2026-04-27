# 组合贷款调研 & PRD 更新

## 一、国内房贷贷款类型调研

### 1. 三种房贷形式

| 类型 | 利率特征 | 额度上限 | 还款周期 | 使用场景 |
|------|----------|----------|----------|----------|
| **纯商贷** | LPR + 基点 (当前约 3.0%-3.5%) | 无硬性上限，取决于房价和首付比例 | 最长 30 年 | 未缴公积金 / 公积金额度不够但不想组合 |
| **纯公积金贷** | 固定利率 (当前首套 2.85%, 二套 3.325%) | 各城市限额 (北京 120万/人, 上海同) | 最长 30 年 | 贷款额不超过公积金上限 |
| **组合贷款** | 两笔独立贷款，各自利率 | 公积金部分走上限，差额走商贷 | 两笔期限可不同 (通常一致) | 公积金不够覆盖全部贷款额 |

### 2. 组合贷款的核心逻辑

组合贷款 = **一笔公积金贷款 + 一笔商业贷款**，本质上是两笔独立贷款：

- **分别计算**：公积金部分和商贷部分各自独立计算月供
- **合并还款**：每月总月供 = 公积金月供 + 商贷月供
- **利率独立**：公积金利率固定，商贷利率可随 LPR 浮动
- **期限可不同**：理论上两笔期限可以不同（实际上大多数银行要求一致）
- **提前还款**：可以选择先还商贷部分（利率高）或先还公积金部分
- **利率变动**：公积金利率政策调整时全国统一变；商贷跟 LPR 浮动

### 3. 利率类型

| 利率类型 | 说明 |
|----------|------|
| **固定利率** | 公积金贷款默认、少数银行提供的固定利率商贷 |
| **LPR浮动** | 商贷主流，基准 = 5年期LPR + 固定基点，每年1月1日调整 |
| **自定义调整日** | 银行允许选 1月1日 或 放款日对应月 作为利率调整日 |

### 4. 提前还款规则

- 组合贷提前还款可**指定还哪一笔**（优先还商贷更省利息）
- 提前还款后可选：缩短期限 / 减少月供 / 保持不变（部分银行支持）
- 部分银行有提前还款违约金（通常贷款满1年后免违约金）

### 5. 公积金贷款额度计算（各城市不同）

- **北京**: 每缴存一年可贷 10 万，最高 120 万/人，夫妻 120 万
- **上海**: 个人最高 60 万 (补充公积金+20万)，家庭 120 万
- **深圳**: 个人最高 50 万，家庭 90 万
- **广州**: 个人最高 60 万，家庭 100 万

> 我们的 app 不需要自动计算公积金额度上限（太依赖城市政策），用户手动输入即可。

---

## 二、数据模型变更

### 现状

当前 `Loan` 是单一实体，一笔贷款 = 一条 `loans` 记录。

### 目标

支持**组合贷款**：一个逻辑贷款包含 1-2 个子贷款（sub-loan）。

### 设计方案：`loan_group` + `loans` 扩展

```
loan_groups (新表)
├── id: UUID PK
├── user_id: UUID
├── name: VARCHAR(100)        -- "XX小区房贷"
├── group_type: VARCHAR(20)   -- commercial_only / provident_only / combined
├── total_principal: BIGINT   -- 总贷款本金（冗余，= sum of sub-loans）
├── payment_day: INT          -- 统一还款日
├── start_date: DATE
├── account_id: UUID?         -- 关联还款账户
├── created_at / updated_at / deleted_at

loans (修改)
├── (现有字段保留)
├── + group_id: UUID? FK → loan_groups(id)   -- 归属组合贷款（null = 独立贷款）
├── + sub_type: VARCHAR(20)  -- commercial(商贷) / provident(公积金)
├── + rate_type: VARCHAR(20) -- fixed(固定) / lpr_floating(LPR浮动)
├── + lpr_base: DECIMAL(6,4)?  -- LPR 基准利率（如 3.45）
├── + lpr_spread: DECIMAL(6,4)? -- 基点（如 -0.20 表示 LPR-20BP）
├── + rate_adjust_month: INT?   -- 利率调整月份（1=每年1月，0=放款月）
```

### 关键决策

1. **向后兼容**：现有独立贷款 `group_id = NULL`，不受影响
2. **组合贷 = 1 个 group + 2 条 loans**：公积金一条 + 商贷一条
3. **纯商贷/纯公积金也可以用 group**：group_type 区分
4. **月供汇总在 group 层面展示**：detail 页面分 tab 显示每笔子贷款
5. **LPR 浮动利率**：存 `lpr_base + lpr_spread`，effective_rate = base + spread

---

## 三、Proto 变更

### 新增/修改

```protobuf
// 新增枚举
enum LoanSubType {
    LOAN_SUB_TYPE_UNSPECIFIED = 0;
    LOAN_SUB_TYPE_COMMERCIAL = 1;   // 商业贷款
    LOAN_SUB_TYPE_PROVIDENT = 2;    // 公积金贷款
}

enum RateType {
    RATE_TYPE_UNSPECIFIED = 0;
    RATE_TYPE_FIXED = 1;           // 固定利率
    RATE_TYPE_LPR_FLOATING = 2;    // LPR浮动
}

// 新增 message
message LoanGroup {
    string id = 1;
    string user_id = 2;
    string name = 3;
    string group_type = 4;         // commercial_only / provident_only / combined
    int64 total_principal = 5;
    int32 payment_day = 6;
    google.protobuf.Timestamp start_date = 7;
    string account_id = 8;
    repeated Loan sub_loans = 9;   // 1-2 笔子贷款
    int64 total_monthly_payment = 10; // 总月供（计算字段）
    google.protobuf.Timestamp created_at = 11;
    google.protobuf.Timestamp updated_at = 12;
}

// Loan message 新增字段
message Loan {
    // ... 保留现有字段 1-15 ...
    string group_id = 16;
    LoanSubType sub_type = 17;
    RateType rate_type = 18;
    double lpr_base = 19;          // LPR 基准
    double lpr_spread = 20;        // 基点偏移
    int32 rate_adjust_month = 21;  // 利率调整月 (1=一月, 0=放款月)
}

// 新增 RPC
rpc CreateLoanGroup(CreateLoanGroupRequest) returns (LoanGroup);
rpc GetLoanGroup(GetLoanGroupRequest) returns (LoanGroup);
rpc ListLoanGroups(ListLoanGroupsRequest) returns (ListLoanGroupsResponse);
rpc SimulateGroupPrepayment(SimulateGroupPrepaymentRequest) returns (GroupPrepaymentSimulation);

// 组合贷提前还款可指定还哪笔
message SimulateGroupPrepaymentRequest {
    string group_id = 1;
    string target_loan_id = 2;     // 指定先还哪笔（为空则自动选利率高的）
    int64 prepayment_amount = 3;
    PrepaymentStrategy strategy = 4;
}

message GroupPrepaymentSimulation {
    string target_loan_id = 1;
    PrepaymentSimulation commercial_sim = 2;  // 商贷部分模拟
    PrepaymentSimulation provident_sim = 3;   // 公积金部分模拟
    int64 total_interest_saved = 4;
}
```

---

## 四、客户端变更

### 添加贷款流程重构

```
选择贷款大类:
├── 纯商业贷款 → 填写 1 笔贷款信息 (利率类型: 固定/LPR)
├── 纯公积金贷款 → 填写 1 笔贷款信息 (固定利率)
└── 组合贷款 → Step 1: 总额 → Step 2: 公积金部分 → Step 3: 商贷部分
```

### 贷款详情页重构

```
组合贷详情:
├── 头部: 总月供 / 总剩余本金 / 已还进度
├── Tab 1: 总览 (合并时间线)
├── Tab 2: 商贷部分 (独立还款计划)
├── Tab 3: 公积金部分 (独立还款计划)
└── 提前还款: 选择还哪部分 + 模拟
```

### 贷款列表页

```
组合贷以卡片展示:
├── 标题: "XX小区房贷 (组合贷)"
├── 副标题: "商贷 80万 + 公积金 50万"
├── 月供: "¥6,234 (商贷 ¥4,012 + 公积金 ¥2,222)"
└── 进度条: 两段色 (商贷+公积金)
```

---

## 五、实施计划

### 后端
1. Migration 30: `loan_groups` 表
2. Migration 31: `loans` 表新增列 (group_id, sub_type, rate_type, lpr_base, lpr_spread, rate_adjust_month)
3. Proto 更新: 新枚举 + LoanGroup message + 4 个新 RPC
4. Service 更新: CreateLoanGroup (创建组合贷 + 子贷款), GetLoanGroup (加载组+子), LPR利率计算逻辑, 组合贷提前还款模拟

### 客户端
1. Proto gen 更新
2. DB schema v8: loan_groups 表 + loans 新列
3. 添加贷款页重构: 3 选 1 入口 + 组合贷向导
4. 贷款详情页重构: Tab 视图 + 合并月供展示
5. 贷款列表页: 组合贷卡片样式
6. Provider 更新: group CRUD + 子贷款加载

### 预计工作量: 后端 ~500 行 + 客户端 ~800 行
