// W11 Attack Tests — Bug Hunting
//
// These tests are designed to FIND BUGS, not to confirm happy paths.
// Each test targets a specific vulnerability hypothesis.
//
// Categories:
// 1. DATA ISOLATION: Can user A access user B's data?
// 2. BALANCE INTEGRITY: Can we make balance go negative / overflow?
// 3. SYNC INCONSISTENCY: gRPC vs sync_operations divergence
// 4. PERMISSION BYPASS: Can restricted users escalate?
// 5. INPUT ABUSE: Edge cases in amounts, IDs, payloads

import 'dart:convert';
import 'dart:math';

import 'package:grpc/grpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';

import 'harness.dart';
import 'package:familyledger/generated/proto/auth.pb.dart' as auth_pb;
import 'package:familyledger/generated/proto/auth.pbgrpc.dart' as auth_grpc;
import 'package:familyledger/generated/proto/transaction.pb.dart' as txn_pb;
import 'package:familyledger/generated/proto/transaction.pbgrpc.dart'
    as txn_grpc;
import 'package:familyledger/generated/proto/transaction.pbenum.dart'
    as txn_enum;
import 'package:familyledger/generated/proto/sync.pb.dart' as sync_pb;
import 'package:familyledger/generated/proto/sync.pbgrpc.dart' as sync_grpc;
import 'package:familyledger/generated/proto/sync.pbenum.dart' as sync_enum;
import 'package:familyledger/generated/proto/family.pb.dart' as family_pb;
import 'package:familyledger/generated/proto/family.pbgrpc.dart'
    as family_grpc;
import 'package:familyledger/generated/proto/account.pb.dart' as acct_pb;
import 'package:familyledger/generated/proto/account.pbgrpc.dart'
    as acct_grpc;
import 'package:familyledger/generated/proto/google/protobuf/timestamp.pb.dart'
    as ts_pb;

String _uuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

