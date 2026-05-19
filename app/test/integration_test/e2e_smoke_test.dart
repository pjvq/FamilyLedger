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
///   - Each golden path is a single self-contained test (no cross-test state)
///   - Uses UUID-only emails for guaranteed uniqueness
///   - Ordered execution (concurrency=1) for deterministic CI
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
/// UUID v4 guarantees uniqueness even across parallel CI runs.
String _testEmail(String prefix) => '${prefix}_${_uuid.v4()}@e2e.test';

/// Creates a protobuf Timestamp from DateTime.
///
/// Note: [DateTime.millisecondsSinceEpoch] is always relative to Unix epoch
/// (UTC) regardless of whether the DateTime is local or UTC, so no `.toUtc()`
/// conversion is needed here.
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

/// Server-availability-aware test wrapper. Eliminates repeated skip boilerplate.
late bool _serverAvailable;

void e2eTest(String name, Future<void> Function() body) {
  test(name, () async {
    if (!_serverAvailable) {
      markTestSkipped('Server unavailable');
      return;
    }
    await body();
  });
}

// ─── Test Entry Point ────────────────────────────────────────────────────────

void main() {
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
      _serverAvailable = true;
    } on SocketException {
      _serverAvailable = false;
      return;
    }

    authClient = auth_grpc.AuthServiceClient(harness.channel);
    syncClient = sync_grpc.SyncServiceClient(harness.channel);
    txnClient = txn_grpc.TransactionServiceClient(harness.channel);
    familyClient = family_grpc.FamilyServiceClient(harness.channel);
  });

  tearDownAll(() async {
    if (_serverAvailable) {
      await harness.tearDown();
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-1: Register → Login → Authenticated API Call
  //
  // Single test: exercises the complete auth flow as one atomic scenario.
  // No cross-test state leakage.
  // ═══════════════════════════════════════════════════════════════════════════

  e2eTest('GP-1: Register → Login → Auth call succeeds → Unauth fails',
      () async {
    final email = _testEmail('gp1');
    const password = 'SecurePass!99';

    // Step 1: Register
    final regResult = await _registerUser(authClient, email, password);
    expect(regResult.userId, isNotEmpty);
    expect(regResult.userId.length, greaterThanOrEqualTo(36));
    expect(regResult.accessToken, isNotEmpty);
    expect(regResult.refreshToken, isNotEmpty);

    // Step 2: Login with same credentials
    final loginResp = await authClient.login(auth_pb.LoginRequest()
      ..email = email
      ..password = password);
    expect(loginResp.userId, regResult.userId);
    expect(loginResp.accessToken, isNotEmpty);
    expect(loginResp.refreshToken, isNotEmpty);

    // Step 3: Authenticated call succeeds
    final pullResp = await syncClient.pullChanges(
      sync_pb.PullChangesRequest(),
      options: _authOpts(loginResp.accessToken),
    );
    expect(pullResp, isNotNull);

    // Step 4: Unauthenticated call fails
    try {
      await syncClient.pullChanges(sync_pb.PullChangesRequest());
      fail('Unauthenticated call should have thrown');
    } on GrpcError catch (e) {
      expect(e.code, StatusCode.unauthenticated);
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-2: Create Transaction → PullChanges → Visible
  // ═══════════════════════════════════════════════════════════════════════════

  e2eTest(
      'GP-2: CreateTransaction → PullChanges → transaction visible with correct payload',
      () async {
    // Setup: register + account + category
    final auth =
        await _registerUser(authClient, _testEmail('gp2'), 'Pass123!');
    final opts = _authOpts(auth.accessToken);

    final accountId = _uuid.v4();
    await _pushOp(syncClient, opts,
        entityType: 'account',
        entityId: accountId,
        opType: sync_enum.OperationType.OPERATION_TYPE_CREATE,
        payload: {
          'id': accountId,
          'name': 'GP2 Checking',
          'type': 'bank',
          'balance': 1000000, // 10000.00 CNY — sufficient for expense
          'currency': 'CNY',
        });

    final categoryId = _uuid.v4();
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

    // Act: Create transaction via dedicated RPC
    final createResp = await txnClient.createTransaction(
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
    final txnId = createResp.transaction.id;
    expect(txnId, isNotEmpty);

    // Assert: PullChanges returns it
    final pullResp = await syncClient.pullChanges(
      sync_pb.PullChangesRequest(),
      options: opts,
    );
    final op = _findOp(pullResp.operations, txnId);
    expect(op, isNotNull,
        reason: 'Created transaction $txnId should appear in PullChanges');

    // Verify payload integrity
    final payload = jsonDecode(op!.payload) as Map<String, dynamic>;
    expect(payload['account_id'], accountId);
    expect(payload['category_id'], categoryId);
    expect(payload['note'], 'GP-2 smoke test');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-3: Family — Create → Invite → Member Sees Shared Transaction
  // ═══════════════════════════════════════════════════════════════════════════

  e2eTest(
      'GP-3: CreateFamily → Invite → Member PullChanges sees family transaction',
      () async {
    // Owner setup
    final ownerAuth =
        await _registerUser(authClient, _testEmail('gp3_owner'), 'Pass123!');
    final ownerOpts = _authOpts(ownerAuth.accessToken);

    // Create family
    final familyResp = await familyClient.createFamily(
      family_pb.CreateFamilyRequest()..name = 'GP3 Test Family',
      options: ownerOpts,
    );
    final familyId = familyResp.family.id;
    expect(familyId, isNotEmpty);

    // Generate invite + member joins
    final inviteResp = await familyClient.generateInviteCode(
      family_pb.GenerateInviteCodeRequest()..familyId = familyId,
      options: ownerOpts,
    );
    expect(inviteResp.inviteCode, isNotEmpty);

    final memberAuth =
        await _registerUser(authClient, _testEmail('gp3_member'), 'Pass123!');
    await familyClient.joinFamily(
      family_pb.JoinFamilyRequest()..inviteCode = inviteResp.inviteCode,
      options: _authOpts(memberAuth.accessToken),
    );

    // Owner pushes family-scoped transaction
    final accountId = _uuid.v4();
    await _pushOp(syncClient, ownerOpts,
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
    await _pushOp(syncClient, ownerOpts,
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

    final sharedTxnId = _uuid.v4();
    await _pushOp(syncClient, ownerOpts,
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

    // Assert: Member can see it via family-scoped pull
    final memberPull = await syncClient.pullChanges(
      sync_pb.PullChangesRequest()..familyId = familyId,
      options: _authOpts(memberAuth.accessToken),
    );
    final found = memberPull.operations
        .any((op) => op.entityType == 'transaction' && op.entityId == sharedTxnId);
    expect(found, true,
        reason: 'Family member should see owner\'s transaction via familyId pull');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-4: Offline Create → Batch Push → Server Has It
  // ═══════════════════════════════════════════════════════════════════════════

  e2eTest('GP-4: Batch push 3 offline-queued transactions → all accepted',
      () async {
    // Setup
    final auth =
        await _registerUser(authClient, _testEmail('gp4'), 'Pass123!');
    final opts = _authOpts(auth.accessToken);

    final accountId = _uuid.v4();
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

    final categoryId = _uuid.v4();
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

    // Act: Simulate offline queue — push 3 transactions in one batch
    final txnIds = List.generate(3, (_) => _uuid.v4());
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

    final pushResp = await syncClient.pushOperations(
      sync_pb.PushOperationsRequest()..operations.addAll(operations),
      options: opts,
    );
    expect(pushResp.acceptedCount, 3);
    expect(pushResp.failedIds, isEmpty);

    // Assert: PullChanges returns all 3
    final pullResp = await syncClient.pullChanges(
      sync_pb.PullChangesRequest(),
      options: opts,
    );
    int foundCount = 0;
    for (final id in txnIds) {
      if (pullResp.operations
          .any((op) => op.entityType == 'transaction' && op.entityId == id)) {
        foundCount++;
      }
    }
    expect(foundCount, 3,
        reason: 'All 3 offline-created transactions should be visible');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GP-5: Token Expired → Refresh → Request Succeeds + Rotation Enforced
  // ═══════════════════════════════════════════════════════════════════════════

  e2eTest('GP-5a: RefreshToken returns new valid access token', () async {
    final auth =
        await _registerUser(authClient, _testEmail('gp5a'), 'Pass123!');

    // Invalid token → UNAUTHENTICATED
    try {
      await syncClient.pullChanges(
        sync_pb.PullChangesRequest(),
        options: _authOpts('clearly.invalid.token.value'),
      );
      fail('Invalid token should have thrown');
    } on GrpcError catch (e) {
      expect(e.code, StatusCode.unauthenticated);
    }

    // Refresh → new access token works
    final refreshResp = await authClient.refreshToken(
      auth_pb.RefreshTokenRequest()..refreshToken = auth.refreshToken,
    );
    expect(refreshResp.accessToken, isNotEmpty);
    expect(refreshResp.refreshToken, isNotEmpty);

    final pullResp = await syncClient.pullChanges(
      sync_pb.PullChangesRequest(),
      options: _authOpts(refreshResp.accessToken),
    );
    expect(pullResp, isNotNull);
  });

  e2eTest('GP-5b: Refresh token rotation — old token invalidated', () async {
    final auth =
        await _registerUser(authClient, _testEmail('gp5b'), 'Pass123!');
    final originalRefresh = auth.refreshToken;

    // First refresh — consumes and rotates the token
    final resp1 = await authClient.refreshToken(
      auth_pb.RefreshTokenRequest()..refreshToken = originalRefresh,
    );
    expect(resp1.accessToken, isNotEmpty);

    // Reuse the ORIGINAL refresh token — must fail (rotation enforced)
    try {
      await authClient.refreshToken(
        auth_pb.RefreshTokenRequest()..refreshToken = originalRefresh,
      );
      fail('Old refresh token should be invalidated after rotation');
    } on GrpcError catch (e) {
      expect(e.code, StatusCode.unauthenticated);
    }
  });
}
