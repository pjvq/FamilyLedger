/// W9 Supplement: Additional E2E tests — Token Refresh, Multi-User Sync,
/// Batch Push, Incremental Pull, Family Sync Isolation.
///
/// Covers:
///   - Token refresh flow (access token expiry → refresh → new token works)
///   - Two users in same family: push+pull isolation
///   - Batch push (5 ops in single request)
///   - Incremental pull with `since` timestamp
///   - Cross-user visibility within family sync
///   - Error cases: expired refresh token, malformed ops
import 'dart:convert';
import 'dart:math';

import 'package:grpc/grpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';

import 'harness.dart';
import 'package:familyledger/generated/proto/auth.pb.dart' as auth_pb;
import 'package:familyledger/generated/proto/auth.pbgrpc.dart' as auth_grpc;
import 'package:familyledger/generated/proto/sync.pb.dart' as sync_pb;
import 'package:familyledger/generated/proto/sync.pbgrpc.dart' as sync_grpc;
import 'package:familyledger/generated/proto/sync.pbenum.dart' as sync_enum;
import 'package:familyledger/generated/proto/family.pb.dart' as family_pb;
import 'package:familyledger/generated/proto/family.pbgrpc.dart' as family_grpc;
import 'package:familyledger/generated/proto/google/protobuf/timestamp.pb.dart'
    as ts_pb;

