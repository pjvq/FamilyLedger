# FamilyLedger 前端审计报告

**审计日期**: 2026-04-27  
**代码统计**: ~56,600 行 Dart（非生成代码），92 个源文件，16 个 test 文件  
**技术栈**: Flutter 3.41 + Riverpod (StateNotifier) + Drift (SQLite) + gRPC + WebSocket  
**测试**: 535 tests 全绿（~12s）

---

## 1. 整体评估

### 实际测试能力

| 维度 | 评分 | 说明 |
|------|------|------|
| UI 渲染正确性 | ⭐⭐⭐⭐ | Widget 测试覆盖面广，验证了组件渲染、主题、动画 |
| 业务逻辑正确性 | ⭐⭐ | Fake Notifier 用 `noSuchMethod` 兜底，大部分 Provider 方法未被真正调用和验证 |
| 同步引擎 | ⭐⭐⭐ | LWW 冲突解决有 8 个测试，但缺少完整 sync 流程测试 |
| 错误处理 | ⭐ | 几乎没有 gRPC 错误码处理的测试 |
| 集成测试 | ⭐⭐⭐ | 79 个 Integration E2E（需模拟器），但日常开发难以频繁运行 |
| 性能 | ⭐⭐⭐ | VirtualList 6 个性能测试，1100 条 21ms |

### 总结

**表面数字好看（535 tests），但测试深度不够**。大量 Widget 测试验证的是「组件能渲染出来」，而非「业务逻辑正确」。核心的 Provider 业务逻辑（记账、同步、家庭权限）缺乏单元级别的验证。

---

## 2. 架构分析

```
┌─────────────────────────────────────────────────┐
│            features/ (14 个功能模块 UI)            │  ← Widget 测试覆盖 ✅
├─────────────────────────────────────────────────┤
│          domain/providers/ (21 个 Provider)       │  ← 测试严重不足 ❌
├──────────────────┬──────────────────────────────┤
│  data/local/     │    data/remote/              │
│  Drift (SQLite)  │    gRPC Clients              │  ← 无 mock/stub 测试 ❌
├──────────────────┴──────────────────────────────┤
│              sync/ (SyncEngine)                   │  ← 仅 LWW 有测试 ⚠️
└─────────────────────────────────────────────────┘
```

### 问题：测试金字塔倒置

正常应该是：大量单元测试（Provider 逻辑） > 少量 Widget 测试（UI）> 更少的集成测试。

实际是：大量 Widget 测试（UI 渲染）> 极少的 Provider 单元测试 > 集成测试仅在模拟器上跑。

---

## 3. 逐层问题清单

### 3.1 Provider 层 — 核心问题

**21 个 Provider 中，只有 3 个有独立单元测试**：

| Provider | 有独立测试 | 测试方式 | 问题 |
|----------|-----------|---------|------|
| `transaction_provider` | ✅ 部分 | `transaction_add_no_flicker_test` (3 tests) + `transaction_provider_load_test` (6 tests) | 只测了 addTransaction 和 loadMore，其余方法（update/delete/filter）无测试 |
| `sync_engine` | ✅ 部分 | `sync_engine_lww_test` (8 tests) | 只测了 LWW 冲突解决，缺少 `sync()` 完整流程、重试、队列管理 |
| 其余 19 个 | ❌ | 仅通过 Widget 测试间接覆盖 | Fake 用 `noSuchMethod` 兜底，方法调用不会报错也不验证结果 |

**严重缺失**：
- `export_provider` — 零测试覆盖
- `family_provider` — 无权限判断测试
- `loan_provider` — 还款计划计算逻辑无前端验证
- `dashboard_provider` — 数据聚合逻辑无验证
- `exchange_rate_provider` — 汇率计算无精度测试

### 3.2 Widget 测试 — 数量多但深度浅

**486 个 testWidgets，大部分测试模式**：

```dart
testWidgets('renders title', (tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [someProvider.overrideWithValue(FakeNotifier())],
    child: MaterialApp(home: SomePage()),
  ));
  expect(find.text('标题'), findsOneWidget);  // 只验证渲染
});
```

**问题**：
1. `FakeNotifier` 所有方法都用 `noSuchMethod` 兜底，调用任何方法都返回 `Future.value()`，不会抛异常
2. Widget 测试 **不验证 Provider 方法是否被正确调用**
3. 不验证 **参数是否正确传递**（如 familyId、pageToken）
4. 不验证 **状态变更后 UI 是否更新**（缺少 pump 后再验证）

**好的测试**（少数）：
- `core_widgets_test.dart` — 113 个测试，验证了动画、主题切换、语义化标签
- `sync_engine_lww_test.dart` — 用真实 Drift database 测试冲突解决

### 3.3 数据层

**database_test.dart (13 tests)** — 测试了 Drift 查询逻辑，是好的：
- 插入、查询、过滤
- 不同 familyId 的数据隔离

**缺失**：
- 无 schema migration 测试（v1→v2→...→v12 升级链）
- 无 gRPC client 超时/重试测试
- 无网络中断恢复测试

### 3.4 SyncEngine — 最关键的模块

