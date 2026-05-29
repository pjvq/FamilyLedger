# FamilyLedger 智能分类系统设计方案

> 版本：v1.0 | 日期：2026-05-29 | 包含：分类推荐 + 分类整理（合并）

---

## 一、功能概述

### 两个功能，一套基础设施

| 功能 | 用户价值 | 触发时机 |
|------|---------|---------|
| **智能推荐** | 记账时自动排序分类，最可能的排最前 | 每次打开记账面板 |
| **分类整理** | 发现重复/相似分类，引导用户合并清理 | 用户主动进入 / 周期性提示 |

两者共享底层的「分类使用画像」数据层，但上层算法和交互完全不同。

---

## 二、系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
├──────────────────────────┬──────────────────────────────────┤
│  QuickCategorySelector   │  CategoryCleanupPage             │
│  (推荐排序的分类网格)     │  (合并建议列表 + 确认流程)        │
├──────────────────────────┴──────────────────────────────────┤
│                     Provider Layer                            │
├──────────────────────────┬──────────────────────────────────┤
│  categoryRecommendProvider│  categoryMergeSuggestProvider    │
│  (实时推荐排序)           │  (合并建议生成)                   │
├──────────────────────────┴──────────────────────────────────┤
│                   Service Layer (纯 Dart)                     │
├──────────────────────────┬──────────────────────────────────┤
│  CategoryRecommender     │  CategoryMergeDetector           │
│  ├─ TimeSlotScorer       │  ├─ TextSimilarityScorer         │
│  ├─ RecencyScorer        │  ├─ BehaviorOverlapScorer        │
│  ├─ FrequencyScorer      │  ├─ KeywordOverlapScorer         │
│  ├─ AmountRangeScorer    │  └─ SemanticScorer (iOS NL)      │
│  ├─ SequenceScorer       │                                  │
│  └─ KeywordScorer        │  CategoryMergeExecutor           │
│                          │  (执行合并: 重映射交易+删除旧分类) │
├──────────────────────────┴──────────────────────────────────┤
│              Shared Infrastructure                            │
├─────────────────────────────────────────────────────────────┤
│  CategoryUsageProfiler (统计聚合引擎)                         │
│  ├─ 从 transactions 表聚合使用画像                            │
│  ├─ 缓存到 category_usage_stats 表                           │
│  └─ 增量更新（每次新交易后局部刷新）                           │
├─────────────────────────────────────────────────────────────┤
│  NLEmbeddingBridge (iOS 平台通道)                            │
│  └─ Swift NaturalLanguage.NLEmbedding → Dart                │
├─────────────────────────────────────────────────────────────┤
│  Drift SQLite (transactions / categories / category_usage)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 三、数据模型

### 3.1 新增表：category_usage_slots（拆行模型）

> ℹ️ 采用拆行存储而非 JSON TEXT，避免每次增量更新时读写整行。单行原子 `count = count + 1`，无写冲突。

```sql
-- 分类使用分布槽位（拆行存储）
CREATE TABLE category_usage_slots (
  category_id TEXT NOT NULL REFERENCES categories(id),
  slot_type TEXT NOT NULL,    -- 'hour' | 'weekday' | 'amount'
  slot_index INTEGER NOT NULL, -- hour: 0-23, weekday: 0-6, amount: 0-5
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (category_id, slot_type, slot_index)
);

-- 分类使用摘要（低频更新字段）
CREATE TABLE category_usage_summary (
  category_id TEXT PRIMARY KEY REFERENCES categories(id),
  total_count INTEGER NOT NULL DEFAULT 0,
  last_30d_count INTEGER NOT NULL DEFAULT 0,
  last_7d_count INTEGER NOT NULL DEFAULT 0,
  top_keywords TEXT NOT NULL DEFAULT '[]', -- JSON array of strings, max 20
  last_used_at DATETIME,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**增量更新示例：**
```sql
-- 记一笔交易后，只更新单行
UPDATE category_usage_slots 
SET count = count + 1 
WHERE category_id = ? AND slot_type = 'hour' AND slot_index = ?;

UPDATE category_usage_summary 
SET total_count = total_count + 1, last_used_at = ? 
WHERE category_id = ?;
```

### 3.2 Drift 表定义

```dart
/// 分类使用分布槽位（拆行模型，原子更新）
class CategoryUsageSlots extends Table {
  @override
  String get tableName => 'category_usage_slots';

  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get slotType => text()();    // 'hour' | 'weekday' | 'amount'
  IntColumn get slotIndex => integer()(); // 0-23 | 0-6 | 0-5
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {categoryId, slotType, slotIndex};
}

/// 分类使用摘要（低频更新字段）
class CategoryUsageSummary extends Table {
  @override
  String get tableName => 'category_usage_summary';

  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get totalCount => integer().withDefault(const Constant(0))();
  IntColumn get last30dCount => integer().withDefault(const Constant(0))();
  IntColumn get last7dCount => integer().withDefault(const Constant(0))();
  TextColumn get topKeywords => text().withDefault(const Constant('[]'))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {categoryId};
}
```

### 3.3 领域模型

```dart
class CategoryUsageProfile {
  final String categoryId;
  final int totalCount;
  final int last30dCount;
  final int last7dCount;
  final List<int> hourDistribution;    // length 24, from slots table
  final List<int> weekdayDistribution; // length 7, from slots table
  final List<int> amountBuckets;       // length 6, from slots table
  final List<String> topKeywords;      // max 20, from summary table
  final DateTime? lastUsedAt;

  /// 归一化的小时分布 (概率向量, sum=1)
  List<double> get hourProbability { ... }
  
  /// 归一化的金额区间分布
  List<double> get amountProbability { ... }
}
```

---

## 四、功能一：智能分类推荐

### 4.1 推荐触发时机

| 时机 | 行为 |
|------|------|
| 打开记账面板 | 根据当前时间+星期生成推荐排序 |
| 输入金额后 | 结合金额区间信号重新排序 |
| 输入备注后 | 结合关键词信号重新排序 |
| 切换收入/支出 | 切换对应类型的推荐 |

### 4.2 评分模型

每个候选分类计算一个综合得分 `score ∈ [0, 1]`：

```
score = w1 × timeSlotScore
      + w2 × recencyScore
      + w3 × frequencyScore
      + w4 × amountScore
      + w5 × sequenceScore
      + w6 × keywordScore
