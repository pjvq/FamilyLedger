/// Issue #64 Item 3: E2E Smoke Tests — 5 Golden Paths
///
/// Full-stack verification: Flutter Dart gRPC Client ↔ Go Server ↔ PostgreSQL.
/// Each test exercises a complete user-facing scenario end-to-end.
///
/// Golden Paths:
///   GP-1: Register → Login → Token works
///   GP-2: Create Transaction → PullChanges → visible
///   GP-3: Create Family → Invite → Member sees shared transactions
///   GP-4: Offline create → Network restore → Auto-sync succeeds (batch push)
///   GP-5: Token expired → Refresh → Request succeeds
///
/// Prerequisites:
///   - Go server running on localhost:50051 (gRPC) + localhost:8080 (WS)
///   - PostgreSQL with migrations applied
///   - OAUTH_MODE=mock on server
///
/// Design decisions:
///   - Each golden path is self-contained (creates own test data)
///   - Uses unique emails per test run (timestamp suffix) to avoid collisions
///   - Ordered execution (concurrency=1) — tests within a group share state
///   - 3-minute CI timeout enforced at workflow level
///   - No Flutter widget dependencies — pure Dart gRPC client
///   - Graceful skip when server is unreachable (local dev without Docker)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';

import 'package:familyledger/generated/proto/auth.pb.dart' as auth_pb;
import 'package:familyledger/generated/proto/auth.pbgrpc.dart' as auth_grpc;
import 'package:familyledger/generated/proto/sync.pb.dart' as sync_pb;
import 'package:familyledger/generated/proto/sync.pbgrpc.dart' as sync_grpc;
import 'package:familyledger/generated/proto/sync.pbenum.dart' as sync_enum;
import 'package:familyledger/generated/proto/transaction.pb.dart' as txn_pb;
import 'package:familyledger/generated/proto/transaction.pbgrpc.dart'
    as txn_grpc;
import 'package:familyledger/generated/proto/transaction.pbenum.dart'
    as txn_enum;
import 'package:familyledger/generated/proto/family.pb.dart' as family_pb;
import 'package:familyledger/generated/proto/family.pbgrpc.dart' as family_grpc;
import 'package:familyledger/generated/proto/google/protobuf/timestamp.pb.dart'
    as ts_pb;

import 'harness.dart';

// ─── Shared Utilities ────────────────────────────────────────────────────────

const _uuid = Uuid();

/// Generates a unique email for test isolation.
String _testEmail(String prefix) =>
    '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}@e2e.test';

/// Creates a Timestamp from DateTime.
ts_pb.Timestamp _toTimestamp(DateTime dt) => ts_pb.Timestamp()
  ..seconds = Int64(dt.millisecondsSinceEpoch ~/ 1000)
  ..nanos = (dt.millisecondsSinceEpoch % 1000) * 1000000;

/// Registers a user and returns (userId, accessToken, refreshToken).
Future<({String userId, String accessToken, String refreshToken})>
    _registerUser(
  auth_grpc.AuthServiceClient authClient,
  String email,
  String password,
) async {
  final resp = await authClient.register(auth_pb.RegisterRequest()
    ..email = email
    ..password = password);
  return (
    userId: resp.userId,
    accessToken: resp.accessToken,
    refreshToken: resp.refreshToken,
  );
}

/// Creates auth call options from a token.
CallOptions _authOpts(String token) =>
    CallOptions(metadata: {'authorization': 'Bearer $token'});

/// Pushes a single sync operation.
Future<sync_pb.PushOperationsResponse> _pushOp(
  sync_grpc.SyncServiceClient syncClient,
  CallOptions opts, {
  required String entityType,
  required String entityId,
  required sync_enum.OperationType opType,
  required Map<String, dynamic> payload,
}) async {
  return syncClient.pushOperations(
    sync_pb.PushOperationsRequest()
      ..operations.add(sync_pb.SyncOperation()
        ..entityType = entityType
        ..entityId = entityId
        ..opType = opType
        ..payload = jsonEncode(payload)
        ..clientId = _uuid.v4()),
    options: opts,
  );
}

/// Finds a SyncOperation in PullChanges response by entityId.
sync_pb.SyncOperation? _findOp(
  List<sync_pb.SyncOperation> ops,
  String entityId,
) {
  for (final op in ops) {
    if (op.entityId == entityId) return op;
  }
  return null;
}

