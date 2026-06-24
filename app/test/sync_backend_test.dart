import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/generated/proto/sync.pb.dart' as sync_pb;
import 'package:familyledger/generated/proto/sync.pbenum.dart' as sync_enum;
import 'package:familyledger/generated/proto/sync.pbgrpc.dart';
import 'package:familyledger/sync/grpc_sync_backend.dart';
import 'package:familyledger/sync/no_sync_backend.dart';
import 'package:familyledger/sync/sync_backend.dart';
import 'package:familyledger/sync/sync_backend_factory.dart';

SyncServiceClient _fakeSyncClient() =>
    SyncServiceClient(ClientChannel('localhost', port: 1));


void main() {
  group('NoSyncBackend', () {
    late NoSyncBackend backend;

    setUp(() => backend = NoSyncBackend());

    test('is inert (isActive == false)', () {
      expect(backend.isActive, isFalse);
    });

    test('push returns empty response, contacts nothing', () async {
      final req = sync_pb.PushOperationsRequest()
        ..operations.add(
          sync_pb.SyncOperation(
            id: 'op1',
            entityType: 'transaction',
            entityId: 'txn1',
            opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          ),
        );

      final resp = await backend.push(req);

      // No failures reported and no accepted ops — sync simply does not apply.
      expect(resp.failedIds, isEmpty);
      expect(resp.acceptedCount, 0);
    });

    test('pull returns empty response', () async {
      final resp = await backend.pull(sync_pb.PullChangesRequest());
      expect(resp.operations, isEmpty);
    });

    test('realtime + lifecycle methods are safe no-ops', () {
      // Should not throw even with callbacks unset / after dispose.
      expect(() {
        backend.connectRealtime();
        backend.disconnectRealtime();
        backend.onAppResumed();
        backend.dispose();
        backend.connectRealtime();
      }, returnsNormally);
    });

    test('never invokes engine callbacks', () {
      var called = false;
      backend
        ..onRealtimeChange = (() => called = true)
        ..onRealtimeWatermark = ((_) => called = true)
        ..onConnectionStateChanged = ((_) => called = true)
        ..connectRealtime()
        ..onAppResumed()
        ..disconnectRealtime();
      expect(called, isFalse);
    });
  });

  group('createSyncBackend selection', () {
    test('default build (SYNC_BACKEND=grpc) enables real sync', () {
      // Tests run without --dart-define, so the factory default ('grpc')
      // applies: syncEnabled is true and a real (gRPC) backend is built.
      expect(syncEnabled, isTrue);

      var clientBuilt = false;
      final backend = createSyncBackend(
        syncClientFactory: () {
          clientBuilt = true;
          return _fakeSyncClient();
        },
      );

      // gRPC path: the client factory was invoked and an active backend built.
      expect(clientBuilt, isTrue);
      expect(backend.isActive, isTrue);
      expect(backend, isA<GrpcSyncBackend>());
      backend.dispose();
    });

    test('returns a SyncBackend', () {
      final backend = createSyncBackend(
        syncClientFactory: () => _fakeSyncClient(),
      );
      expect(backend, isA<SyncBackend>());
      backend.dispose();
    });
  });
}