```

**权重配置（可调，通过 `RecommenderConfig` 封装）：**

```dart
/// 可配置的推荐权重，支持远程下发调整
class RecommenderConfig {
  final double timeSlotWeight;
  final double recencyWeight;
  final double frequencyWeight;
  final double amountWeight;
  final double sequenceWeight;
  final double keywordWeight;
  
  const RecommenderConfig({
    this.timeSlotWeight = 0.25,
    this.recencyWeight = 0.20,
    this.frequencyWeight = 0.15,
    this.amountWeight = 0.20,
    this.sequenceWeight = 0.10,
    this.keywordWeight = 0.10,
  });
}
```

| Scorer | 权重 | 信号说明 |
|--------|------|---------|
| TimeSlot | 0.25 | 当前小时在该分类的历史小时分布中的概率 |
| Recency | 0.20 | 近 7 天使用次数 / max(所有分类近7天次数) |
| Frequency | 0.15 | 总使用次数 / max(所有分类总次数) |
| Amount | 0.20 | 当前金额落在该分类金额区间的概率（未输入金额时此项=0，权重重分配） |
| Sequence | 0.10 | 上一笔交易分类 → 当前分类的转移概率 |
| Keyword | 0.10 | 备注文本与该分类 topKeywords 的匹配度（未输入备注时=0） |

**动态权重重分配：** 当某个信号不可用时（如未输入金额），其权重按比例分配给其他 scorer。

### 4.3 各 Scorer 详细算法

#### TimeSlotScorer

```dart
double score(CategoryUsageProfile profile, DateTime now) {
  final hour = now.hour;
  final hourProb = profile.hourProbability;
  // 取当前小时 ± 1 小时的平均概率（平滑）
  final smoothed = (hourProb[(hour - 1) % 24] 
                  + hourProb[hour] 
                  + hourProb[(hour + 1) % 24]) / 3;
  return smoothed / maxHourProb; // 归一化到 [0,1]
}
```

#### RecencyScorer

```dart
double score(CategoryUsageProfile profile) {
  if (maxLast7d == 0) return 0;
  return profile.last7dCount / maxLast7d;
}
```

#### FrequencyScorer

```dart
double score(CategoryUsageProfile profile) {
  if (maxTotal == 0) return 0;
  return profile.totalCount / maxTotal;
}
```

#### AmountRangeScorer

```dart
double score(CategoryUsageProfile profile, int? amountCents) {
  if (amountCents == null) return 0; // 未输入金额
  final bucket = _toBucket(amountCents);
  final prob = profile.amountProbability;
  return prob[bucket]; // 该分类在此金额区间的使用占比
}

int _toBucket(int cents) {
  final yuan = cents / 100;
  if (yuan < 20) return 0;
  if (yuan < 50) return 1;
  if (yuan < 100) return 2;
  if (yuan < 500) return 3;
  if (yuan < 2000) return 4;
  return 5;
}
```

#### SequenceScorer

```dart
/// 基于最近 N 笔交易建立简单的转移矩阵
double score(String? lastCategoryId, String candidateId) {
  if (lastCategoryId == null) return 0;
  final transitions = _transitionMatrix[lastCategoryId];
  if (transitions == null) return 0;
  return transitions[candidateId] ?? 0;
}
```

转移矩阵从最近 200 笔交易中统计相邻交易的分类对。

**转移矩阵管理策略：**
- **存储**：纯内存缓存（`Map<String, Map<String, double>>`），不入库
- **作用域**：当前用户的最近 200 笔交易（不区分账本）
- **更新时机**：惰性重建 — 打开记账面板时从 DB 取最近 200 笔，计算一次，缓存到 Provider 关闭
- **Invalidate**：提交新交易后重置缓存，下次打开记账面板时重建
- **内存占用**：30 分类 × 30 = 900 entry，忽略不计

#### KeywordScorer

```dart
double score(CategoryUsageProfile profile, String? noteText) {
  if (noteText == null || noteText.isEmpty) return 0;
  final words = _tokenize(noteText);
  final keywords = profile.topKeywords.toSet();
  final matches = words.where((w) => keywords.contains(w)).length;
  return min(1.0, matches / 2); // 匹配 2 个关键词即满分
}
```

#### topKeywords 提取算法

```dart
/// 从交易备注中提取高频关键词
/// 分词方案：中文 2-char ngram + 拉丁文完整单词
List<String> extractTopKeywords(List<String> allNotes, {int maxCount = 20}) {
  final freq = <String, int>{};
  final stopwords = {'的', '了', '在', '是', '我', '一', '个', '不', '这', '那'};
  
  for (final note in allNotes) {
    if (note.isEmpty) continue;
    final tokens = _tokenize(note);
    for (final token in tokens) {
      if (stopwords.contains(token)) continue;
      if (_isNumericOrDate(token)) continue; // 排除纯数字/日期
      freq[token] = (freq[token] ?? 0) + 1;
    }
  }
  
  // 按频率降序，取 top N
  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(maxCount).map((e) => e.key).toList();
}

/// 分词器：中文用 2-char sliding window，拉丁文用空格分割
List<String> _tokenize(String text) {
  final tokens = <String>[];
  final latin = RegExp(r'[a-zA-Z]+');
  
  // 拉丁文单词
  for (final m in latin.allMatches(text)) {
    if (m.group(0)!.length >= 2) tokens.add(m.group(0)!.toLowerCase());
  }
  
  // 中文 2-gram
  final cjk = text.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
  for (var i = 0; i < cjk.length - 1; i++) {
    tokens.add(cjk.substring(i, i + 2));
  }
  // 完整匹配（备注本身，去空格/标点）
  final clean = text.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
  if (clean.length >= 2 && clean.length <= 6) tokens.add(clean);
  
  return tokens;
}
```

**更新频率：**
- **全量重建**：首次启动 / CSV 导入后 / 周期性后台刷新（每周）
- **不增量更新 topKeywords**：因为需要计算全局频率排序，增量无意义
- 但 `total_count`, `last_7d_count`, slot counts **每笔交易增量更新**

### 4.4 冷启动策略

| 场景 | 策略 |
|------|------|
| 新用户（0 笔交易） | 使用预设的时间段先验（午餐时段=餐饮，月初=工资） |
| 新分类（用户刚创建） | 给予 0.3 的基础 frequency 分，避免永远排不上来 |
| 交易量 < 30 笔 | 增大 Frequency 权重，减小 TimeSlot 权重（数据不够稳定） |

### 4.5 UI 集成

改造现有 `QuickCategorySelector`：

```dart
/// Before: 最近使用 + 固定排序网格
/// After:  推荐行(Top 5 by ML) + 智能排序网格