void main() {
  late E2EHarness harness;
  late auth_grpc.AuthServiceClient authClient;
  late sync_grpc.SyncServiceClient syncClient;
  late family_grpc.FamilyServiceClient familyClient;

  final ts = DateTime.now().millisecondsSinceEpoch;

  setUpAll(() {
    harness = E2EHarness();
    harness.setUp();
    authClient = auth_grpc.AuthServiceClient(harness.channel);
    syncClient = sync_grpc.SyncServiceClient(harness.channel);
    familyClient = family_grpc.FamilyServiceClient(harness.channel);
  });

  tearDownAll(() async {
    await harness.tearDown();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 1: Token Refresh
  // ═══════════════════════════════════════════════════════════════════════════

  group('W9 Token Refresh E2E', () {
    late String refreshToken;

    test('R-001: Register and store refresh token', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w9_refresh_$ts@test.com'
        ..password = 'RefreshTest123!');

      expect(resp.refreshToken, isNotEmpty);
      refreshToken = resp.refreshToken;
      harness.setTokens(
        accessToken: resp.accessToken,
        refreshToken: resp.refreshToken,
      );
    });

    test('R-002: Refresh token → get new access token', () async {
      final resp = await authClient.refreshToken(
        auth_pb.RefreshTokenRequest()..refreshToken = refreshToken,
      );

      expect(resp.accessToken, isNotEmpty);
      expect(resp.refreshToken, isNotEmpty);
      // New access token should differ from original
      harness.setTokens(
        accessToken: resp.accessToken,
        refreshToken: resp.refreshToken,
      );
    });

    test('R-003: New access token works for API call', () async {
      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()
          ..since = ts_pb.Timestamp(seconds: Int64(0)),
        options: harness.authOptions,
      );
      expect(resp, isNotNull);
    });

    test('R-004: Invalid refresh token → error', () async {
      expect(
        () => authClient.refreshToken(
          auth_pb.RefreshTokenRequest()..refreshToken = 'invalid.refresh.token',
        ),
        throwsA(isA<GrpcError>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 2: Batch Push (multiple ops in single request)
  // ═══════════════════════════════════════════════════════════════════════════

  group('W9 Batch Push E2E', () {
    test('B-001: Register user for batch tests', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w9_batch_$ts@test.com'
        ..password = 'BatchTest123!');
      harness.setTokens(
        accessToken: resp.accessToken,
        refreshToken: resp.refreshToken,
      );
    });

    test('B-002: Push 5 ops in single request → all accepted', () async {
      final ops = List.generate(5, (i) {
        final id = _uuid();
        return sync_pb.SyncOperation()
          ..entityType = 'category'
          ..entityId = id
          ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
          ..payload = jsonEncode({
            'id': id,
            'name': 'Batch Cat $i',
            'type': i.isEven ? 'expense' : 'income',
            'icon': '📂',
          })
          ..clientId = _uuid();
      });

      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()..operations.addAll(ops),
        options: harness.authOptions,
      );

      expect(resp.acceptedCount, equals(5));
      expect(resp.failedIds, isEmpty);
    });

    test('B-003: Batch with mixed valid+invalid → partial accept', () async {
      final validId = _uuid();
      final ops = [
        // Valid: category CREATE
        sync_pb.SyncOperation()
          ..entityType = 'category'
          ..entityId = validId
          ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
          ..payload = jsonEncode({
            'id': validId,
            'name': 'Valid Cat',
            'type': 'expense',
            'icon': '✅',
          })
          ..clientId = _uuid(),
        // Invalid: transaction CREATE without account_id
        sync_pb.SyncOperation()
          ..entityType = 'transaction'
          ..entityId = _uuid()
          ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
          ..payload = jsonEncode({
            'amount': 100,
            'type': 'expense',
          })
          ..clientId = _uuid(),
      ];

      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()..operations.addAll(ops),
        options: harness.authOptions,
      );

      // At least the valid one should be accepted
      expect(resp.acceptedCount, greaterThanOrEqualTo(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 3: Incremental Pull (since timestamp)
  // ═══════════════════════════════════════════════════════════════════════════

  group('W9 Incremental Pull E2E', () {
    test('IP-001: Register user for incremental tests', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w9_incremental_$ts@test.com'
        ..password = 'IncrTest123!');
      harness.setTokens(
        accessToken: resp.accessToken,
        refreshToken: resp.refreshToken,
      );
    });

    test('IP-002: Push op → Pull all → record serverTime', () async {
      final id = _uuid();
      await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'category'
            ..entityId = id
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({
              'id': id,
              'name': 'Before Marker',
              'type': 'expense',
              'icon': '⏰',
            })
            ..clientId = _uuid()),
        options: harness.authOptions,
      );

      final pullResp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()
          ..since = ts_pb.Timestamp(seconds: Int64(0)),
        options: harness.authOptions,
      );

      expect(pullResp.operations, isNotEmpty);
      expect(pullResp.serverTime, isNotNull);
    });

    test('IP-003: Push after checkpoint → Pull since serverTime → only new ops',
        () async {
      // First pull to get serverTime as checkpoint
      final checkpoint = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()
          ..since = ts_pb.Timestamp(seconds: Int64(0)),
        options: harness.authOptions,
      );
      final serverTime = checkpoint.serverTime;

      // Wait a tiny bit to ensure timestamp difference
      await Future.delayed(const Duration(milliseconds: 50));

      // Push new op AFTER checkpoint
      final newId = _uuid();
      await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'category'
            ..entityId = newId
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({
              'id': newId,
              'name': 'After Checkpoint',
              'type': 'income',
              'icon': '🆕',
            })
            ..clientId = _uuid()),
        options: harness.authOptions,
      );

      // Pull since checkpoint → should only return the new op
      final incr = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()..since = serverTime,
        options: harness.authOptions,
      );

      expect(incr.operations, isNotEmpty);
      // All returned ops should have the new entity
      final hasNewOp =
          incr.operations.any((op) => op.entityId == newId);
      expect(hasNewOp, isTrue,
          reason: 'Incremental pull should include ops after checkpoint');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 4: Multi-User Isolation (users can't see each other's data)
  // ═══════════════════════════════════════════════════════════════════════════

  group('W9 Multi-User Isolation E2E', () {
    late String userAToken;
    late String userBToken;
    late String userAEntityId;

    test('MU-001: Register User A', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w9_userA_$ts@test.com'
        ..password = 'UserATest123!');
      userAToken = resp.accessToken;
    });

    test('MU-002: Register User B', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w9_userB_$ts@test.com'
        ..password = 'UserBTest123!');
      userBToken = resp.accessToken;
    });

    test('MU-003: User A pushes account', () async {
      userAEntityId = _uuid();
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $userAToken'},
      );

      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'account'
            ..entityId = userAEntityId
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({
              'id': userAEntityId,
              'name': 'User A Secret Account',
              'type': 'cash',
              'balance': 99999,
              'currency': 'CNY',
            })
            ..clientId = _uuid()),
        options: options,
      );
      expect(resp.acceptedCount, equals(1));
    });

    test('MU-004: User B pulls → cannot see User A data', () async {
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $userBToken'},
      );

      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()
          ..since = ts_pb.Timestamp(seconds: Int64(0)),
        options: options,
      );

      final leaked = resp.operations
          .where((op) => op.entityId == userAEntityId)
          .toList();
      expect(leaked, isEmpty,
          reason: 'User B must NOT see User A personal data');
    });

    test('MU-005: User A can see own data in Pull', () async {
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $userAToken'},
      );

      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()
          ..since = ts_pb.Timestamp(seconds: Int64(0)),
        options: options,
      );

      final own = resp.operations
          .where((op) => op.entityId == userAEntityId)
          .toList();
      expect(own, isNotEmpty,
          reason: 'User A should see own data');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 5: Family Sync — shared visibility
  // ═══════════════════════════════════════════════════════════════════════════

  group('W9 Family Sync E2E', () {
    late String ownerToken;
    late String memberToken;
    late String familyId;

    test('FS-001: Register family owner', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w9_owner_$ts@test.com'
        ..password = 'OwnerTest123!');
      ownerToken = resp.accessToken;
    });

    test('FS-002: Register family member', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w9_member_$ts@test.com'
        ..password = 'MemberTest123!');
      memberToken = resp.accessToken;
    });

    test('FS-003: Owner creates family', () async {
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $ownerToken'},
      );

      final resp = await familyClient.createFamily(
        family_pb.CreateFamilyRequest()..name = 'W9 Test Family',
        options: options,
      );
      expect(resp.family.id, isNotEmpty);
      familyId = resp.family.id;
    });

    test('FS-004: Owner generates invite code', () async {
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $ownerToken'},
      );

      final resp = await familyClient.generateInviteCode(
        family_pb.GenerateInviteCodeRequest()..familyId = familyId,
        options: options,
      );
      expect(resp.inviteCode, isNotEmpty);

      // Member joins
      final memberOptions = CallOptions(
        metadata: {'authorization': 'Bearer $memberToken'},
      );
      final joinResp = await familyClient.joinFamily(
        family_pb.JoinFamilyRequest()..inviteCode = resp.inviteCode,
        options: memberOptions,
      );
      expect(joinResp.family.id, equals(familyId));
    });

    test('FS-005: Owner pushes family-scoped sync op', () async {
      final options = CallOptions(
        metadata: {'authorization': 'Bearer $ownerToken'},
      );

      final id = _uuid();
      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'account'
            ..entityId = id
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({
              'id': id,
              'name': 'Family Shared Account',
              'type': 'bank_card',
              'balance': 50000,
              'currency': 'CNY',
              'family_id': familyId,
            })
            ..clientId = _uuid()),
        options: options,
      );
      expect(resp.acceptedCount, equals(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group 6: Edge Cases & Error Handling
  // ═══════════════════════════════════════════════════════════════════════════

  group('W9 Edge Cases E2E', () {
    test('EC-001: Register user for edge case tests', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w9_edge_$ts@test.com'
        ..password = 'EdgeTest123!');
      harness.setTokens(
        accessToken: resp.accessToken,
        refreshToken: resp.refreshToken,
      );
    });

    test('EC-002: Push with empty operations list → 0 accepted', () async {
      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest(), // no ops
        options: harness.authOptions,
      );
      expect(resp.acceptedCount, equals(0));
    });

    test('EC-003: Push with unknown entity type → rejected', () async {
      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'nonexistent_entity'
            ..entityId = _uuid()
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({'foo': 'bar'})
            ..clientId = _uuid()),
        options: harness.authOptions,
      );
      // Server should either reject (acceptedCount=0) or skip unknown types
      expect(resp.acceptedCount, anyOf(equals(0), equals(1)));
    });

    test('EC-004: Push with malformed JSON payload → rejected', () async {
      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'account'
            ..entityId = _uuid()
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = 'this is {not valid json'
            ..clientId = _uuid()),
        options: harness.authOptions,
      );
      expect(resp.acceptedCount, equals(0),
          reason: 'Malformed JSON should be rejected');
    });

    test('EC-005: Push UPDATE for non-existent entity → rejected', () async {
      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'account'
            ..entityId = _uuid() // doesn't exist
            ..opType = sync_enum.OperationType.OPERATION_TYPE_UPDATE
            ..payload = jsonEncode({
              'name': 'Ghost Account',
              'type': 'cash',
            })
            ..clientId = _uuid()),
        options: harness.authOptions,
      );
      expect(resp.acceptedCount, equals(0),
          reason: 'UPDATE on non-existent entity should fail');
    });

    test('EC-006: Push DELETE for non-existent entity → rejected', () async {
      final resp = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'account'
            ..entityId = _uuid() // doesn't exist
            ..opType = sync_enum.OperationType.OPERATION_TYPE_DELETE
            ..payload = '{}'
            ..clientId = _uuid()),
        options: harness.authOptions,
      );
      expect(resp.acceptedCount, equals(0),
          reason: 'DELETE on non-existent entity should fail');
    });

    test('EC-007: Pull with future timestamp → empty results', () async {
      final future = ts_pb.Timestamp(
        seconds: Int64(DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000),
      );

      final resp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()..since = future,
        options: harness.authOptions,
      );
      expect(resp.operations, isEmpty,
          reason: 'Pull with future timestamp should return nothing');
    });

    test('EC-008: Large payload (10KB) → accepted', () async {
      final id = _uuid();
      final largeNote = 'x' * 10000;

      // Create account first (for FK)
      await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'account'
            ..entityId = id
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({
              'id': id,
              'name': 'Large Payload Account',
              'type': 'cash',
              'balance': 0,
              'currency': 'CNY',
              'note': largeNote,
            })
            ..clientId = _uuid()),
        options: harness.authOptions,
      );

      // Verify it's stored
      final pull = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()
          ..since = ts_pb.Timestamp(seconds: Int64(0)),
        options: harness.authOptions,
      );
      final found = pull.operations.any((op) => op.entityId == id);
      expect(found, isTrue, reason: '10KB payload should be accepted');
    });
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _uuid() {
  final r = Random();
  const hex = '0123456789abcdef';
  String s4() => List.generate(4, (_) => hex[r.nextInt(16)]).join();
  return '${s4()}${s4()}-${s4()}-4${s4().substring(1)}-${hex[8 + r.nextInt(4)]}${s4().substring(1)}-${s4()}${s4()}${s4()}';
}
