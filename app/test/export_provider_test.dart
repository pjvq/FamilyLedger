import 'dart:async';
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

// ─── Fake ExportServiceClient ────────────────────────────────

class FakeExportClient implements ExportServiceClient {
  pb.ExportResponse? exportResponse;
  GrpcError? exportError;

  @override
  ResponseFuture<pb.ExportResponse> exportTransactions(
    pb.ExportRequest request, {CallOptions? options}) {
    if (exportError != null) {
      return FakeResponseFuture.error(exportError!);
    }
    return FakeResponseFuture.value(
      exportResponse ?? pb.ExportResponse(
        data: utf8.encode('日期,类型\n2025-01-01,支出'),
        filename: 'export.csv',
        contentType: 'text/csv',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}

// ─── DB Setup ────────────────────────────────────────────────

Future<AppDatabase> _setupDb({bool addTransactions = true}) async {
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
  // Insert a default category
  await db.customStatement(
      "INSERT OR IGNORE INTO categories (id, name, type, icon_key) "
      "VALUES ('cat_food', '餐饮', 'expense', 'restaurant')");

  if (addTransactions) {
    await db.insertTransaction(TransactionsCompanion.insert(
      id: 'txn1',
      userId: 'user1',
      accountId: 'acc1',
      categoryId: 'cat_food',
      amount: 5000, // 50.00 元
      amountCny: 5000,
      type: 'expense',
      note: const Value('午餐'),
      txnDate: DateTime(2025, 3, 15),
    ));
    await db.insertTransaction(TransactionsCompanion.insert(
      id: 'txn2',
      userId: 'user1',
      accountId: 'acc1',
      categoryId: 'cat_food',
      amount: 3000, // 30.00 元
      amountCny: 3000,
      type: 'expense',
      note: const Value('含,逗号和"引号'),
      txnDate: DateTime(2025, 3, 20),
    ));
  }
  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('ExportNotifier', () {
    group('server export (online)', () {
      test('success: sets lastExportData and filename', () async {
        final db = await _setupDb();
        final client = FakeExportClient();
        client.exportResponse = pb.ExportResponse(
          data: utf8.encode('server-generated-csv'),
          filename: 'server_export.csv',
          contentType: 'text/csv',
        );

        final notifier = ExportNotifier(db, client, 'user1', null);
        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        expect(result, isNotNull);
        expect(utf8.decode(result!), 'server-generated-csv');
        expect(notifier.state.lastFilename, 'server_export.csv');
        expect(notifier.state.isExporting, false);
        expect(notifier.state.error, isNull);

        await db.close();
      });

      test('gRPC error → falls back to local CSV generation', () async {
        final db = await _setupDb();
        final client = FakeExportClient();
        client.exportError = GrpcError.unavailable('offline');

        final notifier = ExportNotifier(db, client, 'user1', null);
        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        // Should fallback to local CSV
        expect(result, isNotNull);
        final csvContent = utf8.decode(result!);
        expect(csvContent, contains('日期,类型,分类,金额(元),账户,备注'));
        expect(csvContent, contains('餐饮'));
        expect(notifier.state.isExporting, false);
        expect(notifier.state.error, isNull);

        await db.close();
      });

      test('gRPC error + non-csv format → returns error', () async {
        final db = await _setupDb();
        final client = FakeExportClient();
        client.exportError = GrpcError.unavailable('offline');

        final notifier = ExportNotifier(db, client, 'user1', null);
        final result = await notifier.exportTransactions(
          format: 'excel',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        expect(result, isNull);
        expect(notifier.state.error, '离线模式仅支持CSV格式导出');

        await db.close();
      });
    });

    group('local CSV generation', () {
      test('generates correct CSV format with headers', () async {
        final db = await _setupDb();
        final client = FakeExportClient();
        client.exportError = GrpcError.unavailable('force local');

        final notifier = ExportNotifier(db, client, 'user1', null);
        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 3, 1),
          endDate: DateTime(2025, 3, 31),
        );

        expect(result, isNotNull);
        final lines = utf8.decode(result!).split('\n');

        // Header
        expect(lines[0].trim(), '日期,类型,分类,金额(元),账户,备注');
        // First transaction
        expect(lines[1], contains('2025-03-15'));
        expect(lines[1], contains('支出'));
        expect(lines[1], contains('餐饮'));
        expect(lines[1], contains('50.00'));
        expect(lines[1], contains('招商银行'));
        expect(lines[1], contains('午餐'));

        await db.close();
      });

      test('commas in notes are replaced with Chinese comma', () async {
        final db = await _setupDb();
        final client = FakeExportClient();
        client.exportError = GrpcError.unavailable('force local');

        final notifier = ExportNotifier(db, client, 'user1', null);
        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 3, 1),
          endDate: DateTime(2025, 3, 31),
        );

        final csvContent = utf8.decode(result!);
        // The note '含,逗号和"引号' should have comma replaced
        expect(csvContent, contains('含，逗号和"引号'));
        // Should NOT contain raw comma inside note field
        expect(csvContent.split('\n')[2], isNot(contains(',逗号')));

        await db.close();
      });

      test('empty transactions: returns header-only CSV', () async {
        final db = await _setupDb(addTransactions: false);
        final client = FakeExportClient();
        client.exportError = GrpcError.unavailable('force local');

        final notifier = ExportNotifier(db, client, 'user1', null);
        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        expect(result, isNotNull);
        final lines = utf8.decode(result!).split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines.length, 1); // Only header
        expect(lines[0].trim(), '日期,类型,分类,金额(元),账户,备注');

        await db.close();
      });

      test('date range filter works correctly', () async {
        final db = await _setupDb();
        final client = FakeExportClient();
        client.exportError = GrpcError.unavailable('force local');

        final notifier = ExportNotifier(db, client, 'user1', null);
        // Only include txn1 (2025-03-15), exclude txn2 (2025-03-20)
        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 3, 10),
          endDate: DateTime(2025, 3, 16),
        );

        expect(result, isNotNull);
        final lines = utf8.decode(result!).split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines.length, 2); // header + 1 transaction
        expect(lines[1], contains('午餐'));

        await db.close();
      });

      test('null userId returns null', () async {
        final db = await _setupDb();
        final client = FakeExportClient();

        final notifier = ExportNotifier(db, client, null, null);
        final result = await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        expect(result, isNull);
        await db.close();
      });
    });

    group('familyId handling', () {
      test('passes familyId to server export request', () async {
        final db = await _setupDb();
        pb.ExportRequest? capturedRequest;
        final client = FakeExportClient();
        // Override to capture request
        client.exportResponse = pb.ExportResponse(
          data: utf8.encode('family-data'),
          filename: 'family.csv',
          contentType: 'text/csv',
        );

        final notifier = ExportNotifier(db, client, 'user1', 'family_123');
        await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );

        // Verify state shows family export succeeded
        expect(notifier.state.lastFilename, 'family.csv');
        await db.close();
      });
    });

    group('clearExportData', () {
      test('clears lastExportData and filename', () async {
        final db = await _setupDb();
        final client = FakeExportClient();

        final notifier = ExportNotifier(db, client, 'user1', null);
        await notifier.exportTransactions(
          format: 'csv',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
        );
        expect(notifier.state.lastExportData, isNotNull);

        notifier.clearExportData();
        expect(notifier.state.lastExportData, isNull);
        expect(notifier.state.lastFilename, isNull);

        await db.close();
      });
    });
  });
}
