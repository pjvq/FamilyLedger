import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/generated/proto/google/protobuf/timestamp.pb.dart'
    as proto_ts;
import 'package:familyledger/generated/proto/sync.pb.dart' as sync_pb;
import 'package:familyledger/generated/proto/sync.pbgrpc.dart';
import 'package:familyledger/generated/proto/sync.pbenum.dart' as sync_enum;
import 'package:familyledger/sync/sync_engine.dart';

// ─── Mocks & Fakes ──────────────────────────────────────────

class MockSyncServiceClient extends Mock implements SyncServiceClient {}

class FakePushOperationsRequest extends Fake
    implements sync_pb.PushOperationsRequest {}

class FakePullChangesRequest extends Fake
    implements sync_pb.PullChangesRequest {}

/// Fake ResponseFuture that wraps a Future value.
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

class MockConnectivity extends Mock implements Connectivity {}

// ─── Testable SyncEngine ─────────────────────────────────────

/// Exposes internal methods for testing by directly calling the real engine
/// with injected dependencies via the public constructor.
class TestableSyncEngine extends SyncEngine {
  TestableSyncEngine(AppDatabase db, SyncServiceClient client,
      SharedPreferences prefs, {Connectivity? connectivity})
      : super(db, client, prefs, connectivity: connectivity);

  /// Public access to syncNow() for testing push + pull flow
  Future<void> testSyncNow() => syncNow();
}

// ─── Test Helpers ────────────────────────────────────────────

Future<AppDatabase> _setupDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', "
      "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");
  await db.insertAccount(AccountsCompanion.insert(
    id: 'acc1',
    userId: 'user1',
    name: 'Test Account',
    familyId: const Value(''),
    accountType: const Value('bank_card'),
  ));
  return db;
}