class QuickCategorySelector extends ConsumerWidget {
  // ...
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取推荐排序
    final recommendations = ref.watch(
      categoryRecommendProvider(CategoryRecommendInput(
        typeIndex: typeIndex,
        amountCents: currentAmount,  // nullable
        noteText: currentNote,       // nullable
        lastCategoryId: lastTxnCategoryId,
      ))
    );
    
    // "推荐" 行替代原来的 "最近" 行
    // 主网格按推荐分数降序排列
  }
}
```

**视觉变化：**
- "最近" label → "推荐" label（带 ✨ 图标）
- Top 5 chip 行：按推荐分排序（不再是简单的最近使用）
- 主网格：按推荐分降序排列（而非固定 sortOrder）
- 可选：推荐分最高的分类有微弱高亮呼吸动效

---

---

## 五、功能二：分类整理（合并）

### 5.1 设计原则

> ⚠️ **绝对不自动合并。** 所有合并操作必须经过用户明确确认。

| 原则 | 说明 |
|------|------|
| **建议而非执行** | 系统只生成「建议合并」列表，用户逐条确认/忽略 |
| **可预览** | 合并前展示影响范围（涉及 N 笔交易） |
| **可撤销** | 合并后 7 天内可一键撤销（保留映射日志） |
| **渐进引导** | 不一次性甩出 20 条建议，分批推送（每次最多 3-5 条） |

### 5.2 合并检测：三层评分模型

对每一对分类 (A, B) 计算「合并置信度」：

```
merge_confidence = w1 × textSimilarity(A, B)
                + w2 × semanticSimilarity(A, B)   // iOS only
                + w3 × behaviorOverlap(A, B)
                + w4 × keywordOverlap(A, B)
```

| Layer | Scorer | 权重 | 说明 | 平台 |
|-------|--------|------|------|------|
| L2 | TextSimilarity | 0.35 | 编辑距离 + 字符 n-gram + 包含关系 | 全平台 |
| L3 | SemanticSimilarity | 0.30 | iOS NLEmbedding 词向量余弦距离 | iOS |
| L1 | BehaviorOverlap | 0.20 | 时间段/金额/星期分布的 Jensen-Shannon 散度 | 全平台 |
| L1 | KeywordOverlap | 0.15 | 两个分类 topKeywords 的 Jaccard 系数 | 全平台 |

**Android 降级：** SemanticSimilarity 不可用时，权重重分配为 TextSimilarity=0.50, Behavior=0.30, Keyword=0.20。

#### TextSimilarityScorer 详细算法

```dart
double textSimilarity(String nameA, String nameB) {
  double score = 0;
  
  // 1. 包含关系 ("点外卖" contains "外卖")
  if (nameA.contains(nameB) || nameB.contains(nameA)) {
    score = max(score, 0.85);
  }
  
  // 2. 归一化编辑距离
  final editDist = levenshtein(nameA, nameB);
  final maxLen = max(nameA.length, nameB.length);
  final editScore = 1.0 - (editDist / maxLen);
  score = max(score, editScore);
  
  // 3. 字符 bigram Jaccard
  final bigramsA = _bigrams(nameA);
  final bigramsB = _bigrams(nameB);
  final intersection = bigramsA.intersection(bigramsB).length;
  final union = bigramsA.union(bigramsB).length;
  final jaccard = union > 0 ? intersection / union : 0;
  score = max(score, jaccard);
  
  return score;
}
```

#### SemanticScorer (iOS NLEmbedding)

```dart
Future<double> semanticSimilarity(String nameA, String nameB) async {
  final distance = await NLEmbeddingBridge.distance(nameA, nameB);
  if (distance == null) return 0; // 平台不支持
  // NLEmbedding distance: 0=相同, 2=完全无关
  // 转换为 similarity: 1=相同, 0=无关
  return max(0, 1.0 - distance / 2.0);
}
```

#### BehaviorOverlapScorer

```dart
double behaviorOverlap(CategoryUsageProfile a, CategoryUsageProfile b) {
  // Jensen-Shannon Divergence of hour distributions
  final hourJS = 1.0 - jensenShannonDivergence(
    a.hourProbability, b.hourProbability
  );
  
  // JS Divergence of amount bucket distributions  
  final amountJS = 1.0 - jensenShannonDivergence(
    a.amountProbability, b.amountProbability
  );
  
  // Weekday cosine similarity
  final weekdayCos = cosineSimilarity(
    a.weekdayDistribution.map((e) => e.toDouble()).toList(),
    b.weekdayDistribution.map((e) => e.toDouble()).toList(),
  );
  
  return (hourJS + amountJS + weekdayCos) / 3;
}
```

#### 过滤规则（不生成建议的情况）

| 规则 | 原因 |
|------|------|
| 同一对已被用户忽略过 | 尊重用户决定 |
| 预设分类之间 | 系统预设的分类不建议合并 |
| 不同类型（收入 vs 支出） | 逻辑上不可合并 |
| 父子关系的分类 | 已有层级关系，不需要合并 |
| merge_confidence < 0.6 | 置信度不够，不打扰用户 |

### 5.3 用户交互流程

#### 入口

| 入口 | 触发条件 |
|------|----------|
| 「我的」→ 分类管理 → 「整理建议」按钮 | 用户主动 |
| 概览页 Reminders 卡片 | 有 ≥3 条高置信度建议时，显示提示卡片 |
| 分类管理页顶部 Banner | 有待处理建议时常驻显示 |

#### 合并确认流程（核心交互）

```
┌────────────────────────────────────────────┐
│        分类整理建议                          │
│                                            │
│  ┌──────────────────────────────────────┐  │
│  │  建议 1/3                    跳过 │  │
│  │                                      │  │
│  │  🍜 "点外卖"  ──合并到──▶  🍽️ "餐饮"  │  │
│  │                                      │  │
│  │  匹配原因: 名称相似(92%) + 使用时段    │  │
│  │  相近(午餐/晚餐时段)                   │  │
│  │                                      │  │
│  │  📊 影响范围                          │  │
│  │  · "点外卖" 下有 47 笔交易             │  │
│  │  · 合并后将归入 "餐饮"                 │  │
│  │                                      │  │
│  │  ┌────────────────────────────────┐  │  │
│  │  │ 合并方向:                       │  │  │
│  │  │ ○ 保留 "餐饮"，删除 "点外卖"    │  │  │
│  │  │ ○ 保留 "点外卖"，删除 "餐饮"    │  │  │
│  │  │ ● 合并为 "餐饮"（推荐）         │  │  │
│  │  └────────────────────────────────┘  │  │
│  │                                      │  │
│  │  [暂不处理]           [确认合并 ✓]    │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  ● ○ ○  (分页指示器)                       │
└────────────────────────────────────────────┘
```

#### 交互细节

| 操作 | 行为 |
|------|------|
| **确认合并** | 执行合并（见 5.4），进入下一条建议 |
| **暂不处理** | 标记为 dismissed，30 天内不再提示，进入下一条 |
| **跳过** | 本次不处理，下次还会出现 |
| **左滑** | 同「暂不处理」|
| **合并方向选择** | 默认推荐使用次数更多的分类作为保留方 |

#### 合并方向的智能推荐

```dart
String recommendRetainCategory(String catIdA, String catIdB) {
  final profileA = getProfile(catIdA);
  final profileB = getProfile(catIdB);
  
  // 规则优先级:
  // 1. 预设分类 > 用户自定义
  // 2. 有子分类的 > 无子分类的
  // 3. 使用次数多的 > 少的
  // 4. 名字短的 > 名字长的（更通用）
  
  if (catA.isPreset && !catB.isPreset) return catIdA;
  if (catB.isPreset && !catA.isPreset) return catIdB;
  if (catA.hasChildren && !catB.hasChildren) return catIdA;
  if (catB.hasChildren && !catA.hasChildren) return catIdB;
  if (profileA.totalCount >= profileB.totalCount) return catIdA;
  return catIdB;
}
```

### 5.4 层级合并策略

> 分类是树形结构（一级→二级），合并时必须处理层级关系。

#### 场景分类

| 场景 | 示例 | 处理方式 |
|------|------|----------|
| **A. 两个叶子（同父）** | 「餐饮」下的「早点」和「早餐」 | 最简单：合并为一个子分类 |
| **B. 两个叶子（不同父）** | 「餐饮→早点」vs「食物→早餐」 | 需要用户选择归属哪个父分类 |
| **C. 两个父分类** | 「餐饮」vs「食物」，各有子分类 | 最复杂：子分类如何归并？ |
| **D. 父 vs 叶子** | 「餐饮」vs「吃饭」（叶子） | 叶子并入父分类（或成为其子分类） |

#### 场景 B：不同父级下的相似子分类

```
合并前:                         合并后（3 种选项）:

