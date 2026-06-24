import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/services/smart_category/category_merge_executor.dart';
import 'package:familyledger/domain/services/smart_category/category_usage_profiler.dart';

void main() {
  late AppDatabase db;
  late CategoryMergeExecutor executor;
  late CategoryUsageProfiler profiler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profiler = CategoryUsageProfiler(db);
    executor = CategoryMergeExecutor(db: db, profiler: profiler);
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper: insert a category directly
  Future<void> insertCategory({
    required String id,
    required String name,
    String type = 'expense',
    String? parentId,
    bool isPreset = false,
  }) async {
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            type: type,
            parentId: Value(parentId),
            isPreset: Value(isPreset),
          ),
        );
  }

  /// Helper: insert a transaction
  Future<void> insertTransaction({
    required String id,
    required String categoryId,
    String userId = 'user1',
    String accountId = 'acc1',
    int amount = 1000,
  }) async {
    // Need user + account first
    await db.customInsert(
      "INSERT OR IGNORE INTO users (id, email) VALUES (?, ?)",
      variables: [
        Variable.withString(userId),
        Variable.withString('test@test.com'),
      ],
    );
    await db.customInsert(
      "INSERT OR IGNORE INTO accounts (id, user_id, name, account_type, balance, currency) VALUES (?, ?, ?, ?, ?, ?)",
      variables: [
        Variable.withString(accountId),
        Variable.withString(userId),
        Variable.withString('TestAccount'),
        Variable.withString('cash'),
        Variable.withInt(0),
        Variable.withString('CNY'),
      ],
    );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: id,
            userId: userId,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            amountCny: amount,
            type: 'expense',
            txnDate: DateTime(2026, 5, 1),
          ),
        );
  }

  group('CategoryMergeExecutor — executeMerge', () {
    test('简单合并：交易重映射 + 源分类软删除', () async {
      await insertCategory(id: 'cat-food', name: '餐饮');
      await insertCategory(id: 'cat-takeaway', name: '点外卖');
      await insertTransaction(id: 'tx1', categoryId: 'cat-takeaway');
      await insertTransaction(id: 'tx2', categoryId: 'cat-takeaway');
      await insertTransaction(id: 'tx3', categoryId: 'cat-food');

      final result = await executor.executeMerge(
        sourceCategoryId: 'cat-takeaway',
        targetCategoryId: 'cat-food',
      );

      expect(result.affectedTransactions, 2);
      expect(result.sourceCategoryId, 'cat-takeaway');
      expect(result.targetCategoryId, 'cat-food');

      // 验证交易已重映射
      final txns = await db.select(db.transactions).get();
      for (final txn in txns) {
        expect(txn.categoryId, 'cat-food');
      }

      // 验证源分类已软删除
      final source = await (db.select(
        db.categories,
      )..where((c) => c.id.equals('cat-takeaway'))).getSingleOrNull();
      expect(source!.deletedAt, isNotNull);

      // 验证目标分类仍存在
      final target = await (db.select(
        db.categories,
      )..where((c) => c.id.equals('cat-food'))).getSingleOrNull();
      expect(target!.deletedAt, isNull);
    });

    test('合并后交易带有 mergeLogId 标记', () async {
      await insertCategory(id: 'cat-a', name: 'A');
      await insertCategory(id: 'cat-b', name: 'B');
      await insertTransaction(id: 'tx1', categoryId: 'cat-a');

      final result = await executor.executeMerge(
        sourceCategoryId: 'cat-a',
        targetCategoryId: 'cat-b',
      );

      final txn = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('tx1'))).getSingle();
      expect(txn.mergeLogId, result.mergeLogId);
    });

    test('子分类被移动到 target 下', () async {
      await insertCategory(id: 'cat-food', name: '餐饮');
      await insertCategory(id: 'cat-snack', name: '零食');
      await insertCategory(id: 'cat-child', name: '早点', parentId: 'cat-snack');

      await executor.executeMerge(
        sourceCategoryId: 'cat-snack',
        targetCategoryId: 'cat-food',
      );

      final child = await (db.select(
        db.categories,
      )..where((c) => c.id.equals('cat-child'))).getSingle();
      expect(child.parentId, 'cat-food');
    });

    test('源分类不存在时抛 StateError', () async {
      await insertCategory(id: 'cat-b', name: 'B');

      expect(
        () => executor.executeMerge(
          sourceCategoryId: 'nonexistent',
          targetCategoryId: 'cat-b',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('合并日志正确记录', () async {
      await insertCategory(id: 'cat-a', name: '外卖');
      await insertCategory(id: 'cat-b', name: '餐饮');
      await insertTransaction(id: 'tx1', categoryId: 'cat-a');
      await insertTransaction(id: 'tx2', categoryId: 'cat-a');

      final result = await executor.executeMerge(
        sourceCategoryId: 'cat-a',
        targetCategoryId: 'cat-b',
      );

      final log = await (db.select(
        db.categoryMergeLog,
      )..where((l) => l.id.equals(result.mergeLogId))).getSingle();

      expect(log.sourceCategoryId, 'cat-a');
      expect(log.targetCategoryId, 'cat-b');
      expect(log.sourceCategoryName, '外卖');
      expect(log.affectedCount, 2);
      expect(log.undoneAt, isNull);
      expect(log.expiresAt.isAfter(DateTime.now()), isTrue);
    });
  });

  group('CategoryMergeExecutor — undoMerge', () {
    test('撤销恢复源分类 + 交易 categoryId', () async {
      await insertCategory(id: 'cat-a', name: '外卖');
      await insertCategory(id: 'cat-b', name: '餐饮');
      await insertTransaction(id: 'tx1', categoryId: 'cat-a');
      await insertTransaction(id: 'tx2', categoryId: 'cat-b');

      final result = await executor.executeMerge(
        sourceCategoryId: 'cat-a',
        targetCategoryId: 'cat-b',
      );

      // 撤销
      await executor.undoMerge(result.mergeLogId);

      // 验证源分类恢复
      final source = await (db.select(
        db.categories,
      )..where((c) => c.id.equals('cat-a'))).getSingle();
      expect(source.deletedAt, isNull);

      // 验证 tx1 恢复为 cat-a, tx2 仍为 cat-b
      final tx1 = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('tx1'))).getSingle();
      expect(tx1.categoryId, 'cat-a');
      expect(tx1.mergeLogId, isNull);

      final tx2 = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('tx2'))).getSingle();
      expect(tx2.categoryId, 'cat-b');
    });

    test('已撤销的合并不能再次撤销', () async {
      await insertCategory(id: 'cat-a', name: 'A');
      await insertCategory(id: 'cat-b', name: 'B');
      await insertTransaction(id: 'tx1', categoryId: 'cat-a');

      final result = await executor.executeMerge(
        sourceCategoryId: 'cat-a',
        targetCategoryId: 'cat-b',
      );

      await executor.undoMerge(result.mergeLogId);

      expect(
        () => executor.undoMerge(result.mergeLogId),
        throwsA(isA<AlreadyUndoneException>()),
      );
    });

    test('target 被删除时撤销抛 UndoTargetDeletedException', () async {
      await insertCategory(id: 'cat-a', name: 'A');
      await insertCategory(id: 'cat-b', name: 'B');
      await insertTransaction(id: 'tx1', categoryId: 'cat-a');

      final result = await executor.executeMerge(
        sourceCategoryId: 'cat-a',
        targetCategoryId: 'cat-b',
      );

      // 模拟 target 被删除
      await (db.update(db.categories)..where((c) => c.id.equals('cat-b')))
          .write(CategoriesCompanion(deletedAt: Value(DateTime.now())));

      expect(
        () => executor.undoMerge(result.mergeLogId),
        throwsA(isA<UndoTargetDeletedException>()),
      );
    });
  });

  group('CategoryMergeExecutor — dismissPair', () {
    test('忽略后可查到记录', () async {
      await executor.dismissPair('cat-1', 'cat-2');

      final dismissals = await db.select(db.categoryMergeDismissals).get();
      expect(dismissals, hasLength(1));
      expect(dismissals.first.pairKey, 'cat-1|cat-2');
    });

    test('重复忽略不会创建多行（upsert）', () async {
      await executor.dismissPair('cat-1', 'cat-2');
      await executor.dismissPair('cat-1', 'cat-2');

      final dismissals = await db.select(db.categoryMergeDismissals).get();
      expect(dismissals, hasLength(1));
    });

    test('pairKey 与顺序无关', () async {
      await executor.dismissPair('cat-2', 'cat-1');

      final dismissals = await db.select(db.categoryMergeDismissals).get();
      expect(dismissals.first.pairKey, 'cat-1|cat-2');
    });
  });

  group('CategoryMergeExecutor — getUndoableMergeLogs', () {
    test('只返回未过期未撤销的日志', () async {
      await insertCategory(id: 'cat-a', name: 'A');
      await insertCategory(id: 'cat-b', name: 'B');
      await insertCategory(id: 'cat-c', name: 'C');
      await insertTransaction(id: 'tx1', categoryId: 'cat-a');
      await insertTransaction(id: 'tx2', categoryId: 'cat-c');

      // 执行两次合并
      await executor.executeMerge(
        sourceCategoryId: 'cat-a',
        targetCategoryId: 'cat-b',
      );
      final result2 = await executor.executeMerge(
        sourceCategoryId: 'cat-c',
        targetCategoryId: 'cat-b',
      );

      // 撤销第二次
      await executor.undoMerge(result2.mergeLogId);

      final logs = await executor.getUndoableMergeLogs();
      expect(logs, hasLength(1));
      expect(logs.first.sourceCategoryId, 'cat-a');
    });
  });
}
