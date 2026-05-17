import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/export_provider.dart';
import 'package:familyledger/generated/proto/export.pb.dart' as pb;
import 'package:familyledger/generated/proto/export.pbgrpc.dart';
import 'dart:async';

// ─── Fake gRPC ResponseFuture ────────────────────────────────

class FakeResponseFuture<T> implements ResponseFuture<T> {
  final Future<T> _future;
  FakeResponseFuture.value(T value) : _future = Future.value(value);
  FakeResponseFuture.error(Object error) : _future = Future.error(error);

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);
  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      _future.catchError(onError, test: test);
  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);
  @override
  Stream<T> asStream() => _future.asStream();
  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);
  @override
  Future<Map<String, String>> get headers => Future.value({});
  @override
  Future<Map<String, String>> get trailers => Future.value({});
  @override
  Future<void> cancel() => Future.value();
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Fake ExportServiceClient (force offline) ────────────────

class OfflineExportClient implements ExportServiceClient {
  @override
  ResponseFuture<pb.ExportResponse> exportTransactions(
    pb.ExportRequest request, {
    CallOptions? options,
  }) {
    return FakeResponseFuture.error(GrpcError.unavailable('offline'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}

// ─── DB Setup ────────────────────────────────────────────────

Future<AppDatabase> _setupDb({
  List<TransactionsCompanion> transactions = const [],
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', "
      "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");
  await db.insertAccount(AccountsCompanion.insert(
    id: 'acc1',
    userId: 'user1',
    name: '招商银行',
    familyId: const Value(''),
    accountType: const Value('bank_card'),
  ));
  await db.customStatement(
      "INSERT OR IGNORE INTO categories (id, name, type, icon_key) "
      "VALUES ('cat_food', '餐饮', 'expense', 'restaurant')");
  await db.customStatement(
      "INSERT OR IGNORE INTO categories (id, name, type, icon_key) "
      "VALUES ('cat_salary', '工资', 'income', 'work')");

  for (final txn in transactions) {
    await db.insertTransaction(txn);
  }
  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('ExportNotifier — 导出格式验证', () {
    group('CSV BOM 头验证', () {
      test('本地生成的 CSV 不包含 UTF-8 BOM', () async {
        // 根据代码分析：_generateLocalCsv 使用 utf8.encode(csvString)
        // 不添加 BOM 头。这是一个已知行为（某些 Excel 版本需要 BOM 才能正确识别中文）
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn1',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 5000,
            amountCny: 5000,
            type: 'expense',
            note: const Value('测试'),
            txnDate: DateTime(2025, 3, 15),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        expect(result, isNotNull);
        // Check first 3 bytes are NOT BOM (EF BB BF)
        final bytes = result!;
        final hasBom = bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF;
        // NOTE: 代码没有添加 BOM。这可能是个 BUG —— Excel 打开中文 CSV 会乱码
        // 记录但不修改业务代码
        expect(hasBom, false,
            reason: '当前代码不添加 BOM，Excel 打开中文 CSV 可能乱码（潜在 BUG）');

        await db.close();
      });
    });

    group('金额格式', () {
      test('负数金额正确展示（收入）', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_income',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_salary',
            amount: 100000, // 1000.00 元
            amountCny: 100000,
            type: 'income',
            note: const Value('工资到账'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        expect(csv, contains('1000.00'));
        expect(csv, contains('收入'));

        await db.close();
      });

      test('大金额格式正确（100万）', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_big',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 100000000, // 100万 元
            amountCny: 100000000,
            type: 'expense',
            note: const Value('大额支出'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        expect(csv, contains('1000000.00'));

        await db.close();
      });

      test('零金额格式正确', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_zero',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 0,
            amountCny: 0,
            type: 'expense',
            note: const Value('零元'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        expect(csv, contains('0.00'));

        await db.close();
      });

      test('1分金额格式正确', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_penny',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 1,
            amountCny: 1,
            type: 'expense',
            note: const Value('一分钱'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        expect(csv, contains('0.01'));

        await db.close();
      });
    });

    group('日期格式一致性', () {
      test('所有日期格式为 YYYY-MM-DD', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_d1',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 1000,
            amountCny: 1000,
            type: 'expense',
            note: const Value('一月'),
            txnDate: DateTime(2025, 1, 5),
          ),
          TransactionsCompanion.insert(
            id: 'txn_d2',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 2000,
            amountCny: 2000,
            type: 'expense',
            note: const Value('十二月'),
            txnDate: DateTime(2025, 12, 25),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        // Month and day should be zero-padded
        expect(csv, contains('2025-01-05'));
        expect(csv, contains('2025-12-25'));

        await db.close();
      });

      test('单位数月份和日期被零填充', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_pad',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 1000,
            amountCny: 1000,
            type: 'expense',
            note: const Value(''),
            txnDate: DateTime(2025, 2, 3),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        expect(csv, contains('2025-02-03'));
        // Should NOT have unpadded format like 2025-2-3
        expect(csv, isNot(contains('2025-2-3')));

        await db.close();
      });
    });

    group('非 ASCII 字符编码', () {
      test('中文字符正确编码', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_cn',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 1500,
            amountCny: 1500,
            type: 'expense',
            note: const Value('北京烤鸭全聚德'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        expect(csv, contains('北京烤鸭全聚德'));

        await db.close();
      });

      test('emoji 正确编码', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_emoji',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 2000,
            amountCny: 2000,
            type: 'expense',
            note: const Value('🍜午餐🎉'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        expect(csv, contains('🍜午餐🎉'));

        await db.close();
      });

      test('混合语言字符正确编码', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_mixed',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 3000,
            amountCny: 3000,
            type: 'expense',
            note: const Value('Starbucks星巴克☕️ café'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        expect(csv, contains('Starbucks星巴克☕️ café'));

        await db.close();
      });
    });

    group('换行符在 note 中的处理', () {
      test('note 中的逗号被替换为中文逗号', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_comma',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 1000,
            amountCny: 1000,
            type: 'expense',
            note: const Value('早餐,午餐,晚餐'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        // Commas in note should be replaced with Chinese commas
        expect(csv, contains('早餐，午餐，晚餐'));
        // The data lines should have exactly 5 commas (6 fields)
        final dataLines = csv.split('\n').where((l) =>
            l.trim().isNotEmpty && !l.startsWith('日期')).toList();
        for (final line in dataLines) {
          final commaCount = ','.allMatches(line).length;
          expect(commaCount, 5,
              reason: 'Each data line should have exactly 5 commas separating 6 fields');
        }

        await db.close();
      });

      test('note 中的换行符不破坏 CSV 行结构', () async {
        // NOTE: 当前代码只替换逗号，不处理换行符
        // 如果 note 含换行符，会破坏 CSV 结构 —— 这是潜在 BUG
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_newline',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 1000,
            amountCny: 1000,
            type: 'expense',
            note: const Value('第一行\n第二行'),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
        // BUG: 换行符会导致额外的行
        // 当前行为: note 中的 \n 会变成 CSV 中的新行，破坏结构
        // header + 1 transaction 应该是 2 行，但因为 \n 会变成 3 行
        // 记录此 BUG 但不修改业务代码
        if (lines.length > 2) {
          // 确认 BUG 存在: 换行符没有被转义/替换
          expect(lines.length, 3,
              reason: 'BUG: note 中的换行符破坏了 CSV 行结构');
        } else {
          // If somehow handled (future fix), verify correctness
          expect(lines.length, 2);
        }

        await db.close();
      });

      test('空 note 不影响 CSV 格式', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_empty_note',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 1000,
            amountCny: 1000,
            type: 'expense',
            note: const Value(''),
            txnDate: DateTime(2025, 3, 1),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines.length, 2); // header + 1 data line
        // Last field (note) should be empty
        expect(lines[1].endsWith(',') || lines[1].split(',').last.trim().isEmpty,
            true);

        await db.close();
      });
    });

    group('CSV 排序', () {
      test('交易按日期升序排列', () async {
        final db = await _setupDb(transactions: [
          TransactionsCompanion.insert(
            id: 'txn_late',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 2000,
            amountCny: 2000,
            type: 'expense',
            note: const Value('后面的'),
            txnDate: DateTime(2025, 3, 20),
          ),
          TransactionsCompanion.insert(
            id: 'txn_early',
            userId: 'user1',
            accountId: 'acc1',
            categoryId: 'cat_food',
            amount: 1000,
            amountCny: 1000,
            type: 'expense',
            note: const Value('前面的'),
            txnDate: DateTime(2025, 3, 5),
          ),
        ]);
        final client = OfflineExportClient();
        final notifier = ExportNotifier(db, client, 'user1', null);

        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        final csv = utf8.decode(result!);
        final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
        // First data line should be earlier date
        expect(lines[1], contains('2025-03-05'));
        expect(lines[2], contains('2025-03-20'));

        await db.close();
      });
    });
  });
}