餐饮                            选项 1: 合并子分类 + 归入一个父级
├─ 早点                         餐饮
├─ 午餐                         ├─ 早餐 ✓（合并「早点」+「早餐」）
食物                            ├─ 午餐
├─ 早餐                         食物
├─ 零食                         ├─ 零食

                                选项 2: 只移动，不合并子分类
                                餐饮
                                ├─ 早点
                                ├─ 早餐（从「食物」移过来）
                                ├─ 午餐
                                食物
                                ├─ 零食

                                选项 3: 保持不动，只标记为相似
                                （用户选择「暂不处理」）
```

**用户确认 UI（场景 B）：**

```
┌──────────────────────────────────────────┐
│  💡 发现相似子分类                        │
│                                          │
│  「餐饮 → 早点」 与 「食物 → 早餐」       │
│  名称相似度 92%                           │
│                                          │
│  📋 请选择处理方式:                       │
│                                          │
│  ○ 合并为一个分类                         │
│    合并后名称: [早餐  ▼]                  │
│    归入父分类: [餐饮  ▼]                  │
│    (影响 12+8=20 笔交易)                  │
│                                          │
│  ○ 仅移动到同一父分类下（保留两个子分类）   │
│    移动「早餐」到: [餐饮  ▼]              │
│    (不影响交易分类，仅调整归属)            │
│                                          │
│  [暂不处理]              [确认 ✓]         │
└──────────────────────────────────────────┘
```

#### 场景 C：两个父分类合并

```
合并前:                         合并后:

餐饮（32笔）                    餐饮（32+15=47笔）
├─ 早点（8笔）                  ├─ 早点（8笔）← 保留? 与「早餐」合并?
├─ 午餐（12笔）                 ├─ 午餐（12笔）
食物（15笔）                    ├─ 早餐（5笔）← 保留? 与「早点」合并?
├─ 早餐（5笔）                  ├─ 零食（10笔）
├─ 零食（10笔）
```

**父分类合并时的子分类处理流程：**

```dart
/// 父分类合并时的子分类处理策略
enum ChildMergeStrategy {
  /// 所有子分类全部移动到保留的父级下
  moveAll,
  /// 逐一处理：对相似的子分类对询问是否合并
  reviewEach,
}
```

**用户确认 UI（场景 C）：**

```
┌──────────────────────────────────────────────────┐
│  建议合并一级分类                                  │
│                                                  │
│  🍽️「餐饮」(32笔) ←── 合并 ──→ 🥘「食物」(15笔)  │
│                                                  │
│  Step 1: 选择保留哪个一级分类                      │
│  ● 保留「餐饮」，删除「食物」（推荐，使用更多）     │
│  ○ 保留「食物」，删除「餐饮」                      │
│                                                  │
│  Step 2: 处理子分类                               │
│  ┌────────────────────────────────────────────┐  │
│  │ 「食物」的子分类将移入「餐饮」：             │  │
│  │                                            │  │
│  │  「早餐」→ ⚠️ 与「早点」相似               │  │
│  │     ○ 合并为「早餐」                       │  │
│  │     ○ 合并为「早点」                       │  │
│  │     ● 保留两个（都放在「餐饮」下）          │  │
│  │                                            │  │
│  │  「零食」→ ✅ 无冲突，直接移入              │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  [暂不处理]                     [确认合并 ✓]      │
└──────────────────────────────────────────────────┘
```

#### 场景 D：父分类 vs 叶子分类

```
「餐饮」(一级，有子分类) vs 「吃饭」(一级，无子分类)