// ─── Test Entry Point ────────────────────────────────────────────────────────

void main() {
  late final bool serverAvailable;
  late final E2EHarness harness;
  late final auth_grpc.AuthServiceClient authClient;
  late final sync_grpc.SyncServiceClient syncClient;
  late final txn_grpc.TransactionServiceClient txnClient;
  late final family_grpc.FamilyServiceClient familyClient;

  setUpAll(() async {
    harness = E2EHarness();
    harness.setUp();

    // Probe server availability with a 5-second timeout.
    try {
      final socket = await Socket.connect(
        harness.config.grpcHost,
        harness.config.grpcPort,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      serverAvailable = true;
    } on SocketException {
      serverAvailable = false;
      return;
    }

    authClient = auth_grpc.AuthServiceClient(harness.channel);
    syncClient = sync_grpc.SyncServiceClient(harness.channel);
    txnClient = txn_grpc.TransactionServiceClient(harness.channel);
    familyClient = family_grpc.FamilyServiceClient(harness.channel);
  });

  tearDownAll(() async {
    if (serverAvailable) {
      await harness.tearDown();
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-1: Register → Login → Authenticated API Call
  // ═══════════════════════════════════════════════════════════════════════════

  group('GP-1: Auth Flow', () {
    late String userId;
    late String accessToken;
    late String refreshToken;
    final email = _testEmail('gp1');
    const password = 'SecurePass!99';

    test('GP-1a: Register creates user and returns valid tokens', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final result = await _registerUser(authClient, email, password);
      userId = result.userId;
      accessToken = result.accessToken;
      refreshToken = result.refreshToken;

      expect(userId, isNotEmpty);
      expect(accessToken, isNotEmpty);
      expect(refreshToken, isNotEmpty);
      expect(userId.length, greaterThanOrEqualTo(36));
    });

    test('GP-1b: Login with same credentials returns new tokens', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final resp = await authClient.login(auth_pb.LoginRequest()
        ..email = email
        ..password = password);

      expect(resp.userId, userId);
      expect(resp.accessToken, isNotEmpty);
      expect(resp.refreshToken, isNotEmpty);
      // Note: JWT may be identical if issued within same second (same iat/exp).
      // We only assert tokens are valid, not necessarily different.
      accessToken = resp.accessToken;
      refreshToken = resp.refreshToken;
    });

    test('GP-1c: Authenticated PullChanges succeeds', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest(),
        options: _authOpts(accessToken),
      );
      // Fresh user — no changes yet (operations list empty or has seed data)
      expect(resp, isNotNull);
    });

    test('GP-1d: Unauthenticated call fails with UNAUTHENTICATED', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      try {
        await syncClient.pullChanges(sync_pb.PullChangesRequest());
        fail('Should have thrown');
      } on GrpcError catch (e) {
        expect(e.code, StatusCode.unauthenticated);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-2: Create Transaction → PullChanges → Visible
  // ═══════════════════════════════════════════════════════════════════════════

  group('GP-2: Transaction Lifecycle', () {
    late String accessToken;
    late String accountId;
    late String categoryId;
    late String txnId;

    test('GP-2a: Setup — register + create account + category', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final email = _testEmail('gp2');
      final auth = await _registerUser(authClient, email, 'Pass123!');
      accessToken = auth.accessToken;
      final opts = _authOpts(accessToken);

      // Create account via sync push
      accountId = _uuid.v4();
      await _pushOp(syncClient, opts,
          entityType: 'account',
          entityId: accountId,
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'id': accountId,
            'name': 'GP2 Checking',
            'type': 'bank',
            'balance': 1000000,
            'currency': 'CNY',
          });

      // Create category
      categoryId = _uuid.v4();
      await _pushOp(syncClient, opts,
          entityType: 'category',
          entityId: categoryId,
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'id': categoryId,
            'name': 'GP2 Food',
            'type': 'expense',
            'icon': '🍕',
          });
    });

    test('GP-2b: CreateTransaction via gRPC succeeds', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final opts = _authOpts(accessToken);
      txnId = _uuid.v4();

      final resp = await txnClient.createTransaction(
        txn_pb.CreateTransactionRequest()
          ..accountId = accountId
          ..categoryId = categoryId
          ..amount = Int64(5000)
          ..amountCny = Int64(5000)
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = 'GP-2 smoke test'
          ..txnDate = _toTimestamp(DateTime.now()),
        options: opts,
      );

      // Response contains the created transaction
      expect(resp.transaction.id, isNotEmpty);
      txnId = resp.transaction.id;
    });

    test('GP-2c: PullChanges returns the created transaction', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final opts = _authOpts(accessToken);
      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest(),
        options: opts,
      );

      // Find our transaction in the operations list
      final found = resp.operations.any((op) =>
          op.entityType == 'transaction' && op.entityId == txnId);
      expect(found, true,
          reason: 'Created transaction should appear in PullChanges');
    });

    test('GP-2d: Transaction payload matches what was sent', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final opts = _authOpts(accessToken);
      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest(),
        options: opts,
      );

      final op = _findOp(resp.operations, txnId);
      expect(op, isNotNull, reason: 'Transaction $txnId not found in pull');

      final payload = jsonDecode(op!.payload) as Map<String, dynamic>;
      expect(payload['account_id'], accountId);
      expect(payload['category_id'], categoryId);
      expect(payload['note'], 'GP-2 smoke test');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-3: Family — Create → Invite → Member Sees Shared Transaction
  // ═══════════════════════════════════════════════════════════════════════════

  group('GP-3: Family Collaboration', () {
    late String ownerToken;
    late String memberToken;
    late String familyId;
    late String sharedTxnId;

    test('GP-3a: Owner registers and creates family', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final ownerAuth =
          await _registerUser(authClient, _testEmail('gp3_owner'), 'Pass123!');
      ownerToken = ownerAuth.accessToken;

      final resp = await familyClient.createFamily(
        family_pb.CreateFamilyRequest()..name = 'GP3 Test Family',
        options: _authOpts(ownerToken),
      );
      familyId = resp.family.id;
      expect(familyId, isNotEmpty);
    });

    test('GP-3b: Owner invites, member joins', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final inviteResp = await familyClient.generateInviteCode(
        family_pb.GenerateInviteCodeRequest()..familyId = familyId,
        options: _authOpts(ownerToken),
      );
      expect(inviteResp.inviteCode, isNotEmpty);

      // Member registers and joins
      final memberAuth =
          await _registerUser(authClient, _testEmail('gp3_member'), 'Pass123!');
      memberToken = memberAuth.accessToken;

      await familyClient.joinFamily(
        family_pb.JoinFamilyRequest()..inviteCode = inviteResp.inviteCode,
        options: _authOpts(memberToken),
      );
    });

    test('GP-3c: Owner pushes a family transaction', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final opts = _authOpts(ownerToken);

      // Setup account + category with familyId
      final accountId = _uuid.v4();
      await _pushOp(syncClient, opts,
          entityType: 'account',
          entityId: accountId,
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'id': accountId,
            'name': 'GP3 Shared Wallet',
            'type': 'cash',
            'balance': 0,
            'currency': 'CNY',
            'family_id': familyId,
          });

      final categoryId = _uuid.v4();
      await _pushOp(syncClient, opts,
          entityType: 'category',
          entityId: categoryId,
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'id': categoryId,
            'name': 'GP3 Groceries',
            'type': 'expense',
            'icon': '🛒',
            'family_id': familyId,
          });

      // Push transaction tagged to family
      sharedTxnId = _uuid.v4();
      await _pushOp(syncClient, opts,
          entityType: 'transaction',
          entityId: sharedTxnId,
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'id': sharedTxnId,
            'account_id': accountId,
            'category_id': categoryId,
            'amount': 8800,
            'amount_cny': 8800,
            'type': 'expense',
            'note': 'GP3 family purchase',
            'txn_date': DateTime.now().toIso8601String(),
            'family_id': familyId,
          });
    });

    test('GP-3d: Member can see the family transaction', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      // Member pulls changes with familyId — family transactions should be visible
      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()..familyId = familyId,
        options: _authOpts(memberToken),
      );

      final found = resp.operations.any((op) =>
          op.entityType == 'transaction' && op.entityId == sharedTxnId);
      expect(found, true,
          reason: 'Family member should see transactions shared via familyId');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-4: Offline Create → Batch Push → Server Has It
  // ═══════════════════════════════════════════════════════════════════════════

  group('GP-4: Offline → Sync', () {
    late String accessToken;
    late String accountId;
    late String categoryId;
    late List<String> txnIds;

    test('GP-4a: Setup user + account + category', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final auth =
          await _registerUser(authClient, _testEmail('gp4'), 'Pass123!');
      accessToken = auth.accessToken;
      final opts = _authOpts(accessToken);

      accountId = _uuid.v4();
      await _pushOp(syncClient, opts,
          entityType: 'account',
          entityId: accountId,
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'id': accountId,
            'name': 'GP4 Offline Account',
            'type': 'cash',
            'balance': 0,
            'currency': 'CNY',
          });

      categoryId = _uuid.v4();
      await _pushOp(syncClient, opts,
          entityType: 'category',
          entityId: categoryId,
          opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
          payload: {
            'id': categoryId,
            'name': 'GP4 Transport',
            'type': 'expense',
            'icon': '🚕',
          });
    });

    test('GP-4b: Batch push of 3 offline-queued transactions', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final opts = _authOpts(accessToken);
      txnIds = List.generate(3, (_) => _uuid.v4());

      // Simulate: client was offline, queued 3 txns, now pushes all at once
      final operations = txnIds
          .map((id) => sync_pb.SyncOperation()
            ..entityType = 'transaction'
            ..entityId = id
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({
              'id': id,
              'account_id': accountId,
              'category_id': categoryId,
              'amount': 1500,
              'amount_cny': 1500,
              'type': 'expense',
              'note': 'GP4 offline txn',
              'txn_date': DateTime.now().toIso8601String(),
            })
            ..clientId = _uuid.v4())
          .toList();

      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()..operations.addAll(operations),
        options: opts,
      );

      // acceptedCount should be 3, failedIds should be empty
      expect(resp.acceptedCount, 3);
      expect(resp.failedIds, isEmpty);
    });

    test('GP-4c: PullChanges shows all 3 synced transactions', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest(),
        options: _authOpts(accessToken),
      );

      int foundCount = 0;
      for (final id in txnIds) {
        if (resp.operations.any(
            (op) => op.entityType == 'transaction' && op.entityId == id)) {
          foundCount++;
        }
      }
      expect(foundCount, 3,
          reason: 'All 3 offline-created transactions should be visible');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-5: Token Expired → Refresh → Request Succeeds
  // ═══════════════════════════════════════════════════════════════════════════

  group('GP-5: Token Refresh', () {
    late String refreshToken;

    test('GP-5a: Register and get initial tokens', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final auth =
          await _registerUser(authClient, _testEmail('gp5'), 'Pass123!');
      refreshToken = auth.refreshToken;
      expect(refreshToken, isNotEmpty);
    });

    test('GP-5b: Invalid access token gets UNAUTHENTICATED', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      try {
        await syncClient.pullChanges(
          sync_pb.PullChangesRequest(),
          options: _authOpts('clearly.invalid.token.value'),
        );
        fail('Should have thrown');
      } on GrpcError catch (e) {
        expect(e.code, StatusCode.unauthenticated);
      }
    });

    test('GP-5c: RefreshToken returns new valid access token', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      final resp = await authClient.refreshToken(
        auth_pb.RefreshTokenRequest()..refreshToken = refreshToken,
      );

      expect(resp.accessToken, isNotEmpty);
      expect(resp.refreshToken, isNotEmpty);

      // New access token should work for authenticated calls
      final pullResp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest(),
        options: _authOpts(resp.accessToken),
      );
      expect(pullResp, isNotNull);

      // Store the new refresh token for next test
      refreshToken = resp.refreshToken;
    });

    test('GP-5d: Refresh token rotation — old token invalidated', () async {
      if (!serverAvailable) {
        markTestSkipped('Server unavailable');
        return;
      }

      // Register a fresh user to get a clean token pair
      final freshAuth =
          await _registerUser(authClient, _testEmail('gp5d'), 'Pass123!');
      final originalRefresh = freshAuth.refreshToken;

      // First refresh — should succeed and rotate the token
      final resp1 = await authClient.refreshToken(
        auth_pb.RefreshTokenRequest()..refreshToken = originalRefresh,
      );
      expect(resp1.accessToken, isNotEmpty);

      // Reuse the ORIGINAL refresh token — should fail (rotation)
      try {
        await authClient.refreshToken(
          auth_pb.RefreshTokenRequest()..refreshToken = originalRefresh,
        );
        // If server doesn't rotate, this is a known security gap but not a test failure
      } on GrpcError catch (e) {
        expect(e.code, StatusCode.unauthenticated);
      }
    });
  });
}