**已测试** (8 tests)：
- LWW：remote newer → apply, local newer → skip
- DELETE 终态：始终应用
- Account/Category 同步

**未测试**：
- `sync()` 完整流程（push pending ops → pull remote → apply）
- 重试机制（push 失败后是否保留队列）
- 分页拉取（pageToken 循环）
- 网络中断恢复
- 并发安全（多次 sync() 重入）
- 离线时间过长导致 token 过期

---

## 4. 优先修复清单

### P0 — 必须补充

| # | 缺失 | 风险 | 建议 |
|---|------|------|------|
| 1 | SyncEngine.sync() 完整流程测试 | 数据丢失 | 用真实 Drift DB + mock gRPC，测 push→pull→apply 全链路 |
| 2 | TransactionProvider 全方法单元测试 | 记账错误 | mock Database + mock gRPC client，验证 CRUD + 余额计算 |
| 3 | 离线队列入队/出队/持久化测试 | 离线记账丢失 | 测 enqueue → kill app → restart → dequeue |
| 4 | gRPC 错误码处理测试 | 用户看到白屏 | 测 Unauthenticated/Unavailable/DeadlineExceeded 各种码 |

### P1 — 应该补充

| # | 缺失 | 风险 | 建议 |
|---|------|------|------|
| 5 | 家庭权限前端判断 | 越权操作 | 测 canEdit=false 时 UI 禁用 + Provider 拒绝 |
| 6 | LoanProvider 还款计划计算 | 计算错误 | 表驱动测试，对比 Excel 结果 |
| 7 | Schema migration 链测试 | 升级崩溃 | 测 v1→v12 逐步升级，数据完整 |
| 8 | DashboardProvider 聚合逻辑 | 数据错误 | mock 数据，验证净资产/分类汇总 |

### P2 — 建议补充

| # | 缺失 | 说明 |
|---|------|------|
| 9 | export_provider 测试 | 导出格式正确性 |
| 10 | 多币种计算精度 | 浮点数陷阱 |
| 11 | Widget 测试改用 verify 模式 | 用 Mockito verify 替代 Fake，验证方法调用 |
| 12 | 分页加载边界 | maxPages=200 保护 + 空页停止 |

---

## 5. Fake Notifier 问题详解

当前所有 Widget 测试使用的 `test_helpers.dart` 中：

```dart
class FakeTransactionNotifier extends StateNotifier<TransactionState>
    implements TransactionNotifier {
  FakeTransactionNotifier([TransactionState? s])
      : super(s ?? const TransactionState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}
```

**问题**：
- 调用 `addTransaction(amount: 100, category: '餐饮')` → 返回 `Future.value()` → 成功
- 调用 `deleteTransaction(id: 'xxx')` → 返回 `Future.value()` → 成功
- **传什么参数都一样成功，无法发现 bug**

**改进方案**：用 `mockito` 或 `mocktail`：

```dart
class MockTransactionNotifier extends Mock implements TransactionNotifier {}

// 测试中：
final mock = MockTransactionNotifier();
when(() => mock.addTransaction(any())).thenAnswer((_) async => txn);
// ... 操作 UI ...
verify(() => mock.addTransaction(
  captureAny(that: isA<AddTransactionParams>()
    .having((p) => p.amount, 'amount', 100)
    .having((p) => p.categoryId, 'categoryId', 'food_id')
  ),
)).called(1);
```

---

## 6. 好的部分（值得保留）

1. **core_widgets_test.dart (113 tests)** — 组件测试模范，验证了动画、可访问性、主题
2. **sync_engine_lww_test.dart** — 用真实 Drift DB 测试，验证了关键冲突逻辑
3. **transaction_add_no_flicker_test.dart** — 测试了 Server-first 策略的三种路径
4. **perf_virtual_list_test.dart** — 性能基准测试，有明确的指标（<50ms）
5. **database_test.dart** — 测试了 Drift 查询和数据隔离
6. **import_categories_test.dart (12 tests)** — 测试了分类模糊匹配逻辑

---

## 7. 代码质量指标

| 指标 | 数值 | 评价 |
|------|------|------|
| 源文件数 | 92 | 合理 |
| 测试文件数 | 16 | 偏少（应 ≥ 30） |
| 测试/源码比 | 11,479 / 56,600 = 20% | 偏低（健康值 40-60%） |
| Provider 测试覆盖 | 3/21 = 14% | **严重不足** |
| Widget 测试 | 486 个 | 数量多但深度浅 |
| 业务逻辑测试 | ~30 个 | **极度不足** |
| 集成测试 | 79 个 | 好，但需模拟器 |

---

## 8. 结论

**表面完成度高，实质测试深度不够。** 535 个测试中：

- ~486 个是 Widget 渲染测试（验证「能画出来」）
- ~30 个是业务逻辑测试（验证「算对了」）
- ~19 个是数据/同步测试（验证「存对了」）

核心风险：**Provider 层的业务逻辑基本没有独立测试覆盖**。一旦 Provider 代码改动引入 bug，Widget 测试因为 Fake `noSuchMethod` 全部静默通过，无法发现问题。

最紧迫的是补充 SyncEngine 完整流程测试和 TransactionProvider 单元测试——这两个是整个 App 的数据基座。