选项:
● 将「吃饭」的交易归入「餐饮」（吃饭删除）
○ 将「吃饭」变为「餐饮」的子分类（保留为二级）
```

#### 层级合并的检测逻辑

> ⚠️ **两阶段筛选策略**：避免 O(n²) 全量 NLEmbedding 调用
>
> Pass 1: 纯 Dart TextSimilarity 快速筛选（< 1ms/pair），只有 `textSim >= 0.4` 的对进入 Pass 2
> Pass 2: 对候选对调用完整 scorer（含 NLEmbedding），最多 200 对

```dart
class CategoryMergeDetector {
  /// 扫描上限：进入详细评分的最大候选对数
  static const _maxDetailedPairs = 200;

  Future<List<MergeSuggestion>> scan(List<CategoryEntity> categories) async {
    final suggestions = <MergeSuggestion>[];
    
    // 按层级分组
    final parents = categories.where((c) => c.parentId == null).toList();
    final children = categories.where((c) => c.parentId != null).toList();
    
    // === Pass 1: TextSimilarity 快速筛选 ===
    final candidates = <_CandidatePair>[];
    
    // 1. 父分类间
    for (var i = 0; i < parents.length; i++) {
      for (var j = i + 1; j < parents.length; j++) {
        if (parents[i].type != parents[j].type) continue; // 不同类型跳过
        final textSim = TextSimilarityScorer.score(parents[i].name, parents[j].name);
        if (textSim >= 0.4) {
          candidates.add(_CandidatePair(parents[i], parents[j], textSim, PairType.parent));
        }
      }
    }
    
    // 2. 不同父级下子分类间
    final childrenByParent = groupBy(children, (c) => c.parentId!);
    final parentIds = childrenByParent.keys.toList();
    for (var i = 0; i < parentIds.length; i++) {
      for (var j = i + 1; j < parentIds.length; j++) {
        final groupA = childrenByParent[parentIds[i]]!;
        final groupB = childrenByParent[parentIds[j]]!;
        for (final a in groupA) {
          for (final b in groupB) {
            if (a.type != b.type) continue;
            final textSim = TextSimilarityScorer.score(a.name, b.name);
            if (textSim >= 0.4) {
              candidates.add(_CandidatePair(a, b, textSim, PairType.crossParent));
            }
          }
        }
      }
    }
    
    // 3. 同一父级下子分类间
    for (final group in childrenByParent.values) {
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          if (group[i].type != group[j].type) continue;
          final textSim = TextSimilarityScorer.score(group[i].name, group[j].name);
          if (textSim >= 0.4) {
            candidates.add(_CandidatePair(group[i], group[j], textSim, PairType.sameParent));
          }
        }
      }
    }
    
    // 按 textSim 降序，截取前 _maxDetailedPairs 对
    candidates.sort((a, b) => b.textSim.compareTo(a.textSim));
    final topCandidates = candidates.take(_maxDetailedPairs);
    
    // === Pass 2: 完整评分（含 NLEmbedding + Behavior + Keyword） ===
    // 批量调用 NLEmbedding（一次 batchDistances，减少 channel round-trip）
    final words = topCandidates
        .expand((p) => [p.catA.name, p.catB.name])
        .toSet().toList();
    final semanticDistances = await NLEmbeddingBridge.batchDistances(words);
    
    for (final pair in topCandidates) {
      // 过滤规则
      if (_isDismissed(pair.catA.id, pair.catB.id)) continue;
      if (_isPresetPair(pair.catA, pair.catB)) continue;
      if (_isParentChild(pair.catA, pair.catB)) continue;
      
      final confidence = _computeFullConfidence(
        pair, semanticDistances,
      );
      if (confidence >= 0.6) {
        suggestions.add(_buildSuggestion(pair, confidence, children));
      }
    }
    
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return suggestions;
  }
}
```

#### 建议类型体系

```dart
/// 合并建议基类
sealed class MergeSuggestion {
  final CategoryEntity categoryA;
  final CategoryEntity categoryB;
  final double confidence;
}

/// 同一父级下的子分类合并（最简单）
class SameParentChildMergeSuggestion extends MergeSuggestion { }

/// 不同父级下的子分类合并（需选择归属）
class CrossParentChildMergeSuggestion extends MergeSuggestion {
  final CategoryEntity parentA;
  final CategoryEntity parentB;
}

/// 父分类合并（最复杂，可能有子分类冲突）
class ParentMergeSuggestion extends MergeSuggestion {
  final List<ChildConflict> childConflicts; // 相似的子分类对
}

/// 子分类冲突项
class ChildConflict {
  final CategoryEntity childA;
  final CategoryEntity childB;
  final double similarity;
}
```

#### 合并执行：按场景分发

```dart
Future<MergeResult> executeMerge(MergeDecision decision) async {
  return switch (decision) {
    SimpleMergeDecision d => _executeSimpleMerge(d),
    CrossParentMergeDecision d => _executeCrossParentMerge(d),
    ParentMergeDecision d => _executeParentMerge(d),
    MoveOnlyDecision d => _executeMoveOnly(d),
  };
}