void main() {
  final ts = DateTime.now().millisecondsSinceEpoch;

  late ClientChannel channel;
  late auth_grpc.AuthServiceClient authClient;
  late txn_grpc.TransactionServiceClient txnClient;
  late acct_grpc.AccountServiceClient acctClient;
  late sync_grpc.SyncServiceClient syncClient;
  late family_grpc.FamilyServiceClient familyClient;

  setUpAll(() {
    final config = HarnessConfig();
    channel = ClientChannel(
      config.grpcHost,
      port: config.grpcPort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    authClient = auth_grpc.AuthServiceClient(channel);
    txnClient = txn_grpc.TransactionServiceClient(channel);
    acctClient = acct_grpc.AccountServiceClient(channel);
    syncClient = sync_grpc.SyncServiceClient(channel);
    familyClient = family_grpc.FamilyServiceClient(channel);
  });

  tearDownAll(() async {
    await channel.shutdown();
  });

  // ═══════════════════════════════════════════════════════════════════
  // 1. DATA ISOLATION — Cross-user access attacks
  // ═══════════════════════════════════════════════════════════════════
  group('DATA ISOLATION', () {
    late String userAToken;
    late String userBToken;
    late String userAAccountId;
    late String userATxnId;
    late String categoryId;

    test('Setup: Two independent users with transactions', () async {
      // Register user A
      final respA = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'attack_a_$ts@test.com'
        ..password = 'Attack_A_123!');
      userAToken = respA.accessToken;

      // Register user B
      final respB = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'attack_b_$ts@test.com'
        ..password = 'Attack_B_123!');
      userBToken = respB.accessToken;

      final aOpts = CallOptions(
        metadata: {'authorization': 'Bearer $userAToken'},
      );

      // Create account with sufficient balance for A
      final newAcctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'Isolation Test Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_CASH
          ..currency = 'CNY'
          ..initialBalance = Int64(100000),
        options: aOpts,
      );
      userAAccountId = newAcctResp.account.id;

      // Get category
      final catResp = await txnClient.getCategories(
        txn_pb.GetCategoriesRequest()
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        options: aOpts,
      );
      categoryId = catResp.categories.first.id;

      // A creates a transaction
      final txnResp = await txnClient.createTransaction(
        txn_pb.CreateTransactionRequest()
          ..accountId = userAAccountId
          ..categoryId = categoryId
          ..amount = Int64(10000)
          ..currency = 'CNY'
          ..amountCny = Int64(10000)
          ..exchangeRate = 1.0
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = 'Secret purchase A',
        options: aOpts,
      );
      userATxnId = txnResp.transaction.id;
    });

    test('ISOLATION-001: User B cannot delete User A\'s transaction', () async {
      final bOpts = CallOptions(
        metadata: {'authorization': 'Bearer $userBToken'},
      );

      try {
        await txnClient.deleteTransaction(
          txn_pb.DeleteTransactionRequest()..transactionId = userATxnId,
          options: bOpts,
        );
        fail('BUG: User B was able to delete User A\'s transaction!');
      } on GrpcError catch (e) {
        expect(
            e.code == StatusCode.permissionDenied ||
                e.code == StatusCode.notFound,
            isTrue,
            reason:
                'Should reject with PermissionDenied or NotFound, got: ${e.code} ${e.message}');
      }
    });

    test('ISOLATION-002: User B cannot update User A\'s transaction', () async {
      final bOpts = CallOptions(
        metadata: {'authorization': 'Bearer $userBToken'},
      );

      try {
        await txnClient.updateTransaction(
          txn_pb.UpdateTransactionRequest()
            ..transactionId = userATxnId
            ..amount = Int64(1)
            ..note = 'Hacked by B',
          options: bOpts,
        );
        fail('BUG: User B was able to update User A\'s transaction!');
      } on GrpcError catch (e) {
        expect(
            e.code == StatusCode.permissionDenied ||
                e.code == StatusCode.notFound,
            isTrue,
            reason:
                'Should reject B modifying A\'s transaction, got: ${e.code}');
      }
    });

    test('ISOLATION-003: User B cannot create transaction on A\'s account',
        () async {
      final bOpts = CallOptions(
        metadata: {'authorization': 'Bearer $userBToken'},
      );

      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = userAAccountId // A's account!
            ..categoryId = categoryId
            ..amount = Int64(1)
            ..currency = 'CNY'
            ..amountCny = Int64(1)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
            ..note = 'B stealing from A',
          options: bOpts,
        );
        fail('BUG: User B created a transaction on User A\'s account!');
      } on GrpcError catch (e) {
        expect(
            e.code == StatusCode.permissionDenied ||
                e.code == StatusCode.notFound,
            isTrue,
            reason: 'Should reject B using A\'s account, got: ${e.code}');
      }
    });

    test('ISOLATION-004: User B cannot list A\'s transactions', () async {
      final bOpts = CallOptions(
        metadata: {'authorization': 'Bearer $userBToken'},
      );

      // B tries to list transactions for A's account
      final listResp = await txnClient.listTransactions(
        txn_pb.ListTransactionsRequest()..accountId = userAAccountId,
        options: bOpts,
      );

      // Should either error or return empty (not A's data)
      final leakedTxns = listResp.transactions
          .where((t) => t.note.contains('Secret purchase A'));
      expect(leakedTxns, isEmpty,
          reason:
              'BUG: B can see A\'s transactions by specifying A\'s accountId!');
    });

    test(
        'ISOLATION-005: User B Pull with A\'s familyId should be denied',
        () async {
      final bOpts = CallOptions(
        metadata: {'authorization': 'Bearer $userBToken'},
      );

      // B tries to pull using a random familyId (if they somehow know it)
      // First create a family for A
      final aOpts = CallOptions(
        metadata: {'authorization': 'Bearer $userAToken'},
      );
      final familyResp = await familyClient.createFamily(
        family_pb.CreateFamilyRequest()..name = 'A Private Family $ts',
        options: aOpts,
      );
      final aFamilyId = familyResp.family.id;

      // B tries to pull A's family data
      try {
        await syncClient.pullChanges(
          sync_pb.PullChangesRequest()
            ..since = ts_pb.Timestamp(seconds: Int64(0))
            ..familyId = aFamilyId
            ..clientId = 'attacker-${_uuid()}',
          options: bOpts,
        );
        fail('BUG: B can pull A\'s family data without being a member!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.permissionDenied),
            reason: 'Should deny non-member from pulling family data');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 2. BALANCE INTEGRITY — Financial consistency attacks
  // ═══════════════════════════════════════════════════════════════════
  group('BALANCE INTEGRITY', () {
    late String token;
    late String accountId;
    late String categoryId;

    test('Setup: Fresh user with known balance', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'balance_attack_$ts@test.com'
        ..password = 'Balance_123!');
      token = resp.accessToken;

      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      // Create account with initial balance = 10000 (100.00 CNY)
      final acctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'Balance Test Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_CASH
          ..currency = 'CNY'
          ..initialBalance = Int64(10000),
        options: opts,
      );
      accountId = acctResp.account.id;

      // Get category
      final catResp = await txnClient.getCategories(
        txn_pb.GetCategoriesRequest()
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        options: opts,
      );
      categoryId = catResp.categories.first.id;
    });

    test('BALANCE-001: Expense exceeding balance (overdraft allowed?)',
        () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      // Try to spend 50000 when balance is only 10000
      // After fix: non-credit-card accounts reject overdraft
      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = accountId
            ..categoryId = categoryId
            ..amount = Int64(50000) // 500 CNY, balance is only 100 CNY
            ..currency = 'CNY'
            ..amountCny = Int64(50000)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
            ..note = 'Overdraft test',
          options: opts,
        );
        fail('BUG: Cash account allowed overdraft!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.failedPrecondition),
            reason: 'Cash account should reject overdraft with FailedPrecondition');
      }
    });

    test('BALANCE-002: INT64_MAX amount (overflow attack)', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      // Try to create transaction with maximum int64 value
      // After fix: amount > 99999999999 (10 billion) is rejected
      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = accountId
            ..categoryId = categoryId
            ..amount = Int64(9223372036854775807) // max int64
            ..currency = 'CNY'
            ..amountCny = Int64(9223372036854775807)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_INCOME
            ..note = 'Overflow test',
          options: opts,
        );
        fail('BUG: INT64_MAX amount was accepted!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.invalidArgument),
            reason: 'Amount exceeding 10 billion should be rejected with InvalidArgument');
      }
    });

    test('BALANCE-003: Zero amount transaction', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = accountId
            ..categoryId = categoryId
            ..amount = Int64(0) // Zero!
            ..currency = 'CNY'
            ..amountCny = Int64(0)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
            ..note = 'Zero amount',
          options: opts,
        );
        fail(
            'BUG: Zero amount transaction should be rejected but was accepted!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.invalidArgument),
            reason: 'Zero amount should be InvalidArgument');
      }
    });

    test('BALANCE-004: Negative amount transaction', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = accountId
            ..categoryId = categoryId
            ..amount = Int64(-5000) // Negative!
            ..currency = 'CNY'
            ..amountCny = Int64(-5000)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
            ..note = 'Negative amount',
          options: opts,
        );
        fail(
            'BUG: Negative amount transaction should be rejected but was accepted!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.invalidArgument),
            reason: 'Negative amount should be InvalidArgument');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 3. SYNC INCONSISTENCY — gRPC ↔ sync_operations divergence
  // ═══════════════════════════════════════════════════════════════════
  group('SYNC INCONSISTENCY', () {
    late String token;
    late String accountId;
    late String categoryId;

    test('Setup: User with account', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'sync_attack_$ts@test.com'
        ..password = 'Sync_Attack_123!');
      token = resp.accessToken;

      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      final acctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'Sync Test Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_CASH
          ..currency = 'CNY'
          ..initialBalance = Int64(100000),
        options: opts,
      );
      accountId = acctResp.account.id;

      final catResp = await txnClient.getCategories(
        txn_pb.GetCategoriesRequest()
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        options: opts,
      );
      categoryId = catResp.categories.first.id;
    });

    test(
        'BUG-SYNC-001: CreateTransaction via gRPC is invisible to PullChanges',
        () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      // Create via gRPC
      final txnResp = await txnClient.createTransaction(
        txn_pb.CreateTransactionRequest()
          ..accountId = accountId
          ..categoryId = categoryId
          ..amount = Int64(7777)
          ..currency = 'CNY'
          ..amountCny = Int64(7777)
          ..exchangeRate = 1.0
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = 'gRPC-only transaction',
        options: opts,
      );
      final txnId = txnResp.transaction.id;

      // Try to find it via PullChanges
      final pullResp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()
          ..since = ts_pb.Timestamp(seconds: Int64(0))
          ..clientId = 'pull-device-${_uuid()}',
        options: opts,
      );

      final found = pullResp.operations.any((op) => op.entityId == txnId);
      // THIS IS THE BUG: CreateTransaction does NOT write to sync_operations
      // So another device of the same user cannot discover this transaction via Pull
      expect(found, isTrue,
          reason:
              'BUG: Transaction created via gRPC is NOT visible in PullChanges! '
              'This means multi-device sync is broken for gRPC-created transactions. '
              'A user creating a transaction on web cannot sync it to their mobile app.');
    });

    test(
        'BUG-SYNC-002: Family member\'s gRPC transaction invisible to family Pull',
        () async {
      // This is the family variant of BUG-SYNC-001
      final ownerResp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'sync_owner_$ts@test.com'
        ..password = 'Sync_Owner_123!');
      final ownerToken = ownerResp.accessToken;
      final ownerOpts = CallOptions(
        metadata: {'authorization': 'Bearer $ownerToken'},
      );

      final memberResp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'sync_member_$ts@test.com'
        ..password = 'Sync_Member_123!');
      final memberToken = memberResp.accessToken;
      final memberOpts = CallOptions(
        metadata: {'authorization': 'Bearer $memberToken'},
      );

      // Create family
      final famResp = await familyClient.createFamily(
        family_pb.CreateFamilyRequest()..name = 'Sync Bug Family $ts',
        options: ownerOpts,
      );
      final familyId = famResp.family.id;

      // Invite + join
      final invResp = await familyClient.generateInviteCode(
        family_pb.GenerateInviteCodeRequest()..familyId = familyId,
        options: ownerOpts,
      );
      await familyClient.joinFamily(
        family_pb.JoinFamilyRequest()..inviteCode = invResp.inviteCode,
        options: memberOpts,
      );

      // Owner creates family account
      final acctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'Sync Bug Family Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_CASH
          ..currency = 'CNY'
          ..initialBalance = Int64(100000)
          ..familyId = familyId,
        options: ownerOpts,
      );
      final familyAcctId = acctResp.account.id;

      // Get member's category
      final catResp = await txnClient.getCategories(
        txn_pb.GetCategoriesRequest()
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        options: memberOpts,
      );
      final catId = catResp.categories.first.id;

      // Member creates transaction via gRPC (not sync Push)
      final txnResp = await txnClient.createTransaction(
        txn_pb.CreateTransactionRequest()
          ..accountId = familyAcctId
          ..categoryId = catId
          ..amount = Int64(9999)
          ..currency = 'CNY'
          ..amountCny = Int64(9999)
          ..exchangeRate = 1.0
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = 'Member gRPC txn - invisible?',
        options: memberOpts,
      );
      final txnId = txnResp.transaction.id;

      // Owner tries to see it via Pull
      final pullResp = await syncClient.pullChanges(
        sync_pb.PullChangesRequest()
          ..since = ts_pb.Timestamp(seconds: Int64(0))
          ..familyId = familyId
          ..clientId = 'owner-device-${_uuid()}',
        options: ownerOpts,
      );

      final found = pullResp.operations.any((op) => op.entityId == txnId);
      expect(found, isTrue,
          reason:
              'BUG: Member\'s gRPC transaction invisible to owner via family Pull! '
              'Family members cannot see each other\'s gRPC-created transactions. '
              'Only PushOperations-created transactions appear in PullChanges.');
    });

    test('SYNC-003: Push with duplicate clientId is idempotent', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      final entityId = _uuid();
      final clientId = 'idempotent-${_uuid()}';

      // Push first time
      final resp1 = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'account'
            ..entityId = entityId
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({
              'id': entityId,
              'name': 'Idempotent Account',
              'type': 'cash',
              'balance': 0,
              'currency': 'CNY',
            })
            ..clientId = clientId),
        options: opts,
      );
      expect(resp1.acceptedCount, equals(1));

      // Push same clientId again (simulating retry)
      final resp2 = await syncClient.pushOperations(
        sync_pb.PushOperationsRequest()
          ..operations.add(sync_pb.SyncOperation()
            ..entityType = 'account'
            ..entityId = entityId
            ..opType = sync_enum.OperationType.OPERATION_TYPE_CREATE
            ..payload = jsonEncode({
              'id': entityId,
              'name': 'Idempotent Account',
              'type': 'cash',
              'balance': 0,
              'currency': 'CNY',
            })
            ..clientId = clientId),
        options: opts,
      );
      // Should be accepted (idempotent) but NOT duplicate the entity
      expect(resp2.acceptedCount, equals(1),
          reason: 'Duplicate push should be accepted idempotently');

      // Verify only one account was created
      final acctResp = await acctClient.listAccounts(
        acct_pb.ListAccountsRequest(),
        options: opts,
      );
      final matches =
          acctResp.accounts.where((a) => a.name == 'Idempotent Account');
      expect(matches.length, equals(1),
          reason:
              'BUG: Duplicate clientId created multiple accounts! Idempotency broken.');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 4. PERMISSION BYPASS — Escalation attacks
  // ═══════════════════════════════════════════════════════════════════
  group('PERMISSION BYPASS', () {
    late String ownerToken;
    late String memberToken;
    late String familyId;
    late String familyAccountId;
    late String memberTxnId;

    test('Setup: Family with owner account + member transaction', () async {
      final ownerResp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'perm_owner_$ts@test.com'
        ..password = 'Perm_Owner_123!');
      ownerToken = ownerResp.accessToken;
      final ownerOpts = CallOptions(
        metadata: {'authorization': 'Bearer $ownerToken'},
      );

      final memberResp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'perm_member_$ts@test.com'
        ..password = 'Perm_Member_123!');
      memberToken = memberResp.accessToken;
      final memberOpts = CallOptions(
        metadata: {'authorization': 'Bearer $memberToken'},
      );

      // Create family
      final famResp = await familyClient.createFamily(
        family_pb.CreateFamilyRequest()..name = 'Perm Attack Family $ts',
        options: ownerOpts,
      );
      familyId = famResp.family.id;

      // Invite + join
      final invResp = await familyClient.generateInviteCode(
        family_pb.GenerateInviteCodeRequest()..familyId = familyId,
        options: ownerOpts,
      );
      await familyClient.joinFamily(
        family_pb.JoinFamilyRequest()..inviteCode = invResp.inviteCode,
        options: memberOpts,
      );

      // Owner creates family account
      final acctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'Perm Test Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_CASH
          ..currency = 'CNY'
          ..initialBalance = Int64(100000)
          ..familyId = familyId,
        options: ownerOpts,
      );
      familyAccountId = acctResp.account.id;

      // Member creates a transaction (has can_create)
      final catResp = await txnClient.getCategories(
        txn_pb.GetCategoriesRequest()
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        options: memberOpts,
      );
      final catId = catResp.categories.first.id;

      final txnResp = await txnClient.createTransaction(
        txn_pb.CreateTransactionRequest()
          ..accountId = familyAccountId
          ..categoryId = catId
          ..amount = Int64(5000)
          ..currency = 'CNY'
          ..amountCny = Int64(5000)
          ..exchangeRate = 1.0
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = 'Member legitimate expense',
        options: memberOpts,
      );
      memberTxnId = txnResp.transaction.id;
    });

    test('PERM-001: Member cannot edit own transaction (no can_edit)',
        () async {
      final memberOpts = CallOptions(
        metadata: {'authorization': 'Bearer $memberToken'},
      );

      try {
        await txnClient.updateTransaction(
          txn_pb.UpdateTransactionRequest()
            ..transactionId = memberTxnId
            ..note = 'Member trying to edit',
          options: memberOpts,
        );
        fail('BUG: Member without can_edit was able to edit transaction on family account!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.permissionDenied),
            reason: 'Member without can_edit should be denied even for own transactions on family accounts');
      }
    });

    test('PERM-002: Member cannot delete own transaction (no can_delete)',
        () async {
      final memberOpts = CallOptions(
        metadata: {'authorization': 'Bearer $memberToken'},
      );

      try {
        await txnClient.deleteTransaction(
          txn_pb.DeleteTransactionRequest()..transactionId = memberTxnId,
          options: memberOpts,
        );
        fail('BUG: Member without can_delete was able to delete transaction on family account!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.permissionDenied),
            reason: 'Member without can_delete should be denied even for own transactions on family accounts');
      }
    });

    test('PERM-003: Member cannot create family account (no can_manage_accounts)',
        () async {
      final memberOpts = CallOptions(
        metadata: {'authorization': 'Bearer $memberToken'},
      );

      try {
        await acctClient.createAccount(
          acct_pb.CreateAccountRequest()
            ..name = 'Member Sneaky Account'
            ..type = acct_pb.AccountType.ACCOUNT_TYPE_CASH
            ..currency = 'CNY'
            ..familyId = familyId,
          options: memberOpts,
        );
        fail('BUG: Member without can_manage_accounts created a family account!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.permissionDenied),
            reason: 'Should deny member from creating family accounts');
      }
    });

    test('PERM-004: Member cannot set own permissions (privilege escalation)',
        () async {
      final memberOpts = CallOptions(
        metadata: {'authorization': 'Bearer $memberToken'},
      );

      // Get member's own user ID from a transaction listing
      try {
        await familyClient.setMemberPermissions(
          family_pb.SetMemberPermissionsRequest()
            ..familyId = familyId
            ..userId = '' // will fill dynamically
            ..permissions = (family_pb.MemberPermissions()
              ..canView = true
              ..canCreate = true
              ..canEdit = true
              ..canDelete = true
              ..canManageAccounts = true),
          options: memberOpts,
        );
        fail('BUG: Member was able to escalate own permissions!');
      } on GrpcError catch (e) {
        expect(
            e.code == StatusCode.permissionDenied ||
                e.code == StatusCode.invalidArgument,
            isTrue,
            reason:
                'Non-owner should not be able to set permissions, got: ${e.code}');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 5. INPUT ABUSE — Edge case / malformed input attacks
  // ═══════════════════════════════════════════════════════════════════
  group('INPUT ABUSE', () {
    late String token;
    late String accountId;
    late String categoryId;

    test('Setup: User for input testing', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'input_abuse_$ts@test.com'
        ..password = 'Input_Abuse_123!');
      token = resp.accessToken;

      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      final acctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'Input Test Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_CASH
          ..currency = 'CNY'
          ..initialBalance = Int64(1000000),
        options: opts,
      );
      accountId = acctResp.account.id;

      final catResp = await txnClient.getCategories(
        txn_pb.GetCategoriesRequest()
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        options: opts,
      );
      categoryId = catResp.categories.first.id;
    });

    test('INPUT-001: Empty account_id in CreateTransaction', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = '' // empty!
            ..categoryId = categoryId
            ..amount = Int64(100)
            ..currency = 'CNY'
            ..amountCny = Int64(100)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
          options: opts,
        );
        fail('BUG: Empty account_id was accepted!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.invalidArgument));
      }
    });

    test('INPUT-002: Non-existent UUID as account_id', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = _uuid() // random non-existent
            ..categoryId = categoryId
            ..amount = Int64(100)
            ..currency = 'CNY'
            ..amountCny = Int64(100)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
          options: opts,
        );
        fail('BUG: Non-existent account_id was accepted!');
      } on GrpcError catch (e) {
        expect(
            e.code == StatusCode.notFound ||
                e.code == StatusCode.permissionDenied,
            isTrue,
            reason: 'Non-existent account should return NotFound or PermDenied');
      }
    });

    test('INPUT-003: Non-existent category_id', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = accountId
            ..categoryId = _uuid() // random non-existent category
            ..amount = Int64(100)
            ..currency = 'CNY'
            ..amountCny = Int64(100)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
          options: opts,
        );
        fail('BUG: Non-existent category_id was accepted!');
      } on GrpcError catch (e) {
        // Should fail with FK violation or validation error
        expect(
            e.code == StatusCode.invalidArgument ||
                e.code == StatusCode.notFound ||
                e.code == StatusCode.internal,
            isTrue,
            reason: 'Invalid category should be rejected, got: ${e.code}');
      }
    });

    test('INPUT-004: SQL injection in note field', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      // This shouldn't cause any issues with parameterized queries,
      // but let's verify the system doesn't crash
      final resp = await txnClient.createTransaction(
        txn_pb.CreateTransactionRequest()
          ..accountId = accountId
          ..categoryId = categoryId
          ..amount = Int64(100)
          ..currency = 'CNY'
          ..amountCny = Int64(100)
          ..exchangeRate = 1.0
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = "Robert'); DROP TABLE transactions;--",
        options: opts,
      );
      expect(resp.transaction.id, isNotEmpty);
      expect(resp.transaction.note, contains('DROP TABLE'),
          reason: 'Note should be stored as-is (parameterized query)');
    });

    test('INPUT-005: Extremely long note (10KB)', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      final longNote = 'A' * 10240; // 10KB note — exceeds 1000 char limit

      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = accountId
            ..categoryId = categoryId
            ..amount = Int64(100)
            ..currency = 'CNY'
            ..amountCny = Int64(100)
            ..exchangeRate = 1.0
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
            ..note = longNote,
          options: opts,
        );
        fail('BUG: 10KB note was accepted! Should reject notes > 1000 chars');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.invalidArgument),
            reason: 'Notes exceeding 1000 chars should be rejected with InvalidArgument');
      }
    });

    test('INPUT-006: Foreign currency without amountCny', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      try {
        await txnClient.createTransaction(
          txn_pb.CreateTransactionRequest()
            ..accountId = accountId
            ..categoryId = categoryId
            ..amount = Int64(1000)
            ..currency = 'USD'
            ..amountCny = Int64(0) // missing CNY amount!
            ..exchangeRate = 7.2
            ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
            ..note = 'USD without CNY conversion',
          options: opts,
        );
        fail(
            'BUG: Foreign currency transaction accepted without amountCny!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.invalidArgument),
            reason: 'Foreign currency must provide amountCny');
      }
    });

    test('INPUT-007: Delete non-existent transaction', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      try {
        await txnClient.deleteTransaction(
          txn_pb.DeleteTransactionRequest()..transactionId = _uuid(),
          options: opts,
        );
        fail('BUG: Deleting non-existent transaction did not error!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.notFound),
            reason: 'Non-existent transaction should return NotFound');
      }
    });

    test('INPUT-008: Update non-existent transaction', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $token'},
      );

      try {
        await txnClient.updateTransaction(
          txn_pb.UpdateTransactionRequest()
            ..transactionId = _uuid()
            ..note = 'Ghost update',
          options: opts,
        );
        fail('BUG: Updating non-existent transaction did not error!');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.notFound),
            reason: 'Non-existent transaction should return NotFound');
      }
    });
  });
}