Future<void> _insertPendingSyncOp(AppDatabase db, {
  String id = 'op1',
  String entityType = 'transaction',
  String entityId = 'txn1',
  String opType = 'create',
  Map<String, dynamic>? payload,
}) async {
  await db.insertSyncOp(SyncQueueCompanion.insert(
    id: id,
    entityType: entityType,
    entityId: entityId,
    opType: opType,
    payload: jsonEncode(payload ?? {
      'id': entityId,
      'account_id': 'acc1',
      'category_id': 'cat1',
      'amount': 1000,
      'type': 'expense',
      'note': 'test',
      'txn_date': '2025-01-01T00:00:00',
    }),
    clientId: 'client_user1',
    timestamp: DateTime.now(),
  ));
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(FakePushOperationsRequest());
    registerFallbackValue(FakePullChangesRequest());
  });

  group('SyncEngine full flow', () {
    late AppDatabase db;
    late MockSyncServiceClient mockClient;
    late MockConnectivity mockConnectivity;
    late SharedPreferences prefs;

    setUp(() async {
      db = await _setupDb();
      mockClient = MockSyncServiceClient();
      mockConnectivity = MockConnectivity();
      // Default: connectivity is wifi (online)
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      SharedPreferences.setMockInitialValues({
        'user_id': 'user1',
        'access_token': 'test_token',
      });
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await db.close();
    });

    group('syncNow() complete flow: push → pull → apply', () {
      test('pushes pending ops then pulls remote changes', () async {
        // Arrange: insert a pending op
        await _insertPendingSyncOp(db, id: 'op_push_1', entityId: 'txn_push');

        // Mock push: success, no failures
        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PushOperationsResponse(acceptedCount: 1),
                ));

        // Mock pull: return one remote op
        final remoteOp = sync_pb.SyncOperation(
          id: 'remote_op_1',
          entityType: 'transaction',
          entityId: 'txn_remote',
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: jsonEncode({
            'user_id': 'user1',
            'account_id': 'acc1',
            'category_id': 'cat1',
            'amount': 2000,
            'amount_cny': 2000,
            'type': 'expense',
            'note': 'pulled from server',
            'txn_date': '2025-03-01T12:00:00',
          }),
          clientId: 'server',
          timestamp: proto_ts.Timestamp(
            seconds: Int64(DateTime(2025, 3, 1).millisecondsSinceEpoch ~/ 1000),
          ),
        );
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PullChangesResponse(
                    operations: [remoteOp],
                    serverTime: proto_ts.Timestamp(
                      seconds: Int64(
                          DateTime(2025, 3, 1, 1).millisecondsSinceEpoch ~/ 1000),
                    ),
                  ),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);

        // Act
        await engine.testSyncNow();

        // Assert: push was called
        verify(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .called(1);

        // Assert: pull was called
        verify(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .called(1);

        // Assert: remote op was applied locally
        final txn = await db.getTransactionById('txn_remote');
        expect(txn, isNotNull);
        expect(txn!.note, 'pulled from server');
        expect(txn.amount, 2000);

        // Assert: pending op was marked as uploaded
        final pendingOps = await db.getPendingSyncOps(10);
        expect(pendingOps, isEmpty);

        engine.dispose();
      });
    });

    group('push failure: ops retained in queue', () {
      test('when push throws, ops remain pending', () async {
        // Arrange
        await _insertPendingSyncOp(db, id: 'op_fail_1', entityId: 'txn_fail');

        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.error(
                  GrpcError.unavailable('network down'),
                ));

        // Still need pull mock since syncNow calls both
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PullChangesResponse(),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);

        // Act
        await engine.testSyncNow();

        // Assert: ops still pending (not marked uploaded)
        final pendingOps = await db.getPendingSyncOps(10);
        expect(pendingOps, hasLength(1));
        expect(pendingOps.first.id, 'op_fail_1');

        engine.dispose();
      });
    });

    group('pull with empty data stops', () {
      test('pull with no operations does not crash', () async {
        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PushOperationsResponse(acceptedCount: 0),
                ));
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PullChangesResponse(operations: []),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);

        // Act — should not throw
        await engine.testSyncNow();

        // Verify pull was called once (no pagination in current impl)
        verify(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .called(1);

        engine.dispose();
      });
    });

    group('network exception: sync does not crash', () {
      test('push network error is caught gracefully', () async {
        await _insertPendingSyncOp(db, id: 'op_net', entityId: 'txn_net');

        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.error(
                  GrpcError.unavailable('connection refused'),
                ));
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.error(
                  GrpcError.deadlineExceeded('timeout'),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);

        // Act — should not throw
        await engine.testSyncNow();

        // ops should still be pending
        final pendingOps = await db.getPendingSyncOps(10);
        expect(pendingOps, hasLength(1));

        engine.dispose();
      });

      test('pull network error is caught gracefully', () async {
        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PushOperationsResponse(acceptedCount: 0),
                ));
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.error(
                  Exception('socket error'),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);

        // Should not throw
        await engine.testSyncNow();

        engine.dispose();
      });
    });

    group('concurrent sync: _isSyncing guard prevents re-entry', () {
      test('second syncNow during active push is effectively serialized',
          () async {
        // The _isSyncing guard is in _pushPendingOps. Since syncNow()
        // awaits _pushPendingOps then _pullChanges sequentially,
        // calling syncNow() twice concurrently should not cause issues.
        await _insertPendingSyncOp(db, id: 'op_conc', entityId: 'txn_conc');

        int pushCallCount = 0;
        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) {
          pushCallCount++;
          return FakeResponseFuture.value(
            sync_pb.PushOperationsResponse(acceptedCount: 1),
          );
        });
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PullChangesResponse(),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);

        // Act: call syncNow twice concurrently
        final f1 = engine.testSyncNow();
        final f2 = engine.testSyncNow();
        await Future.wait([f1, f2]);

        // The _isSyncing flag should have prevented the second push
        // from running concurrently. Due to await semantics, the second
        // call sees _isSyncing=true and returns early from _pushPendingOps.
        // So pushOperations should only be called once.
        expect(pushCallCount, 1);

        engine.dispose();
      });
    });

    group('offline op → sync → push', () {
      test('transaction created offline is pushed on next sync', () async {
        // Simulate an offline transaction by inserting directly into sync queue
        await _insertPendingSyncOp(db,
            id: 'op_offline',
            entityType: 'transaction',
            entityId: 'txn_offline',
            opType: 'create',
            payload: {
              'id': 'txn_offline',
              'account_id': 'acc1',
              'category_id': 'cat1',
              'amount': 5000,
              'type': 'expense',
              'note': 'offline created',
              'txn_date': '2025-04-01T10:00:00',
            });

        // Verify it's pending
        final before = await db.getPendingSyncOps(10);
        expect(before, hasLength(1));
        expect(before.first.entityId, 'txn_offline');

        // Mock successful push
        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PushOperationsResponse(acceptedCount: 1),
                ));
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PullChangesResponse(),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);

        // Act
        await engine.testSyncNow();

        // Assert: push was called with our op
        final captured = verify(() =>
                mockClient.pushOperations(captureAny(), options: any(named: 'options')))
            .captured;
        expect(captured, hasLength(1));
        final request = captured.first as sync_pb.PushOperationsRequest;
        expect(request.operations, hasLength(1));
        expect(request.operations.first.entityId, 'txn_offline');

        // Assert: op marked uploaded
        final after = await db.getPendingSyncOps(10);
        expect(after, isEmpty);

        engine.dispose();
      });
    });

    group('push with partial failures', () {
      test('only succeeded ops are marked uploaded; failed ops stay in queue for retry',
          () async {
        // Insert 2 pending ops
        await _insertPendingSyncOp(db, id: 'op_ok', entityId: 'txn_ok');
        await _insertPendingSyncOp(db, id: 'op_bad', entityId: 'txn_bad');

        // Server says op_bad failed
        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PushOperationsResponse(
                    acceptedCount: 1,
                    failedIds: ['op_bad'],
                  ),
                ));
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PullChangesResponse(),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);
        await engine.testSyncNow();

        // R7 fix: Only succeeded ops marked uploaded; failed ops remain for retry
        // After failure, retryCount is incremented and nextRetryAt is set (exponential backoff).
        // getPendingSyncOps respects nextRetryAt, so the op won't appear until backoff expires.
        // Verify the op still exists (not uploaded) by querying without the time filter.
        final allOps = await (db.select(db.syncQueue)
              ..where((s) => s.uploaded.equals(false)))
            .get();
        expect(allOps, hasLength(1));
        expect(allOps.first.id, equals('op_bad'));
        expect(allOps.first.retryCount, equals(1));
        expect(allOps.first.nextRetryAt, isNotNull);

        engine.dispose();
      });
    });

    group('pull saves serverTime for next pull', () {
      test('serverTime from response is persisted in SharedPreferences',
          () async {
        final serverTimeMs =
            DateTime(2025, 5, 1, 12, 0, 0).millisecondsSinceEpoch;

        when(() => mockClient.pushOperations(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PushOperationsResponse(acceptedCount: 0),
                ));
        when(() => mockClient.pullChanges(any(), options: any(named: 'options')))
            .thenAnswer((_) => FakeResponseFuture.value(
                  sync_pb.PullChangesResponse(
                    operations: [],
                    serverTime: proto_ts.Timestamp(
                      seconds: Int64(serverTimeMs ~/ 1000),
                      nanos: (serverTimeMs % 1000) * 1000000,
                    ),
                  ),
                ));

        final engine = TestableSyncEngine(db, mockClient, prefs, connectivity: mockConnectivity);
        await engine.testSyncNow();

        // Verify prefs saved the timestamp
        final savedTs = prefs.getInt('sync_last_pull_ts');
        expect(savedTs, serverTimeMs);

        engine.dispose();
      });
    });
  });
}