/// 场景 B 选项 2: 只移动不合并
Future<MergeResult> _executeMoveOnly(MoveOnlyDecision d) async {
  return _db.transaction(() async {
    // 只修改 parentId，不动交易
    await _updateCategoryParent(
      categoryId: d.categoryToMove,
      newParentId: d.targetParentId,
    );
    await _insertMoveLog(d);
    await _enqueueSyncOp(MoveCategoryOp(...));
    return MergeResult(affectedTransactions: 0, type: MergeType.moveOnly);
  });
}

/// 场景 C: 父分类合并（含子分类处理）
Future<MergeResult> _executeParentMerge(ParentMergeDecision d) async {
  return _db.transaction(() async {
    int totalAffected = 0;
    
    // 1. 处理子分类冲突（用户已决定的）
    for (final childDecision in d.childDecisions) {
      switch (childDecision) {
        case ChildMergeDecision cm:
          // 合并相似子分类
          totalAffected += await _remapTransactions(
            from: cm.sourceChildId, to: cm.targetChildId);
          await _softDeleteCategory(cm.sourceChildId);
        case ChildKeepBothDecision kb:
          // 保留两个，但移动到保留的父分类下
          await _updateCategoryParent(
            categoryId: kb.childToMove, newParentId: d.retainParentId);
        case ChildMoveDecision mv:
          // 无冲突子分类，直接移入
          await _updateCategoryParent(
            categoryId: mv.childId, newParentId: d.retainParentId);
      }
    }
    
    // 2. 被删父分类的直属交易归入保留方
    totalAffected += await _remapTransactions(
      from: d.sourceParentId, to: d.retainParentId);
    
    // 3. 软删除源父分类
    await _softDeleteCategory(d.sourceParentId);
    
    // 4. 日志 + 同步
    await _insertMergeLog(...);
    await _enqueueSyncOp(...);
    
    return MergeResult(affectedTransactions: totalAffected, type: MergeType.parentMerge);
  });
}
```

---

### 5.5 合并执行逻辑（简单场景）

#### 执行步骤（事务性）

```dart
Future<MergeResult> executeMerge({
  required String sourceCategoryId,  // 被删除的分类
  required String targetCategoryId,  // 保留的分类
}) async {
  return _db.transaction(() async {
    // 1. 记录合并日志（用于撤销）
    await _insertMergeLog(sourceCategoryId, targetCategoryId);
    
    // 2. 重映射所有交易的 categoryId
    final affected = await _remapTransactions(
      from: sourceCategoryId, 
      to: targetCategoryId,
    );
    
    // 3. 如果 source 有子分类，移动到 target 下
    await _reparentChildren(sourceCategoryId, targetCategoryId);
    
    // 4. 合并使用统计
    await _mergeUsageStats(sourceCategoryId, targetCategoryId);
    
    // 5. 更新预算引用（避免预算规则指向已删除分类）
    await _remapBudgetCategories(
      from: sourceCategoryId, to: targetCategoryId);
    
    // 6. 软删除源分类
    await _softDeleteCategory(sourceCategoryId);
    
    // 6. 生成同步操作（通知服务端）
    await _enqueueSyncOp(MergeCategoryOp(
      sourceId: sourceCategoryId,
      targetId: targetCategoryId,
    ));
    
    return MergeResult(
      affectedTransactions: affected,
      sourceCategory: sourceCategoryId,
      targetCategory: targetCategoryId,
    );
  });
}
```

#### 合并日志表（支持撤销）

```sql
CREATE TABLE category_merge_log (
  id TEXT PRIMARY KEY,
  source_category_id TEXT NOT NULL,
  target_category_id TEXT NOT NULL,
  source_category_name TEXT NOT NULL,  -- 留存名字用于撤销重建
  source_icon_key TEXT,
  source_parent_id TEXT,
  affected_count INTEGER NOT NULL DEFAULT 0,  -- 受影响交易数量
  merge_type TEXT NOT NULL DEFAULT 'simple',  -- simple/crossParent/parentMerge/moveOnly
  merged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  undone_at DATETIME,                    -- 非空=已撤销
  expires_at DATETIME NOT NULL           -- merged_at + 7 days
);
```

> ℹ️ **不存储受影响的交易 ID 列表**（避免单行存储数百个 UUID）。改为给 `transactions` 表加 `merge_log_id` 字段：

```sql
-- 在 transactions 表新增字段
ALTER TABLE transactions ADD COLUMN merge_log_id TEXT;
```

合并执行时，重映射交易的同时标记 `merge_log_id`：
```sql
UPDATE transactions 
SET category_id = ?, merge_log_id = ? 
WHERE category_id = ? AND deleted_at IS NULL;
```

撤销时：
```sql
UPDATE transactions 
SET category_id = ?, merge_log_id = NULL 
WHERE merge_log_id = ?;
```

这样撤销时只需 `WHERE merge_log_id = ?`，无需存储巨大的 ID 列表。

#### 撤销机制

```dart
Future<void> undoMerge(String mergeLogId) async {
  final log = await _getMergeLog(mergeLogId);
  if (log == null || log.undoneAt != null) throw AlreadyUndoneException();
  if (DateTime.now().isAfter(log.expiresAt)) throw UndoExpiredException();
  
  await _db.transaction(() async {
    // 1. 恢复源分类
    await _restoreCategory(log);
    
    // 2. 恢复交易的 categoryId
    await _remapTransactions(
      from: log.targetCategoryId,
      to: log.sourceCategoryId,
      onlyIds: log.affectedTransactionIds, // 只恢复原来属于 source 的
    );
    
    // 3. 重建使用统计
    await _rebuildUsageStats(log.sourceCategoryId);
    await _rebuildUsageStats(log.targetCategoryId);
    
    // 4. 标记日志为已撤销
    await _markUndone(mergeLogId);
    
    // 5. 同步
    await _enqueueSyncOp(UndoMergeCategoryOp(...));
  });
}
```

### 5.6 合并建议的生命周期

```
┌─────────┐    用户自定义分类 ≥ 5 个     ┌──────────┐
│  Idle   │ ────────────────────────▶ │ Scanning │
└─────────┘                           └────┬─────┘
                                           │ 发现 confidence ≥ 0.6 的对
                                           ▼
                                     ┌──────────┐
                                     │ Pending  │ ← 等待用户查看
                                     └────┬─────┘
                                    ┌─────┼─────────┐
                                    │     │         │
                               确认合并  暂不处理   跳过
                                    │     │         │
                                    ▼     ▼         │
                              ┌────────┐ ┌────────┐ │
                              │Executed│ │Dismissed│ │
                              └───┬────┘ └────────┘ │
                                  │                  │
                            7天内可撤销         下次扫描仍出现
                                  │
                                  ▼
                            ┌──────────┐
                            │ Finalized│ ← 超过 7 天，清理日志
                            └──────────┘
```

### 5.7 建议生成触发时机

| 触发 | 条件 |
|------|------|
| 用户进入分类管理页 | 后台扫描，有结果时显示 Banner |
| 每周一次后台刷新 | 统计数据更新后重新扫描 |
| 用户创建新分类时 | 与现有分类即时比对，如果高度相似立刻提示 |
| CSV 导入后 | 导入可能创建大量新分类，导入完成后自动扫描 |

### 5.8 「创建时即时提示」特殊场景

> ⚠️ 创建时即时检测**只用 TextSimilarity**（纯 Dart, <1ms），不走 NLEmbedding 和 BehaviorOverlap。
> 原因：新分类没有使用数据，行为层无意义；且创建流程不能等 30+ 次平台通道调用。

用户在分类管理页创建新分类「打的」→ 与现有「打车」高度相似：

```
┌──────────────────────────────────────┐
│  💡 发现相似分类                      │
│                                      │
│  你创建的 "打的" 与已有分类 "打车"    │
│  非常相似。                           │
│                                      │
│  [仍然创建]    [使用 "打车"]          │
└──────────────────────────────────────┘
```

这个提示在创建确认前弹出，避免重复分类从一开始就产生。

---

---

## 六、iOS 平台通道：NLEmbedding

### 6.1 架构

```
Dart (CategoryMergeDetector)
  │
  │ MethodChannel('familyledger/nl_embedding')
  ▼
Swift (NLEmbeddingPlugin)
  │
  │ NaturalLanguage.framework
  ▼
iOS System Word Embeddings (SimplifiedChinese)
```

### 6.2 Dart 侧接口

```dart
/// 平台通道桥接层 — 封装 iOS NLEmbedding
class NLEmbeddingBridge {
  static const _channel = MethodChannel('familyledger/nl_embedding');
  
  /// 检查平台是否支持语义嵌入
  static Future<bool> get isAvailable async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }
  
  /// 计算两个词的语义距离
  /// 返回 0~2 (0=相同, 2=无关)，平台不支持时返回 null
  static Future<double?> distance(String word1, String word2) async {
    try {
      return await _channel.invokeMethod<double>('distance', {
        'word1': word1,
        'word2': word2,
      });
    } catch (_) {
      return null;
    }
  }
  
  /// 批量计算：给定一组词，返回所有 pair 的距离
  /// key 格式: "word1|word2"(字典序排列，确保唯一性)
  static Future<Map<String, double>?> batchDistances(
    List<String> words,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map>('batchDistances', {
        'words': words,
      });
      return result?.cast<String, double>();
    } catch (_) {
      return null;
    }
  }
}
```

### 6.3 Swift 侧实现

```swift
import Flutter
import NaturalLanguage

public class NLEmbeddingPlugin: NSObject, FlutterPlugin {
    private let embedding: NLEmbedding?
    
    override init() {
        self.embedding = NLEmbedding.wordEmbedding(for: .simplifiedChinese)
        super.init()
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "familyledger/nl_embedding",
            binaryMessenger: registrar.messenger()
        )
        let instance = NLEmbeddingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(embedding != nil)
            
        case "distance":
            guard let args = call.arguments as? [String: String],
                  let w1 = args["word1"],
                  let w2 = args["word2"],
                  let emb = embedding else {
                result(nil)
                return
            }
            let dist = emb.distance(between: w1, and: w2)
            result(dist.isNaN ? nil : dist)
            
        case "batchDistances":
            guard let args = call.arguments as? [String: Any],
                  let words = args["words"] as? [String],
                  let emb = embedding else {
                result(nil)
                return
            }
            var distances: [String: Double] = [:]
            for i in 0..<words.count {
                for j in (i+1)..<words.count {
                    // key 格式: "word1|word2"(字典序，保证唯一性）
                    let pair = [words[i], words[j]].sorted()
                    let key = "\(pair[0])|\(pair[1])"
                    let dist = emb.distance(between: words[i], and: words[j])
                    distances[key] = dist.isNaN ? 2.0 : dist
                }
            }
            result(distances)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

### 6.4 Android 降级策略

```dart
/// Android 上 NLEmbeddingBridge.isAvailable = false
/// CategoryMergeDetector 自动跳过 SemanticScorer，权重重分配给 TextSimilarity

class CategoryMergeDetector {
  Future<List<MergeSuggestion>> scan(List<CategoryEntity> categories) async {
    final useSemantics = await NLEmbeddingBridge.isAvailable;
    
    // 动态权重
    final weights = useSemantics
        ? MergeWeights(text: 0.35, semantic: 0.30, behavior: 0.20, keyword: 0.15)
        : MergeWeights(text: 0.50, semantic: 0.00, behavior: 0.30, keyword: 0.20);
    
    // ...评分逻辑
  }
}
```

---

## 七、服务端同步

### 7.1 新增 Proto 定义

```protobuf
// transaction.proto 新增
message MergeCategoriesRequest {
  string source_category_id = 1;  // 被合并（删除）的
  string target_category_id = 2;  // 保留的
}

message MergeCategoriesResponse {
  int32 affected_transactions = 1;
}

// 在 TransactionService 中新增 RPC
rpc MergeCategories(MergeCategoriesRequest) returns (MergeCategoriesResponse);
```

### 7.2 服务端处理

```go
func (s *TransactionService) MergeCategories(ctx context.Context, req *pb.MergeCategoriesRequest) (*pb.MergeCategoriesResponse, error) {
    userID := auth.UserIDFromContext(ctx)
    
    // 事务内执行:
    // 1. 验证两个分类都属于该用户
    // 2. UPDATE transactions SET category_id = target WHERE category_id = source AND user_id = ?
    // 3. UPDATE categories SET deleted_at = NOW() WHERE id = source
    // 4. 记录合并日志
    // 5. 广播 WebSocket 通知其他设备
}
```

### 7.3 同步流程

```
客户端确认合并 → 本地事务执行 → 入 sync_queue → SyncEngine 推送
                                                        ↓
其他设备 ← WebSocket 通知 ← 服务端执行 + 广播
                                                        ↓
                                              拉取最新分类列表 + 交易更新
```

---

## 八、实施计划

> ⚠️ **实施顺序：先做分类整理（合并），后做智能推荐。** 两者共享统计基础设施。

### 总览

| Sprint | 周期 | 产出 |
|--------|------|------|
| S1 | 2天 | 统计基础设施 + 合并检测算法 |
| S2 | 2天 | 合并确认 UI + 执行逻辑 + 撤销 |
| S3 | 1.5天 | iOS NLEmbedding 平台通道 |
| S4 | 1天 | 服务端同步 + 创建时即时提示 |
| S5（后续） | 3天 | 智能推荐功能（基于已有统计层） |

### S1：统计基础 + 合并检测算法（2天）

| Day | 任务 | 产出物 |
|-----|------|--------|
| D1 | Drift 新表 `category_usage_stats` + `category_merge_log` + `category_merge_dismissals` + Migration v23 | 表定义 + 迁移脚本 |
| D1 | `CategoryUsageProfiler` 服务（从 transactions 聚合） | 全量重建 + 增量更新 |
| D2 | `TextSimilarityScorer` + `BehaviorOverlapScorer` + `KeywordOverlapScorer` | 合并检测算法 |
| D2 | `CategoryMergeDetector` 编排器 + 过滤规则 + 单元测试 | 扫描逻辑（15 tests pass） |

### S2：合并确认 UI + 执行逻辑（2天）

| Day | 任务 | 产出物 |
|-----|------|--------|
| D3 | `CategoryMergeExecutor` 执行服务（事务性合并 + 撤销） | 合并/撤销引擎 |
| D3 | `categoryMergeSuggestProvider` Riverpod 接入 | Provider 层 |
| D4 | `CategoryCleanupPage` UI（卡片式逐条确认 + 层级合并选项） | 完整确认交互 |
| D4 | 入口嵌入（分类管理页 Banner + 概览页 Reminders 卡片） | 全流程贯通 |

### S3：iOS NLEmbedding（1.5天）

| Day | 任务 | 产出物 |
|-----|------|--------|
| D5 | Swift Plugin 实现 + Flutter MethodChannel 注册 | 平台通道 |
| D5半 | `SemanticScorer` 集成 + Android 降级 + 测试 | 语义层上线 |

### S4：服务端同步 + 即时提示（1天）

| Day | 任务 | 产出物 |
|-----|------|--------|
| D6 | Proto 定义 + Go 服务端 `MergeCategories` RPC | 服务端实现 |
| D6 | SyncEngine 集成 + WebSocket 广播 | 多设备同步 |
| D6 | 创建分类时即时相似检测提示 | 防重复 |

### S5：智能推荐（后续迭代，3天）

| Day | 任务 | 产出物 |
|-----|------|--------|
| D7 | 6 个 Scorer 实现 + `CategoryRecommender` | 纯算法层，单元测试覆盖 |
| D7 | `categoryRecommendProvider` Riverpod 接入 | Provider + 响应式更新 |
| D8 | `QuickCategorySelector` 改造（推荐排序） | UI 集成 + 视觉微调 |
| D8 | 冷启动策略 + 集成测试 | 端到端验证 |

---

## 九、测试策略

### 单元测试

| 模块 | 测试重点 |
|------|----------|
| TimeSlotScorer | 午餐时段推荐餐饮分数最高 |
| AmountRangeScorer | 35元匹配餐饮 > 交通 |
| TextSimilarityScorer | "点外卖" vs "外卖" → 0.85+ |
| BehaviorOverlapScorer | 相同时段+金额分布 → 高重叠度 |
| CategoryMergeExecutor | 合并后交易 categoryId 正确重映射 |
| UndoMerge | 撤销后数据完全恢复 |

### 集成测试

| 场景 | 验证点 |
|------|--------|
| 新用户冷启动 | 推荐不 crash，显示预设分类 |
| 100笔交易后 | 推荐结果与实际习惯匹配 |
| 合并后立即测试 | 旧分类不再出现在推荐/网格中 |
| 撤销后 | 两个分类都恢复正常 |
| Android 无语义层 | 合并建议仍然能工作（靠 text+behavior） |
| 多设备同步 | A 设备合并 → B 设备分类列表更新 |

---

## 十、风险与决策点

| 风险 | 等级 | 应对 |
|------|------|------|
| NLEmbedding 对 2 字短词效果不稳定 | 中 | TextSimilarity 作为主信号，语义层只是加分项 |
| 用户误合并后才发现 | 中 | 7天撤销窗口 + 合并后 Toast 带「撤销」按钮 |
| 统计刷新开销大 | 低 | 增量更新为主，全量重建只在首次启动/导入后 |
| 服务端无 MergeCategories RPC | 低 | 客户端先本地执行，同步失败时进死信队列 |
| 合并导致预算规则引用旧 categoryId | 中 | 合并执行时同步更新 budget_categories 表 |

---

## 十一、未来扩展

| 方向 | 说明 | 优先级 |
|------|------|--------|
| 语音记账 NLP 分类 | 语音输入“午饭35”→ KeywordScorer 匹配分类 | P2 |
| 学习用户修正 | 用户手动改分类后增强对应信号 | P1 |
| 分类合并批量模式 | 一键应用所有建议（高级用户） | P3 |
| 商户名称识别 | 从备注中提取商户，建立商户→分类映射 | P2 |
| 分类健康度报告 | 定期生成：未使用分类、重复分类、建议简化 | P3 |

---

> 🎯 **实施顺序：** 先分类整理（S1→S4），后智能推荐（S5）。两者共享 `CategoryUsageProfiler` 统计基础设施。
